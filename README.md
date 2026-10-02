<div align="center">

<h1><code>$ txsu</code></h1>

<p><strong>A proper Termux shell from any root context.</strong></p>

<p>Run <code>txsu</code> from any root shell and land directly in your full configured Termux environment. Correct UID, groups, networking, storage, and shell init. No broken impostor.</p>

<br>

<!-- VERSION_BADGE_START -->
<img alt="Version" src="https://img.shields.io/badge/version-v2.4-7c3aed?style=for-the-badge&logo=github&logoColor=white">
<!-- VERSION_BADGE_END -->
&nbsp;
<img alt="License" src="https://img.shields.io/badge/license-MIT-00bfff?style=for-the-badge&labelColor=0d1117">
&nbsp;
<img alt="Root" src="https://img.shields.io/badge/root-Magisk%20%7C%20KSU%20%7C%20APatch-ff6b6b?style=for-the-badge&labelColor=0d1117">
&nbsp;
<img alt="Shell" src="https://img.shields.io/badge/shell-bash%20%7C%20zsh%20%7C%20any-f7c948?style=for-the-badge&labelColor=0d1117&logo=gnubash&logoColor=f7c948">
&nbsp;
<img alt="Android" src="https://img.shields.io/badge/android-rooted-3ddc84?style=for-the-badge&labelColor=0d1117&logo=android&logoColor=3ddc84">

<br><br>

by <a href="https://mariayuno.neocities.org/"><strong>Maria Yuno</strong></a> &nbsp;·&nbsp; <a href="mailto:mariayuno001@proton.me"><code>mariayuno001@proton.me</code></a>

</div>

---

## 📋 Table of Contents

