#include "source_package_file_checks.h"

#include <cassert>
#include <fstream>
#include <limits>

static int OpenDescriptors()
{
    int count = 0;
    for (int fd = 0; fd < 256; ++fd) if (fcntl(fd, F_GETFD) >= 0) ++count;
    return count;
}

int main(int argc, char **argv)
{
    assert(argc == 2);
    const std::string root(argv[1]);
    const std::string file = root + "/source.wasm";
    const std::string link = root + "/link.wasm";
    const std::string directory = root + "/directory";
    { std::ofstream out(file); out << "abc"; }
    assert(mkdir(directory.c_str(), 0700) == 0);
    assert(symlink(file.c_str(), link.c_str()) == 0);
    const int before = OpenDescriptors();
    assert(koma::SourcePackageFilesMatch({}, {}));
    assert(koma::SourcePackageFilesMatch({file, link}, {3, 3}));
    assert(!koma::SourcePackageFilesMatch({file}, {}));
    assert(!koma::SourcePackageFilesMatch({file}, {2}));
    assert(!koma::SourcePackageFilesMatch({root + "/missing"}, {3}));
    assert(!koma::SourcePackageFilesMatch({directory}, {0}));
    assert(!koma::SourcePackageFilesMatch({""}, {3}));
    assert(!koma::SourcePackageFilesMatch({file + std::string(1, '\0') + "suffix"}, {3}));
    assert(!koma::SourcePackageFilesMatch({file}, {std::numeric_limits<double>::quiet_NaN()}));
    assert(chmod(file.c_str(), 0000) == 0);
    if (geteuid() != 0) assert(!koma::SourcePackageFilesMatch({file}, {3}));
    assert(chmod(file.c_str(), 0600) == 0);
    assert(OpenDescriptors() == before);
    return 0;
}
