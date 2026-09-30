<div align="center">

<h1><code>$ txsu</code></h1>

<p><strong>A proper Termux shell from any root context.</strong></p>

<p>Run <code>txsu</code> from any root shell and land directly in your full configured Termux environment. Correct UID, groups, networking, storage, and shell init. No broken impostor.</p>

<br>

<!-- VERSION_BADGE_START -->
<img alt="Version" src="https://img.shields.io/badge/version-v1.7-7c3aed?style=for-the-badge&logo=github&logoColor=white">
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
| 🔧 `sudo` / `tsu` | Not found — `$PREFIX/bin` is absent from PATH because no rc file is sourced |
| 📦 PATH duplicated | Naive env-copy makes rc file append paths multiple times |
| 🐚 Wrong shell | Ignoring the user's configured shell preference |

`txsu` fixes all of this. Precisely, portably, and without SELinux hacks.

---

## ⚡ Try It Now — No Install Required

Run this in a **root shell** (ADB, a root terminal, or any root context) to try `txsu` without touching your system:

```sh
curl -fsSL https://raw.githubusercontent.com/mariayuno/TermuxSu-Magisk/main/system/bin/txsu -o /tmp/txsu && sh /tmp/txsu
```

Nothing is installed — the script is only saved to `/tmp/txsu` and run from there. If it works, pick a method below to make it permanent.

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
curl -Lo /tmp/txsu.zip https://github.com/mariayuno/TermuxSu-Magisk/releases/latest/download/TermuxSu-v1.7.zip && /data/adb/ksud module install /tmp/txsu.zip
```

**Magisk**

```sh
curl -Lo /tmp/txsu.zip https://github.com/mariayuno/TermuxSu-Magisk/releases/latest/download/TermuxSu-v1.7.zip && magisk --install-module /tmp/txsu.zip
```

**APatch**

```sh
curl -Lo /tmp/txsu.zip https://github.com/mariayuno/TermuxSu-Magisk/releases/latest/download/TermuxSu-v1.7.zip && /data/adb/apd module install /tmp/txsu.zip
```

</td>
<td valign="top" align="right" width="30%">

<p align="right">
<img alt="Version" src="https://img.shields.io/badge/v1.7-7c3aed?style=for-the-badge&logo=github&logoColor=white"><br>
<img alt="Package" src="https://img.shields.io/badge/package-TermuxSu-v1.7.zip-2563eb?style=for-the-badge&logo=files&logoColor=white"><br>
<img alt="Version Code" src="https://img.shields.io/badge/version%20code-8-0891b2?style=for-the-badge">
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

Magisk and KernelSU also support in-app auto-update via `update.json` — the module will show an update prompt when a new version is released.

### Method 3 — No-Flash Persistent Install *(no reboot needed)*

Run this in a **root shell** to drop `txsu` into `/data/adb/` without flashing anything:

```sh
curl -fsSL https://raw.githubusercontent.com/mariayuno/TermuxSu-Magisk/main/system/bin/txsu -o /data/adb/txsu && chmod 755 /data/adb/txsu
```

Then call it by full path, or add `/data/adb` to PATH:

```sh
# Run directly
/data/adb/txsu

