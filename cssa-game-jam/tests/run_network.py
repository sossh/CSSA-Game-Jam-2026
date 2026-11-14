#!/usr/bin/env python3
"""Six-process ENet test, including a late join and a peer disconnect."""
import os
import pathlib
import socket
import subprocess
import tempfile
import time

project = pathlib.Path(__file__).resolve().parents[1]
base = [os.environ.get("GODOT_BIN", "godot"), "--headless", "--path", str(project), "--", "--network-test", "--skip-intro", "--quit-after=35"]
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
    reservation.bind(("127.0.0.1", 0))
    base.append(f"--port={reservation.getsockname()[1]}")
with tempfile.TemporaryDirectory(prefix="cosmic-network-") as folder:
    folder = pathlib.Path(folder)
    processes, handles, paths = [], [], []

    def start(args):
        path = folder / f"peer{len(paths)}.log"
        handle = path.open("w")
        paths.append(path)
        handles.append(handle)
        processes.append(subprocess.Popen(base + args, stdout=handle, stderr=subprocess.STDOUT))

    def until(marker, timeout=15):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if marker in paths[0].read_text():
                return
            time.sleep(0.1)
        raise RuntimeError(f"Host did not reach {marker}")

    try:
        start(["--host", "--loopback"])
        time.sleep(1)
        for _ in range(4):
            start(["--join=127.0.0.1"])
        until("NETWORK_READY_FOR_LATE_JOIN")
        start(["--join=127.0.0.1", "--late"])
        until("NETWORK_READY_FOR_DISCONNECT")
        processes[-1].wait(timeout=5)
        processes[0].wait(timeout=15)
        for process in processes[1:-1]:
            process.wait(timeout=40)
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
        for handle in handles:
            handle.close()
        logs = [path.read_text() for path in paths]
        for path, log in zip(paths, logs):
            print(path.name)
            print(log)
    success = "NETWORK_HOST_PASSED" in logs[0]
    success &= all("NETWORK_CLIENT_PASSED" in log for log in logs[1:])
    success &= all("ERROR:" not in log and "WARNING:" not in log for log in logs)
    raise SystemExit(0 if success else 1)
