#pragma once
#include <string>

// Runs on a worker. The caller owns the fresh, app-private extraction directory.
void ExtractComicArchive(const std::string &archivePath, const std::string &outputDirectory);
