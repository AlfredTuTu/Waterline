#!/usr/bin/env python3
"""Generate a reviewable cask from a signed, stapled DMG; never publish or install it."""
import argparse
import hashlib
import os
import pathlib
import plistlib
import re
import subprocess
import tempfile
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent


def render(version, digest, url, architectures):
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("A stable numeric release version is required")
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("An actual SHA-256 digest is required")
    parsed = urllib.parse.urlsplit(url)
    expected = rf"/AlfredTuTu/Waterline/releases/download/v{re.escape(version)}/Waterline-[A-Za-z0-9._-]+\.dmg"
    if (parsed.scheme != "https" or parsed.netloc != "github.com" or parsed.query or parsed.fragment
            or not re.fullmatch(expected, parsed.path)):
        raise ValueError("Use this project's versioned HTTPS GitHub release asset URL")
    arches = set(architectures)
    if not arches or not arches <= {"arm64", "x86_64"}:
        raise ValueError("Unsupported or missing executable architecture")
    dependency = f"  depends_on arch: :{next(iter(arches))}\n" if len(arches) == 1 else ""
    return (f'cask "waterline" do\n  version "{version}"\n  sha256 "{digest}"\n\n'
            f'  url "{url}"\n  name "Waterline"\n'
            '  desc "Menu bar monitor for AI account usage and balances"\n'
            '  homepage "https://github.com/AlfredTuTu/Waterline"\n\n'
            f'  depends_on macos: :sonoma\n{dependency}\n  app "Waterline.app"\nend\n')


def run(*arguments):
    return subprocess.run(arguments, check=True, capture_output=True, text=True).stdout.strip()


def main():
    os.environ.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dmg", type=pathlib.Path)
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    if args.output.exists() or args.output.is_symlink():
        parser.error("Output must be a new file")
    dmg = args.dmg.resolve(strict=True)
    initial_stat = dmg.stat()
    run("codesign", "--verify", "--strict", str(dmg))
    signature = subprocess.run(["codesign", "-dv", "--verbose=4", str(dmg)], check=True,
                               capture_output=True, text=True).stderr
    if "Authority=Developer ID Application:" not in signature or "Timestamp=" not in signature:
        raise ValueError("DMG needs a Developer ID signature and secure timestamp")
    run("xcrun", "stapler", "validate", str(dmg))
    run("hdiutil", "verify", str(dmg))
    mount = pathlib.Path(tempfile.mkdtemp(prefix="waterline-cask-")).resolve()
    mounted = False
    try:
        run("hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount), str(dmg))
        mounted = True
        app = mount / "Waterline.app"
        if app.is_symlink() or not app.is_dir():
            raise ValueError("The DMG must contain a real Waterline.app directory")
        for entry in app.rglob("*"):
            if entry.is_symlink() and not entry.resolve().is_relative_to(mount):
                raise ValueError("App symlink escapes the mounted artifact")
        run("bash", str(ROOT / "Scripts/check-distribution.sh"), str(app))
        with (app / "Contents/Info.plist").open("rb") as source:
            info = plistlib.load(source)
        if info.get("CFBundleExecutable") != "WaterlineApp":
            raise ValueError("Unexpected bundle executable")
        arches = run("lipo", "-archs", str(app / "Contents/MacOS/WaterlineApp")).split()
        digest_state = hashlib.sha256()
        with dmg.open("rb") as source:
            for chunk in iter(lambda: source.read(1_048_576), b""):
                digest_state.update(chunk)
        digest = digest_state.hexdigest()
        final_stat = dmg.stat()
        if (initial_stat.st_dev, initial_stat.st_ino, initial_stat.st_size, initial_stat.st_mtime_ns) != (
                final_stat.st_dev, final_stat.st_ino, final_stat.st_size, final_stat.st_mtime_ns):
            raise ValueError("Artifact changed during validation")
        output = render(info["CFBundleShortVersionString"], digest, args.url, arches)
    finally:
        if mounted:
            run("hdiutil", "detach", str(mount))
        mount.rmdir()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x") as destination:
        destination.write(output)
    print(f"Cask generated: {args.output}. Online audit and clean installation remain required.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Cask generation stopped: {error}") from None
