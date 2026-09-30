#!/usr/bin/env python3
"""ci-vehu-l9-table.py — L9 gate + table for cds1 official-CQL measure results.

Args: one "measure|cohortN|IPP|DENOM|NUMER|DENEX|note" string per measure
(IPP..DENEX from ^C0FQUAL("SUM",m) after reeval; cohortN = C0X SPARQL IPP DFNs
promoted with /c0x/cohort/use).

Prints a one-line summary, then a Markdown table. Gate (exit 1):
  * a measure with a non-empty cohort has no SUM, or reeval did not finish "done"
  * nesting violated: NUMER <= DENOM <= IPP <= cohortN, DENEX <= DENOM
  * scripts/vehu-l9-golden.json exists and a count differs from it
The golden file is written by hand only after George reviews where the cohort
lands per measure (VEHU_ROUNDTRIP_PLAN.md, Decisions).
"""
import json
import pathlib
import sys

GOLDEN = pathlib.Path(__file__).with_name("vehu-l9-golden.json")


def num(x):
    try:
        return int(x)
    except (TypeError, ValueError):
        return None


def main(rows):
    golden = json.loads(GOLDEN.read_text()) if GOLDEN.exists() else None
    fails, table = [], ["| Measure | C0X IPP DFNs | IPP | DENOM | NUMER | DENEX | Reeval |", "|---|---:|---:|---:|---:|---:|---|"]
    for r in rows:
        m, n, ipp, den, numer, denex, note = (r.split("|") + [""] * 7)[:7]
        n, ipp, den, numer, denex = num(n), num(ipp), num(den), num(numer), num(denex)
        table.append(f"| {m} | {n} | {ipp if ipp is not None else '-'} | {den if den is not None else '-'} | "
                     f"{numer if numer is not None else '-'} | {denex if denex is not None else '-'} | {note} |")
        if not n:
            continue  # empty C0X cohort: nothing to evaluate (reported, not failed)
        if None in (ipp, den, numer, denex):
            fails.append(f"{m}: no SUM after reeval ({note})")
            continue
        if "status=done" not in note.lower():
            fails.append(f"{m}: reeval did not finish ({note})")
        if not (numer <= den <= ipp <= n and denex <= den):
            fails.append(f"{m}: nesting violated {ipp}/{den}/{numer}/{denex} (cohort {n})")
        if golden and m in golden and golden[m] != [ipp, den, numer, denex]:
            fails.append(f"{m}: {[ipp, den, numer, denex]} != golden {golden[m]}")
    evaluated = sum(1 for r in rows if num(r.split("|")[1]))
    head = (f"{evaluated}/{len(rows)} measures evaluated by cds1; "
            + ("golden table compared" if golden else "golden table not frozen yet (awaiting cohort review)"))
    print(("; ".join(fails) if fails else head))
    print("\n".join(table))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
