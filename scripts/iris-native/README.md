# Native IRIS Health on Rocky Linux

The `scripts/iris-*.sh` files install the community edition in Docker on
Ubuntu. This directory is the same bring-up for a licensed IRIS Health kit
on Rocky, with no Docker.

Run from a checkout that has the sibling repos (`VistA-FHIR-Data-Loader`,
`VistA-DataLoader`, `rehmp`, `fhir-triple-store`):

```bash
scripts/iris-native/setup.sh root@newhost \
  --kit /path/to/IRISHealth-*-lnxrh9x64.tar.gz \
  --key /path/to/iris.key \
  --copy-from root@irisfhir.vistaplex.org
```

DNS for `newhost` must already point at the machine. Ports 22, 80, and 443
need to be reachable. Open 9430 as well if CPRS will connect from outside.

| Step | Script | Docker original |
|---|---|---|
| Kit, license, systemd | `install.sh` | `iris-host-setup.sh` (image pull) |
| Consistent `IRIS.DAT` copy | `foia-copy.sh` | staged by hand |
| FOIA namespace and mappings | `foia.sh` | `iris-host-setup.sh` |
| RPC broker, `USER.1` / `VISTA.99` | `cprs.sh` | `iris-cprs-setup.sh` |
| Routes, Codex/SYN/C0RG, listeners | `web.sh` | `iris-web-setup.sh` |
| Caddy and rehmp UI | `public.sh` | `iris-public-setup.sh` |
| C0X UI, routes, `/c0x/` redirect | `c0x.sh` | `fhir-triple-store/scripts/iris-c0x-deploy.sh` |
| HTTP and FileMan checks | `smoke.sh` | `iris-lane-smoke.sh` |

`cprs.sh` resets USER,ONE to the demo access and verify codes, the same way
`iris-cprs-setup.sh` does.

## Secrets

The key is copied to `/root/iris-install/iris.key` (mode 600) and
`/usr/irissys/mgr/iris.key` (mode 640, `irisusr`). The SuperUser password is
created on the host at `/root/iris-install/superuser.pass` (mode 600). The
scripts do not print either value. Do not commit the key, the password file,
or a copy of the install log.

Rocky is not RHEL. The installer is forced to platform `lnxrh9x64`, and
Apache setup is skipped (`ISC_PACKAGE_WEB_CONFIGURE=N`). Caddy is the
official binary, not a dnf package. The Cloudsmith Rocky repo has no Caddy
build.

## What this does not do

`setup.sh` does not edit `scripts/deploy-quality-all.sh`. The fleet lane
is `iris2` (https://iris2.vistaplex.org). `irisfhir` remains an alias.
