#!/usr/bin/env python3
# Print the newest PUBLISHED OpenBSD release, e.g. "7.9". Empty output
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
# A RELEASE DIRECTORY IS NOT A RELEASE. OpenBSD creates the next
# release's directory weeks before the release, to stage its packages:
# on 2026-10-01 "8.0/" was listed in the index but held nothing except
# "packages/" -- no amd64/, no SHA256, no install media. The previous
# version of this hook printed the bare directory name, so watch.py
# modelled 8.0 confs on 7.9, every derived install80.iso/.img URL got
# HTTP 404 at the HEAD gate, the run went red and filed an issue
# (https://github.com/anyvm-org/openbsd-builder/actions/runs/36794686189).
# That would repeat every night until the real 8.0 release.
#
# So a version only counts once its amd64 install ISO -- the media the
# base conf (openbsd-<ver>.conf) installs from -- answers. A clean 404
# means "staged, not released": that version is skipped and the next
# newest one is considered, which already has confs, so the run stays
# green and quiet until the media appears. Any other failure (another
# HTTP status, a network error) is broken detection and exits non-zero.
# OpenBSD publishes every platform of a release together, so amd64 is
# the marker; if another arch were ever late, the HEAD gate still
# catches it for that one night, which is a real signal.
#
# stdlib only (urllib.request, urllib.error, re, sys, os) -- no external
# dependencies.

import os
import re
import sys
import urllib.error
import urllib.request

URL = "https://cloudflare.cdn.openbsd.org/pub/OpenBSD/"
# Same path as VM_ISO_LINK in conf/openbsd-<ver>.conf.
MEDIA = URL + "{v}/amd64/install{vc}.iso"
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


def published(version):
    """True when <version>'s amd64 install ISO exists, False on a 404.

    Any other outcome raises, so the caller reports broken detection
    instead of mistaking an outage for "not released yet".
    """
    url = MEDIA.format(v=version, vc=version.replace(".", ""))
    req = urllib.request.Request(url, method="HEAD",
                                 headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT):
            return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        raise


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
    for version in sorted(set(versions), key=key, reverse=True):
        try:
            ok = published(version)
        except Exception as e:
            sys.stderr.write("upstream_check: media check for %s failed: "
                             "%s\n" % (version, e))
            return 1
        if ok:
            print(version)
            return 0
        sys.stderr.write("upstream_check: %s/ is listed but its install "
                         "media is not published yet, skipping\n" % version)
    sys.stderr.write("upstream_check: no listed release has install media "
                     "at %s; media naming may have changed\n"
                     % MEDIA.format(v="X.Y", vc="XY"))
    return 1


if __name__ == "__main__":
    sys.exit(main())
