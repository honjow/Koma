#include "comic_archive_extract.h"
#include <archive.h>
#include <archive_entry.h>
#include <algorithm>
#include <array>
#include <cerrno>
#include <cstring>
#include <filesystem>
#include <fcntl.h>
#include <memory>
#include <stdexcept>
#include <sys/stat.h>
#include <unistd.h>

namespace {
std::filesystem::path EntryPath(const char *name)
{
    if (!name || !*name) throw std::runtime_error("Empty archive entry path");
    std::string normalized(name);
    std::replace(normalized.begin(), normalized.end(), '\\', '/');
    std::filesystem::path path(normalized);
    if (path.is_absolute() || normalized.find(':') != std::string::npos)
        throw std::runtime_error("Absolute archive entry path");
    for (const auto &part : path) {
        if (part == "..") throw std::runtime_error("Archive entry escapes extraction directory");
    }
    return path.lexically_normal();
}

void EnsureDirectory(const std::filesystem::path &root, const std::filesystem::path &relative)
{
    auto current = root;
    for (const auto &part : relative) {
        if (part == "." || part.empty()) continue;
        current /= part;
        if (::mkdir(current.c_str(), 0700) != 0 && errno != EEXIST)
            throw std::runtime_error("Cannot create archive directory");
        struct stat info {};
        if (::lstat(current.c_str(), &info) != 0 || !S_ISDIR(info.st_mode))
            throw std::runtime_error("Archive directory is not a regular directory");
    }
}
}

void ExtractComicArchive(const std::string &archivePath, const std::string &outputDirectory)
{
    std::unique_ptr<archive, decltype(&archive_read_free)> reader(archive_read_new(), archive_read_free);
    if (!reader) throw std::runtime_error("Cannot allocate archive reader");
    // No external filter programs, links, device nodes, ownership or permissions are restored.
    archive_read_support_filter_none(reader.get());
    archive_read_support_format_zip(reader.get());
    archive_read_support_format_rar(reader.get());
    archive_read_support_format_rar5(reader.get());
    archive_read_support_format_7zip(reader.get());
    archive_read_support_format_tar(reader.get());
    if (archive_read_open_filename(reader.get(), archivePath.c_str(), 128 * 1024) != ARCHIVE_OK)
        throw std::runtime_error(archive_error_string(reader.get()) ?: "Cannot open archive");
    archive_entry *entry = nullptr;
    int status;
    const std::filesystem::path root(outputDirectory);
    std::array<char, 128 * 1024> buffer;
    while ((status = archive_read_next_header(reader.get(), &entry)) != ARCHIVE_EOF) {
        if (status < ARCHIVE_WARN) throw std::runtime_error(archive_error_string(reader.get()) ?: "Cannot read archive header");
        const auto relative = EntryPath(archive_entry_pathname(entry));
        const auto type = archive_entry_filetype(entry);
        if (archive_entry_symlink(entry) || archive_entry_hardlink(entry) ||
            (type != AE_IFREG && type != AE_IFDIR))
            throw std::runtime_error("Archive contains unsupported linked or special entry");
        if (type == AE_IFDIR) { EnsureDirectory(root, relative); continue; }
        EnsureDirectory(root, relative.parent_path());
        const int fd = ::open((root / relative).c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0600);
        if (fd < 0) throw std::runtime_error("Cannot create extracted archive file");
        try {
            la_ssize_t size;
            while ((size = archive_read_data(reader.get(), buffer.data(), buffer.size())) > 0) {
                la_ssize_t offset = 0;
                while (offset < size) {
                    const ssize_t written = ::write(fd, buffer.data() + offset, size - offset);
                    if (written < 0 && errno == EINTR) continue;
                    if (written <= 0) throw std::runtime_error("Cannot write extracted archive file");
                    offset += written;
                }
            }
            if (size < 0) throw std::runtime_error(archive_error_string(reader.get()) ?: "Cannot decode archive entry");
        } catch (...) { ::close(fd); throw; }
        if (::close(fd) != 0) throw std::runtime_error("Cannot finish extracted archive file");
    }
}
