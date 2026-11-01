"""Bump the release version in every place it lives, keeping them in sync.

    python3 tools/bump_version.py          # patch: 0.0.1 -> 0.0.2 (the default for updates)
    python3 tools/bump_version.py minor    # 0.0.7 -> 0.1.0

Also raises the store build numbers by one (iOS application/version, Android version/code),
since each upload needs a new, higher build number.
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
PROJECT = os.path.join(ROOT, "project.godot")
PRESETS = os.path.join(ROOT, "export_presets.cfg")


def main():
    part = sys.argv[1] if len(sys.argv) > 1 else "patch"
    proj = open(PROJECT).read()
    old = re.search(r'^config/version="(\d+)\.(\d+)\.(\d+)"', proj, re.M)
    major, minor, patch = map(int, old.groups())
    if part == "major":
        major, minor, patch = major + 1, 0, 0
    elif part == "minor":
        minor, patch = minor + 1, 0
    else:
        patch += 1
    new = "%d.%d.%d" % (major, minor, patch)
    proj = proj[:old.start()] + 'config/version="%s"' % new + proj[old.end():]

    pre = open(PRESETS).read()
    pre = re.sub(r'^(application/short_version|version/name)="[^"]*"', r'\1="%s"' % new, pre, flags=re.M)
    pre = re.sub(r'^application/version="(\d+)"', lambda m: 'application/version="%d"' % (int(m.group(1)) + 1), pre, flags=re.M)
    pre = re.sub(r'^version/code=(\d+)', lambda m: "version/code=%d" % (int(m.group(1)) + 1), pre, flags=re.M)

    open(PROJECT, "w").write(proj)
    open(PRESETS, "w").write(pre)
    build = re.search(r'^application/version="(\d+)"', pre, re.M).group(1)
    print("version %s (iOS build %s)" % (new, build))


if __name__ == "__main__":
    main()
