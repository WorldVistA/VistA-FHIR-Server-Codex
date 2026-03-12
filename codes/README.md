# Synthea value set definitions (extracted)

This folder contains FHIR ValueSet resources extracted from the [Synthea](https://github.com/synthetichealth/synthea) module JSON files.

- **`<category>_<system>.json`** — One ValueSet per (category, code system) with all inline codes from modules.
- **`synthea_value_set_uris.json`** — Bundle of value_set URIs (ECL / fhir_vs) used in modules (expanded at runtime when a terminology service is configured).
- **`module_code_index.jsonl`** — Line-delimited index: module path, state name, state type, kind (code vs value_set), system, code, display.

Categories align with Synthea state types: encounter, procedure, condition, allergy, careplan, medication, observation, etc.

Source: `synthetichealth/synthea` branch master, `src/main/resources/modules/**/*.json`.
Extraction script: `scripts/extract_synthea_valuesets.py`.
