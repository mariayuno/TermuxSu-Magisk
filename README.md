# TermuxSu — `txsu`

Drop into a proper Termux shell from any root session (SSH, ADB, etc).

```sh
txsu
```

---

## How it works

```
ROOT ENVIRONMENT
      │
      │  intentionally NOT inherited
      ▼
  ┌───────┐
  │  txsu │
  └───┬───┘
      │  stat-based UID/GID detection
      │  inet + storage supplementary groups
      │  full Termux env constructed fresh
      ▼
  zsh -l -i  (your .zshrc, your PATH, sudo works)
```

`txsu` never inherits the root shell's environment. It:

1. Detects Termux UID/GID via `stat` on the data directory (no hardcoding, no cache)
2. Adds `inet` (network) and `storage` supplementary groups
3. Constructs a clean env: `HOME`, `PREFIX`, `ZDOTDIR`, `PATH`, `TMPDIR`, all `ANDROID_*` and `TERMUX_*` vars
4. Clears `LD_LIBRARY_PATH`, loads `libtermux-exec-ld-preload.so`
5. `exec`s into `zsh -l -i`

---

## The four hurdles solved

### 1. Primary userspace shell & ownership
`su <uid>` alone doesn't give you a Termux shell — it gives you a root-env shell with a wrong UID. `txsu` passes UID, GID, and all env vars explicitly through `su`, then `exec`s zsh as a login shell so `.zshrc` runs correctly.

### 2. Internet
Android's `netd`/`fwmarkd` selects the network based on the process UID. The shell must run with the correct **supplementary group `inet`** (GID of `/dev/socket/dnsproxyd`) for network access to be granted. `txsu` detects this GID dynamically and passes it via `-G`.

### 3. Internal storage access
`/storage` and `/sdcard` require the storage supplementary group. `txsu` detects the GID of `/storage` dynamically and passes it via `-G`.

### 4. `sudo` / `tsu`
`sudo` inside Termux breaks if `PATH` is wrong or if `HOME`/`PREFIX` are unset or stale from the root environment. `txsu` builds a clean `PATH` (`$PREFIX/bin` first, then system paths) and never inherits the root shell's `PATH`, so `sudo` and `tsu` work correctly from inside the shell.

---

## Requirements

- Rooted device: Magisk, KernelSU, ResuKiSU, or APatch
- Termux installed with zsh (`pkg install zsh`)
- Android 7+

---

## SELinux

Ships `sepolicy.rule` allowing the root manager domain to call `setcurrent` and transition into the Termux app domain. Required on some devices for correct SELinux context matching.

Covered domains: `magisk` (Magisk, APatch), `ksu` (KernelSU, ResuKiSU)
Covered types: `untrusted_app`, `untrusted_app_25`, `untrusted_app_27`

> ⚠️ This allows `magisk`/`ksu` to transition into any `untrusted_app` domain, not only Termux. Acceptable trade-off on a rooted device, but weakens SELinux defence-in-depth.

---

## License

MIT © mariayuno
