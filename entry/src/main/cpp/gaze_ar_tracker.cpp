/**
 * Native AR Engine face tracker for the gaze page turn feature.
 *
 * Uses the HMS AREngine C API "human perception" session (no rendering
 * surface required): a FACE-type front-camera session is created, and a
 * dedicated native pump thread drives HMS_AREngine_ARSession_Update at
 * ~30 Hz so the JS thread never blocks on frame availability. Each update
 * acquires the tracked face's blendshape set and extracts the eyeball
 * direction coefficients (left/right eyeball up/down/left/right) plus the
 * face center pose quaternion; the latest snapshot is stored under a mutex
 * and read cheaply from ArkTS through readSample().
 *
 * The ArkTS layer maps the snapshot onto the existing GazeSample pipeline
 * (pitch from the pose quaternion, eyeCenterY synthesized from the eyeball
 * down/up coefficients), so the engine's calibration/servo/threshold logic
 * is reused unchanged and the faceDetector camera pipeline remains the
 * fallback for devices without AREngine support.
 */
#include <ar/ar_engine_core.h>
#include <napi/native_api.h>
#include <atomic>
#include <chrono>
#include <cmath>
#include <mutex>
#include <thread>

namespace {

/** Eyeball/pose sample from the most recent tracked face; guarded by the state mutex. */
struct GazeArSnapshot {
    bool hasFace = false;
    int64_t frameSequence = 0;
    int64_t lossSequence = 0;
    AREngine_ARStatus status = ARENGINE_SUCCESS;
    /** Averaged left/right eyeball blendshape coefficients (typically 0..1). */
    float eyeUp = 0.0f;
    float eyeDown = 0.0f;
    float eyeLeft = 0.0f;
    float eyeRight = 0.0f;
    /** Face center pose quaternion (qx, qy, qz, qw). */
    float quat[4] = {0.0f, 0.0f, 0.0f, 1.0f};
    /** Euler pitch extracted from the quaternion, degrees; used relative to a baseline. */
    float headPitchDeg = 0.0f;
};

struct GazeArTrackerState {
    std::mutex mutex;
    AREngine_ARSession *session = nullptr;
    AREngine_ARFrame *frame = nullptr;
    std::thread pump;
    std::atomic<bool> running{false};
    GazeArSnapshot latest;
};

GazeArTrackerState g_tracker;

/** Tait-Bryan (ZYX) pitch from a quaternion. Only used relative to a calibration baseline. */
float PitchFromQuat(const float *q)
{
    const float qx = q[0];
    const float qy = q[1];
    const float qz = q[2];
    const float qw = q[3];
    const float sinp = 2.0f * (qw * qy - qz * qx);
    if (std::fabs(sinp) >= 1.0f) {
        return std::copysign(90.0f, sinp);
    }
    return std::asin(sinp) * (180.0f / 3.14159265f);
}

/** Reads eyeball blendshape coefficients and the face center pose into the snapshot. */
void CollectFace(AREngine_ARSession *session, AREngine_ARFace *face, GazeArSnapshot &snapshot)
{
    snapshot.hasFace = true;
    AREngine_ARFaceBlendShapes *shapes = nullptr;
    if (HMS_AREngine_ARFace_AcquireBlendShapes(session, face, &shapes) == ARENGINE_SUCCESS && shapes != nullptr) {
        int32_t count = 0;
        const float *data = nullptr;
        const AREngine_ARAnimojiBlendShape *types = nullptr;
        if (HMS_AREngine_ARFaceBlendShapes_GetCount(session, shapes, &count) == ARENGINE_SUCCESS && count > 0 &&
            HMS_AREngine_ARFaceBlendShapes_AcquireData(session, shapes, &data) == ARENGINE_SUCCESS && data != nullptr &&
            HMS_AREngine_ARFaceBlendShapes_AcquireTypes(session, shapes, &types) == ARENGINE_SUCCESS &&
            types != nullptr) {
            float upSum = 0.0f;
            float downSum = 0.0f;
            float leftSum = 0.0f;
            float rightSum = 0.0f;
            for (int32_t i = 0; i < count; i++) {
                const float value = data[i];
                switch (types[i]) {
                    case ARENGINE_ARANIMOJI_LEFT_EYEBALL_UP:
                    case ARENGINE_ARANIMOJI_RIGHT_EYEBALL_UP:
                        upSum += value;
                        break;
                    case ARENGINE_ARANIMOJI_LEFT_EYEBALL_DOWN:
                    case ARENGINE_ARANIMOJI_RIGHT_EYEBALL_DOWN:
                        downSum += value;
                        break;
                    case ARENGINE_ARANIMOJI_LEFT_EYEBALL_LEFT:
                    case ARENGINE_ARANIMOJI_RIGHT_EYEBALL_LEFT:
                        leftSum += value;
                        break;
                    case ARENGINE_ARANIMOJI_LEFT_EYEBALL_RIGHT:
                    case ARENGINE_ARANIMOJI_RIGHT_EYEBALL_RIGHT:
                        rightSum += value;
                        break;
                    default:
                        break;
                }
            }
            snapshot.eyeUp = upSum / 2.0f;
            snapshot.eyeDown = downSum / 2.0f;
            snapshot.eyeLeft = leftSum / 2.0f;
            snapshot.eyeRight = rightSum / 2.0f;
        }
        HMS_AREngine_ARFaceBlendShapes_Release(shapes);
    }
    AREngine_ARPose *pose = nullptr;
    if (HMS_AREngine_ARPose_Create(session, nullptr, 0, &pose) == ARENGINE_SUCCESS && pose != nullptr) {
        if (HMS_AREngine_ARFace_GetCenterPose(session, face, pose) == ARENGINE_SUCCESS) {
            float raw[7] = {0.0f};
            if (HMS_AREngine_ARPose_GetPoseRaw(session, pose, raw, 7) == ARENGINE_SUCCESS) {
                snapshot.quat[0] = raw[0];
                snapshot.quat[1] = raw[1];
                snapshot.quat[2] = raw[2];
                snapshot.quat[3] = raw[3];
                snapshot.headPitchDeg = PitchFromQuat(snapshot.quat);
            }
        }
        HMS_AREngine_ARPose_Destroy(pose);
    }
}

/** Pump thread body: drives Update at ~30 Hz and refreshes the latest snapshot. */
void PumpLoop()
{
    AREngine_ARSession *session = nullptr;
    AREngine_ARFrame *frame = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_tracker.mutex);
        session = g_tracker.session;
        frame = g_tracker.frame;
    }
    int64_t lastFrameTimestampNs = 0;
    int64_t frameSequence = 0;
    int64_t lossSequence = 0;
    bool previousUsable = false;
    while (g_tracker.running.load()) {
        GazeArSnapshot snapshot;
        snapshot.status = HMS_AREngine_ARSession_Update(session, frame);
        int64_t timestampNs = 0;
        if (snapshot.status == ARENGINE_SUCCESS) {
            snapshot.status = HMS_AREngine_ARFrame_GetTimestamp(session, frame, &timestampNs);
        }
        if (snapshot.status == ARENGINE_SUCCESS && timestampNs > 0) {
            // LATEST can return the preceding frame even on success. A
            // successful poll is not evidence of a distinct camera sample.
            if (timestampNs <= lastFrameTimestampNs) {
                std::this_thread::sleep_for(std::chrono::milliseconds(33));
                continue;
            }
            lastFrameTimestampNs = timestampNs;
            snapshot.frameSequence = ++frameSequence;
            AREngine_ARTrackableList *list = nullptr;
            if (HMS_AREngine_ARTrackableList_Create(session, &list) == ARENGINE_SUCCESS && list != nullptr) {
                if (HMS_AREngine_ARFrame_GetUpdatedTrackables(session, frame, ARENGINE_TRACKABLE_FACE, list) ==
                    ARENGINE_SUCCESS) {
                    int32_t size = 0;
                    HMS_AREngine_ARTrackableList_GetSize(session, list, &size);
                    for (int32_t i = 0; i < size; i++) {
                        AREngine_ARTrackable *trackable = nullptr;
                        if (HMS_AREngine_ARTrackableList_AcquireItem(session, list, i, &trackable) !=
                            ARENGINE_SUCCESS || trackable == nullptr) {
                            continue;
                        }
                        AREngine_ARTrackingState state = ARENGINE_TRACKING_STATE_STOPPED;
                        HMS_AREngine_ARTrackable_GetTrackingState(session, trackable, &state);
                        // ARFace is the same tracked object as ARTrackable (ArkTS: ARFace extends ARTrackable).
                        if (state == ARENGINE_TRACKING_STATE_TRACKING) {
                            CollectFace(session, reinterpret_cast<AREngine_ARFace *>(trackable), snapshot);
                        }
                        HMS_AREngine_ARTrackable_Release(trackable);
                    }
                }
                HMS_AREngine_ARTrackableList_Destroy(list);
            }
        }
        // Preserve interruptions even if the next good frame reaches ArkTS
        // before the polling timer observes this invalid snapshot.
        if (previousUsable && !snapshot.hasFace) ++lossSequence;
        previousUsable = snapshot.hasFace;
        snapshot.lossSequence = lossSequence;
        {
            std::lock_guard<std::mutex> lock(g_tracker.mutex);
            g_tracker.latest = snapshot;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(snapshot.status == ARENGINE_SUCCESS ? 33 : 66));
    }
}

