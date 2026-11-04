#!/usr/bin/env python3
"""Prune reproducible video frames and trace databases from Koma validation runs."""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = ROOT / '.hvigor' / 'outputs'


def local_file(path):
    return not path.is_symlink() and path.is_file() and path.resolve().is_relative_to(OUTPUTS)


def candidates():
    for summary in OUTPUTS.rglob('summary.txt'):
        if not local_file(summary):
            continue
        match = re.search(r'^input=(.+)$', summary.read_text(errors='replace'), re.M)
        if not match:
            continue
        video = ROOT / match[1]
        if video.suffix.lower() != '.mp4' or not local_file(video) or not video.stat().st_size:
            continue
        frames = summary.parent / 'frames'
        if not frames.is_symlink() and (summary.parent / 'frame-timeline.tsv').is_file():
            yield from (p for p in frames.glob('frame_*.png') if re.fullmatch(r'frame_\d+\.png', p.name))

    for meta in OUTPUTS.rglob('meta.json'):
        if not local_file(meta) or not (meta.parent / 'summary.json').is_file():
            continue
        try:
            rows = json.loads(meta.read_text())
        except (ValueError, OSError):
            continue
        if not isinstance(rows, list):
            continue
        sources = [Path(row['value']) for row in rows if isinstance(row, dict) and
                   row.get('name') == 'source_name' and isinstance(row.get('value'), str)]
        if any(p.suffix == '.htrace' and local_file(p) and p.stat().st_size for p in sources):
            yield meta.parent / 'trace.db'
            yield meta.parent / 'trace.db.ohos.ts'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--days', type=int, default=14)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if args.days < 0:
        parser.error('--days must be nonnegative')
    cutoff = time.time() - args.days * 86400
    open_paths = set()
    if args.apply:
        result = subprocess.run(['/usr/sbin/lsof', '-nP', '-Fn'], capture_output=True, text=True)
        if result.returncode or not result.stdout:
            raise SystemExit('Unable to list open files, cleanup skipped')
        open_paths = {line[1:] for line in result.stdout.splitlines() if line.startswith('n/')}
    count = allocated = 0
    for path in candidates():
        if not local_file(path) or str(path.resolve()) in open_paths:
            continue
        info = path.stat()
        if info.st_mtime >= cutoff:
            continue
        if args.apply:
            path.unlink()
        count += 1
        allocated += info.st_blocks * 512
    print(json.dumps({'applied': args.apply, 'files': count, 'allocatedBytes': allocated}))


if __name__ == '__main__':
    main()
