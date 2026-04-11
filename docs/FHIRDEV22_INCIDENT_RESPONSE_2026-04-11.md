# fhirdev22 incident response (2026-04-11)

## Purpose

This note records the live incident review and containment work performed on
`fhirdev.vistaplex.org` / Docker container `fhirdev22` on **2026-04-11** after
reports that the server networking and SSH access were behaving erratically
while the demo on `9080` still worked.

It complements:

- `docs/FHIRDEV_INCIDENT_RESPONSE_2026-03-16.md`
- `docs/FHIRDEV_MATCHR_WEBRSP_WORKERS_2026-03-25.md`
- `docs/FHIRDEV22_FRESH_START_ZSY_SNAPSHOT_2026-03-27.md`

## High-level conclusion

There was a **real compromise indicator** inside `fhirdev22`: the old malware
launcher chain had reappeared on disk and was still configured to relaunch every
minute from cron.

This was **not** explained by host memory, disk, load, or conntrack exhaustion.
The host itself looked operationally healthy.

At the same time, the container had an obvious re-entry path:

- host publishes `2222 -> container 22`
- container SSH config allowed `PermitRootLogin yes`
- container SSH config allowed `PasswordAuthentication yes`
- container `root` had a valid password hash
- container `root` also had an unexpected SSH authorized key

That combination is a much more credible compromise path than the `%webreq`
worker issues documented in the March notes.

## Evidence found

### Persistence chain in `fhirdev22`

`/etc/crontab` inside the container contained:

```text
*/1 * * * * root /.mod
```

`/.mod` contained:

```bash
#!/bin/bash
/usr/lib/libgdi.so.0.8.2
```

Known file paths present on disk at review time:

- `/.mod`
- `/usr/lib/libgdi.so.0.8.2`
- `/tmp/linux`
- `/etc/kswpad`
- `/usr/bin/.sshd`

Observed details:

- `/.mod`: root-owned executable shell script
- `/usr/lib/libgdi.so.0.8.2`: root-owned **5 MiB** stripped static ELF
- `/tmp/linux`, `/etc/kswpad`, `/usr/bin/.sshd`: root-owned **zero-length**
  placeholders at the review moment

Observed payload hash:

```text
1e3eb765015fd335cfdcb0ddd020565690b5a2f15a2a62406d750bcb21b6d77b  /usr/lib/libgdi.so.0.8.2
```

This differs from the hash recorded in the March incident note, so the runtime
was not merely carrying old documentation baggage.

### Suspicious SSH access state in the container

Inside `fhirdev22`:

- `/etc/ssh/sshd_config` had:
  - `PermitRootLogin yes`
  - `PasswordAuthentication yes`
- `getent shadow root` showed a valid password hash for `root`
- `getent shadow vehu` remained locked (`!!`)
- `/root/.ssh/authorized_keys` existed and contained one unexpected key:
  - fingerprint: `SHA256:MkYY9qiVsFGBC5WkjoClCkwEFW5iSjcGQF7m4n4H7Cw`
  - comment: `mdrfckr`

### Host state during the review

Host resource checks looked normal:

- low load
- ample free memory
- disk not close to full
- conntrack nowhere near exhaustion

So the “disintegrating networking” report was **not** backed by a host resource
collapse.

One source of confusion: the host already had `ufw limit` on `22/tcp`, and
rapid repeated SSH probes from the same client IP can trigger temporary
connection refusal. That explains some of the intermittent `Connection refused`
behavior seen during investigation, but **does not** explain the reappeared
malware chain.

## Containment performed

### Inside `fhirdev22`

The following were removed or changed:

1. removed the `/.mod` cron entry from `/etc/crontab`
2. removed:
   - `/.mod`
   - `/tmp/linux`
   - `/etc/kswpad`
   - `/usr/bin/.sshd`
   - `/usr/lib/libgdi.so.0.8.2`
3. locked the container `root` password
4. removed the unexpected `/root/.ssh/authorized_keys` entry by replacing the
   file with an empty root-owned `0600` file
