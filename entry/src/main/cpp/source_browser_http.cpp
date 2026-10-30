#include <algorithm>
#include <atomic>
#include <curl/curl.h>
#include <memory>
#include <mutex>
#include <napi/native_api.h>
#include <network/netmanager/net_connection.h>
#include <string>
#include <unistd.h>
#include <unordered_map>
#include <vector>
struct CurlWork {
  napi_async_work work{};
  napi_deferred deferred{};
  std::string id, url, body, profile;
  std::vector<std::string> headers, responseHeaders;
  std::atomic<bool> cancelled{false};
  long timeout = 0, status = 0;
  curl_off_t dnsUs = -1, tcpUs = -1, tlsUs = -1, firstByteUs = -1, totalUs = -1;
  long createdConnections = 0;
  int code = 0;
  bool eligible = false;
};
static std::mutex mu;
static std::unordered_map<std::string, CurlWork *> calls;
static std::once_flag curlInit;
static CURLcode globalResult = CURLE_FAILED_INIT;
static bool str(napi_env e, napi_value v, std::string &o, size_t cap) {
  size_t n = 0;
  if (napi_get_value_string_utf8(e, v, nullptr, 0, &n) != napi_ok || n > cap)
    return false;
  std::vector<char> b(n + 1);
  if (napi_get_value_string_utf8(e, v, b.data(), b.size(), &n) != napi_ok)
    return false;
  o.assign(b.data(), n);
  return true;
}
static size_t writeBody(char *p, size_t s, size_t n, void *v) {
  auto &w = *static_cast<CurlWork *>(v);
  const size_t nbytes = s * n;
  if (nbytes > 1048576 - w.body.size())
    return 0;
  w.body.append(p, nbytes);
  return nbytes;
}
static size_t writeHead(char *p, size_t s, size_t n, void *v) {
  auto &w = *static_cast<CurlWork *>(v);
  const size_t size = s * n;
  if (size > 8192 || w.responseHeaders.size() >= 128)
    return 0;
  std::string l(p, size);
  if (l.rfind("HTTP/", 0) == 0)
    w.responseHeaders.clear();
  while (!l.empty() && (l.back() == '\r' || l.back() == '\n'))
    l.pop_back();
  if (l.find(':') != std::string::npos)
    w.responseHeaders.push_back(std::move(l));
  return size;
}
static int progress(void *p, curl_off_t, curl_off_t, curl_off_t, curl_off_t) {
  return static_cast<CurlWork *>(p)->cancelled.load() ? 1 : 0;
}
static void execute(napi_env, void *data) {
  auto &w = *static_cast<CurlWork *>(data);
  // The candidate cannot reproduce every system proxy policy yet. Report
  // ineligible and let NetworkKit retain its existing behavior when needed.
  NetConn_HttpProxy p{};
  if (OH_NetConn_GetDefaultHttpProxy(&p) != 0 || p.host[0] || p.port ||
      p.exclusionListSize ||
      access("/etc/security/certificates", R_OK | X_OK) != 0)
    return;
  std::call_once(curlInit,
                 [] { globalResult = curl_global_init(CURL_GLOBAL_DEFAULT); });
  if (globalResult != CURLE_OK)
    return;
  CURL *c = curl_easy_init();
  if (!c)
    return;
  if (curl_easy_impersonate(c, w.profile.c_str(), 0) != CURLE_OK) {
    curl_easy_cleanup(c);
    return;
  }
  w.eligible = true;
  curl_slist *list = nullptr;
  for (const auto &h : w.headers) {
    curl_slist *next = curl_slist_append(list, h.c_str());
    if (!next) {
      w.code = CURLE_OUT_OF_MEMORY;
      curl_slist_free_all(list);
      curl_easy_cleanup(c);
      return;
    }
    list = next;
  }
  curl_easy_setopt(c, CURLOPT_URL, w.url.c_str());
  curl_easy_setopt(c, CURLOPT_HTTPHEADER, list);
  curl_easy_setopt(c, CURLOPT_PROXY, "");
  curl_easy_setopt(c, CURLOPT_CAPATH, "/etc/security/certificates");
  curl_easy_setopt(c, CURLOPT_SSL_VERIFYPEER, 1L);
  curl_easy_setopt(c, CURLOPT_SSL_VERIFYHOST, 2L);
  curl_easy_setopt(c, CURLOPT_TIMEOUT_MS, w.timeout);
  curl_easy_setopt(c, CURLOPT_CONNECTTIMEOUT_MS, w.timeout);
  curl_easy_setopt(c, CURLOPT_NOSIGNAL, 1L);
  curl_easy_setopt(c, CURLOPT_FOLLOWLOCATION, 0L);
  curl_easy_setopt(c, CURLOPT_WRITEFUNCTION, writeBody);
  curl_easy_setopt(c, CURLOPT_WRITEDATA, &w);
  curl_easy_setopt(c, CURLOPT_HEADERFUNCTION, writeHead);
  curl_easy_setopt(c, CURLOPT_HEADERDATA, &w);
  curl_easy_setopt(c, CURLOPT_NOPROGRESS, 0L);
  curl_easy_setopt(c, CURLOPT_XFERINFOFUNCTION, progress);
  curl_easy_setopt(c, CURLOPT_XFERINFODATA, &w);
  w.code = curl_easy_perform(c);
  curl_easy_getinfo(c, CURLINFO_RESPONSE_CODE, &w.status);
  // Cumulative microsecond checkpoints are available even for a failed transfer.
  // Zero is not proof that a phase completed; no URL, headers or peer identity is logged.
  curl_easy_getinfo(c, CURLINFO_NAMELOOKUP_TIME_T, &w.dnsUs);
  curl_easy_getinfo(c, CURLINFO_CONNECT_TIME_T, &w.tcpUs);
  curl_easy_getinfo(c, CURLINFO_APPCONNECT_TIME_T, &w.tlsUs);
  curl_easy_getinfo(c, CURLINFO_STARTTRANSFER_TIME_T, &w.firstByteUs);
  curl_easy_getinfo(c, CURLINFO_TOTAL_TIME_T, &w.totalUs);
  curl_easy_getinfo(c, CURLINFO_NUM_CONNECTS, &w.createdConnections);
  curl_slist_free_all(list);
  curl_easy_cleanup(c);
}
static void num(napi_env e, napi_value o, const char *k, int64_t n) {
  napi_value v;
  napi_create_int64(e, n, &v);
  napi_set_named_property(e, o, k, v);
}
static void flag(napi_env e, napi_value o, const char *k, bool x) {
  napi_value v;
  napi_get_boolean(e, x, &v);
  napi_set_named_property(e, o, k, v);
}
static void milliseconds(napi_env env, napi_value object, const char *key, curl_off_t microseconds) {
  napi_value value;
  napi_create_double(env, microseconds < 0 ? -1 : microseconds / 1000.0, &value);
  napi_set_named_property(env, object, key, value);
}
static void complete(napi_env e, napi_status st, void *data) {
  std::unique_ptr<CurlWork> w(static_cast<CurlWork *>(data));
  {
    std::lock_guard<std::mutex> l(mu);
    calls.erase(w->id);
  }
  napi_value o, v, arr;
  napi_create_object(e, &o);
  flag(e, o, "eligible", w->eligible);
  flag(e, o, "cancelled", w->cancelled.load());
  num(e, o, "code", st == napi_ok ? w->code : -1);
  num(e, o, "status", w->status);
  num(e, o, "createdConnections", w->createdConnections);
  napi_value timing;
  napi_create_object(e, &timing);
  milliseconds(e, timing, "dnsTiming", w->dnsUs);
  milliseconds(e, timing, "tcpTiming", w->tcpUs);
  milliseconds(e, timing, "tlsTiming", w->tlsUs);
  milliseconds(e, timing, "firstReceiveTiming", w->firstByteUs);
  milliseconds(e, timing, "totalFinishTiming", w->totalUs);
  napi_set_named_property(e, o, "performanceTiming", timing);
  napi_create_string_utf8(e, w->body.data(), w->body.size(), &v);
  napi_set_named_property(e, o, "body", v);
  napi_create_array_with_length(e, w->responseHeaders.size(), &arr);
  for (size_t i = 0; i < w->responseHeaders.size(); i++) {
    napi_create_string_utf8(e, w->responseHeaders[i].data(),
                            w->responseHeaders[i].size(), &v);
    napi_set_element(e, arr, i, v);
  }
  napi_set_named_property(e, o, "headers", arr);
  napi_resolve_deferred(e, w->deferred, o);
  napi_delete_async_work(e, w->work);
}
napi_value KomaSourceBrowserHttp(napi_env e, napi_callback_info info) {
  size_t argc = 5;
  napi_value v[5]{};
  napi_get_cb_info(e, info, &argc, v, nullptr, nullptr);
  auto w = std::make_unique<CurlWork>();
  bool ar = false;
  uint32_t n = 0;
  int64_t timeout = 0;
  if (argc != 5 || !str(e, v[0], w->id, 128) || !str(e, v[1], w->url, 8192) ||
      napi_is_array(e, v[2], &ar) != napi_ok || !ar ||
      napi_get_array_length(e, v[2], &n) != napi_ok || n > 128 ||
      napi_get_value_int64(e, v[3], &timeout) != napi_ok || timeout < 1 ||
      timeout > 60000 || !str(e, v[4], w->profile, 32) ||
      (w->profile != "firefox133" && w->profile != "chrome145")) {
    napi_throw_type_error(e, nullptr, "invalid request");
    return nullptr;
  }
  w->timeout = timeout;
  for (uint32_t i = 0; i < n; i++) {
    napi_value x;
    std::string h;
    if (napi_get_element(e, v[2], i, &x) != napi_ok || !str(e, x, h, 8192) ||
        h.find('\r') != std::string::npos ||
        h.find('\n') != std::string::npos) {
      napi_throw_type_error(e, nullptr, "invalid header");
      return nullptr;
    }
    w->headers.push_back(std::move(h));
  }
  napi_value promise, name;
  napi_create_promise(e, &w->deferred, &promise);
  napi_create_string_utf8(e, "sourceBrowserHttp", NAPI_AUTO_LENGTH, &name);
  {
    std::lock_guard<std::mutex> l(mu);
    if (calls.count(w->id)) {
      napi_throw_error(e, nullptr, "duplicate request");
      return nullptr;
    }
    calls[w->id] = w.get();
  }
  if (napi_create_async_work(e, nullptr, name, execute, complete, w.get(),
                             &w->work) != napi_ok ||
      napi_queue_async_work(e, w->work) != napi_ok) {
    std::lock_guard<std::mutex> l(mu);
    calls.erase(w->id);
    if (w->work)
      napi_delete_async_work(e, w->work);
    napi_throw_error(e, nullptr, "worker unavailable");
    return nullptr;
  }
  w.release();
  return promise;
}
napi_value KomaCancelSourceBrowserHttp(napi_env e, napi_callback_info info) {
  size_t n = 1;
  napi_value v;
  napi_get_cb_info(e, info, &n, &v, nullptr, nullptr);
  std::string id;
  if (n == 1 && str(e, v, id, 128)) {
    std::lock_guard<std::mutex> l(mu);
    auto i = calls.find(id);
    if (i != calls.end())
      i->second->cancelled.store(true);
  }
  napi_value x;
  napi_get_undefined(e, &x);
  return x;
}
