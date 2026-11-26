#include "comic_archive_extract.h"
#include "comic_zip.h"
#include <napi/native_api.h>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
enum class Action { Extract, List, Read, Prefix, Copy, Write };

struct ArchiveWork {
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
    Action action = Action::List;
    std::string source, destination, path, metadata, error;
    uint64_t limit = 0;
    std::vector<std::pair<std::string, std::string>> files;
    std::vector<ComicZipEntry> entries;
    std::vector<uint8_t> bytes;
};

std::string StringArgument(napi_env env, napi_value value)
{
    size_t size = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &size) != napi_ok)
        throw std::runtime_error("Archive paths must be strings");
    std::vector<char> buffer(size + 1);
    napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &size);
    if (std::memchr(buffer.data(), '\0', size))
        throw std::runtime_error("Archive strings must not contain NUL");
    return std::string(buffer.data(), size);
}

napi_value ToEntries(napi_env env, const std::vector<ComicZipEntry> &entries)
{
    napi_value list;
    napi_create_array_with_length(env, entries.size(), &list);
    for (uint32_t i = 0; i < entries.size(); ++i) {
        napi_value row, path, size, hash;
        napi_create_object(env, &row);
        napi_create_string_utf8(env, entries[i].path.c_str(), entries[i].path.size(), &path);
        napi_create_double(env, entries[i].size, &size);
        napi_create_string_utf8(env, entries[i].hash.c_str(), entries[i].hash.size(), &hash);
        napi_set_named_property(env, row, "path", path);
        napi_set_named_property(env, row, "size", size);
        napi_set_named_property(env, row, "hash", hash);
        napi_set_element(env, list, i, row);
    }
    return list;
}

void ParseArguments(napi_env env, napi_callback_info info, ArchiveWork &request)
{
    size_t count = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    if (count == 0) throw std::runtime_error("Archive path is required");
    request.source = StringArgument(env, args[0]);
    switch (request.action) {
        case Action::Extract:
            if (count != 2) throw std::runtime_error("Extraction destination is required");
            request.destination = StringArgument(env, args[1]);
            break;
        case Action::List:
            break;
        case Action::Read:
        case Action::Prefix:
        case Action::Copy: {
            const bool copy = request.action == Action::Copy;
            if (count != (copy ? 4 : 3)) throw std::runtime_error("ZIP entry and limit are required");
            request.path = StringArgument(env, args[1]);
            int64_t limit = 0;
            if (napi_get_value_int64(env, args[2], &limit) != napi_ok || limit <= 0)
                throw std::runtime_error("Invalid ZIP entry limit");
            request.limit = limit;
            if (copy) request.destination = StringArgument(env, args[3]);
            break;
        }
        case Action::Write: {
            uint32_t length = 0;
            if (count != 3 || napi_get_array_length(env, args[1], &length) != napi_ok ||
                length == 0 || length > 199998 || length % 2 != 0)
                throw std::runtime_error("CBZ pages are required");
            for (uint32_t i = 0; i < length; i += 2) {
                napi_value path, name;
                napi_get_element(env, args[1], i, &path);
                napi_get_element(env, args[1], i + 1, &name);
                request.files.emplace_back(StringArgument(env, path), StringArgument(env, name));
            }
            request.metadata = StringArgument(env, args[2]);
            break;
        }
    }
}

void Execute(napi_env, void *data)
{
    auto &request = *static_cast<ArchiveWork *>(data);
    try {
        switch (request.action) {
            case Action::Extract:
                ExtractComicArchive(request.source, request.destination);
                break;
            case Action::List:
                request.entries = ListComicZip(request.source, false);
                break;
            case Action::Read:
            case Action::Prefix:
            case Action::Copy:
                request.bytes = ReadComicZipEntry(request.source, request.path, request.limit, request.destination,
                    request.action == Action::Prefix);
                break;
            case Action::Write:
                WriteComicZip(request.source, request.files, request.metadata);
                break;
        }
    } catch (const std::exception &error) { request.error = error.what(); }
}

void Complete(napi_env env, napi_status status, void *data)
{
    std::unique_ptr<ArchiveWork> request(static_cast<ArchiveWork *>(data));
    napi_value value;
    if (status != napi_ok || !request->error.empty()) {
        napi_value message;
        napi_create_string_utf8(env, request->error.empty() ? "Archive operation interrupted" : request->error.c_str(),
            NAPI_AUTO_LENGTH, &message);
        napi_create_error(env, nullptr, message, &value);
        napi_reject_deferred(env, request->deferred, value);
    } else {
        if (request->action == Action::List) {
            value = ToEntries(env, request->entries);
        } else if (request->action == Action::Read || request->action == Action::Prefix) {
            void *buffer = nullptr;
            if (napi_create_arraybuffer(env, request->bytes.size(), &buffer, &value) != napi_ok) {
                napi_value message;
                napi_create_string_utf8(env, "Could not allocate ZIP entry", NAPI_AUTO_LENGTH, &message);
                napi_create_error(env, nullptr, message, &value);
                napi_reject_deferred(env, request->deferred, value);
                napi_delete_async_work(env, request->work);
                return;
            }
            if (!request->bytes.empty()) std::memcpy(buffer, request->bytes.data(), request->bytes.size());
        } else {
            napi_get_undefined(env, &value);
        }
        napi_resolve_deferred(env, request->deferred, value);
    }
    napi_delete_async_work(env, request->work);
}

template<Action action>
napi_value Run(napi_env env, napi_callback_info info)
{
    auto request = std::make_unique<ArchiveWork>();
    request->action = action;
    try {
        ParseArguments(env, info, *request);
    } catch (const std::exception &error) {
        napi_throw_type_error(env, nullptr, error.what());
        return nullptr;
    }
    napi_value promise, label;
    napi_create_promise(env, &request->deferred, &promise);
    napi_create_string_utf8(env, "ComicArchive", NAPI_AUTO_LENGTH, &label);
    auto result = napi_create_async_work(env, nullptr, label, Execute, Complete, request.get(), &request->work);
    if (result == napi_ok) result = napi_queue_async_work(env, request->work);
    if (result != napi_ok) {
        if (request->work) napi_delete_async_work(env, request->work);
        napi_throw_error(env, nullptr, "Cannot schedule archive operation");
        return nullptr;
    }
    request.release();
    return promise;
}

napi_value ListSync(napi_env env, napi_callback_info info)
{
    try {
        size_t count = 2;
        napi_value args[2];
        napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
        bool hash = false;
        if (count != 2 || napi_get_value_bool(env, args[1], &hash) != napi_ok)
            throw std::runtime_error("ZIP path and verification mode are required");
        return ToEntries(env, ListComicZip(StringArgument(env, args[0]), hash));
    } catch (const std::exception &error) {
        napi_throw_error(env, nullptr, error.what());
        return nullptr;
    }
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor entries[] {
        {"extract", nullptr, Run<Action::Extract>, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"listZip", nullptr, Run<Action::List>, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"listZipSync", nullptr, ListSync, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"readZipEntry", nullptr, Run<Action::Read>, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"readZipPrefix", nullptr, Run<Action::Prefix>, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"copyZipEntry", nullptr, Run<Action::Copy>, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"writeZip", nullptr, Run<Action::Write>, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(entries) / sizeof(entries[0]), entries);
    return exports;
}
napi_module module {1, 0, nullptr, Init, "koma_archive", nullptr, {0}};
}
extern "C" __attribute__((constructor)) void RegisterComicArchiveModule() { napi_module_register(&module); }
