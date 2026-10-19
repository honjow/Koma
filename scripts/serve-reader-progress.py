#!/usr/bin/env python3
"""Read-only local view of an authoritative work order; no device calls."""
import argparse
import hashlib
import json
import mimetypes
import re
import subprocess
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parents[1]
ORDER = ROOT / 'docs/CURRENT_STATUS.md'
PAGE = ROOT / 'docs/qa/koma-production-progress.html'
ARTIFACTS = ROOT / '.hermes-artifacts/recovery-20261019'
KIT = ROOT.parent / 'reader-kit'
MARKER = re.compile(r'<!-- koma-progress-snapshot\s*\n(.*?)\n-->', re.S)
# Exact reviewed receipt IDs only; never serve arbitrary work-order paths.
EVIDENCE_ALLOWLIST = {'b744-preservation': {'path': 'kit-b744-parent-content-complete-r134-20261019.receipt.json', 'sha256': 'a4f2f4d5f0d6887da868d01fb8d5253fefdd962d5f3a1bd405e0feb16ef9487d'}, 'app05-retirement': {'path': 'app-production05-exact-admin-retirement-2958a016-result.json', 'sha256': '11b027e30cf74e23462ef19aa3b3db27b141464f7d8b7a40834caafb88be9602'}, 'comicabc-cleanup': {'path': 'comicabc-eleven-evidence-parents-cleanup-result.json', 'sha256': 'd619d9adca186e6efa368703c05dd040b4af9290d7b77c26493dedee78e874da'}}

def snapshot():
    match = MARKER.search(ORDER.read_text())
    if not match:
        raise ValueError('Work-order progress snapshot is missing')
    data = json.loads(match.group(1))
    if data.get('schemaVersion') != 1:
        raise ValueError('Unsupported progress snapshot version')
    return data


def live_kit_heads(data):
    # Koma's current build reads the sibling Kit, not an embedded gitlink.
    try:
        head = subprocess.check_output(
            ['git', '-C', str(KIT), 'rev-parse', 'HEAD'],
            text=True, timeout=2).strip()
    except (OSError, subprocess.SubprocessError):
        head = None
    return {'Koma': head}


class Handler(BaseHTTPRequestHandler):
    kit_cache = (0, None)

    def log_message(self, *_):
        pass

    def reply(self, status, body, content_type='application/json; charset=utf-8'):
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        route = urlparse(self.path)
        try:
            if route.path in ('/', '/index.html'):
                return self.reply(200, PAGE.read_bytes(), 'text/html; charset=utf-8')
            if route.path == '/api/progress':
                data = snapshot()
                stamp, cache = Handler.kit_cache
                if time.monotonic() - stamp > 10 or cache is None:
                    cache = live_kit_heads(data)
                    Handler.kit_cache = (time.monotonic(), cache)
                data['liveKitHeads'] = cache
                data['servedAt'] = datetime.now(timezone.utc).isoformat()
                return self.reply(200, json.dumps(data, ensure_ascii=False).encode())
            if route.path == '/work-order':
                return self.reply(200, ORDER.read_bytes(), 'text/plain; charset=utf-8')
            if route.path == '/evidence':
                evidence_id = parse_qs(route.query).get('id', [''])[0]
                entries = {e['id']: e for e in snapshot()['evidence']}
                entry = entries.get(evidence_id)
                if entry is None:
                    return self.reply(404, b'{"error":"Unknown evidence"}')
                allowed = EVIDENCE_ALLOWLIST.get(evidence_id)
                if (allowed is None or entry.get('storage') != 'recovery'
                        or entry.get('path') != allowed['path']):
                    return self.reply(404, b'{"error":"Unknown evidence storage or path"}')
                path = (ARTIFACTS / allowed['path']).resolve()
                if not path.is_relative_to(ARTIFACTS.resolve()) or not path.is_file():
                    return self.reply(404, b'{"error":"Evidence unavailable"}')
                if hashlib.sha256(path.read_bytes()).hexdigest() != allowed['sha256']:
                    return self.reply(503, b'{"error":"Evidence changed since review"}')
                mime = mimetypes.guess_type(path)[0] or 'application/octet-stream'
                # Range requests allow the browser to seek through local recordings.
                size = path.stat().st_size
                start, end = 0, size - 1
                range_header = self.headers.get('Range')
                status = 200
                if range_header:
                    match = re.fullmatch(r'bytes=(\d+)-(\d*)', range_header)
                    if not match:
                        return self.reply(416, b'{"error":"Unsupported range"}')
                    start = int(match.group(1))
                    end = min(int(match.group(2)) if match.group(2) else end, end)
                    if start > end:
                        return self.reply(416, b'{"error":"Range out of bounds"}')
                    status = 206
                self.send_response(status)
                self.send_header('Content-Type', mime)
                self.send_header('Accept-Ranges', 'bytes')
                self.send_header('Content-Length', str(end - start + 1))
                self.send_header('Cache-Control', 'no-store')
                self.send_header('X-Content-Type-Options', 'nosniff')
                if status == 206:
                    self.send_header('Content-Range', f'bytes {start}-{end}/{size}')
                self.end_headers()
                with path.open('rb') as stream:
                    stream.seek(start)
                    remaining = end - start + 1
                    while remaining:
                        chunk = stream.read(min(remaining, 65536))
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                        remaining -= len(chunk)
                return
            self.reply(404, b'{"error":"Not found"}')
        except (BrokenPipeError, ConnectionResetError):
            pass
        except (OSError, ValueError, KeyError) as error:
            self.reply(503, json.dumps({'error': str(error)}, ensure_ascii=False).encode())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, choices=[8766], default=8766)
    args = parser.parse_args()
    snapshot()  # Refuse to serve a missing/malformed authority document.
    if not PAGE.is_file():
        parser.error('Progress page is missing')
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(f'Local progress: http://127.0.0.1:{args.port}', flush=True)
    server.serve_forever()
