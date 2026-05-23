#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace koma {
namespace html {

/// Initialize HTML subsystem (call once).
void Init();

/// Shutdown HTML subsystem (call once).
void Shutdown();

/// Parse HTML bytes into a document. Returns descriptor >= 0 on success, -1 on failure.
int32_t Parse(const char *html, uint32_t htmlLen);

/// Select first matching element by CSS selector. Returns descriptor >= 0, or -1.
int32_t Select(int32_t parentDescriptor, const char *selector, uint32_t selectorLen);

/// Select ALL matching elements. Writes descriptors to outBuf (little-endian i32 each).
/// Returns count of matches found (may exceed outCap/4 if more matches exist).
int32_t SelectAll(int32_t parentDescriptor, const char *selector, uint32_t selectorLen,
    char *outBuf, uint32_t outCap);

/// Get attribute value. Returns length written to out, or -1 on failure.
int32_t Attr(int32_t descriptor, const char *attrName, uint32_t attrLen,
    char *out, uint32_t outCap);

/// Get inner text. Returns length written to out, or -1 on failure.
int32_t Text(int32_t descriptor, char *out, uint32_t outCap);

/// Close/release a descriptor.
int32_t Close(int32_t descriptor);

} // namespace html
} // namespace koma
