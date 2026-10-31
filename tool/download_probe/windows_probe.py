"""Bounded, no-login download experiment; run with the isolated probe venv."""
import argparse
import json
import pathlib
import shutil
import subprocess
import sys
import time
from urllib.parse import urlparse

HOSTS = {"youtube.com", "www.youtube.com", "youtu.be", "m.youtube.com",
         "facebook.com", "www.facebook.com", "m.facebook.com", "fb.watch",
         "tiktok.com", "www.tiktok.com", "vm.tiktok.com", "vt.tiktok.com",
         "x.com", "www.x.com", "twitter.com", "www.twitter.com"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--local-fixture", action="store_true")
    args = parser.parse_args()
    parsed = urlparse(args.url)
    local = args.local_fixture and parsed.hostname == "127.0.0.1"
    if parsed.username or parsed.password or not (
        (parsed.scheme == "https" and parsed.hostname in HOSTS)
        or (local and parsed.scheme == "http")
    ):
        parser.error("Use a public HTTPS URL from one of the four approved sites.")
    directory = args.output.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    # Each run gets its own directory; never mistake an old file for success.
    run = directory / str(time.time_ns())
    run.mkdir()
    command = [sys.executable, "-m", "yt_dlp", "--ignore-config", "--no-playlist",
               "--no-progress", "--socket-timeout", "20", "--retries", "1",
               "--extractor-retries", "1", "--max-filesize", "100M",
               "--js-runtimes", "node", "--write-info-json",
               "--format", "best[height<=480]/best",
               "--output", str(run / "media.%(ext)s"), "--", args.url]
    started = time.monotonic()
    try:
        result = subprocess.run(command, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=180)
        log = result.stdout + "\n" + result.stderr
        code = result.returncode
    except subprocess.TimeoutExpired:
        log, code = "Probe exceeded 180 seconds", -1
    (run / "download.log").write_text(log, encoding="utf-8")
    media = [p for p in run.iterdir() if p.suffix.lower() in
             {".mp4", ".webm", ".mkv", ".mov", ".flv", ".avi"} and p.stat().st_size]
    summary = {"url": args.url, "platform": "windows", "exitCode": code,
               "elapsedSeconds": round(time.monotonic() - started, 2),
               "downloaded": code == 0 and bool(media), "validated": False,
               "files": [{"path": str(p), "bytes": p.stat().st_size} for p in media]}
    if summary["downloaded"] and shutil.which("ffprobe"):
        probe = subprocess.run(["ffprobe", "-v", "error", "-show_streams",
                                "-show_format", "-of", "json", str(media[0])],
                               capture_output=True, text=True, timeout=30)
        if probe.returncode == 0:
            metadata = json.loads(probe.stdout)
            summary["streams"] = [{"type": s.get("codec_type"),
                                    "codec": s.get("codec_name")}
                                   for s in metadata.get("streams", [])]
            summary["durationSeconds"] = metadata.get("format", {}).get("duration")
            summary["validated"] = any(s["type"] == "video" for s in summary["streams"])
    if not summary["downloaded"]:
        summary["error"] = log[-2500:]
    (run / "result.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=True, indent=2))
    return 0 if summary["validated"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
