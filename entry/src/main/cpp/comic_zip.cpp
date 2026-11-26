#include "comic_zip.h"

#include <archive.h>
#include <archive_entry.h>
#include <algorithm>
#include <array>
#include <cerrno>
#include <fstream>
#include <iomanip>
#include <locale.h>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <unordered_set>

namespace {
using Archive = std::unique_ptr<archive, int (*)(archive *)>;
constexpr size_t BLOCK_SIZE = 128 * 1024;
constexpr size_t MAX_ENTRIES = 100000;

// libarchive decodes ZIP names through the calling thread's character set.
class Utf8Locale {
public:
    Utf8Locale()
    {
        static locale_t utf8 = [] {
            locale_t locale = newlocale(LC_CTYPE_MASK, "C.UTF-8", nullptr);
            return locale ? locale : newlocale(LC_CTYPE_MASK, "en_US.UTF-8", nullptr);
        }();
        if (utf8) previous_ = uselocale(utf8);
    }
    ~Utf8Locale() { if (previous_) uselocale(previous_); }
    Utf8Locale(const Utf8Locale &) = delete;
    Utf8Locale &operator=(const Utf8Locale &) = delete;

private:
    locale_t previous_ = nullptr;
};

void Check(archive *handle, int status)
{
    if (status < ARCHIVE_OK) {
        if (archive_errno(handle) == ENOSPC) throw std::runtime_error("archive_insufficient_space");
        const char *message = archive_error_string(handle);
        throw std::runtime_error(message ? message : "ZIP operation failed");
    }
}

Archive OpenZip(const std::string &path)
{
    Archive reader(archive_read_new(), archive_read_free);
    if (!reader) throw std::runtime_error("Cannot allocate ZIP reader");
    Check(reader.get(), archive_read_support_format_zip_seekable(reader.get()));
    Check(reader.get(), archive_read_open_filename(reader.get(), path.c_str(), BLOCK_SIZE));
    return reader;
}

std::string EntryName(archive_entry *entry)
{
    const char *name = archive_entry_pathname_utf8(entry);
    if (!name) name = archive_entry_pathname(entry);
    if (!name) throw std::runtime_error("ZIP entry has no name");
    std::string path(name);
    std::replace(path.begin(), path.end(), '\\', '/');
    while (path.compare(0, 2, "./") == 0) path.erase(0, 2);
    return path;
}

bool IsFile(archive_entry *entry)
{
    return archive_entry_filetype(entry) == AE_IFREG && !archive_entry_hardlink(entry) &&
        !archive_entry_symlink(entry);
}

template<class Consume>
void ReadEntry(archive *reader, uint64_t expected, Consume consume)
{
    std::array<uint8_t, BLOCK_SIZE> buffer;
    uint64_t total = 0;
    for (;;) {
        const auto size = archive_read_data(reader, buffer.data(), buffer.size());
        if (size < 0) Check(reader, static_cast<int>(size));
        if (size == 0) break;
        total += size;
        if (total > expected) throw std::runtime_error("ZIP entry exceeds its declared size");
        consume(buffer.data(), static_cast<size_t>(size));
    }
    if (total != expected) throw std::runtime_error("ZIP entry size mismatch");
}

std::string EntryHash(archive *reader, uint64_t size)
{
    uint32_t a = 2166136261u, b = a ^ 0x9e3779b9u, index = 0;
    ReadEntry(reader, size, [&](const uint8_t *data, size_t count) {
        for (size_t i = 0; i < count; ++i, ++index) {
            a = (a ^ data[i]) * 16777619u;
            b = (b ^ (data[i] + index)) * 16777619u;
        }
    });
    std::ostringstream hex;
    hex << std::hex << std::setfill('0') << std::setw(8) << a << std::setw(8) << b;
    return hex.str();
}

void WriteHeader(archive *writer, const std::string &name, uint64_t size)
{
    std::unique_ptr<archive_entry, decltype(&archive_entry_free)> entry(archive_entry_new(), archive_entry_free);
    if (!entry) throw std::runtime_error("Cannot allocate ZIP entry");
    archive_entry_set_pathname_utf8(entry.get(), name.c_str());
    archive_entry_set_filetype(entry.get(), AE_IFREG);
    archive_entry_set_perm(entry.get(), 0644);
    archive_entry_set_size(entry.get(), size);
    Check(writer, archive_write_header(writer, entry.get()));
}

void WriteBlock(archive *writer, const void *data, size_t size)
{
    const auto written = archive_write_data(writer, data, size);
    if (written < 0) Check(writer, static_cast<int>(written));
    if (written != static_cast<la_ssize_t>(size))
        throw std::runtime_error("Cannot write ZIP entry");
}
}

