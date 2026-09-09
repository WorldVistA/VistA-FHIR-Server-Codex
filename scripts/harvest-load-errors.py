#!/usr/bin/env python3
"""Harvest C0FW/SYN load summaries and optional gtree load-log messages.

Examples:
  scripts/harvest-load-errors.py --url https://fhir.vistaplex.org/fhir
  scripts/harvest-load-errors.py --url https://fhir.vistaplex.org/fhir --logs 3 --out /tmp/h.json
  scripts/harvest-load-errors.py --html /tmp/fhirprod-index.html --baseline /tmp/h.json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
from collections import Counter, defaultdict
from html import unescape
from pathlib import Path
from urllib.parse import urljoin, urlparse

C0FW = {
    "Patient", "Encounter", "Condition", "Lab", "Observation", "Procedure",
    "Medication", "Immunization", "DocumentReference", "CarePlan", "Allergy",
    "ServiceRequest", "Smoking", "AIConsult",
}


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "vista-load-harvest/1"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read().decode("utf-8", "replace")


def parse_index(html: str) -> list[dict]:
    parts = re.split(r"<tr>", html)
    patients: list[dict] = []
    for part in parts:
        m = re.search(
            r'href="(/fhir\?dfn=(\d+)&view=browser)">([^<]+)</a>.*?>'
            r"(\d+)</td><td>([^<]+)</td>",
            part,
            re.S,
        )
        gtree = re.search(r'href="(/gtree/[^"]+)"', part)
        if m:
            patients.append(
                {
                    "dfn": int(m.group(2)),
                    "name": unescape(m.group(3)),
                    "ien": m.group(5),
                    "browser": m.group(1),
                    "gtree": unescape(gtree.group(1)) if gtree else "",
                    "sum": "",
                    "domains": {},
                }
            )
            continue
        m = re.search(r"<small>([^<]+)</small>", part)
        if m and patients and not patients[-1]["sum"]:
            patients[-1]["sum"] = unescape(m.group(1))
            patients[-1]["domains"] = parse_sum(patients[-1]["sum"])
    return patients


def parse_sum(text: str) -> dict[str, tuple[int, int]]:
    out: dict[str, tuple[int, int]] = {}
    for part in text.split("|"):
        m = re.match(r"\s*([^:]+):(\d+)/(\d+)", part)
        if m:
            out[m.group(1).strip()] = (int(m.group(2)), int(m.group(3)))
    return out


def classify(domains: dict) -> str:
    keys = set(domains)
    c0 = bool(keys & C0FW)
    syn = bool(keys - C0FW)
    if c0 and syn:
        return "mixed"
    if c0:
        return "c0fw"
    if syn:
        return "syn"
    return "other"


def totals(patients: list[dict], bucket: str | None = None) -> dict[str, list[int]]:
    acc: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for p in patients:
        if bucket and classify(p["domains"]) != bucket:
            continue
        for name, (loaded, source) in p["domains"].items():
            acc[name][0] += loaded
            acc[name][1] += source
    return acc


def parse_gtree(html: str) -> list[dict]:
    m = re.search(r"<pre>(.*)</pre>", html, re.S)
    text = m.group(1) if m else html
    domain = None
    cur: dict | None = None
    recs: list[dict] = []
    for line in text.splitlines():
        m = re.match(r"\|--([A-Za-z][A-Za-z0-9]*)\s*$", line)
        if m:
            domain = m.group(1)
            continue
        m = re.match(r"\|  \|--(\d+)\s*$", line)
        if m:
            if cur:
                recs.append(cur)
            cur = {"domain": domain, "rien": m.group(1)}
            continue
        m = re.match(r"\|  \|  \|--(\S+)\s*(.*)$", line)
        if m and cur is not None:
            cur[m.group(1)] = m.group(2).strip()
    if cur:
        recs.append(cur)
    return recs


def norm_msg(msg: str) -> str:
    msg = re.sub(r"\b\d{4,}\b", "N", msg)
    msg = re.sub(r"SCT=\S+", "SCT=X", msg)
    msg = re.sub(r"LOINC \S+", "LOINC X", msg)
    return msg[:180]


def harvest_logs(base: str, patients: list[dict], n: int) -> dict:
    msgs: Counter[tuple[str, str, str]] = Counter()
    status: dict[str, Counter[str]] = defaultdict(Counter)
    taken = 0
    for p in patients:
        if not p.get("gtree"):
            continue
        if taken >= n:
            break
        url = urljoin(base if base.endswith("/") else base + "/", p["gtree"].lstrip("/"))
        recs = parse_gtree(fetch(url))
        taken += 1
        for r in recs:
            st = r.get("loadStatus") or "?"
            status[r.get("domain", "?")][st] += 1
            if st in {"error", "not_implemented", "skipped"}:
                msgs[(r.get("domain", "?"), st, norm_msg(r.get("message", "(none)")))] += 1
    return {
        "patients_sampled": taken,
        "status": {d: dict(c) for d, c in status.items()},
        "messages": [
            {"n": n, "domain": d, "status": s, "message": m}
            for (d, s, m), n in msgs.most_common(40)
        ],
    }


def print_totals(title: str, acc: dict[str, list[int]]) -> None:
    print(f"\n=== {title} ===")
    print(f"  {'domain':22} {'loaded':>8} {'source':>8} {'pct':>7}")
    for name in sorted(acc):
        loaded, source = acc[name]
        pct = (100.0 * loaded / source) if source else 0.0
        print(f"  {name:22} {loaded:8} {source:8} {pct:6.1f}%")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--url", help="Dashboard URL, e.g. https://fhir.vistaplex.org/fhir")
    ap.add_argument("--html", help="Saved dashboard HTML")
    ap.add_argument("--logs", type=int, default=0, help="Fetch this many newest load logs")
    ap.add_argument("--out", help="Write JSON harvest")
    ap.add_argument("--baseline", help="Previous harvest JSON to diff message classes")
    args = ap.parse_args()
    if not args.url and not args.html:
        ap.error("need --url or --html")

    if args.html:
        html = Path(args.html).read_text(encoding="utf-8", errors="replace")
        base = args.url or ""
    else:
        html = fetch(args.url)
        base = args.url.rsplit("/fhir", 1)[0] + "/"

    patients = parse_index(html)
    host = urlparse(args.url).netloc if args.url else Path(args.html).name
    report = {
        "host": host,
        "n": len(patients),
        "buckets": {},
        "c0fw": {},
        "logs": {},
    }
    print(f"{host}: {len(patients)} patients")
    for bucket in ("c0fw", "syn", "mixed"):
        acc = totals(patients, bucket)
        n = sum(1 for p in patients if classify(p["domains"]) == bucket)
        report["buckets"][bucket] = {
            "n": n,
            "domains": {k: {"loaded": v[0], "source": v[1]} for k, v in acc.items()},
        }
        if acc:
            print_totals(f"{bucket} n={n}", acc)
    report["c0fw"] = report["buckets"].get("c0fw", {})

    if args.logs and args.url:
        newest = sorted(patients, key=lambda p: p["dfn"], reverse=True)
        report["logs"] = harvest_logs(base, newest, args.logs)
        print(f"\n=== load-log sample {report['logs']['patients_sampled']} ===")
        for row in report["logs"]["messages"][:20]:
            print(f"  {row['n']:5} [{row['domain']}/{row['status']}] {row['message']}")

    if args.baseline:
        prev = json.loads(Path(args.baseline).read_text())
        old = {(m["domain"], m["status"], m["message"]) for m in prev.get("logs", {}).get("messages", [])}
        new = {(m["domain"], m["status"], m["message"]) for m in report.get("logs", {}).get("messages", [])}
        added = sorted(new - old)
        print(f"\n=== new error classes vs baseline: {len(added)} ===")
        for item in added:
            print("  +", "/".join(item))
        report["new_classes"] = [list(x) for x in added]

    if args.out:
        Path(args.out).write_text(json.dumps(report, indent=2) + "\n")
        print(f"\nwrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
