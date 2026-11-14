#!/usr/bin/env python3
"""Run a real host plus ENet client, fail on assertions or engine errors."""
import argparse
import os
import pathlib
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument("--render", action="store_true", help="Render host and save cosmic-detention.png in the system temp folder")
args = parser.parse_args()
project = pathlib.Path(__file__).resolve().parents[1]
base = [os.environ.get("GODOT_BIN", "godot"), "--path", str(project)]
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
    reservation.bind(("127.0.0.1", 0))
    port_arg = f"--port={reservation.getsockname()[1]}"
host_args = ["--rendering-method", "gl_compatibility"] if args.render else ["--headless"]
screenshot_args = [f"--smoke-screenshot={pathlib.Path(tempfile.gettempdir()) / 'cosmic-detention.png'}"] if args.render else []
with tempfile.TemporaryDirectory(prefix="cosmic-smoke-") as folder:
    paths = [pathlib.Path(folder) / name for name in ("host.log", "client.log")]
    processes = []
    handles = [path.open("w") for path in paths]
    try:
        processes.append(subprocess.Popen(base + host_args + ["--", port_arg, "--host", "--loopback", "--smoke", "--skip-intro", "--quit-after=30"] + screenshot_args, stdout=handles[0], stderr=subprocess.STDOUT))
        time.sleep(1.5)
        processes.append(subprocess.Popen(base + ["--headless", "--", port_arg, "--join=127.0.0.1", "--smoke", "--skip-intro", "--quit-after=20"], stdout=handles[1], stderr=subprocess.STDOUT))
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