napi_value IsSupported(napi_env env, napi_callback_info info)
{
    (void)info;
    const AREngine_ARStatus status = HMS_AREngine_CheckSupported(ARENGINE_FEATURE_TYPE_FACE);
    napi_value result = nullptr;
    napi_create_int32(env, static_cast<int32_t>(status), &result);
    return result;
}

napi_value Start(napi_env env, napi_callback_info info)
{
    (void)info;
    napi_value result = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_tracker.mutex);
        if (g_tracker.session != nullptr) {
            napi_create_int32(env, 0, &result);
            return result;
        }
    }
    AREngine_ARSession *session = nullptr;
    AREngine_ARStatus status = HMS_AREngine_ARSession_Create_Human_Perception(nullptr, nullptr, &session);
    if (status != ARENGINE_SUCCESS || session == nullptr) {
        napi_create_int32(env, static_cast<int32_t>(status != ARENGINE_SUCCESS ? status : ARENGINE_ERROR_FATAL),
            &result);
        return result;
    }
    AREngine_ARConfig *config = nullptr;
    bool configured = false;
    if (HMS_AREngine_ARConfig_Create(session, &config) == ARENGINE_SUCCESS && config != nullptr) {
        configured = HMS_AREngine_ARConfig_SetARType(session, config, ARENGINE_TYPE_FACE) == ARENGINE_SUCCESS &&
            HMS_AREngine_ARConfig_SetCameraLensFacing(session, config, ARENGINE_CAMERA_FACING_FRONT) ==
                ARENGINE_SUCCESS &&
            HMS_AREngine_ARConfig_SetUpdateMode(session, config, ARENGINE_UPDATE_MODE_LATEST) == ARENGINE_SUCCESS &&
            HMS_AREngine_ARSession_Configure(session, config) == ARENGINE_SUCCESS;
        HMS_AREngine_ARConfig_Destroy(config);
    }
    if (!configured) {
        HMS_AREngine_ARSession_Destroy(session);
        napi_create_int32(env, static_cast<int32_t>(ARENGINE_ERROR_FATAL), &result);
        return result;
    }
    AREngine_ARFrame *frame = nullptr;
    status = HMS_AREngine_ARFrame_Create(session, &frame);
    if (status != ARENGINE_SUCCESS || frame == nullptr) {
        HMS_AREngine_ARSession_Destroy(session);
        napi_create_int32(env, static_cast<int32_t>(status != ARENGINE_SUCCESS ? status : ARENGINE_ERROR_FATAL),
            &result);
        return result;
    }
    status = HMS_AREngine_ARSession_Resume(session);
    if (status != ARENGINE_SUCCESS) {
        HMS_AREngine_ARFrame_Destroy(frame);
        HMS_AREngine_ARSession_Destroy(session);
        napi_create_int32(env, static_cast<int32_t>(status), &result);
        return result;
    }
    {
        std::lock_guard<std::mutex> lock(g_tracker.mutex);
        g_tracker.session = session;
        g_tracker.frame = frame;
        g_tracker.latest = GazeArSnapshot{};
    }
    g_tracker.running.store(true);
    g_tracker.pump = std::thread(PumpLoop);
    napi_create_int32(env, 0, &result);
    return result;
}

