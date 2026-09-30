# Vendored M-Web-Server (classic `%web*` API)

Runtime routines of the M-Web-Server (CHANGELOG top entry `0.1.4`), Apache 2.0
(see `LICENSE`, `NOTICE`). Copied 2026-09-30 from `vehu10:/home/vehu/lib/M-Web-Server/src`;
byte-identical to the `_web*.m` routines vehu10 runs from `/home/vehu/p`.

Why vendored: stock `worldvista/vehu:latest` ships only the YottaDB Web Server
v5 plugin (`_ydbmwebserver.so`), which renamed the API to `%ydbweb*`. Codex,
C0RG and SYN code call the classic `%webreq` / `%webjson` / `%webapi` /
`addService^%webutils` (`^%web(17.6001)`) names, so installs copy these into the
routine directory instead of depending on a long-lived container.

Test/demo routines (`_webtest`, `_webjson*Test*`) and the Caché installer are not
vendored. Drift is guarded by `scripts/check-artifacts.sh` (sha256 manifest).
