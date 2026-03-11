#!/usr/bin/env python3
"""
Smoke checks for no-DFN /fhir index and related views.

Checks:
- /fhir returns HTML
- rendered VPR links include format=xml
- each listed patient has labs loaded > 0 in summary row
- /fhir?dfn=<sample> returns JSON Bundle
- /fhir?dfn=<sample>&view=browser returns HTML
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Dict, List, Tuple


class CheckError(RuntimeError):
    """Raised when a smoke check fails."""


@dataclass
class Row:
    dfn: int
    ien: int
    vpr_link: str
    summary: str


def fetch(url: str, timeout: int) -> Tuple[int, Dict[str, str], str]:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as rsp:
            body = rsp.read().decode("utf-8", "replace")
            headers = {k.lower(): v for k, v in rsp.headers.items()}
            return rsp.status, headers, body
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        raise CheckError(f"HTTP {exc.code} for {url}\n{body[:400]}") from exc
    except urllib.error.URLError as exc:
        raise CheckError(f"Request failed for {url}: {exc}") from exc


def ensure(ok: bool, message: str) -> None:
    if not ok:
        raise CheckError(message)


def parse_index_rows(index_html: str) -> List[Row]:
    row_pattern = re.compile(
        r'<tr><td><a href="/fhir\?dfn=(?P<dfn>\d+)&view=browser">[^<]*</a></td>'
        r'<td><a href="/fhir\?dfn=\d+">fhir</a></td>'
        r"<td>\d+</td><td>(?P<ien>\d+)</td>"
        r'<td><a href="/showfhir\?ien=\d+">json</a></td>'
        r'<td><a href="[^"]+">load</a></td>'
        r'<td><a href="(?P<vpr>/vpr\?dfn=\d+[^"]*)">vpr</a></td></tr>',
        re.IGNORECASE,
    )
    summary_pattern = re.compile(
        r'<tr><td colspan="7"><small>(?P<summary>.*?)</small></td></tr>',
        re.IGNORECASE,
    )

    rows = list(row_pattern.finditer(index_html))
    summaries = [m.group("summary") for m in summary_pattern.finditer(index_html)]

    ensure(rows, "No patient rows found in /fhir index output.")
    ensure(
        len(summaries) >= len(rows),
        f"Expected at least {len(rows)} summary rows, found {len(summaries)}.",
    )

    parsed: List[Row] = []
    for i, match in enumerate(rows):
        parsed.append(
            Row(
                dfn=int(match.group("dfn")),
                ien=int(match.group("ien")),
                vpr_link=match.group("vpr"),
                summary=summaries[i],
            )
        )
    return parsed


def vpr_link_is_xml(link: str) -> bool:
    parsed = urllib.parse.urlparse(link)
    query = urllib.parse.parse_qs(parsed.query)
    return query.get("format", [""])[0].lower() == "xml"


def labs_loaded_from_summary(summary: str) -> int:
    match = re.search(r"(?i)\blabs:(\d+)/(\d+)\b", summary)
    if not match:
        raise CheckError(f"Summary missing labs count: {summary}")
    loaded = int(match.group(1))
    source = int(match.group(2))
    ensure(source >= loaded, f"Invalid labs ratio in summary: {summary}")
    return loaded


def check_index(base_url: str, timeout: int) -> List[Row]:
    url = f"{base_url}/fhir"
    status, headers, body = fetch(url, timeout)
    ensure(status == 200, f"/fhir expected HTTP 200, got {status}")
    content_type = headers.get("content-type", "")
    ensure(
        content_type.lower().startswith("text/html"),
        f"/fhir expected text/html, got {content_type}",
    )

    rows = parse_index_rows(body)
    for row in rows:
        ensure(
            vpr_link_is_xml(row.vpr_link),
            f"VPR link missing format=xml: {row.vpr_link}",
        )
        ensure(
            labs_loaded_from_summary(row.summary) > 0,
            f"Row DFN {row.dfn} has labs loaded <= 0: {row.summary}",
        )
    print(f"PASS /fhir index HTML and row checks ({len(rows)} rows)")
    return rows


def check_json_bundle(base_url: str, timeout: int, dfn: int) -> None:
    url = f"{base_url}/fhir?dfn={dfn}"
    status, headers, body = fetch(url, timeout)
    ensure(status == 200, f"/fhir?dfn={dfn} expected HTTP 200, got {status}")
    content_type = headers.get("content-type", "")
    ensure(
        "application/json" in content_type.lower(),
        f"/fhir?dfn={dfn} expected application/json, got {content_type}",
    )
    try:
        payload = json.loads(body)
    except json.JSONDecodeError as exc:
        raise CheckError(f"/fhir?dfn={dfn} is not valid JSON: {exc}") from exc
    ensure(
        payload.get("resourceType") == "Bundle",
        f"/fhir?dfn={dfn} resourceType is not Bundle",
    )
    ensure(isinstance(payload.get("entry"), list), f"/fhir?dfn={dfn} missing entry list")
    print(f"PASS /fhir?dfn={dfn} JSON Bundle")


def check_browser(base_url: str, timeout: int, dfn: int) -> None:
    url = f"{base_url}/fhir?dfn={dfn}&view=browser"
    status, headers, body = fetch(url, timeout)
    ensure(
        status == 200,
        f"/fhir?dfn={dfn}&view=browser expected HTTP 200, got {status}",
    )
    content_type = headers.get("content-type", "")
    ensure(
        content_type.lower().startswith("text/html"),
        f"/fhir?dfn={dfn}&view=browser expected text/html, got {content_type}",
    )
    ensure("C0FHIR Browser" in body, "Browser page marker missing.")
    ensure(
        f"/vpr?dfn={dfn}&format=xml" in body,
        f"Browser page missing XML VPR link for DFN {dfn}.",
    )
    print(f"PASS /fhir?dfn={dfn}&view=browser HTML")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="FHIR no-DFN regression smoke checks")
    parser.add_argument(
        "--base-url",
        default="http://localhost:9081",
        help="Base URL for the FHIR server (default: %(default)s)",
    )
    parser.add_argument(
        "--dfn",
        type=int,
        default=0,
        help="Specific DFN for patient-level checks (default: first row in /fhir index)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=60,
        help="HTTP timeout in seconds (default: %(default)s)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    base_url = args.base_url.rstrip("/")
    try:
        rows = check_index(base_url, args.timeout)
        dfn = args.dfn if args.dfn > 0 else rows[0].dfn
        check_json_bundle(base_url, args.timeout, dfn)
        check_browser(base_url, args.timeout, dfn)
    except CheckError as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        return 1
    print("PASS all smoke checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