- [The Problem](#-the-problem)
- [Try It Now](#-try-it-now--no-install-required)
- [Install](#-install)
- [Requirements](#-requirements)
- [How It Works — Full Flowchart](#-how-it-works--full-flowchart)
- [Script Walkthrough](#-script-walkthrough)
  - [Variables Declared](#variables-declared)
  - [Preflight Checks](#preflight-checks)
  - [Shell Detection](#shell-detection)
  - [Dynamic GID Detection](#dynamic-gid-detection)
  - [The su Invocation](#the-su-invocation)
  - [Environment Construction](#environment-construction)
- [Security Notes](#-security-notes)

---

## 🔥 The Problem

When you `su` to your Termux UID from a root session, you don't get a Termux shell.
You get a **broken impostor** that looks like one.

| What breaks | Why |
|---|---|
| 🌐 Networking | Missing `inet` supplementary group — can't open `dnsproxyd` socket |
| 💾 `/sdcard` access | Missing `storage` supplementary group — FUSE denies access |
| 🔧 `sudo` / `tsu` | `$PREFIX/bin` is absent from PATH because no rc file is sourced |
| 📦 PATH duplicated | Naive env-copy makes rc file append paths multiple times |
| 🐚 Wrong shell | Ignoring the user's configured shell preference |
| 🏷 Wrong SELinux label | Files created get root's label, not the app's — unreadable by native Termux |

`txsu` fixes all of this precisely and portably.

---

## ✅ Requirements

| Requirement | How to satisfy |
|---|---|
| Rooted Android | Magisk, KernelSU, ResuKiSU, or APatch |
| `/system/bin/su` | Provided automatically by any root implementation above |
| Termux | Install from **F-Droid or GitHub**, then **open it once** to bootstrap (`bash`, `termux-exec`, and the base filesystem are set up on first launch) |
| `clang` | Run `pkg install clang` inside Termux — required to build the SELinux preload library; **txsu refuses to launch without it** |

> ⚠️ **Prefer F-Droid or GitHub.** The Google Play build is experimental. Install from [F-Droid](https://f-droid.org/en/packages/com.termux/) or [GitHub releases](https://github.com/termux/termux-app/releases).

---

## 🗺 How It Works — Full Flo

---

## ⚡ Try It Now — No Install Required

Run this in a **root shell** to try `txsu` without touching your system:

```sh
curl -fsSL https://raw.githubusercontent.com/mariayuno/TermuxSu-Magisk/main/system/bin/txsu -o /tmp/txsu && sh /tmp/txsu
```

The script is only saved to `/tmp/txsu` and run from there. If it works, pick a method below to make it permanent.

---

## 📦 Install

<!-- INSTALL_ONELINER_START -->
<table>
<tr>
<td valign="top" width="70%">

### One-liner — Flash from root shell *(recommended)*

> Downloads the latest release zip and installs it in one command. Run in a root shell.

**KernelSU / ResuKiSU**

```sh
curl -Lo /tmp/txsu.zip https://github.com/mariayuno/TermuxSu-Magisk/releases/latest/download/TermuxSu-v2.4.zip && /data/adb/ksud module install /tmp/txsu.zip
```

**Magisk**

```sh
curl -Lo /tmp/txsu.zip https://github.com/mariayuno/TermuxSu-Magisk/releases/latest/download/TermuxSu-v2.4.zip && magisk --install-module /tmp/txsu.zip
```

**APatch**

```sh
curl -Lo /tmp/txsu.zip https://github.com/mariayuno/TermuxSu-Magisk/releases/latest/download/TermuxSu-v2.4.zip && /data/adb/apd module install /tmp/txsu.zip
```

</td>
<td valign="top" align="right" width="30%">

<p align="right">
<img alt="Version" src="https://img.shields.io/badge/v2.4-7c3aed?style=for-the-badge&logo=github&logoColor=white"><br>
<img alt="Package" src="https://img.shields.io/badge/package-TermuxSu-v2.4.zip-2563eb?style=for-the-badge&logo=files&logoColor=white"><br>
<img alt="Version Code" src="https://img.shields.io/badge/version%20code-15-0891b2?style=for-the-badge">
</p>

</td>
</tr>
</table>

<!-- INSTALL_ONELINER_END -->

### Method 2 — Flash from Manager UI

Download the zip from [Releases](https://github.com/mariayuno/TermuxSu-Magisk/releases/latest) and flash it:

> **Magisk:** Magisk app → Modules tab → ➕ Install from storage → select zip → Reboot
>
> **KernelSU / APatch:** same flow inside their respective manager apps

Magisk and KernelSU also support in-app auto-update via `update.json`.

### Method 3 — No-Flash Persistent Install *(no reboot needed)*

```sh
curl -fsSL https://raw.githubusercontent.com/mariayuno/TermuxSu-Magisk/main/system/bin/txsu -o /data/adb/txsu && chmod 755 /data/adb/txsu
```

Then call it by full path, or add `/data/adb` to PATH.

> `/data/adb/` persists across reboots.

---

### Aliases

| Command | Notes |
|---|---|
| `txsu` | canonical name |
| `txsh` | shell-flavoured alias |
| `termsu` | long-form, readable |
| `termux` | shorthand for "open Termux" |
| `trmx` | compact variant |

### Non-interactive use

```sh
txsu -c "pkg upgrade -y"
txsu -c "python3 /data/local/myscript.py"
```

Only a leading `-c CMD` is parsed. `-c` without an argument is an error. Extra arguments after `CMD` are ignored. `TXSU_CMD` is exported before calling `su` so it crosses the exec boundary as an environment variable rather than being interpolated into the inner shell string.

---

> **Termux prerequisite:** Bash ships with Termux by default. To use a different shell, install it in Termux and run `chsh -s zsh` — `txsu` reads `~/.termux/shell` to pick it up. If you've never run `chsh`, `txsu` falls back to bash then zsh.

---

wchart

```
┌─────────────────────────────────────────────────────────────────┐
│      ROOT SESSION  (adb shell, root terminal, any su)           │
│                    uid=0  ·  u:r:ksu:s0                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │   run: txsu    │
                    └───────┬────────┘
                            │
             ───────────────▼───────────────
            │        PREFLIGHT CHECKS        │
            │  ✔ running as root?            │
            │  ✔ /data/data/com.termux ?     │
            │  ✔ Termux home exists?         │
            │  ✔ Termux prefix exists?       │
            │  ✔ libtermux-exec.so exists?   │
             ───────────────┬───────────────
                            │ all pass
                            ▼
             ──────────────────────────────────────
            │           SHELL DETECTION             │
            │                                      │
            │   ~/.termux/shell exists?            │
            │       ──yes──► use it  (user chsh)   │
            │           │                          │
            │          no                          │
            │           │                          │
            │   zsh installed?   ──yes──► use zsh  │
            │       │                              │
            │      no                              │
            │       │                              │
            │   bash installed?  ──yes──► use bash │
            │       │                              │
            │      no ──► die()                    │
            │                                      │
            │   resolved shell executable? ──no──► die()
             ──────────────┬───────────────────────
                           │
                           ▼
             ──────────────────────────────────────
            │   ZDOTDIR  (zsh only, XDG only)      │
            │                                      │
            │   shell = */zsh?                     │
            │     AND ~/.config/zsh/ exists?        │
            │       ──yes──► ZDOTDIR_EXPORT set    │
            │       ──no───► ZDOTDIR_EXPORT=""     │
             ──────────────┬───────────────────────
                           │
                           ▼
             ──────────────────────────────────────
            │   DYNAMIC UID / GID DETECTION        │
            │                                      │
            │  TUID  = stat '%u' com.termux/       │
            │  TGID  = stat '%g' com.termux/       │
            │  IGID  = stat '%g' /dev/socket/dnsproxyd  ← inet
            │  SGID  = stat '%g' /storage          │  ← storage (soft)
            │                                      │
            │  TERMUX_HOME_CTX = stat '%C' HOME    │  ← SELinux ctx
             ──────────────┬───────────────────────
                           │
                           ▼
             ──────────────────────────────────────
            │   BUILD SELINUX PRELOAD LIBRARY      │
            │                                      │
            │  libtxsu-fscreate.so exists?         │
            │    ──yes──► skip build               │
            │    ──no───► find clang/cc            │
            │               not found?             │
            │                 ──► !! DANGER die !! │
            │               found ──► compile .so  │
            │                        chown TUID    │
            │                        chcon CTX     │
            │                        chmod 755     │
             ──────────────┬───────────────────────
                           │
                           ▼
                   ────────────────────
                  │   su INVOCATION    │
                  │                   │
                  │  /system/bin/su   │
                  │    -g  TGID       │  ← primary group
                  │    -G  IGID       │  ← +inet
                  │    -G  SGID       │  ← +storage (if available)
                  │    TUID           │  ← UID switch
                  │    /system/bin/sh │
                  │    -c INNER       │  ← positional args
                   ────────┬──────────
                           │
              ┌────────────▼───────────────────────────────┐
              │    INNER SHELL  (uid=TUID)                  │
              │                                             │
              │  receive positional args:                   │
              │    $1 TERMUX_HOME   $2 TERMUX_PREFIX        │
              │    $3 TERMUX_FILES  $4 TERMUX_DATA          │
              │    $5 TERMUX_SHELL  $6 TERMUX_EXEC          │
              │    $7 TERMUX_FSCTX  $8 TXSU_LIB             │
              │    $9 TXSU_CMD                              │
              │                                             │
              │  export HOME / PREFIX / SHELL / ZDOTDIR    │
              │  export TERM / LANG                        │
              │  export TERMUX__* / TERMUX_APP__*          │
              │  export ANDROID_* / EXTERNAL_STORAGE       │
              │  export PATH (7-entry fixed set)           │
              │  export TMPDIR                             │
              │  unset  LD_LIBRARY_PATH                    │
              │  export TXSU_FSCREATE = TERMUX_FSCTX       │
              │  export LD_PRELOAD = libtxsu-fscreate.so   │
              │                    : libtermux-exec.so     │
              │                                             │
              │  cd TERMUX_HOME  || exit 1                 │
              └────────────┬───────────────────────────────┘
                           │
                           ▼
              ┌────────────────────────────────┐
              │  exec SHELL -l -i              │  ← interactive
              │  exec SHELL -c "$TXSU_CMD"     │  ← -c mode
              └────────────┬───────────────────┘
                           │
           ┌───────────────▼────────────────────────────────┐
           │  every dynamically linked child process        │
           │                                                │
           │  dynamic loader                                │
           │    ├── libtxsu-fscreate.so  (constructor)     │
           │    │       reads TXSU_FSCREATE env var         │
           │    │       writes to /proc/self/attr/fscreate  │
           │    │       ──► ALL new files get:              │
           │    │           u:object_r:app_data_file:s0     │
           │    │           :c<A>,c<B>,c<C>,c<D>  (dynamic)│
           │    └── libtermux-exec.so  (Termux exec fix)   │
           └────────────────────────────────────────────────┘
                           │
            ───────────────▼───────────────
           │                               │
           │   ✅  FULL TERMUX SHELL        │
           │                               │
           │   uid = Termux UID            │
           │   groups: Termux + inet +     │
           │           storage             │
           │   internet ✔                  │
           │   /sdcard  ✔                  │
           │   PATH correct ✔              │
           │   rc loaded once ✔            │
           │   new files: correct label ✔  │
            ───────────────────────────────
```

---

## 🔬 Script Walkthrough

### Variables Declared

| Variable | Value | Purpose |
|---|---|---|
| `SU` | `/system/bin/su` | Path to the system `su` binary; expected present on all rooted devices |
| `TERMUX_DATA` | `/data/data/com.termux` | Termux app data root |
| `TERMUX_FILES` | `…/files` | Termux files dir |
| `TERMUX_PREFIX` | `…/files/usr` | Termux package prefix (`$PREFIX`) |
| `TERMUX_HOME` | `…/files/home` | Termux home directory (`$HOME`) |
| `TERMUX_EXEC` | `…/lib/libtermux-exec.so` | Termux exec preload library (compat symlink to active variant) |
| `TXSU_LIB` | `…/lib/libtxsu-fscreate.so` | SELinux fscreate preload library (built by txsu if absent) |
| `TXSU_SRC` | `…/tmp/txsu-fscreate.c` | Temporary C source; removed after compilation |
| `TERMUX_SHELL_LINK` | `$TERMUX_HOME/.termux/shell` | User's shell preference symlink (written by `chsh`) |
| `TERMUX_SHELL` | detected at runtime | Resolved shell binary path |
| `ZDOTDIR_EXPORT` | `~/.config/zsh` or empty | Set only for zsh + XDG layout |
| `TUID` | `stat '%u' TERMUX_DATA` | Termux app UID |
| `TGID` | `stat '%g' TERMUX_DATA` | Termux app GID |
| `IGID` | `stat '%g' /dev/socket/dnsproxyd` | `inet` group — gates network socket access |
| `SGID` | `stat '%g' /storage` | storage group — gates sdcard/FUSE access *(soft: skipped with warning if absent)* *(soft: skipped with warning if absent, continuing without it)* |
| `TERMUX_HOME_CTX` | `stat '%C' TERMUX_HOME` | Full SELinux context including MCS categories of Termux HOME (e.g. `u:object_r:app_data_file:s0:c172,…`) |
| `SUPP_GROUPS` | `-G IGID [-G SGID]` | Supplementary-group args for `su` (intentionally unquoted for word-splitting) |
| `TXSU_CMD` | from `-c`, else empty | Command for non-interactive mode |
| `RC` | exit status of `su` | Printed if non-zero; returned by `txsu` |

---

### Preflight Checks

```sh
die() { echo "txsu: ERROR: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ]    || die "must run as root"
[ -x "$SU" ]          || die "su not found: $SU"
[ -d "$TERMUX_DATA" ] || die "Termux data directory not found"
[ -d "$TERMUX_HOME" ] || die "Termux HOME not found"
[ -d "$TERMUX_PREFIX" ] || die "Termux PREFIX not found"
[ -f "$TERMUX_EXEC" ] || die "libtermux-exec.so not found"
```

| Check | Guards against |
|---|---|
| `id -u = 0` | Running without root |
| `-x $SU` | Missing su binary |
| `-d TERMUX_DATA` | Termux not installed |
| `-d TERMUX_HOME` | Termux installed but never opened |
| `-d TERMUX_PREFIX` | Corrupt Termux install |
| `-f TERMUX_EXEC` | `termux-exec` not installed |

<details>
<summary>💡 Why check for libtermux-exec.so?</summary>

Without `libtermux-exec.so` as `LD_PRELOAD`, Termux binaries fail to execute outside the Termux app context on Android 10+. The library intercepts `execve()` and rewrites paths so Android's linker finds them under `$PREFIX/bin/`. `libtermux-exec.so` is a backward-compatibility symlink to the active variant (`libtermux-exec-ld-preload.so` or `libtermux-exec-direct-ld-preload.so` depending on Android version).

</details>

---

### Shell Detection

```sh
if [ -x "$TERMUX_SHELL_LINK" ]; then
    TERMUX_SHELL="$(readlink -f "$TERMUX_SHELL_LINK" 2>/dev/null || true)"
elif [ -x "$TERMUX_PREFIX/bin/zsh" ]; then
    TERMUX_SHELL="$TERMUX_PREFIX/bin/zsh"
elif [ -x "$TERMUX_PREFIX/bin/bash" ]; then
    TERMUX_SHELL="$TERMUX_PREFIX/bin/bash"
else
    die "no usable Termux shell found"
fi
[ -x "$TERMUX_SHELL" ] || die "shell is not executable: $TERMUX_SHELL"
```

```
  ~/.termux/shell exists? ──yes──► use it  (honours chsh)
         │
         no
         │
  zsh installed?  ──yes──► use zsh
         │
         no
         │
  bash installed? ──yes──► use bash
         │
         no ──► die()
         │
  resolved path executable? ──no──► die()
```

<details>
<summary>💡 Why ~/.termux/shell first?</summary>

`~/.termux/shell` is a symlink written by `chsh` pointing to the user's chosen shell. Reading it first means `txsu` uses exactly the same shell as native Termux sessions. The `readlink -f` resolves the symlink to an absolute path so `exec` receives a real binary, not a dangling link.

</details>

<details>
<summary>💡 ZDOTDIR — when is it set?</summary>

Only for zsh, and only when `~/.config/zsh/` exists (XDG layout). Setting it unconditionally would break users with `~/.zshrc` in their home directory — zsh would look in `~/.config/zsh/` and find nothing. Users on standard layout get nothing set; zsh finds `.zshrc` in `$HOME` as normal.

</details>

---

### Dynamic UID / GID Detection

```sh
TUID="$(stat -c '%u' "$TERMUX_DATA")"     || die "cannot determine Termux UID"
TGID="$(stat -c '%g' "$TERMUX_DATA")"     || die "cannot determine Termux GID"
IGID="$(stat -c '%g' /dev/socket/dnsproxyd 2>/dev/null || true)"
SGID="$(stat -c '%g' /storage 2>/dev/null || true)"
TERMUX_HOME_CTX="$(stat -c '%C' "$TERMUX_HOME")" || die "cannot determine SELinux context"
```

```
  /data/data/com.termux       ──stat '%u'──►  TUID
  /data/data/com.termux       ──stat '%g'──►  TGID
  /dev/socket/dnsproxyd       ──stat '%g'──►  IGID  (inet group)
  /storage                    ──stat '%g'──►  SGID  (storage group, soft)
  /data/data/com.termux/files/home  ──stat '%C'──►  TERMUX_HOME_CTX
```

<details>
<summary>💡 Why stat instead of hardcoding?</summary>

`stat -c '%u'` and `stat -c '%g'` return decimal integers — they cannot contain shell metacharacters. This eliminates injection vulnerabilities entirely. GIDs are read from the resource each guards: `dnsproxyd` for inet, `/storage` for the storage group. Always correct, always self-documenting.

</details>

<details>
<summary>💡 Why is inet a soft failure (warning only) like storage — the shell still opens, but networking will be broken but storage is not?</summary>

Without `inet`, DNS is broken and every network call fails. That's an unusable shell.

Without `storage`, `/sdcard` is inaccessible but the shell itself and everything under `$PREFIX` still works fine. Worth a warning, not a hard abort.

</details>

---

### Build SELinux Preload Library

```sh
build_preload() {
    [ -f "$TXSU_LIB" ] && return 0        # already built — skip

    # find clang or cc in Termux prefix
    # NOT FOUND → scary die()

    # compile libtxsu-fscreate.so
    # constructor reads TXSU_FSCREATE env var on every execve()
    # and writes it to /proc/self/attr/fscreate

    chown "$TUID:$TGID" "$TXSU_LIB" || die  # must not be root-owned
    chcon "$TERMUX_HOME_CTX" "$TXSU_LIB"    # correct SELinux label
    chmod 755 "$TXSU_LIB"
}
```

<details>
<summary>💡 Why a preload library instead of writing fscreate directly?</summary>

`/proc/self/attr/fscreate` is per-process and **resets to empty across `execve()`**. Writing it in the outer shell before calling `su` does nothing — it's reset the moment `su` exec's. Writing it in the inner `/system/bin/sh` does nothing — it resets again when the final shell is exec'd. And once privileges are dropped to `TUID`, the process no longer has `CAP_MAC_ADMIN` to write it at all.

The preload library solves this: its constructor runs inside the dynamic loader of every `execve()` call that inherits `LD_PRELOAD`, **before** `main()`. It reads `TXSU_FSCREATE` from the environment (which survives `execve()`) and writes to `/proc/self/attr/fscreate` in the new process, before any file is created.

```
execve("touch")
   │
   ▼
dynamic loader
   ├── libtxsu-fscreate.so  constructor()
   │       reads TXSU_FSCREATE
   │       writes /proc/self/attr/fscreate   ◄── set BEFORE main()
   └── touch
           creates file  ──► correct label ✔
```

</details>

<details>
<summary>💡 Why must the library not be root-owned?</summary>

If `libtxsu-fscreate.so` were owned by root and had the wrong SELinux label, loading it would itself fail under the app's SELinux policy, or worse — the wrong ownership would cause every file written through it to inherit wrong metadata. The `chown` to `TUID:TGID` and `chcon` to `TERMUX_HOME_CTX` are not optional hygiene, they are correctness requirements. If `chown` fails, `txsu` aborts.

</details>

<details>
<summary>⚠️ What happens if clang is not installed?</summary>

```
╔══════════════════════════════════════════════════════╗
║               !! DANGER — DO NOT IGNORE !!           ║
╠══════════════════════════════════════════════════════╣
║  clang is not installed in Termux.                   ║
║                                                      ║
║  Without it, txsu cannot build the SELinux context   ║
║  bridge. Running without it means EVERY FILE you     ║
║  create in this shell will have the WRONG SELinux    ║
║  label and will be UNREADABLE by native Termux.      ║
║                                                      ║
║  Fix: open Termux and run:                           ║
║       pkg install clang                              ║
║  Then retry txsu.                                    ║
╚══════════════════════════════════════════════════════╝
```

`txsu` refuses to launch. There is no degraded mode — a shell without the SELinux fix silently corrupts your Termux file labels.

</details>

---

### The `su` Invocation

```sh
"$SU" \
    -g "$TGID" \
    $SUPP_GROUPS \
    "$TUID" \
    /system/bin/sh \
    -c "$INNER" \
    txsu \
    "$TERMUX_HOME" "$TERMUX_PREFIX" "$TERMUX_FILES" "$TERMUX_DATA" \
    "$TERMUX_SHELL" "$TERMUX_EXEC" "$TERMUX_HOME_CTX" "$TXSU_LIB" \
    "$TXSU_CMD"
```

| Argument | Value | Effect |
|---|---|---|
| `-g TGID` | Termux GID | Primary group |
| `-G IGID` | inet GID | Supplementary: network socket access |
| `-G SGID` | storage GID | Supplementary: sdcard/FUSE access *(omitted if unavailable)* *(soft: omitted with a warning if `/storage` unavailable)* |
| `TUID` | Termux UID | UID switch from 0 |
| `/system/bin/sh -c INNER` | inner script | Intermediate shell that sets env before exec |
| `txsu … $9` | positional args | All dynamic values passed as data, not embedded in the script string |

All dynamic values are passed as positional arguments `$1`–`$9`. Nothing is interpolated into the `$INNER` script string itself — which means no quoting issues regardless of what those values contain.

`$SUPP_GROUPS` is intentionally left unquoted so shell word-splitting passes each `-G <gid>` pair as separate arguments to `su`.

---

### Environment Construction

Inside the inner `sh -c`, positional args are unpacked and the environment is built before `exec`:

**🟢 Group A — Termux Identity**

| Variable | Value |
|---|---|
| `HOME` | `$TERMUX_HOME` |
| `PREFIX` | `$TERMUX_PREFIX` |
| `SHELL` | resolved shell binary |
| `ZDOTDIR` | `~/.config/zsh` *(zsh + XDG only)* |  *(passed via `TXSU_ZDOTDIR` environment variable)*
| `TMPDIR` | `$PREFIX/tmp` |
| `TERM` | `xterm-256color` |
| `LANG` | inherited if set, else `en_US.UTF-8` (`${LANG:-en_US.UTF-8}`) |

**🔵 Group B — Termux Internal**

| Variable | Value |
|---|---|
| `TERMUX__ROOTFS_DIR` | `$TERMUX_FILES` |
| `TERMUX__HOME` | `$TERMUX_HOME` |
| `TERMUX__PREFIX` | `$TERMUX_PREFIX` |
| `TERMUX__UID` | `$(id -u)` *(inside inner shell, already TUID)* |
| `TERMUX_APP__PACKAGE_NAME` | `com.termux` |
| `TERMUX_APP__DATA_DIR` | `$TERMUX_DATA` |

**🟠 Group C — Android System Paths**

| Variable | Value |
|---|---|
| `ANDROID_ROOT` | `/system` |
| `ANDROID_DATA` | `/data` |
| `ANDROID_STORAGE` | `/storage` |
| `ANDROID_ASSETS` | `/system/app` |
| `ANDROID_ART_ROOT` | `/apex/com.android.art` |
| `ANDROID_I18N_ROOT` | `/apex/com.android.i18n` |
| `ANDROID_TZDATA_ROOT` | `/apex/com.android.tzdata` |
| `EXTERNAL_STORAGE` | `/sdcard` |

**🔴 Group D — PATH & Linker**

| Variable | Value |
|---|---|
| `PATH` | `$PREFIX/bin` → `$PREFIX/bin/applets` → `/system/bin` → `/system/xbin` → `/system/sbin` → `/sbin` → `/sbin/bin` |
| `LD_LIBRARY_PATH` | *(unset)* |
| `TXSU_FSCREATE` | `$TERMUX_HOME_CTX` — SELinux context passed to preload library |
| `LD_PRELOAD` | `libtxsu-fscreate.so:libtermux-exec.so` |

**Working directory:** `cd "$TERMUX_HOME" || exit 1` — if this fails, `txsu` prints `txsu: shell exited with status 1` and exits.

<details>
<summary>💡 Why pass everything as positional args?</summary>

The inner script is a single string passed to `/system/bin/sh -c "..."`. Any variable interpolated directly into that string would be parsed by the outer shell before `su` ever runs — embedded quotes, spaces and special characters would corrupt the script. Positional arguments cross the `su` boundary as data. The inner shell unpacks them cleanly with `VAR="$1"` regardless of their content.

</details>

<details>
<summary>💡 Why -l -i for the final shell?</summary>

`-l` sources login config (`.bash_profile` / `.zprofile`). `-i` sources interactive config (`.bashrc` / `.zshrc`). Together they produce the same experience as opening a native Termux terminal. In `-c` mode neither flag is passed — `exec SHELL -c "$TXSU_CMD"` only.

</details>

<details>
<summary>💡 Why unset LD_LIBRARY_PATH?</summary>

Some root environments set `LD_LIBRARY_PATH` to system library paths. If that leaks into the Termux shell, the dynamic linker can pick up wrong `.so` files. Clearing it ensures the linker uses its standard search path.

</details>

---

## 🔒 Security Notes

- **Inputs:** only two external inputs — the shell symlink target and, with `-c`, the command string. Everything else is hardcoded paths and integer `stat` output
- **No data sourced** — not `passwd`, not cache files, not `/proc/<pid>/environ`; only existence/symlink checks run as root
- **Environment overridden, not cleared** — variables are set explicitly; `LD_LIBRARY_PATH` is unset; anything else `su` passes through is left as-is
- **No SELinux domain switching** — process stays `u:r:ksu:s0`; only file-create context is set via `fscreate`, making new files indistinguishable from those created by native Termux
- **Injection-immune GID detection** — `stat` returns integers; integers cannot contain shell syntax
- **Preload library integrity** — `chown` to Termux UID and `chcon` to Termux's SELinux context are verified before launch; root-owned preload is rejected

---

## 📄 License

MIT
