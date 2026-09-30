#!/usr/bin/env python3
"""xindex-gate.py — fail on NEW fatal (F) XINDEX findings versus a committed baseline.

Reads a captured XINDEX run (the "Compiled list of Errors and Warnings" output),
keys each finding as routine|tag|class|message (the +offset is dropped so edits
above a finding do not look like new findings), and compares the F-class multiset
with scripts/xindex-baseline.tsv. Known-acceptable F findings on VEHU today:
RPMS-only / optional-module routine references (guarded at runtime), YottaDB
ZY* commands XINDEX predates, and $ZYHASH-style functions.

Usage:
  xindex-gate.py <xindex.log>            # print counts; exit 1 on new F findings
  xindex-gate.py <xindex.log> --update   # re-record the baseline
"""
import collections
import pathlib
import re
import sys

BASELINE = pathlib.Path(__file__).with_name("xindex-baseline.tsv")
HDR = re.compile(r"^([%A-Z0-9]+)\s+\* \*\s+\d+ Lines")
FIND = re.compile(r"^\s+(\S+)\s+([FEWSI]) - (.*\S)\s*$")


def parse(path):
    rows, routine = [], ""
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        m = HDR.match(line)
        if m:
            routine = m.group(1)
            continue
        m = FIND.match(line)
        if m and routine:
            tag = m.group(1).split("+")[0]
            rows.append((routine, tag, m.group(2), m.group(3)))
    return rows


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    rows = parse(sys.argv[1])
    if not rows:
        print("XINDEX: no findings parsed (did XINDEX run?)")
        return 1
    counts = collections.Counter(r[2] for r in rows)
    routines = len({r[0] for r in rows})
    fatal = collections.Counter("\t".join(r) for r in rows if r[2] == "F")
    if "--update" in sys.argv:
        BASELINE.write_text("".join(f"{k}\n" * n for k, n in sorted(fatal.items())))
        print(f"baseline recorded: {BASELINE} ({sum(fatal.values())} F findings)")
        return 0
    base = collections.Counter(l for l in BASELINE.read_text().splitlines() if l) if BASELINE.exists() else collections.Counter()
    new = fatal - base
    summary = " ".join(f"{c}={counts.get(c, 0)}" for c in "FEWSI")
    print(f"XINDEX {routines} routines with findings: {summary}; F baseline={sum(base.values())} new={sum(new.values())}")
    for k, n in sorted(new.items()):
        print(f"  NEW F x{n}: {k.replace(chr(9), ' | ')}")
    return 1 if new else 0


if __name__ == "__main__":
    sys.exit(main())
