# TermuxSu-Magisk

> Invoke a full [Termux](https://termux.dev) shell from any Android root shell —  
> with correct UID, SELinux context, environment, `LD_PRELOAD`, and working DNS.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Magisk](https://img.shields.io/badge/Magisk-Module-blue)](https://github.com/topjohnwu/Magisk)
[![KernelSU](https://img.shields.io/badge/KernelSU-Compatible-green)](https://github.com/tiann/KernelSU)
[![APatch](https://img.shields.io/badge/APatch-Compatible-green)](https://github.com/bmax121/APatch)

## The Problem

When you `su` into root on Android and try to run Termux commands, things silently break:

| Issue | Cause |
|---|---|
| Wrong file ownership | Running as `root`, not `u0_a172` |
| Binaries crash / not found | `LD_PRELOAD` (termux-exec) not set |
| SELinux denials | Wrong process context (`ksu` vs `untrusted_app_27`) |
| DNS doesn't work | `/etc/resolv.conf` missing on Android 14+ / KSU |
| Wrong `HOME`, `PREFIX`, `PATH` | Environment not set up |

`txsu` fixes all of this in one command.

## Install

1. Download the latest `.zip` from [Releases](../../releases)
2. Flash via **Magisk Manager**, **MMRL**, or **KSU WebUI**
3. Reboot

## Usage

```sh
# From any root shell (adb, ssh, Magisk shell, KSU...):

txsu                        # interactive Termux shell (zsh → bash → sh)
txsu -c "pkg update -y"     # run a single command
txsu python3 script.py      # exec a Termux binary directly
txsu node server.js         # same — any binary in Termux's prefix

termux                      # alias → same as txsu
```

## How It Works

```
root shell
    │
    ├─ resolve UID from /data/data/com.termux ownership  (dumpsys broken under KSU)
    ├─ build SELinux context: u:r:untrusted_app_27:s0:c{uid-10000},c256,c512,c768
    ├─ guard Termux resolv.conf (fallback: 8.8.8.8 / 1.1.1.1)
    │
    └─ runcon <selinux_ctx>
           └─ su <termux_uid>
                  └─ env -i  HOME PREFIX PATH LD_LIBRARY_PATH LD_PRELOAD ...
                         └─ zsh --login   (or bash, or direct binary)
```

### Key detail — `LD_PRELOAD`

Termux ships `libtermux-exec-ld-preload.so` which patches `execve()` so that  
Termux binaries use Termux's own dynamic linker instead of Android's.  
Without it, most compiled Termux packages crash immediately. `txsu` sets it.

### Key detail — UID resolution

`dumpsys package com.termux | grep userId=` fails under `u:r:ksu:s0` context.  
`txsu` reads the UID directly from `/data/data/com.termux` directory ownership via `ls -lnd` — no `dumpsys` needed.

### Key detail — DNS

Android 14+ KSU root has no `/etc/resolv.conf`.  
Termux provides its own at `$PREFIX/etc/resolv.conf` (`nameserver 8.8.8.8`).  
`txsu` verifies it exists and writes a fallback if not.

## Files

| Path | Purpose |
|---|---|
| `/system/bin/txsu` | Main binary |
| `/system/bin/termux` | Symlink alias (created at boot) |
| `service.sh` | Boot script that creates the alias |
| `module.prop` | Magisk module metadata |

## Compatibility

| Root solution | Status |
|---|---|
| Magisk | ✅ Tested |
| KernelSU / ResuKiSU | ✅ Tested |
| APatch | ✅ Should work |

## Requirements

- Android with Magisk, KernelSU, or APatch
- [Termux](https://f-droid.org/packages/com.termux/) installed (`com.termux`)

## License

MIT © mariayuno
