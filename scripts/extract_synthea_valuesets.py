#!/usr/bin/env python3
"""
Extract all code and value_set definitions from Synthea module JSON files
and write FHIR ValueSet resources into the codes/ folder.
"""
from __future__ import annotations

import json
import os
import re
from collections import defaultdict
from pathlib import Path

# State type -> FHIR/resource category for grouping
TYPE_TO_CATEGORY = {
    "Encounter": "encounter",
    "Procedure": "procedure",
    "ConditionOnset": "condition",
    "ConditionEnd": "condition",
    "AllergyOnset": "allergy",
    "CarePlanStart": "careplan",
    "CarePlanEnd": "careplan",
    "MedicationOrder": "medication",
    "MedicationEnd": "medication",
    "Observation": "observation",
    "Symptom": "symptom",
    "DiagnosticReport": "diagnosticreport",
    "Immunization": "immunization",
    "ImagingStudy": "imaging",
    "Device": "device",
    "Supply": "supply",
}

# Normalize code system to FHIR URL
SYSTEM_ALIASES = {
    "SNOMED-CT": "http://snomed.info/sct",
    "SNOMED": "http://snomed.info/sct",
    "RxNorm": "http://www.nlm.nih.gov/research/umls/rxnorm",
    "RxNorm:": "http://www.nlm.nih.gov/research/umls/rxnorm",
    "LOINC": "http://loinc.org",
    "CVX": "http://hl7.org/fhir/sid/cvx",
    "ICD-10": "http://hl7.org/fhir/sid/icd-10-cm",
    "ICD-10-CM": "http://hl7.org/fhir/sid/icd-10-cm",
    "ICD9": "http://hl7.org/fhir/sid/icd-9-cm",
    "CPT": "http://www.ama-assn.org/go/cpt",
    "HL7.ActCode": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
    "NUCC": "http://nucc.org/provider-taxonomy",
    "ActCode": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
}


def normalize_system(s: str) -> str:
    s = (s or "").strip()
    return SYSTEM_ALIASES.get(s, s) if s else ""


def walk_states(obj, path: str = ""):
    """Yield (state_name, state_dict) for every state in a module."""
    if not isinstance(obj, dict):
        return
    states = obj.get("states")
    if isinstance(states, dict):
        for name, state in states.items():
            if isinstance(state, dict):
                yield name, state
                # recurse into submodule-like structures if any
                for k, v in state.items():
                    if k == "activities" and isinstance(v, list):
                        for act in v:
                            if isinstance(act, dict):
                                yield f"{name}.activity", act
                    elif k == "reactions" and isinstance(v, list):
                        for r in v:
                            if isinstance(r, dict):
                                yield f"{name}.reaction", r


def extract_codes(state: dict) -> list[dict]:
    """Get list of {system, code, display} from a state's codes or value_set."""
    out = []
    # Inline codes
    codes = state.get("codes") or state.get("code")
    if isinstance(codes, list):
        for c in codes:
            if isinstance(c, dict):
                sys = c.get("system") or c.get("codeSystem") or ""
                code = c.get("code")
                display = c.get("display") or c.get("name") or ""
                if code is not None:
                    out.append({"system": sys, "code": str(code).strip(), "display": (display or "").strip()})
    elif isinstance(codes, dict):
        sys = codes.get("system") or codes.get("codeSystem") or ""
        code = codes.get("code")
        display = codes.get("display") or codes.get("name") or ""
        if code is not None:
            out.append({"system": sys, "code": str(code).strip(), "display": (display or "").strip()})
    # Single activity/reaction object with system/code/display
    if "system" in state and "code" in state:
        out.append({
            "system": state.get("system", ""),
            "code": str(state.get("code", "")).strip(),
            "display": (state.get("display") or state.get("name") or "").strip(),
        })
    return out


def extract_value_set_uri(state: dict) -> str | None:
    v = state.get("value_set")
    if isinstance(v, str) and v.strip():
        return v.strip()
    return None


