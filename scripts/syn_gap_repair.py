#!/usr/bin/env python3
"""
Analyze SYN ingested-patient gaps and selectively rerun loader categories.

Default mode is read-only analysis. Add --repair to rerun categories.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from dataclasses import dataclass
from typing import Dict, Iterable, List, Tuple


CATEGORY_TO_IMPORT = {
    # Use wsIntake* entrypoints directly (instead of import* wrappers) so we
    # can merge deltas into existing load logs without replacing prior "loaded" nodes.
    "labs": {"ws": "wsIntakeLabs^SYNFLAB", "load_key": "labs"},
    "vitals": {"ws": "wsIntakeVitals^SYNFVIT", "load_key": "vitals"},
    "encounters": {"ws": "wsIntakeEncounters^SYNFENC", "load_key": "encounters"},
    "immunizations": {"ws": "wsIntakeImmu^SYNFIMM", "load_key": "immunizations"},
    "conditions": {"ws": "wsIntakeConditions^SYNFPRB", "load_key": "conditions"},
    "allergy": {"ws": "wsIntakeAllergy^SYNFALG", "load_key": "allergy"},
    "appointment": {"ws": "wsIntakeAppointment^SYNFAPT", "load_key": "appointment"},
    "meds": {"ws": "wsIntakeMeds^SYNFMED2", "load_key": "meds"},
    "procedures": {"ws": "wsIntakeProcedures^SYNFPROC", "load_key": "procedures"},
    "careplan": {"ws": "wsIntakeCareplan^SYNFCP", "load_key": "careplan"},
}

KNOWN_CATEGORIES = list(CATEGORY_TO_IMPORT.keys())


@dataclass
class PatientAnalysis:
    dfn: int
    ien: int
    source_counts: Dict[str, int]
    loaded_counts: Dict[str, int]
    status_counts: Dict[str, Dict[str, int]]


def http_get(base_url: str, path: str) -> str:
    url = base_url.rstrip("/") + path
    try:
        with urllib.request.urlopen(url, timeout=60) as rsp:
            return rsp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"HTTP {exc.code} for {url}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Request failed for {url}: {exc}") from exc


def parse_dfn_list(raw_values: Iterable[str]) -> List[int]:
    values: List[int] = []
    for raw in raw_values:
        for part in raw.split(","):
            part = part.strip()
            if not part:
                continue
            values.append(int(part))
    if not values:
        raise ValueError("No DFNs provided")
    return values


def get_iens_for_dfn(base_url: str, dfn: int) -> List[int]:
    path = f"/global/%25wd(17.040801,3,%22DFN%22,{dfn})"
    text = http_get(base_url, path)
    pattern = re.compile(rf'\^%wd\(17\.040801,3,"DFN",{dfn},([0-9]+)\)=')
    iens = sorted({int(m.group(1)) for m in pattern.finditer(text)})
    return iens


def select_ien(iens: List[int], mode: str) -> int:
    if not iens:
        raise RuntimeError("No graph IEN found for patient")
    if mode == "first":
        return iens[0]
    return iens[-1]


def source_counts_from_showfhir(base_url: str, dfn: int) -> Dict[str, int]:
    """Bundle counts from stored source JSON via GET showfhir -> wsShow^SYNFHIR."""
    text = http_get(base_url, f"/showfhir?dfn={dfn}")
    payload = json.loads(text)
    counts = Counter()
    for entry in payload.get("entry", []):
        resource = entry.get("resource", {})
        rtype = resource.get("resourceType", "")
        if rtype == "Observation":
            cat = ""
            categories = resource.get("category") or []
            if categories:
                coding = categories[0].get("coding") or []
                if coding:
                    cat = coding[0].get("code", "")
            if cat == "laboratory":
                counts["labs"] += 1
            elif cat == "vital-signs":
                counts["vitals"] += 1
        elif rtype == "Encounter":
            counts["encounters"] += 1
        elif rtype == "Immunization":
            counts["immunizations"] += 1
        elif rtype == "Condition":
            counts["conditions"] += 1
        elif rtype == "Procedure":
            counts["procedures"] += 1
        elif rtype == "MedicationRequest":
            counts["meds"] += 1
        elif rtype == "CarePlan":
            counts["careplan"] += 1
        elif rtype == "AllergyIntolerance":
            counts["allergy"] += 1
        elif rtype == "Appointment":
            counts["appointment"] += 1
    return dict(counts)


def load_status_counts(base_url: str, ien: int) -> Tuple[Dict[str, int], Dict[str, Dict[str, int]]]:
    text = http_get(base_url, f"/global/%25wd(17.040801,3,{ien},%22load%22)")
    # Example:
    # ^%wd(17.040801,3,1520,"load","labs",42,"status","loadstatus")="loaded"
    patt = re.compile(
        rf'\^%wd\(17\.040801,3,{ien},"load","([^"]+)",([0-9]+),"status","loadstatus"\)="([^"]*)"'
    )
    by_status: Dict[str, Dict[str, int]] = defaultdict(lambda: defaultdict(int))
    loaded = Counter()
    for sec, _idx, status in patt.findall(text):
        sec_key = sec.lower()
        st_key = status.lower() if status else "empty"
        by_status[sec_key][st_key] += 1
        if st_key == "loaded":
            loaded[sec_key] += 1
    by_status_plain = {k: dict(v) for k, v in by_status.items()}
    return dict(loaded), by_status_plain


def analyze_patient(base_url: str, dfn: int, ien_select: str) -> PatientAnalysis:
    iens = get_iens_for_dfn(base_url, dfn)
    ien = select_ien(iens, ien_select)
    source_counts = source_counts_from_showfhir(base_url, dfn)
    loaded_counts, status_counts = load_status_counts(base_url, ien)
    return PatientAnalysis(
        dfn=dfn,
        ien=ien,
        source_counts=source_counts,
        loaded_counts=loaded_counts,
        status_counts=status_counts,
    )


def compute_gap(source_counts: Dict[str, int], loaded_counts: Dict[str, int], category: str) -> int:
    source = source_counts.get(category, 0)
    loaded = loaded_counts.get(category, 0)
    return max(source - loaded, 0)


def print_analysis(analysis: PatientAnalysis) -> None:
    print(f"\nDFN {analysis.dfn}  Graph IEN {analysis.ien}")
    print("category        source  loaded  gap  status_summary")
    print("--------------  ------  ------  ---  ------------------------------")
    for cat in KNOWN_CATEGORIES:
        source = analysis.source_counts.get(cat, 0)
        loaded = analysis.loaded_counts.get(cat, 0)
        gap = compute_gap(analysis.source_counts, analysis.loaded_counts, cat)
        status = analysis.status_counts.get(cat, {})
        status_text = ", ".join(f"{k}:{v}" for k, v in sorted(status.items())) if status else "-"
        print(f"{cat:14}  {source:6}  {loaded:6}  {gap:3}  {status_text}")


def parse_categories(args_categories: List[str], auto_categories: bool, analysis: PatientAnalysis) -> List[str]:
    if auto_categories:
        cats = [
            cat
            for cat in KNOWN_CATEGORIES
            if compute_gap(analysis.source_counts, analysis.loaded_counts, cat) > 0
        ]
        return cats
    cats = []
    for raw in args_categories:
        for cat in raw.split(","):
            key = cat.strip().lower()
            if not key:
                continue
            if key not in CATEGORY_TO_IMPORT:
                raise ValueError(f"Unsupported category '{key}'. Choose from: {', '.join(KNOWN_CATEGORIES)}")
            cats.append(key)
    # preserve order, remove duplicates
    seen = set()
    unique = []
    for cat in cats:
        if cat in seen:
            continue
        seen.add(cat)
        unique.append(cat)
    return unique


def build_m_script(ien: int, categories: List[str], debug: bool) -> str:
    lines = [
        "S DUZ=1 D ^XUP",
        "^",
        "D INITMAPS^SYNQLDM",
        'N ROOT S ROOT=$$setroot^%wd("fhir-intake")',
        "S ARGS(\"load\")=1",
        f"S ARGS(\"debug\")={'1' if debug else '0'}",
    ]
    for cat in categories:
        ws_entry = CATEGORY_TO_IMPORT[cat]["ws"]
        load_key = CATEGORY_TO_IMPORT[cat]["load_key"]
        lines.append("K RTN")
        lines.append(f"D {ws_entry}(.ARGS,,.RTN,{ien})")
        lines.append(f'I $D(RTN("{load_key}")) M @ROOT@({ien},"load","{load_key}")=RTN("{load_key}")')
        lines.append(f'W !,"### {cat} ###",!')
        lines.append('ZWRITE RTN("status")')
    lines.append("H")
    return "\n".join(lines) + "\n"


def run_repair(container: str, ien: int, categories: List[str], debug: bool) -> str:
    script = build_m_script(ien, categories, debug)
    cp = subprocess.run(
        ["docker", "exec", "-i", container, "bash", "-lc", "mumps -dir"],
        input=script,
        text=True,
        capture_output=True,
        timeout=300,
        check=False,
    )
    if cp.returncode != 0:
        raise RuntimeError(f"Repair command failed with rc={cp.returncode}\n{cp.stderr}")
    return cp.stdout


def parse_repair_stdout(stdout: str) -> Dict[str, Dict[str, str]]:
    # Sample line: RTN("labsStatus","loaded")=""
    pat = re.compile(r'RTN\("([^"]+)","([^"]+)"\)=(".*?"|[^ \n]+)')
    out: Dict[str, Dict[str, str]] = defaultdict(dict)
    for stat_key, field, value in pat.findall(stdout):
        out[stat_key][field] = value.strip('"')
    return dict(out)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Analyze SYN load gaps and selectively rerun loader categories."
    )
    parser.add_argument("--dfn", action="append", required=True, help="DFN or comma list (e.g. 1539,1595)")
    parser.add_argument("--base-url", default="http://localhost:9081", help="SYN web service base URL")
    parser.add_argument(
        "--ien-select",
        choices=["latest", "first"],
        default="latest",
        help="When multiple graph IENs exist for a DFN, pick which one",
    )
    parser.add_argument("--repair", action="store_true", help="Run selective loader rerun")
    parser.add_argument(
        "--category",
        action="append",
        default=[],
        help="Category to rerun (repeat or comma list): labs,vitals,encounters,immunizations,conditions,allergy,appointment,meds,procedures,careplan",
    )
    parser.add_argument(
        "--auto-gap",
        action="store_true",
        help="With --repair, rerun only categories where source_count > loaded_count",
    )
    parser.add_argument("--container", default="fhir", help="Docker container name for VistA runtime")
    parser.add_argument("--debug", action="store_true", help="Set ARGS(\"debug\")=1 during rerun")
    parser.add_argument("--show-raw", action="store_true", help="Print raw M output for rerun calls")
    args = parser.parse_args()

    dfns = parse_dfn_list(args.dfn)
    had_error = False

    for dfn in dfns:
        try:
            before = analyze_patient(args.base_url, dfn, args.ien_select)
            print_analysis(before)
        except Exception as exc:  # pylint: disable=broad-except
            print(f"\nDFN {dfn}: analysis failed: {exc}", file=sys.stderr)
            had_error = True
            continue

        if not args.repair:
            continue

        try:
            categories = parse_categories(args.category, args.auto_gap, before)
            if not categories:
                print(f"DFN {dfn}: no categories selected for repair")
                continue
            print(f"\nDFN {dfn}: rerunning categories -> {', '.join(categories)}")
            raw = run_repair(args.container, before.ien, categories, args.debug)
            parsed = parse_repair_stdout(raw)
            if args.show_raw:
                print("\n--- raw rerun output ---")
                print(raw)
            if parsed:
                print("rerun_status:")
                for key in sorted(parsed):
                    fields = ", ".join(f"{k}={v}" for k, v in sorted(parsed[key].items()))
                    print(f"  {key}: {fields}")
            else:
                print("rerun_status: (no direct status nodes returned; use post_rerun counts)")

            after = analyze_patient(args.base_url, dfn, args.ien_select)
            print("\npost_rerun:")
            print_analysis(after)
        except Exception as exc:  # pylint: disable=broad-except
            print(f"DFN {dfn}: repair failed: {exc}", file=sys.stderr)
            had_error = True

    return 1 if had_error else 0


if __name__ == "__main__":
    sys.exit(main())
