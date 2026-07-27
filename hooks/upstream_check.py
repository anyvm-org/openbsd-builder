#!/usr/bin/env python3
# Print the newest OpenBSD release directory, e.g. "7.9". Empty output
# means "nothing detected" and is not an error; a non-zero exit means
# detection itself is broken (network error, HTTP error, or a page that
# no longer matches the expected shape) and must be reported by the
# caller, never swallowed. A failure must NEVER print a plausible-but-
# wrong version -- the version is only printed after every step below
# has succeeded.
#
# Source of truth: https://cloudflare.cdn.openbsd.org/pub/OpenBSD/
# Fetched and confirmed by hand (2026-07-26): the directory is an Apache
# autoindex (modern "Index of" style with a sortable table), one row per
# entry, e.g.
#   <a href="7.7/">7.7/</a>
#   <a href="7.8/">7.8/</a>
#   <a href="7.9/">7.9/</a>
# alongside a mix of non-release entries that never look like a bare
# "X.Y/" version: Changelogs/, LibreSSL/, OpenBGPD/, OpenIKED/,
# OpenNTPD/, OpenSSH/, ftplist, patches/, robots.txt, rpki-client/,
# signify/, snapshots/, songs/, syspatch/, timestamp. None of those
# contain a digit-dot-digit run, so the version-shaped pattern below
# already excludes them without any extra filtering. Every real OpenBSD
# release directory is exactly "<major>.<minor>/" (two components, e.g.
# 7.9, never 7.9.1), so the pattern intentionally has no third segment.
# At fetch time the newest real entry was 7.9.
#
# stdlib only (urllib.request, re, sys, os) -- no external dependencies.

import os
import re
import sys
import urllib.request

URL = "https://cloudflare.cdn.openbsd.org/pub/OpenBSD/"
TIMEOUT = 60
USER_AGENT = "anyvm-org-upstream-watcher/1.0"

# Numbered release directories only -- exactly two dot-separated digit
# groups, same shape as the old shell script's sed pattern
# ([0-9][0-9]*\.[0-9][0-9]*), which already excludes every non-release
# entry (they contain no digit-dot-digit run at all) without extra
# filtering.
PATTERN = re.compile(r'href="(\d+\.\d+)/"')


def resolve_natural_key():
    """Return the engine's own natural_key, or fail loudly.

    watch.yml clones base-builder INTO the builder repo root, so at
    detection time it sits at "base-builder/" (relative to this hook's
    cwd, the builder repo root). A local checkout instead has it as a
    sibling, "../base-builder". Try both, in that order.

    There is deliberately NO local fallback copy. Ordering must be the
    single rule the engine uses -- a per-hook duplicate would have to be
    kept in sync by hand across every builder and would drift silently,
    and a hook that ranks versions differently from watch.py is worse
    than one that refuses to run. Both real contexts (CI and a local
    sibling checkout) always provide base-builder, so an ImportError here
    means the environment is wrong: report it as broken detection rather
    than guessing an order.
    """
    for candidate in ("base-builder", os.path.join("..", "base-builder")):
        if not os.path.isdir(candidate):
            continue
        path = os.path.abspath(candidate)
        if path not in sys.path:
            sys.path.insert(0, path)
        try:
            import gendata
            return gendata.natural_key
        except ImportError:
            continue
    raise ImportError(
        "base-builder/gendata.py not importable from %s; expected it at "
        "./base-builder (CI) or ../base-builder (local checkout)"
        % os.getcwd())


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read().decode("utf-8", "replace")


def main():
    try:
        key = resolve_natural_key()
    except ImportError as e:
        sys.stderr.write("upstream_check: %s\n" % e)
        return 1
    try:
        html = fetch(URL)
    except Exception as e:
        sys.stderr.write("upstream_check: fetch of %s failed: %s\n"
                         % (URL, e))
        return 1
    versions = PATTERN.findall(html)
    if not versions:
        sys.stderr.write("upstream_check: no release directory found in "
                         "%s; page shape may have changed\n" % URL)
        return 1
    newest = sorted(set(versions), key=key)[-1]
    print(newest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