def main() -> int:
    base = Path(__file__).resolve().parent.parent
    repo = base / "_synthea_clone"
    modules_dir = repo / "src" / "main" / "resources" / "modules"
    out_dir = base / "codes"
    out_dir.mkdir(parents=True, exist_ok=True)

    if not modules_dir.is_dir():
        print(f"Modules dir not found: {modules_dir}")
        return 1

    # Collect: by (category, system) -> set of (code, display)
    by_category_system: dict[tuple[str, str], set[tuple[str, str]]] = defaultdict(set)
    # value_set URIs by category
    value_set_uris: dict[str, set[str]] = defaultdict(set)
    # module -> list of (state, type, codes/uri) for an index
    module_index = []

    for jpath in sorted(modules_dir.rglob("*.json")):
        try:
            with open(jpath, encoding="utf-8") as f:
                mod = json.load(f)
        except Exception as e:
            print(f"Skip {jpath}: {e}")
            continue
        rel = jpath.relative_to(modules_dir)
        for state_name, state in walk_states(mod):
            stype = state.get("type") or "Unknown"
            category = TYPE_TO_CATEGORY.get(stype, "other")
            # Inline codes
            for c in extract_codes(state):
                sys = normalize_system(c["system"]) or c["system"]
                if not sys:
                    sys = "http://unknown"
                code = c["code"]
                display = c["display"] or code
                by_category_system[(category, sys)].add((code, display))
                module_index.append((str(rel), state_name, stype, "code", sys, code, display))
            # value_set URI
            uri = extract_value_set_uri(state)
            if uri:
                value_set_uris[category].add(uri)
                module_index.append((str(rel), state_name, stype, "value_set", uri, "", ""))

    # Write one FHIR ValueSet JSON per (category, system)
    for (category, system), code_displays in sorted(by_category_system.items()):
        safe = re.sub(r"[^\w\-]", "_", f"{category}_{system.split('/')[-1]}")
        safe = safe[:80]
        concepts = [{"code": c, "display": d} for c, d in sorted(code_displays)]
        vs = {
            "resourceType": "ValueSet",
            "id": safe,
            "url": f"http://example.org/synthea/ValueSet/{safe}",
            "title": f"Synthea {category} codes ({system.split('/')[-1]})",
            "description": f"Codes extracted from Synthea modules for category '{category}', system {system}.",
            "status": "active",
            "compose": {
                "include": [
                    {
                        "system": system,
                        "concept": concepts,
                    }
                ]
            },
        }
        out_file = out_dir / f"{safe}.json"
        with open(out_file, "w", encoding="utf-8") as f:
            json.dump(vs, f, indent=2)
        print(f"Wrote {out_file.name} ({len(concepts)} concepts)")

    # Write value_set URIs as a single index
    if value_set_uris:
        vs_index = {
            "resourceType": "Bundle",
            "type": "collection",
            "title": "Synthea value_set URIs (ECL/fhir_vs) by category",
            "description": "URIs used in Synthea modules when a terminology service expands a value set at runtime.",
            "entry": [],
        }
        for cat in sorted(value_set_uris):
            for uri in sorted(value_set_uris[cat]):
                vs_index["entry"].append({
                    "resource": {
                        "resourceType": "ValueSet",
                        "id": f"uri-{cat}-{hash(uri) % 2**32}",
                        "url": uri,
                        "title": f"Synthea {cat} (value_set URI)",
                        "status": "active",
                        "description": f"Value set URI from Synthea modules (category: {cat}). Expand via terminology service.",
                    }
                })
        with open(out_dir / "synthea_value_set_uris.json", "w", encoding="utf-8") as f:
            json.dump(vs_index, f, indent=2)
        print("Wrote synthea_value_set_uris.json")

    # Write index of module -> codes (optional, for reference)
    index_path = out_dir / "module_code_index.jsonl"
    with open(index_path, "w", encoding="utf-8") as f:
        for t in module_index:
            f.write(json.dumps({"module": t[0], "state": t[1], "state_type": t[2], "kind": t[3], "system": t[4], "code": t[5], "display": t[6]}) + "\n")
    print(f"Wrote {index_path.name} ({len(module_index)} entries)")

    # README for codes/
    readme = """# Synthea value set definitions (extracted)

This folder contains FHIR ValueSet resources extracted from the [Synthea](https://github.com/synthetichealth/synthea) module JSON files.

- **`<category>_<system>.json`** — One ValueSet per (category, code system) with all inline codes from modules.
- **`synthea_value_set_uris.json`** — Bundle of value_set URIs (ECL / fhir_vs) used in modules (expanded at runtime when a terminology service is configured).
- **`module_code_index.jsonl`** — Line-delimited index: module path, state name, state type, kind (code vs value_set), system, code, display.

Categories align with Synthea state types: encounter, procedure, condition, allergy, careplan, medication, observation, etc.

Source: `synthetichealth/synthea` branch master, `src/main/resources/modules/**/*.json`.
Extraction script: `scripts/extract_synthea_valuesets.py`.
"""
    (out_dir / "README.md").write_text(readme, encoding="utf-8")
    print("Wrote README.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
