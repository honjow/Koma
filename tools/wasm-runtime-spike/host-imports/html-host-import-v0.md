# Koma HTML Host Import v0.1 Fixture Candidate

This is a product-disabled local WAMR fixture for future source-author HTML
parsing. It does not enable HarmonyOS product runtime parsing, WebView,
JavaScript execution, Cloudflare bypasses, public sources, source markets, real
HTTP/network, cookies, sessions, or credentials.

S6 uses the temporary fixture host ABI `koma-host-v0.1-fixture-http-html` and
requires both `experimentalHttpFixture` and `experimentalHtmlFixture` in the
manifest. The fixture host owns all parsing state and returns opaque integer
descriptors to the guest.

## Fixture Imports

```c
int32_t koma_host_html_parse(uint32_t html_ptr, uint32_t html_len);
int32_t koma_host_html_select(
    int32_t descriptor,
    uint32_t selector_ptr,
    uint32_t selector_len);
int32_t koma_host_html_attr(
    int32_t descriptor,
    uint32_t attr_ptr,
    uint32_t attr_len,
    uint32_t out_ptr,
    uint32_t out_cap);
int32_t koma_host_html_text(
    int32_t descriptor,
    uint32_t out_ptr,
    uint32_t out_cap);
int32_t koma_host_html_close(int32_t descriptor);
```

Return values:

- descriptor `> 0`: parse/select succeeded.
- byte length `>= 0`: attr/text wrote UTF-8 bytes to the output buffer.
- `0`: close succeeded.
- negative values: deterministic denial or invalid request.

The current fixture bounds HTML input to 4096 bytes, output strings to 512
bytes, and live descriptors to 15 plus the reserved zero descriptor.

## S6 Selector And Attribute Subset

The local smoke accepts only deterministic fixture HTML containing a manga card.
The selector subset is:

- `article.manga-card`
- `h3.title`
- `a.chapter`

The attribute subset is:

- `data-id`
- `data-page-id`

Unsupported selectors such as `script` and unsupported attributes such as
`href` are denied and recorded as smoke evidence. The host also denies raw
credential-shaped strings and local path-shaped strings in fixture HTML or
returned strings.

## Manifest Gate

```json
{
  "runtime": {
    "hostAbi": "koma-host-v0.1-fixture-http-html",
    "requiredHostImports": [
      {"module": "koma_host", "name": "log"},
      {"module": "koma_host", "name": "check_cancel"},
      {"module": "koma_host", "name": "http_request"},
      {"module": "koma_host", "name": "html_parse"},
      {"module": "koma_host", "name": "html_select"},
      {"module": "koma_host", "name": "html_attr"},
      {"module": "koma_host", "name": "html_text"},
      {"module": "koma_host", "name": "html_close"}
    ]
  },
  "permissions": {
    "network": false,
    "experimentalHtmlFixture": {
      "enabled": true,
      "selectorSubset": ["article.manga-card", "h3.title", "a.chapter"],
      "allowedAttributes": ["data-id", "data-page-id"],
      "maxHtmlBytes": 4096,
      "maxStringBytes": 512,
      "networkPerformed": false
    }
  }
}
```

Non-fixture package validation remains closed to undeclared host imports and to
`network=true`.
