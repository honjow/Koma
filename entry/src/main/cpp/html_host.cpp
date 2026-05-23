#include "html_host.h"

#include <cstring>
#include <unordered_map>
#include <string>
#include <vector>

#if defined(KOMA_ENABLE_LEXBOR)
#include <lexbor/html/parser.h>
#include <lexbor/dom/interfaces/element.h>
#include <lexbor/dom/interfaces/text.h>
#include <lexbor/css/css.h>
#include <lexbor/selectors/selectors.h>
#endif

#if __has_include(<hilog/log.h>)
#include <hilog/log.h>
#define HTML_LOG(fmt, ...) OH_LOG_Print(LOG_APP, LOG_DEBUG, 0x0, "KomaHtmlHost", fmt, ##__VA_ARGS__)
#else
#include <cstdio>
#define HTML_LOG(fmt, ...) std::fprintf(stderr, "KomaHtmlHost: " fmt "\n", ##__VA_ARGS__)
#endif

namespace koma {
namespace html {

#if defined(KOMA_ENABLE_LEXBOR)

namespace {

struct HtmlNode {
    lxb_dom_node_t *node = nullptr;
    lxb_html_document_t *ownerDoc = nullptr; // non-null only if this is the root doc node
};

int32_t g_nextDescriptor = 1;
std::unordered_map<int32_t, HtmlNode> g_nodes;

int32_t AllocDescriptor(lxb_dom_node_t *node, lxb_html_document_t *ownerDoc = nullptr)
{
    int32_t desc = g_nextDescriptor++;
    g_nodes[desc] = {node, ownerDoc};
    return desc;
}

HtmlNode *LookupNode(int32_t descriptor)
{
    auto it = g_nodes.find(descriptor);
    if (it == g_nodes.end()) {
        return nullptr;
    }
    return &it->second;
}

// CSS selector matching callback state
struct SelectAllState {
    std::vector<lxb_dom_node_t *> results;
};

lxb_status_t SelectCallback(lxb_dom_node_t *node, lxb_css_selector_specificity_t *spec, void *ctx)
{
    (void)spec;
    auto *state = static_cast<SelectAllState *>(ctx);
    state->results.push_back(node);
    return LXB_STATUS_OK;
}

// Collect text content recursively
void CollectText(lxb_dom_node_t *node, std::string &out, size_t maxLen)
{
    if (out.size() >= maxLen) return;

    if (node->type == LXB_DOM_NODE_TYPE_TEXT) {
        lxb_dom_text_t *text = lxb_dom_interface_text(node);
        if (text != nullptr) {
            size_t textLen = 0;
            const lxb_char_t *data = lxb_dom_node_text_content(node, &textLen);
            if (data != nullptr && textLen > 0) {
                size_t canWrite = maxLen - out.size();
                size_t writeLen = textLen < canWrite ? textLen : canWrite;
                out.append(reinterpret_cast<const char *>(data), writeLen);
            }
        }
        return;
    }

    lxb_dom_node_t *child = node->first_child;
    while (child != nullptr && out.size() < maxLen) {
        CollectText(child, out, maxLen);
        child = child->next;
    }
}

} // namespace

void Init()
{
    // No global init needed for lexbor
}

void Shutdown()
{
    // Clean up any remaining nodes
    for (auto &pair : g_nodes) {
        if (pair.second.ownerDoc != nullptr) {
            lxb_html_document_destroy(pair.second.ownerDoc);
        }
    }
    g_nodes.clear();
    g_nextDescriptor = 1;
}

int32_t Parse(const char *html, uint32_t htmlLen)
{
    if (html == nullptr || htmlLen == 0) {
        return -1;
    }

    lxb_html_document_t *doc = lxb_html_document_create();
    if (doc == nullptr) {
        return -1;
    }

    lxb_status_t status = lxb_html_document_parse(doc,
        reinterpret_cast<const lxb_char_t *>(html), htmlLen);
    if (status != LXB_STATUS_OK) {
        lxb_html_document_destroy(doc);
        return -1;
    }

    lxb_dom_node_t *root = lxb_dom_interface_node(doc);
    return AllocDescriptor(root, doc);
}

int32_t Select(int32_t parentDescriptor, const char *selector, uint32_t selectorLen)
{
    HtmlNode *parent = LookupNode(parentDescriptor);
    if (parent == nullptr || parent->node == nullptr) {
        return -1;
    }
    if (selector == nullptr || selectorLen == 0) {
        return -1;
    }

    // Get the document from the node
    lxb_dom_document_t *doc = parent->node->owner_document;
    if (doc == nullptr) {
        return -1;
    }

    // Create CSS parser
    lxb_css_parser_t *cssParser = lxb_css_parser_create();
    if (lxb_css_parser_init(cssParser, nullptr) != LXB_STATUS_OK) {
        lxb_css_parser_destroy(cssParser, true);
        return -1;
    }

    // Parse selector
    lxb_selectors_t *selectors = lxb_selectors_create();
    if (lxb_selectors_init(selectors) != LXB_STATUS_OK) {
        lxb_selectors_destroy(selectors, true);
        lxb_css_parser_destroy(cssParser, true);
        return -1;
    }

    lxb_css_selector_list_t *list = lxb_css_selectors_parse(cssParser,
        reinterpret_cast<const lxb_char_t *>(selector), selectorLen);
    if (list == nullptr) {
        lxb_selectors_destroy(selectors, true);
        lxb_css_parser_destroy(cssParser, true);
        return -1;
    }

    SelectAllState state;
    lxb_status_t status = lxb_selectors_find(selectors, parent->node, list, SelectCallback, &state);

    lxb_css_selector_list_destroy_memory(list);
    lxb_selectors_destroy(selectors, true);
    lxb_css_parser_destroy(cssParser, true);

    if (status != LXB_STATUS_OK || state.results.empty()) {
        return -1;
    }

    // Return first match
    return AllocDescriptor(state.results[0]);
}

int32_t SelectAll(int32_t parentDescriptor, const char *selector, uint32_t selectorLen,
    char *outBuf, uint32_t outCap)
{
    HtmlNode *parent = LookupNode(parentDescriptor);
    if (parent == nullptr || parent->node == nullptr) {
        return -1;
    }
    if (selector == nullptr || selectorLen == 0) {
        return -1;
    }

    lxb_dom_document_t *doc = parent->node->owner_document;
    if (doc == nullptr) {
        return -1;
    }

    lxb_css_parser_t *cssParser = lxb_css_parser_create();
    if (lxb_css_parser_init(cssParser, nullptr) != LXB_STATUS_OK) {
        lxb_css_parser_destroy(cssParser, true);
        return -1;
    }

    lxb_selectors_t *selectors = lxb_selectors_create();
    if (lxb_selectors_init(selectors) != LXB_STATUS_OK) {
        lxb_selectors_destroy(selectors, true);
        lxb_css_parser_destroy(cssParser, true);
        return -1;
    }

    lxb_css_selector_list_t *list = lxb_css_selectors_parse(cssParser,
        reinterpret_cast<const lxb_char_t *>(selector), selectorLen);
    if (list == nullptr) {
        lxb_selectors_destroy(selectors, true);
        lxb_css_parser_destroy(cssParser, true);
        return -1;
    }

    SelectAllState state;
    lxb_status_t status = lxb_selectors_find(selectors, parent->node, list, SelectCallback, &state);

    lxb_css_selector_list_destroy_memory(list);
    lxb_selectors_destroy(selectors, true);
    lxb_css_parser_destroy(cssParser, true);

    if (status != LXB_STATUS_OK) {
        return -1;
    }

    int32_t count = static_cast<int32_t>(state.results.size());
    uint32_t maxWrite = outCap / 4;

    for (uint32_t i = 0; i < state.results.size() && i < maxWrite; i++) {
        int32_t desc = AllocDescriptor(state.results[i]);
        uint32_t offset = i * 4;
        outBuf[offset + 0] = static_cast<char>(desc & 0xFF);
        outBuf[offset + 1] = static_cast<char>((desc >> 8) & 0xFF);
        outBuf[offset + 2] = static_cast<char>((desc >> 16) & 0xFF);
        outBuf[offset + 3] = static_cast<char>((desc >> 24) & 0xFF);
    }

    return count;
}

int32_t Attr(int32_t descriptor, const char *attrName, uint32_t attrLen,
    char *out, uint32_t outCap)
{
    HtmlNode *node = LookupNode(descriptor);
    if (node == nullptr || node->node == nullptr) {
        return -1;
    }
    if (node->node->type != LXB_DOM_NODE_TYPE_ELEMENT) {
        return -1;
    }

    lxb_dom_element_t *elem = lxb_dom_interface_element(node->node);
    if (elem == nullptr) {
        return -1;
    }

    size_t valueLen = 0;
    const lxb_char_t *value = lxb_dom_element_get_attribute(elem,
        reinterpret_cast<const lxb_char_t *>(attrName), attrLen, &valueLen);
    if (value == nullptr) {
        return -1;
    }

    uint32_t writeLen = valueLen < outCap ? static_cast<uint32_t>(valueLen) : outCap;
    std::memcpy(out, value, writeLen);
    return static_cast<int32_t>(writeLen);
}

int32_t Text(int32_t descriptor, char *out, uint32_t outCap)
{
    HtmlNode *node = LookupNode(descriptor);
    if (node == nullptr || node->node == nullptr) {
        return -1;
    }

    std::string text;
    text.reserve(256);
    CollectText(node->node, text, outCap);

    if (text.empty()) {
        return 0;
    }

    uint32_t writeLen = text.size() < outCap ? static_cast<uint32_t>(text.size()) : outCap;
    std::memcpy(out, text.data(), writeLen);
    return static_cast<int32_t>(writeLen);
}

int32_t Close(int32_t descriptor)
{
    auto it = g_nodes.find(descriptor);
    if (it == g_nodes.end()) {
        return -1;
    }

    if (it->second.ownerDoc != nullptr) {
        lxb_html_document_destroy(it->second.ownerDoc);
    }
    g_nodes.erase(it);
    return 0;
}

#else // !KOMA_ENABLE_LEXBOR

void Init() {}
void Shutdown() {}
int32_t Parse(const char *, uint32_t) { return -1; }
int32_t Select(int32_t, const char *, uint32_t) { return -1; }
int32_t SelectAll(int32_t, const char *, uint32_t, char *, uint32_t) { return -1; }
int32_t Attr(int32_t, const char *, uint32_t, char *, uint32_t) { return -1; }
int32_t Text(int32_t, char *, uint32_t) { return -1; }
int32_t Close(int32_t) { return -1; }

#endif

} // namespace html
} // namespace koma
