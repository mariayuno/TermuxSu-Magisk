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

`txsu` never inherits the root shell's environment. Every invocation:

1. Detects Termux UID/GID via `stat` on the data directory — no hardcoding, no cache, no guessing
2. Detects `inet` GID dynamically from `/dev/socket/dnsproxyd`
3. Detects `storage` GID dynamically from `/storage`
4. Constructs a clean env from scratch: `HOME`, `PREFIX`, `ZDOTDIR`, `PATH`, `TMPDIR`, all `ANDROID_*` and `TERMUX_*` vars
5. Clears `LD_LIBRARY_PATH`, loads `libtermux-exec-ld-preload.so`
6. `exec`s into `zsh -l -i` — a proper login shell so `.zshrc` runs

---

## The four hurdles

### Hurdle 1 — Primary userspace shell & ownership

**The problem:** `su <uid>` alone gives you a wrong-environment shell. The root shell's `PATH`, `HOME`, `PREFIX`, and `LD_LIBRARY_PATH` survive the UID switch and corrupt Termux toolchain resolution. Termux binaries can't find their libraries, `zsh` fails to init, and you're left in a broken `/system/bin/sh`.

**What previous approaches did wrong:**
- Harvested env from `/proc/<pid>/environ` (attacker-controlled data fed into root shell construction)
- Sourced a writable cache file as shell code (critical RCE: Termux-controlled `passwd` → cache → `. cache` as root)
- Used `env -i $ENV_LINES` with unquoted expansion (word splitting and glob expansion on untrusted data)
- Parsed `/etc/passwd` to find the shell (unreliable, injectable)

**What `txsu` does:** constructs the environment explicitly with individually-quoted assignments, never inherits root's env, never sources external data as code. The only input is `stat` output (UID/GID integers) which cannot contain shell syntax.

```
ROOT SHELL
    │  env intentionally discarded
    ▼
su -g $TGID -G $IGID -G $SGID $TUID
    │
    ▼
/system/bin/sh -c "
    export HOME=...
    export PREFIX=...
    ...
    exec zsh -l -i
"
```

---

### Hurdle 2 — Internet

**The problem:** network access inside the shell was broken. Processes couldn't reach DNS or make connections.

**The wrong diagnosis (and why it's wrong):** the old approach claimed `fwmarkd` routes based on SELinux context, and therefore you need `runcon untrusted_app_27` to get networking. This is **incorrect**.

From AOSP `netd` source (`FwmarkServer.cpp`): `fwmarkd` selects the network via `getNetworkForConnect(client->getUid())` — it uses the **UID**, not the SELinux domain. SELinux is relevant one layer earlier: a process needs permission to connect to `/dev/socket/fwmarkd` and `/dev/socket/dnsproxyd` at all. The `netdomain` policy grants that. KernelSU's `ksu` domain already has `netdomain` in upstream KSU — so transitioning to `untrusted_app_27` for networking is solving the wrong problem.

**The actual requirement:** the process must be in the **`inet` supplementary group** (the GID of `/dev/socket/dnsproxyd`). Android's network stack requires this group membership for socket access. Without it, `connect()` fails silently or DNS is unreachable.

**What `txsu` does:** detects the `inet` GID dynamically at runtime:

```sh
IGID=$(stat -c '%g' /dev/socket/dnsproxyd)
```

and passes it via `su -G $IGID`. No SELinux domain juggling required.

---

### Hurdle 3 — Internal storage access

**The problem:** `/sdcard`, `/storage/emulated/0`, and related paths were inaccessible inside the shell.

**Root cause:** Android gates storage access on the **storage supplementary group** (the GID of `/storage`). A plain `su <uid>` drop doesn't reconstruct supplementary groups — it gives you only the primary UID/GID. The supplementary group membership that a real Android app process has from the framework/zygote is absent.

**What `txsu` does:** detects the storage GID dynamically:

```sh
SGID=$(stat -c '%g' /storage)
```

and passes it via `su -G $SGID`. Both `inet` and `storage` are added as supplementary groups alongside the primary Termux GID.

The old approach tried to fix this by writing to `/data/data/com.termux/files/usr/etc/resolv.conf` from root — mutating the user's Termux installation. That's wrong in both direction (root shouldn't touch app files) and mechanism (DNS resolution isn't the storage problem).

---

### Hurdle 4 — `sudo` / `tsu`

**The problem:** `sudo` and `tsu` inside the shell failed or behaved wrongly.

**Root cause:** two things break `sudo` inside a shell obtained via a naive `su` drop:

1. **Wrong PATH** — if the root shell's `PATH` is inherited, `sudo` finds system `su` before `tsu`, or finds nothing in `$PREFIX/bin` at all. `sudo` itself may not be found.
2. **Unset/stale `HOME` and `PREFIX`** — `sudo`'s env reset and Termux's own `sudo` wrapper both depend on these being correct. If `HOME` still points at `/root` or `PREFIX` is `(null)/usr`, `sudo` breaks its own environment reset.

**What `txsu` does:** constructs PATH explicitly, `$PREFIX/bin` first, never inherited from root:

```sh
export PATH="$PREFIX/bin:$PREFIX/bin/applets:/system/bin:/system/xbin:/system/sbin:/sbin:/sbin/bin"
```

Sets `HOME`, `PREFIX`, `ZDOTDIR` before `zsh` starts so your `.zshrc` sees correct values and `sudo`/`tsu` work normally from inside the shell.

```
txsu shell (uid=10172)
    │
    └── sudo somecommand
            │
            └── tsu / /system/bin/su → root ✅
```

---

## Requirements

- Rooted device: Magisk, KernelSU, ResuKiSU, or APatch
- Termux installed with zsh (`pkg install zsh`)
- Android 7+

---

## SELinux

Ships `sepolicy.rule` allowing the root manager domain to call `setcurrent` and transition into the Termux app domain. This is needed on devices where the root domain lacks `netdomain` permissions (some custom KSU builds, older Magisk builds).

Covered root manager domains:

| Domain | Root manager |
|---|---|
| `u:r:magisk:s0` | Magisk, APatch |
| `u:r:ksu:s0` | KernelSU, ResuKiSU |

Covered app domain types (based on Termux target SDK, not Android version):

| Type | Target SDK | Notes |
|---|---|---|
| `untrusted_app` | latest | current AOSP default |
| `untrusted_app_25` | 25–27 | |
| `untrusted_app_27` | 28+ | Termux currently targets SDK 28 — this is the active one |

> ⚠️ **Security note:** `sepolicy.rule` allows `magisk`/`ksu` to transition into *any* `untrusted_app` domain on the device, not only Termux. On a device you've already rooted, this is an acceptable trade-off — a process already in `ksu` context is already root. However it does weaken SELinux's defence-in-depth between root and app domains. Do not install this module on a device where you rely on SELinux as a meaningful security boundary.

---

## License

MIT © mariayuno
