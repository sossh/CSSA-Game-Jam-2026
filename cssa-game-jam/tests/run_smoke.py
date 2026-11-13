#!/usr/bin/env python3
"""Run a real host plus ENet client, fail on assertions or engine errors."""
import argparse
import pathlib
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument("--render", action="store_true", help="Render host and save /tmp/opencode/cosmic-detention.png")
args = parser.parse_args()
project = pathlib.Path(__file__).resolve().parents[1]
base = ["godot", "--path", str(project)]
host_args = ["--rendering-method", "gl_compatibility"] if args.render else ["--headless"]
with tempfile.TemporaryDirectory(prefix="cosmic-smoke-", dir="/tmp/opencode") as folder:
    paths = [pathlib.Path(folder) / name for name in ("host.log", "client.log")]
    processes = []
    handles = [path.open("w") for path in paths]
    try:
        processes.append(subprocess.Popen(base + host_args + ["--", "--host", "--loopback", "--smoke", "--skip-intro", "--quit-after=30"], stdout=handles[0], stderr=subprocess.STDOUT))
        time.sleep(1.5)
        processes.append(subprocess.Popen(base + ["--headless", "--", "--join=127.0.0.1", "--smoke", "--skip-intro", "--quit-after=20"], stdout=handles[1], stderr=subprocess.STDOUT))
        for process in processes:
            process.wait(timeout=40)
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
        for handle in handles:
            handle.close()
    logs = [path.read_text() for path in paths]
    for name, log in zip(("HOST", "CLIENT"), logs):
        print(name)
        print(log)
    success = all(process.returncode == 0 for process in processes)
    success &= "SMOKE_HOST_PASSED" in logs[0] and "SMOKE_CLIENT_PASSED" in logs[1]
    success &= all("ERROR:" not in log and "SCRIPT ERROR" not in log and "WARNING:" not in log for log in logs)
    raise SystemExit(0 if success else 1)