std::vector<ComicZipEntry> ListComicZip(const std::string &source, bool hash)
{
    const Utf8Locale locale;
    auto reader = OpenZip(source);
    std::vector<ComicZipEntry> entries;
    std::unordered_set<std::string> names;
    archive_entry *entry;
    size_t count = 0;
    for (int status; (status = archive_read_next_header(reader.get(), &entry)) != ARCHIVE_EOF;) {
        Check(reader.get(), status);
        if (++count > MAX_ENTRIES) throw std::runtime_error("ZIP contains too many entries");
        if (!IsFile(entry)) continue;
        auto path = EntryName(entry);
        if (!names.insert(path).second) throw std::runtime_error("ZIP contains duplicate file names");
        const auto size = archive_entry_size(entry);
        if (size < 0 || (hash && size > 128 * 1024 * 1024))
            throw std::runtime_error("Invalid ZIP entry size");
        entries.push_back({std::move(path), static_cast<uint64_t>(size), hash ? EntryHash(reader.get(), size) : ""});
    }
    return entries;
}

std::vector<uint8_t> ReadComicZipEntry(const std::string &source, const std::string &path, uint64_t limit,
    const std::string &destination, bool prefixOnly)
{
    const Utf8Locale locale;
    auto reader = OpenZip(source);
    archive_entry *entry;
    size_t count = 0;
    for (int status; (status = archive_read_next_header(reader.get(), &entry)) != ARCHIVE_EOF;) {
        Check(reader.get(), status);
        if (++count > MAX_ENTRIES) throw std::runtime_error("ZIP contains too many entries");
        if (!IsFile(entry) || EntryName(entry) != path) continue;
        const auto size = archive_entry_size(entry);
        if (size < 0) throw std::runtime_error("Invalid ZIP entry size");
        if (prefixOnly) {
            std::vector<uint8_t> prefix(std::min<uint64_t>(size, limit));
            size_t offset = 0;
            while (offset < prefix.size()) {
                const auto count = archive_read_data(reader.get(), prefix.data() + offset, prefix.size() - offset);
                if (count <= 0) throw std::runtime_error("Cannot read ZIP entry prefix");
                offset += count;
            }
            return prefix;
        }
        if (static_cast<uint64_t>(size) > limit) throw std::runtime_error("ZIP entry is too large");
        std::vector<uint8_t> bytes;
        if (destination.empty()) {
            bytes.reserve(size);
            ReadEntry(reader.get(), size, [&](const uint8_t *data, size_t count) {
                bytes.insert(bytes.end(), data, data + count);
            });
        } else {
            std::ofstream output(destination, std::ios::binary | std::ios::trunc);
            ReadEntry(reader.get(), size, [&](const uint8_t *data, size_t count) {
                if (!output.write(reinterpret_cast<const char *>(data), count))
                    throw std::runtime_error("Cannot write ZIP entry to file");
            });
            output.close();
            if (!output) throw std::runtime_error("Cannot finish ZIP entry file");
        }
        return bytes;
    }
    throw std::runtime_error("ZIP entry is missing");
}

void WriteComicZip(const std::string &destination,
    const std::vector<std::pair<std::string, std::string>> &files, const std::string &metadata)
{
    const Utf8Locale locale;
    Archive writer(archive_write_new(), archive_write_free);
    if (!writer) throw std::runtime_error("Cannot allocate ZIP writer");
    Check(writer.get(), archive_write_set_format_zip(writer.get()));
    Check(writer.get(), archive_write_zip_set_compression_store(writer.get()));
    Check(writer.get(), archive_write_open_filename(writer.get(), destination.c_str()));
    std::array<char, BLOCK_SIZE> buffer;
    for (const auto &[path, name] : files) {
        std::ifstream input(path, std::ios::binary | std::ios::ate);
        const auto size = input.tellg();
        if (size <= 0 || !input.seekg(0)) throw std::runtime_error("Cannot open CBZ page");
        WriteHeader(writer.get(), name, size);
        auto remaining = static_cast<uint64_t>(size);
        while (remaining > 0) {
            const auto count = std::min<uint64_t>(remaining, buffer.size());
            if (!input.read(buffer.data(), count)) throw std::runtime_error("Cannot read CBZ page");
            WriteBlock(writer.get(), buffer.data(), count);
            remaining -= count;
        }
        Check(writer.get(), archive_write_finish_entry(writer.get()));
    }
    if (!metadata.empty()) {
        WriteHeader(writer.get(), "ComicInfo.xml", metadata.size());
        WriteBlock(writer.get(), metadata.data(), metadata.size());
        Check(writer.get(), archive_write_finish_entry(writer.get()));
    }
    Check(writer.get(), archive_write_close(writer.get()));
}