# Or add to root shell profile
export PATH="/data/adb:$PATH"
txsu
```

> `/data/adb/` persists across reboots and persists across reboots.

---

### Aliases

The module installs several aliases alongside `txsu` — all invoke the same script:

| Command | Notes |
|---|---|
| `txsu` | canonical name |
| `txsh` | shell-flavoured alias |
| `termsu` | long-form, readable |
| `termux` | shorthand for "open Termux" |
| `trmx` | compact variant |

All land you in the same full Termux environment.

### Non-interactive use

`txsu` also accepts `-c` to run a single command and exit:

```sh
txsu -c "pkg upgrade -y"
txsu -c "python3 /data/local/myscript.py"
```

The full Termux environment (PATH, LD_PRELOAD, groups) is set up identically before the command runs.

Only a leading `-c CMD` is parsed (`-c` without an argument is an error). Any other arguments, including anything after `CMD`, are ignored, and without `-c` an interactive shell opens. If the shell exits non-zero, `txsu` prints `txsu: shell exited with status N` on stdout and exits with that status. The same happens (status 1) if the inner shell cannot `cd` into the Termux home.

---

> **Termux prerequisite:** Bash ships with Termux by default — no extra setup needed. To use a different shell, install it in Termux and run `chsh -s zsh` (or `fish`, etc.) — `txsu` reads `~/.termux/shell` to pick it up. If you've never run `chsh`, `txsu` falls back to bash. Run `chsh` from inside a `txsu` session, not from Termux directly — `txsu` wraps `chsh` to fix the SELinux context on the symlink it creates.

---

## ✅ Requirements

| Requirement | Details |
|---|---|
| Root | Magisk, KernelSU, ResuKiSU, or APatch |
| Termux | Any recent version — install from **F-Droid or GitHub**, not the Google Play Store (experimental, may have missing functionality) |
| Shell | Bash is Termux's default and works out of the box. `txsu` honours your configured shell. |
| Android | 7.0+ (F-Droid build); the experimental Google Play build requires Android 11+ |

> ⚠️ **Prefer F-Droid or GitHub.** The Google Play build is experimental. Install from [F-Droid](https://f-droid.org/en/packages/com.termux/) or [GitHub releases](https://github.com/termux/termux-app/releases).

---

## 🗺 How It Works — Full Flowchart

```
┌─────────────────────────────────────────────────────────────────┐
│      ROOT SESSION  (adb shell, root terminal, any su)           │
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
            │  ✔ libtermux-exec.so exists?   │
             ───────────────┬───────────────
                            │ all pass
                            ▼
             ──────────────────────────────────────
            │           SHELL DETECTION             │
            │                                      │
            │   ~/.termux/shell exists?            │
            │       ──yes──► use it  (user's chsh) │
            │           │                          │
            │          no                          │
            │           │                          │
            │   bash installed?  ──yes──► use bash │
            │       │            (Termux default)  │
            │      no                              │
            │       │                              │
            │   zsh installed?   ──yes──► use zsh  │
            │       │                              │
            │      no                              │
            │       │                              │
            │   die("pkg install bash")            │
            │                                      │
            │   then: resolved shell executable?   │
            │         no ──► die()                 │
             ──────────────┬───────────────────────
                           │
                           ▼
             ─────────────────────────────────────────────
            │   ZDOTDIR  (zsh only, XDG layout only)      │
            │                                             │
            │   shell is zsh?                             │
            │     AND ~/.config/zsh/ exists?              │
            │         ──yes──► export ZDOTDIR             │
            │         ──no───► skip (normal ~/.zshrc)     │
             ─────────────────────┬───────────────────────
                                  │
                    ──────────────▼──────────────
                   │   DYNAMIC GID DETECTION      │
                   │                             │
                   │  TUID = stat '%u' com.termux/│
                   │  TGID = stat '%g' com.termux/│
                   │  IGID = stat '%g'            │
                   │         /dev/socket/dnsproxyd│  ← inet group
                   │  SGID = stat '%g' /storage   │  ← storage group
                    ──────────────┬──────────────
                                  │
                    ──────────────▼──────────────
                   │       su INVOCATION          │
                   │                             │
                   │  /system/bin/su             │
                   │    -g  TGID                 │  ← primary group
                   │    -G  IGID                 │  ← +inet
                   │    -G  SGID (if available)  │  ← +storage
                   │    TUID                     │  ← UID switch
                   │    /system/bin/sh -c '...'  │
                    ──────────────┬──────────────
                                  │
                    ┌─────────────▼──────────────────────────────┐
                    │    INNER SHELL  (uid=TUID, clean env)       │
                    │                                             │
                    │  export HOME        TERMUX_HOME            │
                    │  export PREFIX      TERMUX_PREFIX          │
                    │  export ZDOTDIR     (if applicable)        │
                    │  export TERM        xterm-256color         │
                    │  export LANG        ${LANG:-en_US.UTF-8}   │
                    │                                             │
                    │  export TERMUX__*   (rootfs, home, prefix, │
                    │                      uid)                  │
                    │  export TERMUX_APP__* (pkg name, data dir) │
                    │                                             │
                    │  export ANDROID_ROOT / DATA / STORAGE      │
                    │  export ANDROID_ART_ROOT / I18N / TZDATA   │
                    │                                             │
                    │  export PATH  PREFIX/bin : applets : system│
                    │  export TMPDIR                              │
                    │  export EXTERNAL_STORAGE  /sdcard          │
                    │                                             │
                    │  unset  LD_LIBRARY_PATH                    │
                    │  export LD_PRELOAD  libtermux-exec.so      │
                    │                                             │
                    │  cd HOME      (exit 1 if it fails)          │
                    └──────────────┬──────────────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │ no -c:  exec SHELL -l -i     │
                    │   sources login + rc config  │
                    │ -c CMD: exec SHELL -c "CMD"  │
                    │   (no -l / -i passed)        │
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
                   │   PATH correct, sudo/tsu findable   │
                   │   rc loaded exactly once      │
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
| `TERMUX_EXEC` | `…/lib/libtermux-exec.so` | Termux's exec preload library (compat symlink to the active variant) |
| `TERMUX_SHELL` | detected at runtime | User's configured shell, or bash, or zsh |
| `ZDOTDIR_EXPORT` | set conditionally | Only for zsh + XDG config layout |
| `TUID` | `stat '%u' TERMUX_DATA` | Termux app UID |
| `TGID` | `stat '%g' TERMUX_DATA` | Termux app GID |
| `IGID` | `stat '%g' /dev/socket/dnsproxyd` | Android `inet` group — gates network socket access |
| `SGID` | `stat '%g' /storage` | Android storage group — gates sdcard/FUSE access *(soft failure: warns and continues without it)* |
| `TERMUX_SHELL_LINK` | `$TERMUX_HOME/.termux/shell` | Path of the user's shell preference (set by `chsh`) |
| `TXSU_CMD` | from `-c`, else empty | Command for non-interactive mode; passed to the inner shell via the environment |
| `SUPP_GROUPS` | `-G IGID [-G SGID]` | Supplementary-group arguments for `su` (intentionally left unquoted) |
| `RC` | exit status of `su` | Reported if non-zero, then returned by `txsu` |

---

### Preflight Checks

```sh
die() { echo "txsu: ERROR: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ]  || die "must run as root"
[ -d "$TERMUX_DATA" ] || die "Termux data directory not found: is Termux installed?"
[ -d "$TERMUX_HOME" ] || die "Termux home not found: open Termux at least once first"
[ -f "$TERMUX_EXEC" ] || die "libtermux-exec.so not found: run 'pkg install termux-exec' in Termux"
```

| Check | Guards against |
|---|---|
| `id -u = 0` | Running without root |
| `-d TERMUX_DATA` | Termux not installed |
| `-d TERMUX_HOME` | Termux installed but never opened — home directory not created yet |
| `-f TERMUX_EXEC` | `termux-exec` package not installed (essential but not always present) |

<details>
<summary>💡 Why check for libtermux-exec.so specifically?</summary>

Without `libtermux-exec.so` set as `LD_PRELOAD`, Termux binaries fail to execute from outside the Termux app context. The library intercepts `exec()` calls and rewrites `/bin/` and `/usr/bin/` paths to Termux's equivalents under `$PREFIX/bin/`, and handles execution restrictions introduced in Android 10+. Without it, virtually every command in the shell will fail with "not found" or "exec format error".

`libtermux-exec.so` is the backward-compatibility symlink to the active variant (`libtermux-exec-ld-preload.so`, `libtermux-exec-direct-ld-preload.so`, etc.) is correct for the current device. The script uses this symlink, not the internal variant files.

</details>

---

### Shell Detection

```sh
TERMUX_SHELL_LINK="$TERMUX_HOME/.termux/shell"
if [ -x "$TERMUX_SHELL_LINK" ]; then
    TERMUX_SHELL="$(readlink -f "$TERMUX_SHELL_LINK" 2>/dev/null || echo "$TERMUX_SHELL_LINK")"
elif [ -x "$TERMUX_PREFIX/bin/bash" ]; then
    TERMUX_SHELL="$TERMUX_PREFIX/bin/bash"
elif [ -x "$TERMUX_PREFIX/bin/zsh" ]; then
    TERMUX_SHELL="$TERMUX_PREFIX/bin/zsh"
else
    die "no usable shell found — install one: pkg install bash"
fi

[ -x "$TERMUX_SHELL" ] || die "resolved shell '$TERMUX_SHELL' is not executable"
```

```
  ~/.termux/shell exists? ──yes──► use it  (honours chsh)
         │
         no
         │
  bash installed? ──yes──► use bash  (Termux's actual default)
         │
         no
         │
  zsh installed?  ──yes──► use zsh
         │
         no
         │
  die()  ──────────────────► error + exit 1
```

<details>
<summary>💡 Why read ~/.termux/shell first, and why bash before zsh?</summary>

`~/.termux/shell` is how Termux itself stores the user's shell preference when they run `chsh`. It is a symlink pointing to the chosen shell binary. Reading it first means `txsu` respects whatever the user has already configured — the same shell their normal Termux sessions use.

**Bash is Termux's actual default**, not zsh. Termux ships with bash pre-installed; zsh is an optional package. The fallback order reflects reality: most Termux users have bash, fewer have zsh.

</details>

<details>
<summary>💡 When is ZDOTDIR set, and when is it not?</summary>

`ZDOTDIR` only matters for zsh, and only for users who store their zsh config in `~/.config/zsh/` (the XDG Base Directory layout). The check is:

```sh
case "$TERMUX_SHELL" in
    */zsh)
        if [ -d "$TERMUX_HOME/.config/zsh" ]; then
            ZDOTDIR_EXPORT="export ZDOTDIR='$TERMUX_HOME/.config/zsh'"
        fi
        ;;
esac
```

If the user is running bash: `ZDOTDIR` is irrelevant, nothing is exported.

If the user is running zsh with `~/.zshrc` in their home directory (the standard location): `~/.config/zsh/` won't exist, so `ZDOTDIR` is not set — zsh finds `.zshrc` in `HOME` exactly as it always does.

If the user is running zsh with XDG layout (`~/.config/zsh/.zshrc`): `~/.config/zsh/` exists, `ZDOTDIR` is set, zsh finds `.zshrc` correctly.

Setting `ZDOTDIR` unconditionally for all zsh users would actively break anyone with a normal `~/.zshrc` setup — zsh would look in `~/.config/zsh/` and find nothing.

</details>

---

### Dynamic GID Detection

```sh
TUID="$(stat -c '%u' "$TERMUX_DATA")" || die "cannot determine Termux UID"
TGID="$(stat -c '%g' "$TERMUX_DATA")" || die "cannot determine Termux GID"
IGID="$(stat -c '%g' /dev/socket/dnsproxyd)" || die "cannot determine inet group"
SGID="$(stat -c '%g' /storage 2>/dev/null)" \
    || { echo "txsu: warning: cannot determine storage group, continuing without it" >&2; SGID=""; }
```

```
  /data/data/com.termux  ──stat──►  TUID  (e.g. 10172)
  /data/data/com.termux  ──stat──►  TGID  (e.g. 10172)
  /dev/socket/dnsproxyd  ──stat──►  IGID  ← GID of the socket itself = inet group
  /storage               ──stat──►  SGID  ← GID of the mount point = storage group
```

<details>
<summary>💡 Why stat instead of hardcoding?</summary>

`stat -c '%u'` and `stat -c '%g'` return decimal integers. Integers cannot contain shell metacharacters — this eliminates the entire class of injection vulnerabilities that come from reading `/proc/<pid>/environ`, parsing `passwd` files, or using `pm dump`.

GIDs for `inet` and storage are read from the resource each guards (`/dev/socket/dnsproxyd` for `inet`, `/storage` mount for the storage group — means detection is always correct and self-documenting. Any other method would be guessing.

</details>

---

### The `su` Invocation

```sh
"$SU" \
    -g "$TGID" \
    $SUPP_GROUPS \
    "$TUID" \
    /system/bin/sh \
    -c "..."
```

| Flag | Value | Effect |
|---|---|---|
| `-g TGID` | Termux GID | Sets primary group to Termux's GID |
| `-G IGID` | inet GID | Adds `inet` supplementary group → network socket access |
| `-G SGID` | storage GID | Adds `storage` supplementary group → sdcard/FUSE access *(omitted with a warning if `/storage` is unavailable)* |
| `TUID` | Termux UID | Switches UID from 0 to Termux's UID |
| `/system/bin/sh -c '...'` | | Intermediate shell; sets the env explicitly before exec |

`$SUPP_GROUPS` is built dynamically and intentionally left unquoted so shell word splitting passes each `-G <gid>` pair as separate arguments. `inet` is always required and is a hard failure; `storage` is best-effort — if `/storage` is absent on the device, a warning is printed and the shell still opens without it.

<details>
<summary>💡 Why does the missing inet group break networking?</summary>

Android's `dnsproxyd` socket is `gid=<inet> mode=660`. Without the `inet` supplementary group, a process cannot open it — a plain Unix DAC (discretionary access control) failure, nothing to do with SELinux.

Without `dnsproxyd` access, `getaddrinfo()` fails. DNS resolution is broken. Every network call — `curl`, `wget`, `git`, `pip` — fails.

`netd` creates `/dev/socket/dnsproxyd` as `0660 root:inet` (from AOSP `netd.rc`). Processes without the `inet` supplementary group get `EACCES` on that socket, breaking DNS and any network call routed through `netd`.

</details>

<details>
<summary>💡 Why does the missing storage group break /sdcard?</summary>

``/sdcard` and `/storage/emulated/0` are FUSE mounts. The kernel checks supplementary group membership at open time. `txsu` adds the storage GID so those opens succeed. [Termux process, it explicitly assigns these storage groups. A bare `su <uid>` replicates none of them. The process has the right UID but still can't access external storage.

Detecting the GID via `stat -c '%g' /storage` reads it from the mount point being guarded — works across all Android versions and custom ROMs without hardcoding.

</details>

<details>
<summary>💡 Why /system/bin/sh -c as an intermediate step?</summary>

`su ... TUID /system/bin/sh -c '...'` drops privileges first, then the inner `sh -c` string sets the environment explicitly. It does not clear it: the inner shell inherits whatever `su` passes on, the variables listed below are overridden, and `LD_LIBRARY_PATH` is unset (in `-c` mode, `TXSU_CMD` reaches the inner shell this way). The `exec` at the end replaces the intermediate `sh` with the final shell process, leaving no wrapper.

</details>

<details>
<summary>💡 Why is the -c command passed through an environment variable?</summary>

The inner shell is one string handed to `/system/bin/sh -c "…"`, which treats it as program text. Pasting the user's command into that string would make `/system/bin/sh` parse it once, inside the surrounding quotes, before the Termux shell ever sees it. Embedded quotes then end the string early and backslashes are consumed: `txsu -c 'echo "two words"'` would print `two`.

So `txsu` exports the command as `TXSU_CMD` before calling `su`, and the inner string contains only the fixed text `exec SHELL -c "$TXSU_CMD"`. The command travels as data, and the Termux shell parses it exactly once, as typed.

</details>

---

### Environment Construction

Inside the inner `sh -c`, the environment is built from hardcoded known-good values before `exec`ing the shell:

**🟢 Group A — Termux Identity**

| Variable | Value |
|---|---|
| `HOME` | `/data/data/com.termux/files/home` |
| `PREFIX` | `/data/data/com.termux/files/usr` |
| `SHELL` | the resolved shell (target of `~/.termux/shell`, else the bash/zsh fallback) |
| `ZDOTDIR` | `~/.config/zsh` *(zsh + XDG layout only)* |
| `TMPDIR` | `$PREFIX/tmp` |
| `TERM` | `xterm-256color` |
| `LANG` | inherited from the calling environment if set, else `en_US.UTF-8` |

**🔵 Group B — Termux Internal Vars**

| Variable | Value |
|---|---|
| `TERMUX__ROOTFS_DIR` | `/data/data/com.termux/files` |
| `TERMUX__HOME` | `…/files/home` |
| `TERMUX__PREFIX` | `…/files/usr` |
| `TERMUX__UID` | Termux UID *(substituted directly from `stat` output — no subshell)* |
| `TERMUX_APP__PACKAGE_NAME` | `com.termux` |
| `TERMUX_APP__DATA_DIR` | `/data/data/com.termux` |

**🟠 Group C — Android System Paths**

| Variable | Value |
|---|---|
| `ANDROID_ROOT` | `/system` |
| `ANDROID_DATA` | `/data` |
| `ANDROID_STORAGE` | `/storage` |
| `ANDROID_ASSETS` | `/system/app` *(fixed value; present for env completeness)* |
| `ANDROID_ART_ROOT` | `/apex/com.android.art` |
| `ANDROID_I18N_ROOT` | `/apex/com.android.i18n` |
| `ANDROID_TZDATA_ROOT` | `/apex/com.android.tzdata` |
| `EXTERNAL_STORAGE` | `/sdcard` |

**🔴 Group D — PATH & Linker**

| Variable | Value |
|---|---|
| `PATH` | `$PREFIX/bin` → `$PREFIX/bin/applets` → `/system/bin` → `/system/xbin` → `/system/sbin` → `/sbin` → `/sbin/bin` |
| `LD_LIBRARY_PATH` | *(unset — cleared in case root session had it set)* |
| `LD_PRELOAD` | `$PREFIX/lib/libtermux-exec.so` |

**Working directory:** once the environment is set, the inner shell runs `cd "$TERMUX_HOME" || exit 1`. If that fails, no shell is started: the inner shell exits with status 1, and `txsu` prints `txsu: shell exited with status 1` and exits with 1. The preflight `-d TERMUX_HOME` check runs as root, while this `cd` runs as the Termux UID.

<details>
<summary>💡 Why is PATH only the base set — no user additions?</summary>

If the env were copied from a live Termux process, it would contain a PATH that the shell's rc file had already expanded — with npm-global, mason, `.local/bin`, etc. When the new shell then sourced its rc file, those paths would be appended again, resulting in duplicates or worse, triplicates.

By providing only a fixed base PATH (`PREFIX/bin` first, then applets and system directories) with no user additions, the shell's rc file runs once on a clean foundation, adding each custom path exactly once. This is identical to what happens when you open a normal Termux terminal.

</details>

<details>
<summary>💡 Why unset LD_LIBRARY_PATH?</summary>

On Android 7+, Termux does not set `LD_LIBRARY_PATH` by default. Some root environments may set it to point at system library paths. If that leaks into Termux's shell, the dynamic linker can pick up wrong `.so` files. Clearing it as a precaution ensures `libtermux-exec.so` operates in a clean linker environment regardless of where `txsu` was called from.

</details>

<details>
<summary>💡 Why -l -i together?</summary>

`-l` (login) causes the shell to source its login-level config: `.bash_profile` / `.zprofile`. This handles environment-level setup.

`-i` (interactive) causes the shell to source its interactive config: `.bashrc` / `.zshrc`. This sets up aliases, plugins, prompt, and PATH additions.

Together they produce the same experience as opening a native Termux terminal. Either flag alone is insufficient — without `-l`, login-level config is skipped; without `-i`, the shell may be treated as non-interactive and skip the rc file.

In `-c` mode neither flag is passed: the script runs `SHELL -c "$TXSU_CMD"`.

</details>

---

## 🔒 Security Notes

- **Only two outside inputs** — the shell path (target of `~/.termux/shell`, interpolated in single quotes and run as the Termux UID) and, with `-c`, the command string; everything else is hardcoded paths and integer `stat` output
- **No Termux data parsed or sourced** — not `passwd`, not cache files, not `/proc/<pid>/environ`; only existence/symlink checks (`~/.termux/shell`, `~/.config/zsh`, `libtermux-exec.so`) run as root before `su`
- **Environment overridden, not cleared** — the listed variables are set explicitly and `LD_LIBRARY_PATH` is unset; anything else `su` passes through is left as is
- **No SELinux domain switching** — no `runcon`, no domain impersonation
- **Injection-immune GID detection** — `stat` returns integers; integers cannot contain shell syntax
- **No cache files** — nothing written to disk, nothing sourced back

---

## 📄 License

MIT