5. changed `sshd_config` to:
   - `PermitRootLogin no`
   - `PasswordAuthentication no`
   - `ChallengeResponseAuthentication no`
   - `KbdInteractiveAuthentication no`
6. stopped `sshd` / `xinetd` inside the container

### On the host

The host firewall was updated to reduce the obvious attack surface:

- `ufw deny in 2222/tcp`
- `ufw route deny 2222/tcp`

In addition, a direct `iptables` drop on `2222/tcp` was inserted during live
containment so the published container SSH port stopped being reachable
immediately.

### Verification after containment

After waiting more than one minute:

- the deleted persistence files did **not** return
- `/etc/crontab` stayed clean
- no suspicious processes matching those names were running
- `GET http://fhirdev.vistaplex.org:9080/fhir` still returned `200`
- external `2222` no longer provided a usable path into the container

## Brute-force SSH traffic

Host SSH logs over the previous 24 hours showed sustained scanner/brute-force
activity. Top sources included:

- `51.158.155.6`
- `118.185.85.137`
- `2.57.122.96`
- `20.2.83.149`
- `80.94.92.186`
- `103.117.56.152`
- `107.189.27.179`
- `81.192.46.45`
- `14.225.217.138`
- `45.249.247.126`
- `45.148.10.151`
- `45.148.10.147`
- `45.227.254.170`
- `2.57.121.118`
- `2.57.122.188`
- `2.57.122.190`
- `5.253.59.171`
- `92.118.39.95`
- `42.118.12.47`
- `118.70.178.158`
- `211.253.37.225`
- `103.210.21.242`

These were geolocated as **non-US** during the live review and were included in
the reusable blocklist below.

Two observed **US** source IPs were **not** added to the non-US list:

- `149.22.93.111`
- `47.180.114.229`

## Reusable blocklist tooling

Versioned helper files were added under `scripts/security/`:

- `scripts/security/fhirdev-nonus-ssh-blocklist-2026-04-11.txt`
- `scripts/security/apply-ufw-blocklist.sh`

Usage examples:

```bash
sudo ./scripts/security/apply-ufw-blocklist.sh \
  --list ./scripts/security/fhirdev-nonus-ssh-blocklist-2026-04-11.txt
```

Remote install from a maintainer workstation:

```bash
./scripts/security/apply-ufw-blocklist.sh \
  --host root@example.org \
  --list ./scripts/security/fhirdev-nonus-ssh-blocklist-2026-04-11.txt
```

To limit only SSH instead of all traffic from those IPs:

```bash
sudo ./scripts/security/apply-ufw-blocklist.sh \
  --list ./scripts/security/fhirdev-nonus-ssh-blocklist-2026-04-11.txt \
  --port 22
```

## Remaining risk / next steps

1. Treat `fhirdev22` as a **compromised container**, even though the live
   persistence chain was removed. Rebuild from a trusted image as soon as
   practical.
2. Review why Docker-published SSH (`2222 -> 22`) existed at all. If it is not
   needed, remove the port mapping from the container definition rather than
   relying only on firewall rules.
3. Review host exposure of Docker API ports `2375` / `2376`.
4. Review host and container SSH authorized keys against a trusted inventory.
5. Consider whether host `22` should also move to key-only auth if not already
   enforced operationally.

## One-paragraph summary

On **2026-04-11**, `fhirdev22` was found to contain a reappeared cron-based
malware launcher (`/.mod` → `/usr/lib/libgdi.so.0.8.2`) plus root-owned
companion file paths on disk. The container also exposed SSH through host port
`2222` with `PermitRootLogin yes`, `PasswordAuthentication yes`, a valid root
password hash, and an unexpected root authorized key. The persistence chain was
removed, the suspicious root SSH key was deleted, root/password SSH was
disabled in the container, container SSH services were stopped, host firewall
rules were added to block `2222`, and the FHIR demo on `9080` remained healthy.
Reusable UFW blocklist tooling was added for the observed non-US SSH scanner IPs.
