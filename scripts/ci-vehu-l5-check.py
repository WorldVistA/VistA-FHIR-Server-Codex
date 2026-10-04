#!/usr/bin/env python3
"""ci-vehu-l5-check.py — L5 gates for one /addpatient round trip.

Usage: ci-vehu-l5-check.py <source-bundle.json> <addpatient-response.json> <readback.json> [Domain=maxErr ...]

Gates (exit 1 if any fails):
  * no domain reports not_implemented (missing/stale routine on the target)
  * per-domain entry error rate <= MAX_ERR (default 10%; Procedure 5%); a caller
    may raise one for a known, documented data gap (e.g. Lab=0.14). A single
    error never fails a domain: random Synthea patients have small domains
    (1 unmapped Condition in 9 is 11%) and one entry is noise, not a trend
  * readback is strict JSON (catches the encode-tail "Extra data" regression)
  * every CORE resource type present in the source reads back
"""
import collections
import json
import sys

MAX_ERR = {"_default": 0.10, "Procedure": 0.05}
CORE = ["Patient", "Encounter", "Condition", "Observation", "Procedure", "Immunization"]


def types(bundle):
    c = collections.Counter()
    for e in bundle.get("entry", []):
        rt = (e.get("resource") or {}).get("resourceType")
        if rt:
            c[rt] += 1
    return c


def main(src_path, add_path, rb_path, *overrides):
    fails, notes = [], []
    limits = dict(MAX_ERR)
    for o in overrides:
        d, v = o.split("=", 1)
        limits[d] = float(v)
    add = json.load(open(add_path))
    notes.append(f"loadStatus={add.get('loadStatus')}")
    doms = []
    for dom, v in sorted((add.get("domains") or {}).items()):
        e = collections.Counter(v.get("entries") or [v.get("status")])
        tot = sum(e.values())
        err = e.get("error", 0)
        doms.append(f"{dom} {tot - err}/{tot}")
        if e.get("not_implemented"):
            fails.append(f"{dom} not_implemented: {str(v.get('message', ''))[:80]}")
        lim = limits.get(dom, limits["_default"])
        if err > 1 and err / tot > lim:
            fails.append(f"{dom} error rate {err}/{tot} > {lim:.0%}")
    notes.append("ok/total: " + ", ".join(doms))
    try:
        rb = json.loads(open(rb_path, encoding="utf-8", errors="strict").read())
    except Exception as ex:  # strict parse is the gate
        fails.append(f"readback not strict JSON: {str(ex)[:80]}")
        rb = {}
    s, r = types(json.load(open(src_path))), types(rb)
    missing = [t for t in CORE if s.get(t) and not r.get(t)]
    if missing:
        fails.append("core types missing on readback: " + ",".join(missing))
    notes.append(f"readback {sum(r.values())}/{sum(s.values())} entries, {len(r)}/{len(s)} types")
    print("; ".join(notes))
    for f in fails:
        print("FAIL " + f)
    return 1 if fails else 0


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(*sys.argv[1:]))
