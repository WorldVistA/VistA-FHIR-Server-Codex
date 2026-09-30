#!/usr/bin/env python3
"""ci-vehu-l6-rates.py — L6 cohort load gate: honest per-domain filing rates.

Aggregates the /addpatient?load=1 responses of a cohort run and compares each
domain's ok-rate (loaded+skipped over entries) with scripts/vehu-l6-baseline.json.
"Honest" = what the loader actually filed; no post-hoc remediation (C0FZREPR
LABGRAPH relabels errors as graph-retained, so showfhir's 100% is not a target).

Usage:
  ci-vehu-l6-rates.py <responses-dir>             # exit 1 if a domain drops >2 pts
  ci-vehu-l6-rates.py <responses-dir> --update    # record the baseline
"""
import collections
import json
import pathlib
import sys

BASELINE = pathlib.Path(__file__).with_name("vehu-l6-baseline.json")
SLACK = 2.0  # percentage points a domain may drift below baseline


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    tot, err, ni = collections.Counter(), collections.Counter(), collections.Counter()
    status = collections.Counter()
    files = sorted(pathlib.Path(sys.argv[1]).glob("*.json"))
    for f in files:
        try:
            d = json.loads(f.read_text())
        except Exception:
            status["unparseable"] += 1
            continue
        status[d.get("loadStatus") or d.get("patient", {}).get("loadStatus") or "none"] += 1
        for dom, v in (d.get("domains") or {}).items():
            e = collections.Counter(v.get("entries") or [v.get("status")])
            tot[dom] += sum(e.values())
            err[dom] += e.get("error", 0)
            ni[dom] += e.get("not_implemented", 0)
    rates = {d: round(100.0 * (tot[d] - err[d] - ni[d]) / tot[d], 1) for d in tot if tot[d]}
    print(f"patients={len(files)} loadStatus={dict(status)}")
    print("ok%: " + ", ".join(f"{d} {rates[d]} ({tot[d] - err[d] - ni[d]}/{tot[d]})" for d in sorted(rates)))
    if "--update" in sys.argv:
        BASELINE.write_text(json.dumps({"patients": len(files), "okPct": rates}, indent=1, sort_keys=True) + "\n")
        print(f"baseline recorded: {BASELINE}")
        return 0
    if not BASELINE.exists():
        print("no baseline yet (run with --update after a clean run)")
        return 1
    base = json.loads(BASELINE.read_text())["okPct"]
    fails = [f"{d} {rates.get(d, 0)} < baseline {b} - {SLACK}" for d, b in sorted(base.items())
             if rates.get(d, 0) < b - SLACK]
    fails += [f"{d} not_implemented x{n}" for d, n in sorted(ni.items()) if n]
    for f in fails:
        print("FAIL " + f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
