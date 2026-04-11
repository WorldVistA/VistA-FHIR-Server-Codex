# vendev15 incident response (2026-04-11)

## Purpose

This note records the live investigation and containment work performed on
`vendev15.vistaplex.org` / Docker container `vapals` on **2026-04-11** after
reports of runaway Mumps jobs and severe login delays.

It complements the earlier 2026-04-11 incident notes for the other VistA hosts
reviewed the same day.

## High-level conclusion

There were two separate operational/security problems on `vendev15`:

1. the `vapals` container had accumulated a large number of runaway
   `mumps -run GTMLNX^HLCSGTM` jobs, which drove host load very high
2. the container exposed the same unsafe SSH pattern seen on the other servers:
   host `2222 -> container 22`, container `sshd` running, `PermitRootLogin yes`,
   `PasswordAuthentication yes`, and a valid container `root` password hash

In addition, the apparent "`su - osehra` is broken" symptom was traced to a
different cause: `/var/log/btmp` inside the container had grown to about
**13 GiB**, and `pam_lastlog` was scanning that file on each `su` invocation to
show failed logins. That created the long delay and CPU-heavy `su` behavior.

Unlike `fhirdev22`, this review did **not** find the `/.mod` /
`libgdi.so.0.8.2` malware persistence chain inside `vapals`.

## Evidence found

### Runaway HL7 listener jobs

Inside `vapals`, `ps` showed **121** processes matching:

```text
/usr/local/lib/yottadb/r122/mumps -run GTMLNX^HLCSGTM
```

Many had been running for days to weeks, and several were consuming meaningful
CPU. Before containment, host load was approximately:

```text
67.65 66.79 65.69
```

### SSH exposure in the container

At review time:

- host published `2222 -> container 22`
- `sshd` was running inside `vapals`
- effective `sshd` settings inside the container included:
  - `PermitRootLogin yes`
  - `PasswordAuthentication yes`
  - `KbdInteractiveAuthentication no`
  - `ChallengeResponseAuthentication no`
- `passwd -S root` inside the container showed a valid password hash:
  - `root PS ... (Password set, SHA512 crypt.)`
- `/root/.ssh/authorized_keys` inside the container did **not** exist

This was still an unnecessary and high-risk remote entry path even without an
unexpected root key.

### `su - osehra` delay root cause

Initial testing showed:

- `docker exec -u osehra vapals bash -lc 'date'` returned immediately
- `runuser -l osehra -c date` returned immediately
- `su osehra -c true` and `su - osehra -c date` appeared to hang and could peg
  CPU

Tracing and follow-up checks showed the delay was explained by the failed-login
log state inside the container:

```text
/var/log/btmp 13451626880 bytes
```

That is roughly **13 GiB**. The container PAM stack included:

```text
session [default=1] pam_lastlog.so nowtmp showfailed
```

and `strace` showed `su` repeatedly reading fixed-size records from a login log,
which is consistent with `pam_lastlog` scanning a huge `btmp` file to report
failed logins.

### Malware checks

The known `fhirdev` / `fhirdev22` persistence markers were checked inside
`vapals` and were **not** present:

- `/.mod`
- `/tmp/linux`
- `/etc/kswpad`
- `/usr/bin/.sshd`
- `/usr/lib/libgdi.so.0.8.2`

`/etc/crontab` was also clean of the `*/1 * * * * root /.mod` launcher entry.

## Containment performed

### Inside `vapals`

1. Stopped all runaway `GTMLNX^HLCSGTM` processes from inside the container as
   `osehra`, using the YottaDB environment from `/home/osehra/etc/env.conf` and
   `mupip stop <pid>`.
2. Verified the HL7 listener count dropped from `121` to `0`.
3. Locked the container `root` password.
4. Changed container `sshd_config` to:
   - `PermitRootLogin no`
   - `PasswordAuthentication no`
   - `ChallengeResponseAuthentication no`
   - `KbdInteractiveAuthentication no`
5. Stopped `sshd` inside the container.
6. Truncated `/var/log/btmp` from about `13 GiB` to `0 bytes`.

### On the host

1. Added `ufw deny 2222/tcp`
2. Inserted a direct `iptables` drop on `2222/tcp`

This preserved the published `9080` demo path while cutting off the obvious
container SSH ingress path.

## Verification after containment

After the live changes:

- `GTMLNX^HLCSGTM` count remained `0` after recheck
- host load dropped to approximately:

```text
0.16 6.61 31.08
```

- `su - osehra -c date` returned immediately again
- `su osehra -c true` returned immediately again
- `runuser -l osehra -c date` continued to work
- `pgrep -a sshd` inside `vapals` returned no running `sshd`
- effective container SSH settings reflected root/password login disabled
- `GET http://127.0.0.1:9080/fhir` still returned an HTTP response
- known malware marker paths remained absent

## Additional notes

The container had no active `crond`, and there was no evident `btmp` / `wtmp`
logrotate configuration in place during review. That helps explain why failed
SSH traffic against the exposed `2222` path was able to grow `btmp` unchecked
until it materially affected `su` performance.

The host `ufw` policy still explicitly allowed `2375/tcp` and `2376/tcp`,
although no listener was observed on those ports during this review.

## Remaining risk / next steps

1. Remove the published `2222 -> 22` mapping from the container definition if it
   is not operationally required, rather than relying only on firewall rules.
2. Review why host `ufw` still allows `2375/tcp` and `2376/tcp`, and close them
   if they are not intentionally used.
3. Add or restore log rotation for `btmp` / `wtmp` in the container image or
   deployment process so failed-login logs cannot regrow without bound.
4. Review whether host SSH can also be tightened to key-only auth if that is
   operationally acceptable.

## One-paragraph summary

On **2026-04-11**, `vendev15.vistaplex.org` / `vapals` was found to have **121**
runaway `mumps -run GTMLNX^HLCSGTM` jobs plus an exposed container SSH path on
host port `2222` with root/password login still enabled in the container. The
runaway HL7 jobs were stopped from inside the container using `mupip stop`, the
container `root` password was locked, container SSH was changed to disable
root/password login and then stopped, and host `2222` was blocked with both
`ufw` and `iptables`. The separate `su - osehra` delay was traced to a
**13 GiB** `/var/log/btmp` file being scanned by `pam_lastlog`; truncating that
file restored immediate `su` behavior. The known `/.mod` malware persistence
chain was **not** present in `vapals`, and the FHIR service on `9080` remained
available after containment.