napi_value Stop(napi_env env, napi_callback_info info)
{
    (void)info;
    g_tracker.running.store(false);
    if (g_tracker.pump.joinable()) {
        g_tracker.pump.join();
    }
    AREngine_ARSession *session = nullptr;
    AREngine_ARFrame *frame = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_tracker.mutex);
        session = g_tracker.session;
        frame = g_tracker.frame;
        g_tracker.session = nullptr;
        g_tracker.frame = nullptr;
        g_tracker.latest = GazeArSnapshot{};
    }
    if (session != nullptr) {
        HMS_AREngine_ARSession_Pause(session);
        if (frame != nullptr) {
            HMS_AREngine_ARFrame_Destroy(frame);
        }
        HMS_AREngine_ARSession_Destroy(session);
    }
    napi_value result = nullptr;
    napi_get_undefined(env, &result);
    return result;
}

napi_value ReadSample(napi_env env, napi_callback_info info)
{
    (void)info;
    GazeArSnapshot snapshot;
    {
        std::lock_guard<std::mutex> lock(g_tracker.mutex);
        snapshot = g_tracker.latest;
    }
    napi_value result = nullptr;
    if (napi_create_object(env, &result) != napi_ok) {
        return nullptr;
    }
    napi_value value = nullptr;
    napi_get_boolean(env, snapshot.hasFace, &value);
    napi_set_named_property(env, result, "hasFace", value);
    napi_create_double(env, snapshot.headPitchDeg, &value);
    napi_set_named_property(env, result, "headPitchDeg", value);
    napi_create_double(env, snapshot.eyeUp, &value);
    napi_set_named_property(env, result, "eyeUp", value);
    napi_create_double(env, snapshot.eyeDown, &value);
    napi_set_named_property(env, result, "eyeDown", value);
    napi_create_double(env, snapshot.eyeLeft, &value);
    napi_set_named_property(env, result, "eyeLeft", value);
    napi_create_double(env, snapshot.eyeRight, &value);
    napi_set_named_property(env, result, "eyeRight", value);
    napi_create_double(env, snapshot.quat[0], &value);
    napi_set_named_property(env, result, "qx", value);
    napi_create_double(env, snapshot.quat[1], &value);
    napi_set_named_property(env, result, "qy", value);
    napi_create_double(env, snapshot.quat[2], &value);
    napi_set_named_property(env, result, "qz", value);
    napi_create_double(env, snapshot.quat[3], &value);
    napi_set_named_property(env, result, "qw", value);
    napi_create_int64(env, snapshot.frameSequence, &value);
    napi_set_named_property(env, result, "frameSequence", value);
    napi_create_int64(env, snapshot.lossSequence, &value);
    napi_set_named_property(env, result, "lossSequence", value);
    napi_create_int32(env, static_cast<int32_t>(snapshot.status), &value);
    napi_set_named_property(env, result, "status", value);
    return result;
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        {"isSupported", nullptr, IsSupported, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"start", nullptr, Start, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"readSample", nullptr, ReadSample, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"stop", nullptr, Stop, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

napi_module module{1, 0, nullptr, Init, "koma_gaze_ar", nullptr, {0}};
} // namespace

extern "C" __attribute__((constructor)) void RegisterKomaGazeArModule()
{
    napi_module_register(&module);
}
