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

## Hurdle 1 — Primary userspace shell & ownership

This was the foundational problem. Getting a shell that actually *is* Termux — right UID, right groups, right env, right toolchain — from a root session.

### What Android actually does when Termux starts

When the Android framework launches Termux normally, it goes through Zygote:

```
Android Framework (ActivityManager)
         │
         │  fork request with full credential spec
         ▼
      Zygote
         │
         ├── UID  = 10172  (u0_a172)
         ├── GID  = 10172
         ├── supplementary groups = [ inet, sdcard_rw, ... ]
         ├── SELinux domain = untrusted_app_27
         ├── capabilities stripped
         ├── secureexec
         └── env = framework-initialized
         │
         ▼
   com.termux process
         │
         ▼
   Termux terminal service
         │
         ▼
   pty → zsh (inside PREFIX)
```

A root bridge has to approximate this from nothing, using only `su`.

---

### What the old approach did (and why it failed)

```
root shell (u:r:ksu:s0)
      │
      ├─► read /proc/<pid>/environ   ← ① untrusted Termux process data
      │         │
      │         ▼
      │   ENV_LINES="HOME=...\nPREFIX=..."
      │         │
      │         ▼
      │   /system/bin/env -i $ENV_LINES   ← ② unquoted expansion
      │         │ word splitting / glob expansion on untrusted data
      │         ▼
      │   read $PREFIX/etc/passwd    ← ③ Termux-writable file
      │         │
      │         ▼
      │   TERMUX_SHELL=<shell path>
      │         │
      │         ▼
      │   cache_write() →  TERMUX_SHELL=${TERMUX_SHELL}  ← ④ unquoted
      │         │
      │         ▼
      │   /data/adb/txsu/cache
      │         │
      │         ▼  . "$CACHE_FILE"   ← ⑤ sourced as root shell code  🔴 RCE
      │
      ├─► runcon "$SELINUX_CTX" /system/bin/true  ← ⑥ weak probe
      │         │ proves only `true` works, not the full chain
      │         ▼
      │   runcon → su $UID → env -i → shell   ← ⑦ order wrong
      │
      └─► su "$TERMUX_UID"   ← ⑧ no GID, no supplementary groups
```

**Failures at each numbered step:**

| # | Problem | Impact |
|---|---|---|
| ① | `/proc/<pid>/environ` is attacker-controlled data | root reads untrusted input |
| ② | `$ENV_LINES` unquoted → word splitting + glob | `FOO=hello world` becomes two args |
| ③ | `$PREFIX/etc/passwd` is Termux-writable | shell path can be injected |
| ④ | Cache written unquoted | `; payload` in shell name becomes shell syntax |
| ⑤ | Cache sourced as root code | **Critical RCE** — Termux controls what root executes |
| ⑥ | `runcon true` proves nothing about the real chain | false confidence |
| ⑦ | SELinux transition before UID switch | transition order matters to kernel |
| ⑧ | No `-g`, no `-G` | missing `inet`, `sdcard_rw`, storage groups → network + storage broken |

---

### What `txsu` does instead

The entire design is: **construct everything from verified integers, never source external data, never inherit root env.**

```
root shell (u:r:ksu:s0)
      │
      ├─► stat -c '%u' /data/data/com.termux   → TUID  (integer only)
      ├─► stat -c '%g' /data/data/com.termux   → TGID  (integer only)
      ├─► stat -c '%g' /dev/socket/dnsproxyd   → IGID  (inet group)
      ├─► stat -c '%g' /storage                → SGID  (storage group)
      │
      │   ┌─────────────────────────────────────┐
      │   │  stat output = integers only        │
      │   │  cannot contain shell syntax        │
      │   │  no Termux filesystem involved      │
      │   └─────────────────────────────────────┘
      │
      ▼
/system/bin/su
    -g  $TGID          ← primary group = Termux GID
    -G  $IGID          ← supplementary: inet  (network access)
    -G  $SGID          ← supplementary: storage (sdcard access)
    $TUID              ← UID switch
    /system/bin/sh -c '
        │
        │  NOW INSIDE uid=10172 PROCESS
        │  root env is GONE — sh -c starts clean
        │
        ├── export HOME=...          (hardcoded known path)
        ├── export PREFIX=...        (hardcoded known path)
        ├── export ZDOTDIR=...       (hardcoded known path)
        ├── export PATH=PREFIX/bin:PREFIX/bin/applets:system paths
        ├── export TMPDIR=...
        ├── export TERM=xterm-256color
        ├── export LANG=...
        │
        ├── export ANDROID_ROOT / DATA / STORAGE / ASSETS
        ├── export ANDROID_ART_ROOT / I18N_ROOT / TZDATA_ROOT
        │
        ├── export TERMUX__ROOTFS_DIR / HOME / PREFIX / UID / USER_ID
        ├── export TERMUX_APP__PACKAGE_NAME / DATA_DIR
        │
        ├── export SHELL=$PREFIX/bin/zsh
        ├── export EXTERNAL_STORAGE=/sdcard
        │
        ├── unset LD_LIBRARY_PATH    ← clear root linker state
        ├── export LD_PRELOAD=$PREFIX/lib/libtermux-exec-ld-preload.so
        │
        ├── cd $HOME
        │
        └── exec $PREFIX/bin/zsh -l -i
                  │
                  │  login shell: sources .zprofile, .zshrc
                  ▼
              your Termux shell ✅
    '
```

---

### Why each decision was made

**`stat` for UID/GID detection** — `stat -c '%u'` returns a decimal integer. Integers cannot contain shell metacharacters. This eliminates the entire class of injection bugs from using `passwd`, `dumpsys`, `pm`, or process scanning.

**`-g $TGID -G $IGID -G $SGID`** — `su <uid>` alone only switches the UID. It does not reconstruct the supplementary group membership that the Android framework gives a real app process. Without `inet` (GID of `dnsproxyd` socket), network sockets are blocked. Without `storage`, `/sdcard` is inaccessible. These GIDs are also detected via `stat` — not hardcoded — so they work across all devices.

**`/system/bin/sh -c '...'`** — The env is constructed inside a double-quoted heredoc-style `-c` string, with all paths baked in at the outer (root) script level. The inner shell never reads any Termux file before the `exec`. There is no cache, no sourced file, no variable inherited from root.

**`unset LD_LIBRARY_PATH` before `LD_PRELOAD`** — Root shells (especially KSU/SSH sessions) may carry `LD_LIBRARY_PATH` pointing at system paths. If that survives into Termux's zsh, the dynamic linker picks up wrong `.so` files. Clearing it first ensures `libtermux-exec-ld-preload.so` operates cleanly.

**`exec zsh -l -i`** — `-l` makes it a login shell (reads `.zprofile`). `-i` makes it interactive (reads `.zshrc`). Together they give you your full configured Termux environment including your custom PATH, aliases, plugins, and `sudo`/`tsu` working correctly.

**No `runcon`** — the old approach used `runcon` to try to match Termux's SELinux domain. This was solving the wrong problem (see Hurdle 2). `txsu` skips it entirely. The shell runs as `u:r:ksu:s0` or `u:r:magisk:s0` and that is fine for UID-based operations.

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
