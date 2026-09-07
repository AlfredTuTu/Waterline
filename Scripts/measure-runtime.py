#!/usr/bin/env python3
"""Measure one existing Waterline process; never launch, restart or alter its configuration."""
import argparse
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
import time


def command(*arguments):
    return subprocess.run(arguments, check=True, capture_output=True, text=True).stdout.strip()


def identity(pid):
    return command("ps", "-p", str(pid), "-o", "lstart=,comm=")


def cpu_seconds(pid):
    parts = command("ps", "-p", str(pid), "-o", "time=").split(":")
    return sum(float(value) * 60**index for index, value in enumerate(reversed(parts)))


def footprint(pid):
    result = command("footprint", "-p", str(pid), "--noCategories", "-f", "bytes")
    current = re.search(r"phys_footprint:\s+(\d+) B", result)
    peak = re.search(r"phys_footprint_peak:\s+(\d+) B", result)
    if not current or not peak:
        raise RuntimeError("Physical footprint fields unavailable")
    return int(current[1]), int(peak[1])


def configuration(path):
    snapshot = json.loads(path.read_text())
    return {
        "preferences": snapshot["preferences"],
        "accounts": sorted(
            ({"provider": row["account"]["provider"], "enabled": row["preferences"]["enabled"]}
             for row in snapshot["accounts"]), key=lambda row: (row["provider"], row["enabled"])),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--executable", type=pathlib.Path, required=True)
    parser.add_argument("--snapshot", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--scope", choices=["real", "fixtures"], default="real")
    args = parser.parse_args()
    initial_identity = identity(args.pid)
    if not initial_identity.endswith(str(args.executable.resolve())):
        raise RuntimeError("PID does not match the selected executable")
    initial_hash = hashlib.sha256(args.executable.read_bytes()).hexdigest()
    if args.scope == "fixtures":
        snapshot = json.loads(args.snapshot.read_text())
        kinds = []
        for row in snapshot["accounts"]:
            if not row["account"]["id"].startswith("verification-"):
                raise RuntimeError("Fixture measurement contains a non-fixture account")
            reading = row["state"].get("fresh", {}).get("reading", {})
            if reading.get("origin") != "verification":
                raise RuntimeError("Fixture reading is not marked as verification data")
            usage = reading.get("usage", {})
            metrics = usage.get("metrics", {})
            windows = bool(metrics.get("windows") or usage.get("windows", {}).get("windows") or usage.get("both", {}).get("windows"))
            balances = bool(metrics.get("balances") or usage.get("balance", {}).get("balance") or usage.get("both", {}).get("balance"))
            kinds.append("both" if windows and balances else "window" if windows else "balance" if balances else "missing")
        if sorted(kinds) != ["balance", "both", "window", "window"]:
            raise RuntimeError("Expected two window, one balance and one both-kind fixture accounts")
    report = {
        "status": "running", "pid": args.pid, "process_identity": initial_identity,
        "executable_sha256": initial_hash,
        "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "os": command("sw_vers"), "hardware": command("sysctl", "-n", "hw.model", "hw.memsize"),
        "configuration": configuration(args.snapshot), "scope": args.scope,
        "warmup_seconds": 600, "sample_seconds": 600, "interval_seconds": 1,
        "samples": [],
    }
    try:
        started = time.monotonic()
        print(f"warmup_started pid={args.pid}", flush=True)
        for minute in range(1, 11):
            time.sleep(max(0, started + minute * 60 - time.monotonic()))
            if identity(args.pid) != initial_identity:
                raise RuntimeError("Target process exited or was replaced")
            print(f"warmup_minutes={minute}", flush=True)
        cpu_start = cpu_seconds(args.pid)
        sample_start = time.monotonic()
        print("sampling_started", flush=True)
        for index in range(600):
            time.sleep(max(0, sample_start + index - time.monotonic()))
            if identity(args.pid) != initial_identity:
                raise RuntimeError("Target process exited or was replaced")
            current, peak = footprint(args.pid)
            report["samples"].append({
                "elapsed_seconds": time.monotonic() - sample_start,
                "physical_bytes": current, "lifetime_peak_physical_bytes": peak,
                "cpu_seconds": cpu_seconds(args.pid),
            })
            if (index + 1) % 60 == 0:
                print(f"samples={index + 1} physical_bytes={current}", flush=True)
        time.sleep(max(0, sample_start + 600 - time.monotonic()))
        elapsed = time.monotonic() - sample_start
        report["mean_cpu_percent"] = (cpu_seconds(args.pid) - cpu_start) / elapsed * 100
        report["sampled_peak_physical_bytes"] = max(row["physical_bytes"] for row in report["samples"])
        report["lifetime_peak_physical_bytes"] = max(row["lifetime_peak_physical_bytes"] for row in report["samples"])
        report["configuration_unchanged"] = configuration(args.snapshot) == report["configuration"]
        report["executable_unchanged"] = hashlib.sha256(args.executable.read_bytes()).hexdigest() == initial_hash
        report["status"] = "measured"
        print("measurement_complete", flush=True)
    except Exception as error:
        report["status"] = "failed"
        report["error"] = str(error)
        raise
    finally:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n")
        print(f"report={args.output}", flush=True)


if __name__ == "__main__":
    main()
