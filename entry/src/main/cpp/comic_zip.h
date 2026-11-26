#pragma once
#include <cstdint>
#include <string>
#include <utility>
#include <vector>

struct ComicZipEntry {
    std::string path;
    uint64_t size;
    std::string hash;
};

std::vector<ComicZipEntry> ListComicZip(const std::string &source, bool hash);
std::vector<uint8_t> ReadComicZipEntry(const std::string &source, const std::string &path, uint64_t limit,
    const std::string &destination = {}, bool prefixOnly = false);
void WriteComicZip(const std::string &destination,
    const std::vector<std::pair<std::string, std::string>> &files, const std::string &metadata);
