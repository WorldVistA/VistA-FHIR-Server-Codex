# local container incident response (2026-04-11)

## Purpose

This note records the local review and containment work performed on the three
Docker containers running on the maintainer laptop on **2026-04-11**:

- `fhir`
- `vehu10`
- `vehu6`

The review used the same checklist applied to the remote servers:

- container SSH exposure
- root password / root key state
- known malware markers (`/.mod`, `/usr/lib/libgdi.so.0.8.2`, related files)
- failed-login log growth (`/var/log/btmp`)
- `su - <user>` delay symptoms
- obvious runaway M jobs

## High-level conclusion

The three local containers did **not** show the `/.mod` /
`libgdi.so.0.8.2` malware chain.

However, all three still exposed container SSH to the host through published
`->22` mappings, and all three had active `sshd` / `xinetd` at review time.

Of the three, **`fhir`** was the one that most closely matched the higher-risk
remote pattern:

- published SSH on host port `2223`
- `PermitRootLogin yes`
- container `root` password set
- suspicious container root authorized key:
  - fingerprint `SHA256:MkYY9qiVsFGBC5WkjoClCkwEFW5iSjcGQF7m4n4H7Cw`
  - comment `mdrfckr`
- large `btmp` file (~`1.5 GiB`)
- `su - osehra` delay
- `osehra` login shell auto-loading NVM and running `nvm use 6`

`vehu10` and `vehu6` did **not** show that suspicious root key and did **not**
show large `btmp` growth, but both still had unnecessary container SSH exposed
with root/password auth enabled in `sshd`.

## Local host context

At review time, Docker was publishing these container SSH ports on the laptop:

- `2222 -> vehu6:22`
- `2223 -> fhir:22`
- `2226 -> vehu10:22`

The laptop had **no host UFW policy** in front of those ports.

Because this is the maintainer's own laptop and the operator explicitly chose to
leave those published host ports alone, the host-side Docker `->22` mappings
were **not** removed or firewall-blocked as part of this pass.

Instead, the containment focused on disabling SSH **inside** the containers so
the published host ports no longer front a live `sshd` / `xinetd` service.

## Evidence found

### `fhir`

At review time:

- `sshd` and `xinetd` were running
- effective container SSH settings included:
  - `PermitRootLogin yes`
  - `PasswordAuthentication no`
  - `KbdInteractiveAuthentication no`
  - `ChallengeResponseAuthentication no`
- `passwd -S root` showed container `root` had a valid password hash
- `/root/.ssh/authorized_keys` existed and contained:
  - fingerprint `SHA256:MkYY9qiVsFGBC5WkjoClCkwEFW5iSjcGQF7m4n4H7Cw`
  - comment `mdrfckr`
- `/var/log/btmp` was about `1.5 GiB`:

```text
/var/log/btmp 1609499136 bytes
```

- `su - osehra -c date` timed out
- `runuser -l osehra -c date` worked, but displayed:

```text
Now using node v6.13.1 (npm v3.10.10)
```

- `/home/osehra/.bash_profile` contained:

```bash
source $HOME/.nvm/nvm.sh
nvm use 6
```

- `http://127.0.0.1:9080/fhir` returned `200`

### `vehu10`

At review time:

- `sshd` and `xinetd` were running
- effective container SSH settings included:
  - `PermitRootLogin yes`
  - `PasswordAuthentication yes`
- no container root authorized key was present
- `/var/log/btmp` was `0 bytes`
- `su - vehu -c date` worked immediately
- `runuser -l vehu -c date` worked immediately
- `/home/vehu/.bash_profile` and `.bashrc` did **not** show the same NVM
  auto-load pattern seen in `fhir`
- `http://127.0.0.1:9080/fhir` returned `200`

### `vehu6`

At review time:

- `sshd` and `xinetd` were running
- effective container SSH settings included:
  - `PermitRootLogin yes`
  - `PasswordAuthentication yes`
- no container root authorized key was present
- `/var/log/btmp` was small (`1152 bytes`)
- `su - vehu -c date` worked immediately
- `runuser -l vehu -c date` worked immediately
- internal `http://127.0.0.1:9080/fhir` returned `000` during the check

### Malware and process checks

Across all three containers:

- no `/.mod`
- no `/tmp/linux`
- no `/etc/kswpad`
- no `/usr/bin/.sshd`
- no `/usr/lib/libgdi.so.0.8.2`
- no obvious `GTMLNX^HLCSGTM` runaway swarm

The observed M processes were ordinary-looking `mumps -direct` sessions rather
than the runaway HL7 listener pattern seen on `vendev15`.

