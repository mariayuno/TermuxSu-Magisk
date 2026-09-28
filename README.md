<div align="center">

# `txsu` — TermuxSu

**Drop into a proper Termux shell from any root session.**

```sh
txsu
```

*SSH into your phone, ADB into it, su from another app — one command gives you your full configured Termux environment with correct identity, networking, storage, and shell initialization.*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Android](https://img.shields.io/badge/Android-7%2B-green.svg)
![Root](https://img.shields.io/badge/Root-Magisk%20%7C%20KSU%20%7C%20APatch-orange.svg)

</div>

---

## The Problem

When you `su` to your Termux UID from a root session, you don't get a Termux shell. You get a broken shell that looks like one. Networking fails. `/sdcard` is inaccessible. `sudo` and `tsu` don't work. Your PATH is corrupted. Your `.zshrc` either doesn't load, or loads three times.

The reason is that Android's framework does a lot of work when it launches an app through Zygote — assigning supplementary groups, initializing the environment, wiring up the resolver — and a bare `su <uid>` replicates none of it.

`txsu` replicates what matters. Precisely, portably, and without security hacks.

---

## What `txsu` Does

```
ROOT SESSION (SSH / ADB / another app)
          │
          │  environment NOT inherited
          ▼
      ┌───────┐
      │  txsu │
      └───┬───┘
          │  stat-based UID/GID detection
          │  inet + storage supplementary groups
          │  complete Termux env constructed from scratch
          ▼
    zsh -l -i  ← your .zshrc, your PATH, sudo works
```

Every invocation:

1. Detects Termux `UID`/`GID` via `stat` on the data directory — no hardcoding, no caching
2. Detects the `inet` GID dynamically from `/dev/socket/dnsproxyd`
3. Detects the `storage` GID dynamically from `/storage`
4. Builds a clean environment from scratch: `HOME`, `PREFIX`, `ZDOTDIR`, `PATH`, `TMPDIR`, all `ANDROID_*` and `TERMUX_*` vars
5. Clears `LD_LIBRARY_PATH`, loads `libtermux-exec-ld-preload.so`
6. `exec`s into `zsh -l -i` — a proper login shell so `.zshrc` runs exactly once

---

## Install

Flash `TermuxSu-Magisk.zip` in Magisk / KernelSU / APatch, then run `txsu` from any root shell.

### Requirements

- Rooted device: Magisk, KernelSU, ResuKiSU, or APatch
- Termux with zsh installed (`pkg install zsh`)
- Android 7+

---

## Design

`txsu` was built by working through four distinct failure modes in existing approaches. Each hurdle below documents what was broken, why, and what the correct fix is.

---

### Hurdle 1 — Getting a shell that actually *is* Termux

The foundational problem: getting a shell with the right UID, right groups, right env, and right toolchain, from a root session.

#### What Android does when Termux starts normally

```
Android Framework (ActivityManager)
         │
         │  fork request with full credential spec
         ▼
      Zygote
         │
         ├── UID  = <termux uid>
         ├── GID  = <termux gid>
         ├── supplementary groups = [ inet, sdcard_rw, ... ]
         ├── SELinux domain = untrusted_app_27
         ├── capabilities stripped
         └── env = framework-initialized
         │
         ▼
   com.termux process → Termux terminal service → pty → zsh
```

A root bridge has to approximate this from nothing, using only `su`.

#### What naive approaches do wrong

Common implementations read `/proc/<pid>/environ` of a running Termux process, parse it into an env string, and pass it to `su`. This has multiple compounding failure modes:

| # | Problem | Impact |
|---|---------|--------|
| ① | `/proc/<pid>/environ` is attacker-controlled data | root reads untrusted input |
| ② | Env string unquoted → word splitting + glob expansion | `FOO=hello world` becomes two args |
| ③ | Shell path read from Termux-writable `passwd` file | shell path can be injected |
| ④ | Cache written unquoted | `; payload` in shell name becomes shell syntax |
| ⑤ | Cache sourced as root code | **RCE** — Termux controls what root executes |
| ⑥ | `runcon true` used as a probe | proves nothing about the full chain |
| ⑦ | SELinux transition before UID switch | transition order matters to the kernel |
| ⑧ | `su <uid>` with no `-g`/`-G` flags | missing `inet`, `sdcard_rw` → network + storage broken |

#### What `txsu` does

The entire design principle: **construct everything from verified integers, never source external data, never inherit the root environment.**

```
root shell
      │
      ├── stat -c '%u' /data/data/com.termux    → TUID
      ├── stat -c '%g' /data/data/com.termux    → TGID
      ├── stat -c '%g' /dev/socket/dnsproxyd    → IGID (inet)
      ├── stat -c '%g' /storage                 → SGID (storage)
      │
      │   ┌──────────────────────────────────────┐
      │   │  stat output = integers only         │
      │   │  cannot contain shell metacharacters │
      │   │  no Termux filesystem involved       │
      │   └──────────────────────────────────────┘
      │
      ▼
/system/bin/su -g $TGID -G $IGID -G $SGID $TUID /system/bin/sh -c '
      │
      │  NOW INSIDE uid=<termux uid> PROCESS
      │  root env is GONE — sh -c starts clean
      │
      ├── export HOME, PREFIX, ZDOTDIR, PATH, TMPDIR, TERM, LANG
      ├── export ANDROID_ROOT / DATA / STORAGE / ASSETS / ART_ROOT / ...
      ├── export TERMUX__ROOTFS_DIR / HOME / PREFIX / UID / USER_ID
      ├── export TERMUX_APP__PACKAGE_NAME / DATA_DIR
      ├── export SHELL=$PREFIX/bin/zsh
      ├── unset LD_LIBRARY_PATH
      ├── export LD_PRELOAD=libtermux-exec-ld-preload.so
      ├── cd $HOME
      └── exec $PREFIX/bin/zsh -l -i    ✅
'
```

**Why `stat` for UID/GID:** `stat -c '%u'` returns a decimal integer. Integers cannot contain shell metacharacters. This eliminates the entire class of injection bugs from using `passwd`, `dumpsys`, `pm`, or process scanning.

**Why `unset LD_LIBRARY_PATH`:** Root/KSU/SSH sessions may carry `LD_LIBRARY_PATH` pointing at system paths. If that survives into Termux's zsh, the dynamic linker picks up wrong `.so` files. Clearing it first ensures `libtermux-exec-ld-preload.so` operates cleanly.

**Why `exec zsh -l -i`:** `-l` makes it a login shell (reads `.zprofile`). `-i` makes it interactive (reads `.zshrc`). Together they give a full configured Termux environment — custom PATH, aliases, plugins, and `sudo`/`tsu` working correctly.

---

### Hurdle 2 — Internet

This was the most misdiagnosed problem in prior implementations. The old fix was a `runcon` call to switch SELinux domains. That reasoning is wrong.

#### How Android's network stack actually works

```
process calls connect() / getaddrinfo()
              │
              ▼
       ┌──────────────────────────────────────────┐
       │  Does this process have permission to    │
       │  reach /dev/socket/fwmarkd ?             │  ← SELinux check (netdomain)
       │  reach /dev/socket/dnsproxyd ?           │
       └──────────────────┬───────────────────────┘
                          │ yes
                          ▼
                   FwmarkServer (netd)
                          │
                          │  getNetworkForConnect(client->getUid())
                          │                              ↑
                          │                       UID — not SELinux domain
                          ▼
                   correct network route + DNS
```

The routing decision in `FwmarkServer.cpp` is UID-based. SELinux only gates whether the process can *open the socket at all* — via the `netdomain` attribute. These are two separate checks.

#### Why `runcon` was the wrong fix

`runcon untrusted_app_27` switches the SELinux domain, which unblocks socket access on builds where `ksu` lacked `netdomain`. But it was solving the access problem while misidentifying the root cause as a routing problem. On current KernelSU, `ksu` explicitly has `netdomain` in `kernel/selinux/rules.c` — `runcon` is entirely unnecessary.

The real problem was always simpler: the process was missing the `inet` supplementary group.

```sh
# Proven live on device:

# UID only — fails
su 10172 python3 -c 'socket.connect("/dev/socket/dnsproxyd")'
# → PermissionError(13, 'Permission denied')   ← DAC failure, not SELinux

# UID + inet group — works
su -g 10172 -G 3003 10172 python3 -c 'socket.connect("/dev/socket/dnsproxyd")'
# → SUCCESS; getaddrinfo("example.com") → [('172.66.147.243', ...)]
```

`/dev/socket/dnsproxyd` is `gid=<inet> mode=660`. Without that group, the process can't open the socket. One supplementary group. No SELinux change.

#### What `txsu` does

Deletes the entire networking subsystem — no `resolv.conf` writing, no `getprop`, no interface scanning, no `runcon`. Adds the `inet` GID detected dynamically:

```sh
IGID=$(stat -c '%g' /dev/socket/dnsproxyd)
# → the GID of the socket that inet access gates
# → works on all devices, all Android versions
```

**Why not copy all real Termux groups:** A real Termux process has 5 supplementary groups. Two matter for a shell session: `inet` (network) and `storage` (sdcard). `stat`-based detection of those two is more portable — it doesn't require a live Termux process.

**Why no `resolv.conf`:** Android's resolver bypasses it entirely. Termux processes using Python, curl, wget, git all go through bionic's `getaddrinfo()` → `dnsproxyd`. DNS state flows automatically once the process has the right UID and `inet` group.

---

### Hurdle 3 — Internal storage access

Storage access failure was also misdiagnosed. The old approach tried patching `resolv.conf`. The real problem was a different missing supplementary group.

#### How Android grants storage access to apps

Zygote assigns supplementary groups explicitly when forking an app process:

```
Zygote fork (for com.termux)
      ├── uid  = <termux uid>
      ├── gid  = <termux gid>
      └── supplementary groups:
            1077   → log
            3003   → inet         (network socket access)
            9997   → everybody    (shared storage)
           20xxx   → u0_aXXX_cache
           50xxx   → all_aXXX     (app-specific external storage)
```

The `everybody` (9997) and per-app groups give the process access to `/sdcard` and `/storage/emulated/0`. These are enforced at the FUSE layer — the storage daemon checks group membership, not just UID.

A plain `su <uid>` gives you only the UID. No supplementary groups:

```
uid=10172  gid=10172  groups=10172

      ├── /sdcard              ❌  FUSE checks everybody/storage group
      ├── /storage/emulated/0  ❌  same
      └── /dev/socket/dnsproxyd ❌  needs inet, mode 0660 gid=inet
```

#### What `txsu` does

Detects the storage GID dynamically and passes it as a supplementary group:

```sh
SGID=$(stat -c '%g' /storage)
# → GID of the /storage mount point
# → what FUSE/sdcardfs checks for access
```

**Why `stat` on the mount point:** The storage GID is not fixed across Android versions and custom ROMs. Reading it from `/storage` itself means the detection is always correct and self-documenting.

**Result:** `/sdcard` read/write works. `curl`, `wget`, `git`, `pip` all work. No SELinux manipulation. No `resolv.conf`. No process scanning.

---

### Hurdle 4 — `sudo` / `tsu`

`sudo` and `tsu` inside the bridged shell failed or behaved incorrectly. Two compounding problems: a corrupted PATH and missing shell initialization.

#### What the naive approach does to PATH

Reading a live Termux process's environment captures its already-expanded PATH — one that `.zshrc` has already built up with custom entries. Then launching `zsh -l` runs `.zshrc` again and appends those same paths on top. The result:

```
PATH=/prefix/bin:~/.npm-global/bin:~/.local/bin:   ← from live env
     ~/.npm-global/bin:~/.local/bin:               ← .zshrc ran again
     ~/.npm-global/bin:~/.local/bin:               ← and again
```

Every custom path segment triplicated. `sudo` finds the wrong binary, or an ambiguous one, or fails entirely.

#### Missing ZDOTDIR

Without `ZDOTDIR` pointing at `~/.config/zsh`, zsh looks for `.zshrc` in `HOME`. If the user's zsh config follows XDG layout under `.config/zsh/`, none of it loads. `sudo` isn't found. Custom tools aren't found. Nothing works as expected.

#### What `txsu` does

Provide only a **base PATH** in the launcher. Let `.zshrc` do its job exactly once.

```
txsu launcher provides:
      PATH = $PREFIX/bin:$PREFIX/bin/applets:system paths
                ↑ base only — no user additions

zsh -l -i runs:
      .zprofile  → login-level setup
      .zshrc     → adds npm-global, mason, .local/bin — ONCE

Result:
      PATH = $PREFIX/bin:~/.npm-global/bin:~/.local/bin:...
               ↑ clean, no duplicates
```

**Why `ZDOTDIR` explicitly:** Set before `exec zsh` so that `.zshrc` loads from the correct XDG location regardless of how `HOME` is configured.

**Why `-l -i` together:** `-l` triggers `.zprofile` (login-level env setup). `-i` triggers `.zshrc` (interactive config, aliases, PATH additions, plugins). Either alone is insufficient. Together they produce an experience identical to opening a normal Termux terminal.

**Result:** `.zshrc` loads once, PATH is clean, `sudo` resolves to `tsu` in `$PREFIX/bin`, `tsu` escalates to root correctly.

---

## Security Notes

- All UID/GID values are obtained via `stat` — integer output only, immune to injection
- No external files are read or sourced during escalation
- No environment is inherited from the root shell
- No Termux filesystem is touched before the `exec`
- No SELinux domain switching
- No cache files

---

## License

MIT
