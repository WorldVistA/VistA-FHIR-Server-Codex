# postkit3 incident response (2026-04-11)

## Purpose

This note records the live investigation and containment work performed on
`postkit3.vistaplex.org` / Docker container `postkit` on **2026-04-11** after
the same cross-host review that identified SSH exposure and login issues on the
other VistA servers.

## High-level conclusion

`postkit3` showed the same basic SSH-risk pattern already seen elsewhere:

- host publishes `2222 -> container 22`
- container `sshd` was running
- container effective SSH config allowed `PermitRootLogin yes`
- container `root` had a valid password hash
- container `root` also had the same suspicious `mdrfckr` authorized key

Unlike `fhirdev22`, this review did **not** find the `/.mod` /
`libgdi.so.0.8.2` malware persistence chain inside the container, and unlike
`vendev15`, it did **not** show a runaway `GTMLNX^HLCSGTM` process pileup.

The separate "`su - osehra` is slow" symptom on `postkit3` was explained by the
same mechanism as on `vendev15`: a very large failed-login log (`/var/log/btmp`)
being scanned by `pam_lastlog`. In addition, `osehra` login shells were still
auto-loading NVM and running `nvm use 6`.

## Evidence found

### Container SSH exposure

At review time inside `postkit`:

- `sshd` and `xinetd` were both running
- effective `sshd` settings included:
  - `PermitRootLogin yes`
  - `PasswordAuthentication no`
  - `KbdInteractiveAuthentication no`
  - `ChallengeResponseAuthentication no`
- `passwd -S root` showed a valid password hash for container `root`
- `/root/.ssh/authorized_keys` existed and contained:
  - fingerprint: `SHA256:MkYY9qiVsFGBC5WkjoClCkwEFW5iSjcGQF7m4n4H7Cw`
  - comment: `mdrfckr`

The host also exposed the container SSH port publicly:

```text
0.0.0.0:2222 -> container 22
```

### Failed-login log growth and login-shell delay

Inside the container:

```text
/var/log/btmp 2696166528 bytes
```

That is roughly **2.6 GiB**. The PAM stack included:

```text
session [default=1] pam_lastlog.so nowtmp showfailed
```

Testing showed:

- `su - osehra -c date` timed out before containment
- `runuser -l osehra -c date` worked

The large `btmp` file makes the failed-login scan expensive, which explains the
slow `su` behavior.

### Osehra login-shell Node/NVM auto-load

Before cleanup, `/home/osehra/.bash_profile` contained:

```bash
source $HOME/.nvm/nvm.sh
nvm use 6
```

This caused login-shell Node initialization on each `su - osehra` / `runuser -l
osehra` path, even when the operator only wanted an M environment.

### Malware and process checks

The known persistence markers from `fhirdev` / `fhirdev22` were **not** present:

- `/.mod`
- `/tmp/linux`
- `/etc/kswpad`
- `/usr/bin/.sshd`
- `/usr/lib/libgdi.so.0.8.2`

`/etc/crontab` did not contain the old launcher entry, and there was no
`GTMLNX^HLCSGTM` runaway swarm. Only a few normal-looking `mumps -direct` jobs
were present.

### Additional host exposure

At review time, host `ufw` also still allowed:

- `2375/tcp`
- `2376/tcp`

No active listeners were found on those ports during this review, but the allow
rules were unnecessary exposure.

The host also publishes:

```text
0.0.0.0:32768 -> container 8080
```

which remained reachable and returned an HTTP response during the review.

## Containment performed

### Inside `postkit`

1. Backed up and then cleared `/root/.ssh/authorized_keys`
2. Locked the container `root` password
3. Changed container `sshd_config` to:
   - `PermitRootLogin no`
   - `PasswordAuthentication no`
   - `ChallengeResponseAuthentication no`
   - `KbdInteractiveAuthentication no`
4. Stopped `sshd` and `xinetd` inside the container
5. Truncated `/var/log/btmp` to `0 bytes`
6. Disabled automatic `nvm use 6` in `/home/osehra/.bash_profile`

### On the host

1. Added `ufw deny 2222/tcp`
2. Added `ufw route deny 2222/tcp`
3. Inserted a direct `iptables` drop on `2222/tcp`
4. Removed `ufw` allow rules for `2375/tcp` and `2376/tcp`

## Verification after containment

After the live changes:

- `su - osehra -c date` returned immediately
- `runuser -l osehra -c date` returned immediately
- the `nvm use 6` login-shell message no longer appeared
- `pgrep -a sshd` and `pgrep -a xinetd` inside the container returned none
- effective container SSH settings reflected root/password login disabled
- `passwd -S root` showed container `root` locked
- `/root/.ssh/authorized_keys` inside the container was an empty root-owned
  `0600` file
- `/var/log/btmp` was `0 bytes`
- external `nc` to host port `2222` failed with `Connection refused`
- external host `22/tcp` remained reachable
- `GET http://127.0.0.1:9080/fhir` still returned an HTTP response
- no `ufw` rules for `2375/tcp` or `2376/tcp` remained on the host

## Remaining risk / next steps

1. Remove the published `2222 -> 22` mapping from the container definition if it
   is no longer operationally needed.
2. Review whether the published `32768 -> 8080` mapping should also remain
   public.
3. Add or restore `btmp` / `wtmp` rotation so failed-login logs cannot regrow
   without bound.
4. Consider whether remaining NVM auto-load in other shell startup files should
   also be disabled if operators do not need Node by default.

## One-paragraph summary

On **2026-04-11**, `postkit3.vistaplex.org` / `postkit` was found to expose
container SSH publicly on host port `2222`, with container `sshd` running,
`PermitRootLogin yes`, a valid container `root` password hash, and the same
suspicious `mdrfckr` root authorized key seen on other compromised containers.
There was no sign of the `/.mod` malware chain and no runaway
`GTMLNX^HLCSGTM` job swarm, but `/var/log/btmp` had grown to about **2.6 GiB**
and was slowing `su`, while `osehra` login shells were also auto-running NVM.
The suspicious container root key was removed, container `root` was locked,
container SSH was hardened and stopped, host `2222` was blocked, `btmp` was
truncated, `nvm use 6` was disabled from `osehra`'s login profile, and the host
`ufw` allow rules for `2375/tcp` and `2376/tcp` were removed.
