#pragma once

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <string>
#include <vector>

namespace koma {

// Every metadata commit still opens every admitted file read-only and checks the
// same descriptor's type and size. No cached filesystem state or WASM reads.
// False sends the caller through its existing per-entry error/rollback path.
inline bool SourcePackageFilesMatch(const std::vector<std::string> &paths,
    const std::vector<double> &expectedByteCounts)
{
    if (paths.size() != expectedByteCounts.size()) return false;
    for (size_t index = 0; index < paths.size(); ++index) {
        const auto &path = paths[index];
        if (path.empty() || path.find('\0') != std::string::npos) return false;
        const int fd = open(path.c_str(), O_RDONLY | O_CLOEXEC);
        if (fd < 0) return false;
        struct stat metadata {};
        const bool matches = fstat(fd, &metadata) == 0 && S_ISREG(metadata.st_mode) &&
            static_cast<double>(metadata.st_size) == expectedByteCounts[index];
        close(fd);
        if (!matches) return false;
    }
    return true;
}

} // namespace koma
