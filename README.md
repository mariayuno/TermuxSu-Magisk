# TermuxSu-Magisk

<!-- VERSION_BADGE_START -->
<!-- VERSION_BADGE_END -->

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Magisk](https://img.shields.io/badge/Magisk-Module-blue?style=flat-square)](https://github.com/topjohnwu/Magisk)
[![KernelSU](https://img.shields.io/badge/KernelSU-Compatible-green?style=flat-square)](https://github.com/tiann/KernelSU)
[![APatch](https://img.shields.io/badge/APatch-Compatible-green?style=flat-square)](https://github.com/bmax121/APatch)

> Invoke a full [Termux](https://termux.dev) shell from any Android root shell —
> with correct UID, SELinux context, environment, `LD_PRELOAD`, and working DNS.
> Results are cached for instant subsequent loads.

---

## The Problem

When you `su` into root on Android and try to run Termux commands, things silently break:

| Issue | Cause |
|---|---|
| Wrong file ownership | Running as `root`, not `u0_a172` |
| Binaries crash / not found | `LD_PRELOAD` (termux-exec) not set |
| SELinux denials | Wrong process context (`ksu` vs `untrusted_app_27`) |
| DNS doesn't work | `/etc/resolv.conf` missing on Android 14+ / KSU |
| Wrong `HOME`, `PREFIX`, `PATH` | Environment not initialised |

`txsu` fixes all of this in one command.

---

## Install

<!-- INSTALL_ONELINER_START -->
<!-- INSTALL_ONELINER_END -->

Or download the latest `.zip` from [Releases](../../releases) and flash manually
via Magisk Manager, MMRL, or KSU WebUI.

---

## Usage

```sh
# From any root shell (adb, ssh, Magisk shell, KSU...):

txsu                        # interactive Termux shell (zsh → bash → sh)
txsu -c "pkg update -y"     # run a single command
txsu python3 script.py      # exec a Termux binary directly
txsu node server.js         # any binary in Termux's prefix

txsu --refresh              # force cache refresh, then open shell
termux                      # alias → same as txsu
```

---

## Cache

Detected values are stored at `/data/adb/txsu/cache` and reused on every call
for instant startup. The cache is automatically invalidated when:

- Termux is updated (version code changes)
- Termux is reinstalled (UID changes)
- Cache is older than 7 days
- `txsu --refresh` is run manually

---

## How It Works

```
root shell
    │
    ├─ cache hit?  ──yes──► load /data/adb/txsu/cache ──► exec
    │
    └─ cache miss ──► detect:
          ├─ UID        from /data/data/com.termux ownership (no dumpsys)
          ├─ SELinux    from /proc/<pid>/attr/current → file label → formula
          ├─ Shell      from $PREFIX/etc/passwd → live proc env → scan bin/
          ├─ LD_PRELOAD glob $PREFIX/lib/libtermux-exec*.so
          ├─ DNS        from getprop net.dns* → dhcp.*.dns* → /proc/net/pnp
          └─ write cache ──► exec
                │
                └─ Termux not found? ──► warn ──► exec su -
```

### Key details

**`LD_PRELOAD`** — Termux ships `libtermux-exec-ld-preload.so` which patches `execve()`
so Termux binaries use Termux's own dynamic linker. Without it, most compiled packages crash.

**UID resolution** — `dumpsys` fails under `u:r:ksu:s0`. UID is read from
`/data/data/com.termux` directory ownership via `stat`.

**SELinux** — context is read from the live Termux process `/proc/<pid>/attr/current`
when available; derived from the file label + SDK version otherwise.

**DNS** — Android 14+ KSU has no `/etc/resolv.conf`. Termux provides its own
at `$PREFIX/etc/resolv.conf`. `txsu` populates it from `getprop net.dns*` if empty.

---

## Files

| Path | Purpose |
|---|---|
| `/system/bin/txsu` | Main binary |
| `/system/bin/termux` | Symlink alias (created at boot) |
| `/data/adb/txsu/cache` | Runtime cache (auto-managed) |
| `service.sh` | Boot script — creates alias |
| `module.prop` | Magisk module metadata |
| `update.json` | OTA update endpoint for module managers |

---

## Compatibility

| Root solution | Status |
|---|---|
| Magisk | ✅ |
| KernelSU / ResuKiSU | ✅ Tested |
| APatch | ✅ |

Requires Android with Termux (`com.termux`) installed.

---

## License

MIT © mariayuno
