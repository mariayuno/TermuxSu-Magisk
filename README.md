<div align="center">

<h1>
  <img src="https://img.shields.io/badge/%24-txsu-00ff99?style=for-the-badge&labelColor=0d1117&color=00ff99&logo=gnubash&logoColor=00ff99" alt="txsu">
</h1>

**Drop into a proper Termux shell from any root session.**

```sh
txsu
```

*One command. Correct UID, groups, environment, networking, storage, and shell init — from SSH, ADB, or any root app.*

[![License: MIT](https://img.shields.io/badge/License-MIT-00bfff?style=flat-square&labelColor=0d1117)](LICENSE)
![Android](https://img.shields.io/badge/Android-7%2B-3ddc84?style=flat-square&labelColor=0d1117)
![Root](https://img.shields.io/badge/Root-Magisk%20%7C%20KSU%20%7C%20APatch-ff6b6b?style=flat-square&labelColor=0d1117)
![Shell](https://img.shields.io/badge/Shell-zsh%20%7C%20bash-f7c948?style=flat-square&labelColor=0d1117)

</div>

---

## 📋 Table of Contents

- [The Problem](#-the-problem)
- [Install](#-install)
- [Requirements](#-requirements)
- [How It Works — Full Flowchart](#-how-it-works--full-flowchart)
- [Script Walkthrough](#-script-walkthrough)
  - [Variables](#variables-declared)
  - [Shell Detection](#shell-detection)
  - [Preflight Checks](#preflight-checks)
  - [Dynamic GID Detection](#dynamic-gid-detection)
  - [The su Invocation](#the-su-invocation)
  - [Environment Construction](#environment-construction)
- [Why Each Decision Was Made](#-why-each-decision-was-made)
- [Security Notes](#-security-notes)

---

## 🔥 The Problem

When you `su` to your Termux UID from a root session, you don't get a Termux shell.
You get a **broken impostor** that looks like one.

| What breaks | Why |
|---|---|
| 🌐 Networking | Missing `inet` supplementary group — can't open `dnsproxyd` socket |
| 💾 `/sdcard` access | Missing `storage` supplementary group — FUSE denies access |
| 🔧 `sudo` / `tsu` | Corrupted PATH or `.zshrc` never loads |
| 📦 PATH duplicated | Naive env-copy makes `.zshrc` append paths 3× |
| 🐚 Wrong shell | No zsh? Crashes instead of falling back |

`txsu` fixes all of this. Precisely, portably, and without SELinux hacks.

---

## 📦 Install

### Option A — Flash as Magisk Module *(recommended)*

```sh
# Download the latest release zip
# Flash in Magisk / KernelSU / APatch Manager
# Reboot
txsu   # from any root shell
```

### Option B — Manual

```sh
# As root on your device
cp txsu /system/bin/txsu
chmod 755 /system/bin/txsu
```

> **Termux prerequisite:** `pkg install zsh` *(or `pkg install bash` as fallback)*

---

## ✅ Requirements

| Requirement | Details |
|---|---|
| Root | Magisk, KernelSU, ResuKiSU, or APatch |
| Termux | Any recent version |
| Shell | `zsh` preferred, `bash` accepted — at least one must be installed |
| Android | 7.0+ |

---

## 🗺 How It Works — Full Flowchart

```
┌─────────────────────────────────────────────────────────────────┐
│              ROOT SESSION  (SSH / ADB / root app)               │
│                    uid=0 · env=root's env                       │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │  run:  txsu    │
                    └───────┬────────┘
                            │
             ───────────────▼───────────────
            │        PREFLIGHT CHECKS        │
            │  ✔ running as root?            │
            │  ✔ /data/data/com.termux  ?    │
            │  ✔ Termux home exists?         │
            │  ✔ libtermux-exec-ld-preload?  │
             ───────────────┬───────────────
                            │ all pass
                            ▼
             ───────────────────────────────
            │         SHELL DETECTION        │
            │                               │
            │   zsh available?  ──yes──►  SHELL=zsh   ZDOTDIR set  │
            │        │                                              │
            │       no                                             │
            │        │                                             │
            │   bash available? ──yes──►  SHELL=bash              │
            │        │                                             │
            │       no                                             │
            │        │                                             │
            │       die("install zsh or bash")                    │
             ───────────────┬───────────────────────────────────
                            │
                            ▼
             ─────────────────────────────────────
            │      DYNAMIC GID DETECTION (stat)   │
            │                                     │
            │  TUID = stat '%u' com.termux/       │
            │  TGID = stat '%g' com.termux/       │
            │  IGID = stat '%g' /dev/socket/      │
            │                      dnsproxyd      │  ← inet group
            │  SGID = stat '%g' /storage          │  ← storage group
             ─────────────────────┬───────────────
                                  │
                    ──────────────▼──────────────
                   │       su INVOCATION          │
                   │                             │
                   │  /system/bin/su             │
                   │    -g  TGID                 │  ← primary group
                   │    -G  IGID                 │  ← +inet
                   │    -G  SGID                 │  ← +storage
                   │    TUID                     │  ← UID switch
                   │    /system/bin/sh -c '...'  │
                    ──────────────┬──────────────
                                  │
                    ┌─────────────▼──────────────────────────────┐
                    │    INNER SHELL  (uid=TUID, clean env)       │
                    │                                             │
                    │  export HOME        TERMUX_HOME            │
                    │  export PREFIX      TERMUX_PREFIX          │
                    │  export ZDOTDIR     ~/.config/zsh  (zsh)   │
                    │  export TERM        xterm-256color         │
                    │  export LANG        en_US.UTF-8            │
                    │                                             │
                    │  export TERMUX__*   (rootfs, home, prefix) │
                    │  export TERMUX_APP__* (pkg name, data dir) │
                    │                                             │
                    │  export ANDROID_ROOT / DATA / STORAGE      │
                    │  export ANDROID_ART_ROOT / I18N / TZDATA   │
                    │                                             │
                    │  export PATH  PREFIX/bin : applets : system│
                    │  export TMPDIR                              │
                    │  export EXTERNAL_STORAGE  /sdcard          │
                    │                                             │
                    │  unset  LD_LIBRARY_PATH   ← clear root junk│
                    │  export LD_PRELOAD  libtermux-exec-*.so    │
                    │                                             │
                    │  cd HOME                                    │
                    └──────────────┬──────────────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │   exec  SHELL  -l  -i         │
                    │                              │
                    │   zsh:  sources .zprofile    │
                    │         sources .zshrc       │
                    │                              │
                    │   bash: sources .bash_profile│
                    │         sources .bashrc      │
                    └──────────────┬───────────────┘
                                   │
                    ───────────────▼───────────────
                   │                               │
                   │   ✅  FULL TERMUX SHELL        │
                   │                               │
                   │   uid = Termux UID            │
                   │   groups = Termux + inet +    │
                   │            storage            │
                   │   internet works              │
                   │   /sdcard works               │
                   │   sudo / tsu works            │
                   │   .zshrc loaded exactly once  │
                   │   PATH clean, no duplicates   │
                    ───────────────────────────────
```

---

## 🔬 Script Walkthrough

### Variables Declared

| Variable | Value | Purpose |
|---|---|---|
| `SU` | `/system/bin/su` | Path to the system `su` binary |
| `TERMUX_DATA` | `/data/data/com.termux` | Termux app data root |
| `TERMUX_PREFIX` | `…/files/usr` | Termux package prefix (`$PREFIX`) |
| `TERMUX_HOME` | `…/files/home` | Termux home directory (`$HOME`) |
| `TERMUX_ZDOTDIR` | `…/home/.config/zsh` | XDG zsh config dir (`$ZDOTDIR`) |
| `TERMUX_EXEC` | `…/lib/libtermux-exec-ld-preload.so` | Termux's exec preload library |
| `TERMUX_SHELL` | detected at runtime | `zsh` or `bash`, whichever is available |
| `SHELL_OPTS` | `-l -i` | Login + interactive flags for the shell |
| `ZDOTDIR_EXPORT` | set if zsh, empty if bash | Conditionally exports `ZDOTDIR` |
| `TUID` | `stat '%u' TERMUX_DATA` | Termux app UID (e.g. `10172`) |
| `TGID` | `stat '%g' TERMUX_DATA` | Termux app GID |
| `IGID` | `stat '%g' /dev/socket/dnsproxyd` | Android `inet` group — gates network access |
| `SGID` | `stat '%g' /storage` | Android storage group — gates sdcard access |

---

### Shell Detection

```sh
if [ -x "$TERMUX_PREFIX/bin/zsh" ]; then
    TERMUX_SHELL="$TERMUX_PREFIX/bin/zsh"
    SHELL_OPTS="-l -i"
    ZDOTDIR_EXPORT="export ZDOTDIR='$TERMUX_ZDOTDIR'"
elif [ -x "$TERMUX_PREFIX/bin/bash" ]; then
    TERMUX_SHELL="$TERMUX_PREFIX/bin/bash"
    SHELL_OPTS="-l -i"
    ZDOTDIR_EXPORT=""
else
    die "no usable shell found (install zsh or bash: pkg install zsh)"
fi
```

```
  zsh exists? ──yes──► use zsh, set ZDOTDIR
       │
       no
       │
  bash exists? ──yes──► use bash, skip ZDOTDIR
       │
       no
       │
  die() ──────────────► error + exit 1
```

<details>
<summary>💡 Why prefer zsh and why set ZDOTDIR?</summary>

`zsh` is the preferred shell because Termux's default configuration, plugin ecosystem, and most user configs target it. `bash` is a perfectly valid fallback — nearly all Termux users have one or the other.

`ZDOTDIR` tells zsh where to find `.zshrc`. If a user follows XDG conventions and keeps their zsh config under `~/.config/zsh/`, zsh will not find it without `ZDOTDIR` being set. By setting it in the launcher before `exec zsh`, we guarantee `.zshrc` loads regardless of home directory quirks.

`bash` doesn't have `ZDOTDIR` — it always reads `.bashrc` from `$HOME`, so no equivalent export is needed.

</details>

---

### Preflight Checks

```sh
die() { echo "txsu: ERROR: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ]         || die "must run as root"
[ -d "$TERMUX_DATA" ]      || die "Termux data directory not found"
[ -d "$TERMUX_HOME" ]      || die "Termux home not found"
[ -f "$TERMUX_EXEC" ]      || die "Termux exec preload not found"
```

| Check | Guards against |
|---|---|
| `id -u = 0` | Running without root — `su` would fail silently downstream |
| `-d TERMUX_DATA` | Termux not installed, or wrong package name |
| `-d TERMUX_HOME` | Termux installed but never opened (home not yet created) |
| `-f TERMUX_EXEC` | Old Termux version without `libtermux-exec-ld-preload.so` |

<details>
<summary>💡 Why check TERMUX_EXEC specifically?</summary>

`libtermux-exec-ld-preload.so` is what makes Termux binaries runnable from a non-Termux process. Without it as `LD_PRELOAD`, Termux's ELF binaries (compiled for Termux's non-standard linker paths) fail to load. This library intercepts `execve` calls and rewrites paths so they resolve correctly. If it's missing, every command in the shell will fail with `not found` or `exec format error`.

</details>

---

### Dynamic GID Detection

```sh
TUID="$(stat -c '%u' "$TERMUX_DATA")" || die "cannot determine Termux UID"
TGID="$(stat -c '%g' "$TERMUX_DATA")" || die "cannot determine Termux GID"
IGID="$(stat -c '%g' /dev/socket/dnsproxyd)" || die "cannot determine inet group"
SGID="$(stat -c '%g' /storage)"        || die "cannot determine storage group"
```

```
  /data/data/com.termux  ──stat──►  TUID (e.g. 10172)
  /data/data/com.termux  ──stat──►  TGID (e.g. 10172)
  /dev/socket/dnsproxyd  ──stat──►  IGID (e.g. 3003)  ← inet group
  /storage               ──stat──►  SGID (e.g. 1023)  ← storage group
```

<details>
<summary>💡 Why stat instead of hardcoding or reading /etc/group?</summary>

`stat -c '%u'` and `stat -c '%g'` return decimal integers. Integers cannot contain shell metacharacters — this eliminates the entire class of injection vulnerabilities from using `passwd`, `pm dump`, `dumpsys`, or `/proc/<pid>/environ`.

GIDs are not fixed across Android versions, OEM builds, or custom ROMs. Reading the GID directly from the resource it guards (the `dnsproxyd` socket for `inet`, the `/storage` mount for storage) means the detection is always correct and self-documenting. The `inet` group is precisely the group that owns `dnsproxyd` — detecting it from any other source would be guessing.

</details>

---

### The `su` Invocation

```sh
"$SU" \
    -g "$TGID" \
    -G "$IGID" \
    -G "$SGID" \
    "$TUID" \
    /system/bin/sh \
    -c "..."
```

| Flag | Value | Effect |
|---|---|---|
| `-g TGID` | Termux GID | Sets primary group to Termux's GID |
| `-G IGID` | inet GID | Adds `inet` supplementary group → network socket access |
| `-G SGID` | storage GID | Adds `storage` supplementary group → sdcard/FUSE access |
| `TUID` | Termux UID | Switches UID from 0 (root) to Termux's UID |
| `/system/bin/sh -c '...'` | | Intermediate shell to build the env before exec |

<details>
<summary>💡 Why does missing the inet group break networking?</summary>

Android's `dnsproxyd` socket is `gid=inet mode=660`. A process without the `inet` supplementary group cannot open it — this is a plain Unix DAC (discretionary access control) failure, not SELinux.

Without `dnsproxyd` access, `getaddrinfo()` fails. DNS resolution is broken. Every network call (`curl`, `wget`, `git`, `pip`) fails.

Proven live: `su 10172 python3 -c 'socket.connect("/dev/socket/dnsproxyd")'` → `PermissionError(13)`.
Then: `su -G 3003 10172 python3 -c 'socket.connect("/dev/socket/dnsproxyd")'` → success, DNS resolves.

One supplementary group. No SELinux change. No `resolv.conf` writing. No `runcon`.

</details>

<details>
<summary>💡 Why does missing the storage group break /sdcard?</summary>

`/sdcard` and `/storage/emulated/0` are served by a FUSE daemon (or sdcardfs). The daemon checks supplementary group membership — not just UID — before granting access. When Android's Zygote forks a real app process, it explicitly assigns these storage groups. A bare `su <uid>` doesn't replicate them, so the process can't access external storage even though it has the right UID.

Detecting the GID via `stat -c '%g' /storage` reads it directly from the mount point being guarded, so it works across all Android versions and custom ROMs without hardcoding.

</details>

<details>
<summary>💡 Why use /system/bin/sh -c as an intermediate step?</summary>

`su ... TUID /system/bin/sh -c '...'` drops privileges first, then lets the inner `sh -c` string build the environment from scratch. The root shell's environment is completely gone — `sh -c` starts clean. This means no root-owned paths, no stale `LD_LIBRARY_PATH`, no leaked variables can contaminate the Termux shell. The `exec` at the end of the inner string replaces the intermediate `sh` with the final shell process, leaving no wrapper.

</details>

---

### Environment Construction

Inside the inner `sh -c`, the full environment is built from hardcoded known-good values before `exec`ing the shell:

```
  GROUP A — Termux identity
  ─────────────────────────────────────────────────────────────────
  HOME          = /data/data/com.termux/files/home
  PREFIX        = /data/data/com.termux/files/usr
  ZDOTDIR       = …/home/.config/zsh              (zsh only)
  SHELL         = PREFIX/bin/zsh  (or bash)
  TMPDIR        = PREFIX/tmp
  TERM          = xterm-256color
  LANG          = ${LANG:-en_US.UTF-8}

  GROUP B — Termux internal vars (used by Termux apps and plugins)
  ─────────────────────────────────────────────────────────────────
  TERMUX__ROOTFS_DIR    = /data/data/com.termux/files
  TERMUX__HOME          = …/files/home
  TERMUX__PREFIX        = …/files/usr
  TERMUX__UID           = $(id -u)             ← evaluated inside inner shell
  TERMUX__USER_ID       = 0
  TERMUX_APP__PACKAGE_NAME = com.termux
  TERMUX_APP__DATA_DIR     = /data/data/com.termux

  GROUP C — Android system paths
  ─────────────────────────────────────────────────────────────────
  ANDROID_ROOT          = /system
  ANDROID_DATA          = /data
  ANDROID_STORAGE       = /storage
  ANDROID_ASSETS        = /system/app
  ANDROID_ART_ROOT      = /apex/com.android.art
  ANDROID_I18N_ROOT     = /apex/com.android.i18n
  ANDROID_TZDATA_ROOT   = /apex/com.android.tzdata
  EXTERNAL_STORAGE      = /sdcard

  GROUP D — PATH and linker
  ─────────────────────────────────────────────────────────────────
  PATH          = PREFIX/bin : PREFIX/bin/applets :
                  /system/bin : /system/xbin :
                  /system/sbin : /sbin : /sbin/bin

  unset LD_LIBRARY_PATH       ← clear root linker state
  LD_PRELOAD    = libtermux-exec-ld-preload.so
```

<details>
<summary>💡 Why is PATH only the base set, without user additions?</summary>

If a previous Termux process's environment were captured and reused, it would contain a PATH that `.zshrc` (or `.bashrc`) had already expanded — with npm-global, mason, `.local/bin`, etc. When the new shell then sourced its rc file, those paths would be appended again. On a typical dev setup this results in every custom path appearing 3× or more.

By providing only the base `PREFIX/bin` as the initial PATH, the shell's rc file runs exactly once on a clean base, adding each custom path exactly once. The result is identical to opening a normal Termux terminal.

</details>

<details>
<summary>💡 Why unset LD_LIBRARY_PATH before setting LD_PRELOAD?</summary>

Root shells — especially KernelSU's `ksu` shell or SSH sessions — may carry `LD_LIBRARY_PATH` pointing at system library paths. If that variable survives into the Termux shell, the dynamic linker picks up system `.so` files before Termux's own, which breaks binaries that expect Termux's library versions. Clearing it first ensures `libtermux-exec-ld-preload.so` operates in a clean linker environment.

</details>

<details>
<summary>💡 Why -l -i together when exec-ing the shell?</summary>

`-l` (login) causes the shell to source login-level config: `.zprofile` for zsh, `.bash_profile` for bash. This sets up environment-level things like `PATH` additions from package managers.

`-i` (interactive) causes the shell to source interactive config: `.zshrc` / `.bashrc`. This sets up aliases, plugins, prompt, and tool-specific PATH entries.

Either flag alone is insufficient. Together, they produce an experience indistinguishable from opening a native Termux terminal session. Without `-l`, `.zprofile` is skipped and some env setup is missing. Without `-i`, the shell is technically non-interactive and `.zshrc` may not run.

</details>

---

## 🔒 Security Notes

- **No external data sourced** — env is built entirely from hardcoded paths and integer `stat` output
- **No Termux filesystem read** during escalation — not `passwd`, not cached files, not `/proc/<pid>/environ`
- **No root environment inherited** — `sh -c` starts with a clean slate
- **No SELinux domain switching** — no `runcon`, no domain impersonation
- **Injection-immune GID detection** — `stat` returns integers; integers cannot contain shell syntax
- **No cache files** — nothing written to disk, nothing sourced back

---

## 📄 License

MIT
