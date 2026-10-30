#include "java_regex_host.h"
#include <unicode/uregex.h>
#include <memory>
#include <chrono>
#include <string>
#include <vector>

namespace {
struct Work {
  napi_env env{}; napi_async_work work{}; napi_deferred deferred{};
  std::u16string pattern; std::vector<std::u16string> input, output;
  bool valid = false; bool ok = false;
};
bool syntaxError(UErrorCode e) {
  switch (e) {
    case U_REGEX_RULE_SYNTAX: case U_REGEX_BAD_ESCAPE_SEQUENCE: case U_REGEX_PROPERTY_SYNTAX:
    case U_REGEX_MISMATCHED_PAREN: case U_REGEX_NUMBER_TOO_BIG: case U_REGEX_BAD_INTERVAL:
    case U_REGEX_MAX_LT_MIN: case U_REGEX_INVALID_BACK_REF: case U_REGEX_INVALID_FLAG:
    case U_REGEX_LOOK_BEHIND_LIMIT: case U_REGEX_SET_CONTAINS_STRING:
    case U_REGEX_MISSING_CLOSE_BRACKET: case U_REGEX_INVALID_RANGE:
    case U_REGEX_INVALID_CAPTURE_GROUP_NAME: return true;
    default: return false;
  }
}
using Deadline = std::chrono::steady_clock::time_point;
UBool U_CALLCONV withinDeadline(const void *context, int32_t) {
  return std::chrono::steady_clock::now() < *static_cast<const Deadline *>(context);
}
bool stringValue(napi_env env, napi_value value, std::u16string &out) {
  napi_valuetype type; size_t len = 0, written = 0;
  if (napi_typeof(env, value, &type) != napi_ok || type != napi_string ||
      napi_get_value_string_utf16(env, value, nullptr, 0, &len) != napi_ok || len > 65536) return false;
  std::vector<char16_t> buf(len + 1);
  if (napi_get_value_string_utf16(env, value, buf.data(), buf.size(), &written) != napi_ok) return false;
  out.assign(buf.data(), written); return true;
}
void Execute(napi_env, void *data) {
  auto &w = *static_cast<Work *>(data);
  try {
  const Deadline deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
  UErrorCode err = U_ZERO_ERROR; UParseError parse{};
  std::unique_ptr<URegularExpression, decltype(&uregex_close)> owned(
      uregex_open(reinterpret_cast<const UChar *>(w.pattern.data()),
        static_cast<int32_t>(w.pattern.size()), UREGEX_ERROR_ON_UNKNOWN_ESCAPES, &parse, &err), &uregex_close);
  URegularExpression *re = owned.get();
  if (U_FAILURE(err) || re == nullptr) { w.ok = syntaxError(err); return; }
  w.valid = true;
  // ICU reports resource exhaustion explicitly; never convert it to a false match.
  uregex_setTimeLimit(re, 1000, &err);
  uregex_setStackLimit(re, 8 * 1024 * 1024, &err);
  uregex_setMatchCallback(re, withinDeadline, &deadline, &err);
  const UChar empty[] = {0};
  for (const auto &text : w.input) {
    if (std::chrono::steady_clock::now() >= deadline) { err = U_REGEX_TIME_OUT; break; }
    if (U_FAILURE(err)) break;
    uregex_setText(re, reinterpret_cast<const UChar *>(text.data()), static_cast<int32_t>(text.size()), &err);
    UErrorCode measure = err;
    int32_t length = uregex_replaceAll(re, empty, 0, nullptr, 0, &measure);
    if (measure != U_BUFFER_OVERFLOW_ERROR && U_FAILURE(measure)) { err = measure; break; }
    if (length < 0 || length > 65536) { err = U_INDEX_OUTOFBOUNDS_ERROR; break; }
    std::vector<UChar> buf(static_cast<size_t>(length) + 1);
    err = U_ZERO_ERROR;
    int32_t written = uregex_replaceAll(re, empty, 0, buf.data(), static_cast<int32_t>(buf.size()), &err);
    if (U_FAILURE(err)) break;
    w.output.emplace_back(reinterpret_cast<const char16_t *>(buf.data()), static_cast<size_t>(written));
  }
  w.ok = U_SUCCESS(err);
  } catch (...) {
    // Allocation and other engine failures are not invalid user syntax.
    w.ok = false; w.output.clear();
  }
}
void Complete(napi_env env, napi_status status, void *data) {
  std::unique_ptr<Work> w(static_cast<Work *>(data));
  napi_value result, dataObj, boolean, array;
  napi_create_object(env, &result);
  napi_get_boolean(env, status == napi_ok && w->ok, &boolean); napi_set_named_property(env, result, "ok", boolean);
  napi_create_object(env, &dataObj); napi_get_boolean(env, w->valid, &boolean);
  napi_set_named_property(env, dataObj, "valid", boolean);
  napi_create_array_with_length(env, w->output.size(), &array);
  for (size_t i = 0; i < w->output.size(); ++i) {
    napi_value text; napi_create_string_utf16(env, w->output[i].data(), w->output[i].size(), &text);
    napi_set_element(env, array, static_cast<uint32_t>(i), text);
  }
  napi_set_named_property(env, dataObj, "texts", array); napi_set_named_property(env, result, "data", dataObj);
  napi_resolve_deferred(env, w->deferred, result); napi_delete_async_work(env, w->work);
}
}
napi_value KomaJavaRegex(napi_env env, napi_callback_info info) {
  try {
  size_t argc = 2; napi_value argv[2]{}; napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  std::unique_ptr<Work> w(new Work); w->env = env;
  bool isArray = false; uint32_t count = 0;
  if (argc != 2 || !stringValue(env, argv[0], w->pattern) ||
      napi_is_array(env, argv[1], &isArray) != napi_ok || !isArray ||
      napi_get_array_length(env, argv[1], &count) != napi_ok || count > 256) {
    napi_throw_type_error(env, nullptr, "Invalid regex request"); return nullptr;
  }
  for (uint32_t i = 0; i < count; ++i) {
    napi_value value; std::u16string text;
    if (napi_get_element(env, argv[1], i, &value) != napi_ok || !stringValue(env, value, text)) {
      napi_throw_type_error(env, nullptr, "Invalid regex text"); return nullptr;
    }
    w->input.push_back(std::move(text));
  }
  napi_value promise, name; napi_create_promise(env, &w->deferred, &promise);
  napi_create_string_utf8(env, "sourceJavaRegex", NAPI_AUTO_LENGTH, &name);
  if (napi_create_async_work(env, nullptr, name, Execute, Complete, w.get(), &w->work) != napi_ok ||
      napi_queue_async_work(env, w->work) != napi_ok) {
    if (w->work) napi_delete_async_work(env, w->work);
    napi_throw_error(env, nullptr, "Regex worker unavailable"); return nullptr;
  }
  w.release(); return promise;
  } catch (...) {
    napi_throw_error(env, nullptr, "Regex worker unavailable"); return nullptr;
  }
}
