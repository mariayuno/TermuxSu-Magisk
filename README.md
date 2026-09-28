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

This was the most misdiagnosed problem. The old implementation had an entire networking subsystem built on a wrong premise, and the real fix turned out to be two lines.

---

#### What Android's networking stack actually does

When any process makes a socket call, the kernel routes it through `netd` via the fwmark mechanism:

```
process calls connect() / getaddrinfo()
              │
              ▼
       ┌─────────────────────────────────────┐
       │  Does this domain have permission   │
       │  to reach /dev/socket/fwmarkd ?     │  ← SELinux check (netdomain)
       │  to reach /dev/socket/dnsproxyd ?   │
       └─────────────┬───────────────────────┘
                     │ yes
                     ▼
              FwmarkServer (netd)
                     │
                     │  getNetworkForConnect(client->getUid())
                     │                            ▲
                     │                            │ UID — not SELinux domain
                     ▼
              NetworkController
                     │
                     │  selects NetId from UID/network policy
                     │  (VPN applicability, per-UID network rules)
                     ▼
              correct network route + DNS
```

**Source:** AOSP `FwmarkServer.cpp` (android-14 tag): `getNetworkForConnect(client->getUid())` — the routing decision is UID-based. SELinux only gates whether the process can *talk to* `fwmarkd` and `dnsproxyd` at all, via the `netdomain` attribute in `net.te`.

---

#### What the old approach believed (and why it was wrong)

The old `txsu` claimed:

> `fwmarkd` routes based on the SELinux context, not just UID.

And built this as the fix:

```
root shell (u:r:ksu:s0)
      │
      │  runcon "$SELINUX_CTX" ...    ← switch to untrusted_app_27
      ▼
u:r:untrusted_app_27:s0
      │
      │  /system/bin/su $TERMUX_UID
      ▼
uid=10172 + untrusted_app_27 context
      │
      ▼
fwmarkd  ← "now it works because we have the right SELinux context"
```

**Why that reasoning is wrong:** `fwmarkd` doesn't care about your SELinux domain for *routing*. It cares only for *access* — can you open the socket at all. The routing is purely UID-based. What the old approach accidentally fixed was the `netdomain` permission gap: `ksu` on some builds lacked permission to reach `fwmarkd`/`dnsproxyd`, and impersonating `untrusted_app_27` (which has `netdomain`) worked around it.

Current upstream KernelSU explicitly grants `ksu` the `netdomain` attribute in `kernel/selinux/rules.c` — so on stock KSU/ResuKiSU the `runcon` workaround is entirely unnecessary.

---

#### The DNS subsystem was also completely broken

On top of the wrong SELinux premise, the old approach had a fake DNS implementation:

```
OLD APPROACH — fake DNS pipeline:

getprop net.dns1          ← system property, often stale/empty
getprop net.dns2
getprop dhcp.wlan0.dns1   ← hardcoded interface names
getprop dhcp.eth0.dns1    ← wlan0, eth0, rmnet0, rmnet_data0 only
grep '^nameserver' /proc/net/pnp  ← legacy Linux interface
         │
         ▼
write $PREFIX/etc/resolv.conf
         │
         ▼  "DNS populated from system properties" ✓ (printed)
         │
         ▼
app calls getaddrinfo()
         │
         ▼
Android libc resolver
         │
         ▼  reads Android's internal resolver state
         │  NOT $PREFIX/etc/resolv.conf   ← file is ignored
         │
         ▼
DNS works or fails based on UID/netd state alone
```

**Three compounding failures:**

| Failure | Detail |
|---|---|
| Wrong consumer | Modern Android (Python, curl in Termux) uses Android's bionic resolver via `dnsproxyd`, not `/etc/resolv.conf`. The file is irrelevant. |
| Stale on network change | The file was only written when empty. Switch from Wi-Fi → mobile → VPN → Private DNS: the file never updates, while Android's resolver state changes dynamically. |
| Wrong interface names | `wlan0`, `eth0`, `rmnet0`, `rmnet_data0` are hardcoded. Modern devices use `wlan1`, `rmnet_data1`, `ccmni0`, `v4-rmnet...`, etc. Even when they exist, the DNS for an interface isn't necessarily the DNS for a given UID at that moment. |

---

#### What `txsu` does instead

The entire networking implementation is **deleted**. No `resolv.conf` writing, no `getprop`, no interface scanning, no `runcon`.

The fix is two `stat` calls:

```
txsu startup
      │
      ├── IGID=$(stat -c '%g' /dev/socket/dnsproxyd)
      │              ▲
      │              └── GID of the dnsproxyd socket
      │                  = the Android "inet" group
      │                  detected dynamically, works on all devices
      │
      ├── SGID=$(stat -c '%g' /storage)
      │
      ▼
/system/bin/su
    -G $IGID       ← add inet supplementary group
    -G $SGID       ← add storage supplementary group
    $TUID
    /system/bin/sh -c '... exec zsh -l -i'
              │
              ▼
    process credentials:
      uid  = 10172
      gid  = 10172
      groups = [ 10172, $IGID, $SGID ]
              │
              ▼
    connect() / getaddrinfo()
              │
              ▼
    fwmarkd: client has inet group → socket allowed
    netd:    getNetworkForConnect(10172) → correct network
    dnsproxyd: uid=10172 → correct DNS resolver state
              │
              ▼
    internet works ✅
```

**Why `stat` on the socket:** the `inet` group GID is not a fixed number across all Android devices and versions. `stat -c '%g' /dev/socket/dnsproxyd` reads it directly from the socket that the group is meant to grant access to — self-documenting, device-agnostic, always correct.

**Why not `runcon`:** the `netdomain` SELinux permission is already present in `ksu` on current KSU/ResuKiSU. If it weren't, the correct fix is `sepolicy.rule` (which the module ships), not impersonating an app domain at runtime.

**Why no `resolv.conf`:** Android's resolver bypasses it entirely. Termux processes using Python, curl, wget, git all go through bionic's `getaddrinfo()` → `dnsproxyd`. The correct DNS state flows automatically once the process has the right UID and `inet` group.

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
