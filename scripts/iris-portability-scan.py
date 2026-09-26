#!/usr/bin/env python3
"""IRIS portability scanner (sprint Day 4).

Scans M routine sources for GT.M/YottaDB-specific constructs and emits a
per-construct, per-file inventory (markdown + TSV) as raw material for the
costed portability report. Purely lexical: comment text after ';' is
ignored, string literals are kept (device parameter strings matter).

Usage: scripts/iris-portability-scan.py [dir ...] > report.md
Default dirs: src/ plus ../rehmp/C0RG relative to the repo root.
"""
from __future__ import annotations

import pathlib
import re
import sys
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parents[1]

# (key, regex, classification, IRIS note)
PATTERNS: list[tuple[str, str, str, str]] = [
    ("$ZCMDLINE", r"\$ZCMD(?:LINE)?\b", "rewrite",
     "no IRIS equivalent; entry args must come from JOB params or a driver"),
    ("ZSYSTEM", r"(?<![\w$])ZSY(?:STEM)?\b", "shim",
     "IRIS: $ZF(-100,...); wrap in a $$OS^shim"),
    ("PIPE device", r"\"PIPE\"|COMMAND=", "shim",
     "IRIS command pipes use |CPIPE|/OPEN cmd syntax; wrap OPEN/USE/CLOSE"),
    ("$ZTRAP", r"\$ZT(?:RAP)?\s*=", "portable*",
     "supported on IRIS but unwind semantics differ from GT.M ($ETRAP-style); verify handlers"),
    ("$ETRAP", r"\$ET(?:RAP)?\s*=", "portable", "same on IRIS"),
    ("$ZTRNLNM", r"\$ZTRNLNM\b", "shim",
     "env lookup; IRIS: $SYSTEM.Util.GetEnviron()"),
    ("$ZSEARCH", r"\$ZSEARCH\b", "shim",
     "file glob; IRIS: %File:FileSetFunc or $ZSEARCH exists on IRIS (different reset rules)"),
    ("$ZF non-call", r"\$ZF\(", "shim", "GT.M external call table vs IRIS $ZF(-100)"),
    ("$ZB/$ZA device", r"(?<![\w$])\$Z[AB]\b", "portable*",
     "read-terminator checks; IRIS supports $ZB with device differences"),
    ("$ZCHSET/$ZCONVERT", r"\$ZCHSET\b|\$ZCONVERT\b|\$ZCO\(", "shim",
     "UTF-8 handling differs; IRIS $ZCONVERT signature differs"),
    ("$ZDATE", r"\$ZDATE\(", "portable*", "IRIS $ZDATE exists, format codes differ"),
    ("$ZUT/$ZH highres", r"\$ZUT\b", "shim", "IRIS: $ZTIMESTAMP-derived microseconds"),
    ("ZHALT", r"(?<![\w$])ZHALT\b", "shim", "IRIS HALT has no exit status; use $SYSTEM.Process.Terminate"),
    ("ZGOTO", r"(?<![\w$])ZGOTO\b", "rewrite", "no IRIS equivalent; restructure control flow"),
    ("ZLINK/ZRUPDATE", r"(?<![\w$])(ZLINK|ZRUPDATE)\b", "shim",
     "dev-time routine reload; IRIS auto-compiles from .int/.mac — belongs in tooling, not product code"),
    ("JOB command", r"(?<![\w$])JOB\s+[%A-Z^$]", "portable*",
     "JOB portable; GT.M-specific jobparams (STARTUP, PASSCURLVN...) are not"),
    ("OPEN w/ params", r"(?<![\w$])O(?:PEN)?\s+[^:;]+:\(", "portable*",
     "device parameter lists differ (newversion/ochset vs IRIS keywords); audit each"),
    ("extended global ref", r"\^\|", "shim", "IRIS uses ^|\"ns\"| syntax too but ns naming differs"),
    ("$VIEW/VIEW", r"\$VIEW\(|^\s+VIEW\s", "rewrite", "implementation-specific"),
    ("%ZTLOAD (TaskMan)", r"%ZTLOAD\b", "portable",
     "VistA Kernel API — portable wherever Kernel runs (IRIS ships Kernel in VistA distros)"),
    ("$ORDER 2-arg reverse etc.", r"\$O(?:RDER)?\([^)]*,-1\)", "portable", "standard"),
    ("$ZPIECE/$ZLENGTH", r"\$ZPIECE\b|\$ZLENGTH\b|\$ZEXTRACT\b", "shim",
     "byte-oriented variants; IRIS is char-oriented — usually replace with standard forms"),
    ("$ZINTERRUPT", r"\$ZINTERRUPT\b", "rewrite", "signal handling differs entirely"),
]


def code_part(line: str) -> str:
    """Strip comment tail (naive: first ';' not inside quotes)."""
    out, inq = [], False
    for ch in line:
        if ch == '"':
            inq = not inq
        if ch == ";" and not inq:
            break
        out.append(ch)
    return "".join(out)


def main() -> int:
    dirs = [pathlib.Path(a) for a in sys.argv[1:]] or [
        ROOT / "src", ROOT.parent / "rehmp" / "C0RG"]
    hits: dict[str, list[tuple[str, int, str]]] = defaultdict(list)
    files = []
    for d in dirs:
        files += sorted(d.glob("*.m"))
    for f in files:
        for n, raw in enumerate(f.read_text(errors="replace").splitlines(), 1):
            code = code_part(raw)
            if not code.strip():
                continue
            for key, rx, _cls, _note in PATTERNS:
                if re.search(rx, code, re.IGNORECASE):
                    hits[key].append((f.name, n, raw.strip()[:110]))

    print(f"# IRIS portability scan\n\nScanned {len(files)} routines in: "
          + ", ".join(str(d) for d in dirs) + "\n")
    print("| Construct | Class | Hits | Files | IRIS note |")
    print("|---|---|---:|---|---|")
    for key, rx, cls, note in PATTERNS:
        rows = hits.get(key, [])
        fset = sorted({r[0] for r in rows})
        fdisp = ", ".join(fset[:6]) + (f" +{len(fset)-6}" if len(fset) > 6 else "")
        print(f"| {key} | {cls} | {len(rows)} | {fdisp or '—'} | {note} |")
    print()
    for key, rx, cls, note in PATTERNS:
        rows = hits.get(key, [])
        if not rows:
            continue
        print(f"\n## {key} ({cls}) — {len(rows)} hits\n")
        for fn, ln, txt in rows[:40]:
            print(f"- `{fn}:{ln}` `{txt}`")
        if len(rows) > 40:
            print(f"- … {len(rows)-40} more")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
