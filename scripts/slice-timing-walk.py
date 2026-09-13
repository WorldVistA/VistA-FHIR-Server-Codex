#!/usr/bin/env python3
"""Time the C0RG continuation walk (patient.fhir.bundle + bundle.continue).

Per slice: wall-clock latency, compressed bytes on the wire, decompressed
bytes, Content-Encoding, entry count. Summary per lane.
Usage: slice_timing.py <base-url> <dfn> [label]
"""
import json, sys, time, uuid, urllib.request, gzip, io

base, dfn = sys.argv[1], sys.argv[2]
label = sys.argv[3] if len(sys.argv) > 3 else base


def post(op, payload):
    body = json.dumps({
        "apiVersion": "1.0",
        "requestId": f"timing-{uuid.uuid4()}",
        "operation": op,
        "payload": payload,
    }).encode()
    req = urllib.request.Request(base + "/rehmp", data=body,
                                 headers={"Content-Type": "application/json",
                                          "Accept-Encoding": "gzip"})
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=120) as r:
        raw = r.read()
        dt = time.monotonic() - t0
        enc = r.headers.get("Content-Encoding", "identity")
    wire = len(raw)
    if enc == "gzip":
        raw = gzip.GzipFile(fileobj=io.BytesIO(raw)).read()
    return json.loads(raw), dt, wire, len(raw), enc


slices = []
resp, dt, wire, plain, enc = post("patient.fhir.bundle",
                                  {"dfn": str(dfn), "fhirQuery": {"domain": "", "max": "100"}})
tok = (resp.get("meta") or {}).get("continuationToken", "")
n = len((resp.get("data") or {}).get("entry", []))
slices.append((dt, wire, plain, enc, n))
while tok:
    resp, dt, wire, plain, enc = post("bundle.continue", {"continuationToken": tok})
    tok = (resp.get("meta") or {}).get("continuationToken", "")
    n = len((resp.get("data") or {}).get("entry", []))
    slices.append((dt, wire, plain, enc, n))
    if len(slices) > 400:
        break

tt = sum(s[0] for s in slices)
tw = sum(s[1] for s in slices)
tp = sum(s[2] for s in slices)
te = sum(s[4] for s in slices)
encs = {s[3] for s in slices}
lat = sorted(s[0] for s in slices)
print(f"{label}: dfn={dfn} slices={len(slices)} entries={te} "
      f"total={tt:.2f}s mean={tt/len(slices)*1000:.0f}ms "
      f"p50={lat[len(lat)//2]*1000:.0f}ms max={lat[-1]*1000:.0f}ms")
print(f"  wire={tw/1024:.0f}KiB plain={tp/1024:.0f}KiB "
      f"ratio={tw/max(tp,1):.2f} encoding={','.join(encs)} "
      f"throughput={tp/1024/max(tt,0.001):.0f}KiB/s(plain)")
