"""Run the separate Android experiment and collect app-owned result evidence."""
import argparse
import json
import pathlib
import shlex
import subprocess
import time

PACKAGE = "com.noor.player.downloadprobe"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("--adb", required=True)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--local-fixture", action="store_true")
    parser.add_argument("--update-engine", action="store_true")
    args = parser.parse_args()
    adb = [args.adb, "-s", args.serial]

    def call(*parts, **kwargs):
        return subprocess.run(adb + list(parts), capture_output=True,
                              text=True, encoding="utf-8", errors="replace",
                              timeout=30, **kwargs)

    args.output.mkdir(parents=True, exist_ok=True)
    # This package is only the test APK, never the user's NOOR app.
    call("shell", "am", "force-stop", PACKAGE)
    before = call("shell", "run-as", PACKAGE, "cat", "files/latest-result.json").stdout
    command = ["am", "start", "-n", PACKAGE + "/.ProbeActivity", "--es", "url", args.url,
               "--ez", "local_fixture", str(args.local_fixture).lower(),
               "--ez", "update_engine", str(args.update_engine).lower()]
    launch = call("shell", shlex.join(command))
    if launch.returncode:
        raise RuntimeError(launch.stderr)
    deadline = time.monotonic() + 210
    while time.monotonic() < deadline:
        response = call("shell", "run-as", PACKAGE, "cat", "files/latest-result.json")
        if response.returncode == 0 and response.stdout and response.stdout != before:
            try:
                result = json.loads(response.stdout)
            except json.JSONDecodeError:
                time.sleep(1)
                continue
            (args.output / "result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
            print(json.dumps(result, ensure_ascii=True, indent=2))
            return 0 if result.get("downloaded") and result.get("validated") else 1
        time.sleep(2)
    call("shell", "am", "force-stop", PACKAGE)
    result = {"url": args.url, "platform": "android", "downloaded": False,
              "validated": False, "error": "No result within 210 seconds; probe stopped"}
    (args.output / "result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