## Containment performed

### Inside `fhir`

1. Backed up and cleared `/root/.ssh/authorized_keys`
2. Locked container `root`
3. Changed `sshd_config` to:
   - `PermitRootLogin no`
   - `PasswordAuthentication no`
   - `ChallengeResponseAuthentication no`
   - `KbdInteractiveAuthentication no`
4. Stopped `sshd` and `xinetd`
5. Truncated `/var/log/btmp` to `0 bytes`
6. Disabled automatic `nvm use 6` from `/home/osehra/.bash_profile`

### Inside `vehu10`

1. Cleared `/root/.ssh/authorized_keys` (it was already effectively empty of
   trusted content)
2. Ran `passwd -l root` as part of the hardening pass
3. Changed `sshd_config` to:
   - `PermitRootLogin no`
   - `PasswordAuthentication no`
   - `ChallengeResponseAuthentication no`
   - `KbdInteractiveAuthentication no`
4. Stopped `sshd` and `xinetd`

### Inside `vehu6`

1. Cleared `/root/.ssh/authorized_keys` (it was already effectively empty of
   trusted content)
2. Ran `passwd -l root` as part of the hardening pass
3. Changed `sshd_config` to:
   - `PermitRootLogin no`
   - `PasswordAuthentication no`
   - `ChallengeResponseAuthentication no`
   - `KbdInteractiveAuthentication no`
4. Stopped `sshd` and `xinetd`

## Verification after containment

### `fhir`

After the live changes:

- `su - osehra -c date` returned immediately
- `runuser -l osehra -c date` returned immediately
- the `nvm use 6` login-shell message no longer appeared
- `pgrep -a sshd` returned none
- `pgrep -a xinetd` returned none
- `passwd -S root` showed container `root` locked
- `/root/.ssh/authorized_keys` was an empty root-owned `0600` file
- `/var/log/btmp` was `0 bytes`
- `http://127.0.0.1:9080/fhir` still returned `200`

### `vehu10`

After the live changes:

- `su - vehu -c date` returned immediately
- `runuser -l vehu -c date` returned immediately
- `pgrep -a sshd` returned none
- `pgrep -a xinetd` returned none
- effective container SSH settings reflected root/password login disabled
- `/root/.ssh/authorized_keys` was an empty root-owned file
- `http://127.0.0.1:9080/fhir` still returned `200`

### `vehu6`

After the live changes:

- `su - vehu -c date` returned immediately
- `runuser -l vehu -c date` returned immediately
- `pgrep -a sshd` returned none
- `pgrep -a xinetd` returned none
- effective container SSH settings reflected root/password login disabled
- `/root/.ssh/authorized_keys` was an empty root-owned file
- internal `http://127.0.0.1:9080/fhir` still returned `000`

## Residual state intentionally left in place

The laptop still has Docker-published host ports corresponding to container SSH:

- `2222`
- `2223`
- `2226`

Those host listeners remain because the containers were created with published
`->22` mappings, and the operator explicitly chose to leave them alone on this
maintainer laptop.

The important change is that those ports no longer front an active `sshd` /
`xinetd` service inside the containers, so the earlier remote-container SSH
foothold pattern is no longer present in the same form.

## Remaining risk / next steps

1. If these containers are ever moved off the laptop or joined to a less-trusted
   network, remove the Docker `->22` mappings instead of relying only on
   in-container SSH shutdown.
2. If `vehu6` is expected to serve the FHIR path locally, investigate why
   `http://127.0.0.1:9080/fhir` returned `000` both before and after the
   hardening pass.
3. If any operator still needs container shell access, use `docker exec` instead
   of reopening SSH in the containers.

## One-paragraph summary

On **2026-04-11**, the local Docker containers `fhir`, `vehu10`, and `vehu6`
were reviewed using the same SSH/malware/login-delay checklist applied to the
remote incidents. No local container contained the `/.mod` malware chain, but
all three had active container SSH exposed through published host `->22`
mappings. The `fhir` container also contained the suspicious `mdrfckr` root key,
had a set root password, had a `1.5 GiB` `btmp` file slowing `su - osehra`, and
auto-ran NVM in login shells. All three containers were hardened by clearing
root authorized keys, disabling root/password SSH, and stopping `sshd` /
`xinetd`; `fhir` additionally had `btmp` truncated and NVM auto-use disabled.
The operator chose to leave the host-side Docker `->22` port mappings in place
because this is a maintainer laptop, but the containers no longer run an active
SSH service behind those ports.
