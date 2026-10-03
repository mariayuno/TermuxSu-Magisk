# TermuxSu

**Full native Termux shell from any root session.**

Reconstructs Android app runtime identity without a donor process: UID, GIDs, SELinux domain + MCS, mount namespace, full Termux userspace. Shell selection, `termux-exec`, and `termux-login.sh` are delegated to Termux's own `login` binary.

<!-- VERSION_BADGE_START -->
<!-- VERSION_BADGE_END -->

---

## ✅ Requirements

| Requirement | How to satisfy |
|---|---|
| Rooted Android | Magisk, KernelSU, ResuKiSU, or APatch |
| `/system/bin/unshare` | Present on Android 7+ via toybox |
| Termux (F-Droid or GitHub) | Open once to bootstrap; installs `login`, `bash`, `termux-exec` |

> ⚠️ **F-Droid or GitHub only.** The Google Play build is experimental.

---

## 📦 Install

<!-- INSTALL_ONELINER_START -->
<!-- INSTALL_ONELINER_END -->

**Method 2 — Manager UI:** Flash zip from [Releases](https://github.com/mariayuno/TermuxSu-Magisk/releases/latest) via Magisk / KernelSU / APatch manager.

### Aliases

`txsu` · `txsh` · `termsu` · `termux` · `trmx`

---

## 🏗 Architecture

### Why naive `su` fails

`su -u <termux-uid>` gives the right UID but:

| Missing | Effect |
|---|---|
| SELinux domain `untrusted_app_27` | App-data files inaccessible |
| MCS categories | Files get wrong label, unreadable by native Termux |
| `inet` group (3003) | DNS broken |
| storage group | `/sdcard` inaccessible |
| Private mount namespace | Differs from real app process |
| `termux-exec` | Termux binaries fail on Android 10+ |
| Termux environment | No `HOME`, `PREFIX`, `PATH`, `TMPDIR` |

txsu reconstructs all of these from first principles.

---

### Components

Three shell scripts shipped to `/system/bin/` by the module:

```
/system/bin/txsu     controller — runs as root
/system/bin/ns       namespace helper — copied to ~/.txsu/ at runtime
/system/bin/child    Termux bootstrap — copied to ~/.txsu/ at runtime
```

`ns` and `child` cannot execute from `/system/bin/` after the KernelSU credential transition — the `untrusted_app` SELinux domain cannot execute files there. The controller (root) copies them into `~/.txsu/` with the correct Termux app-data label on every run before the transition.

Runtime layout:

```
~/.txsu/
├── ns      owner=TERMUX_UID  label=app_data_file:s0:cA,cB,cC,cD  mode=700
└── child   owner=TERMUX_UID  label=app_data_file:s0:cA,cB,cC,cD  mode=700
```

---

### Execution flow

```
root shell
    │
    ▼
/system/bin/txsu  (uid=0, u:r:ksu:s0)
    │
    ├─ 1. Validate DATA, PREFIX, HOME, su, unshare, login
    ├─ 2. TERMUX_UID      ← stat -c '%u' /data/data/com.termux
    ├─ 3. Decompose UID → USER_ID, APP_ID, APP_OFFSET
    ├─ 4. TARGET_SDK      ← dumpsys package com.termux
    ├─ 5. DOMAIN          ← TARGET_SDK bucket table
    ├─ 6. MCS categories  ← LEVELFROM_ALL(APP_OFFSET, USER_ID)
    ├─ 7. SUPP_GIDS       ← dumpsys GIDs + cache + shared + 9997 + 1077
    ├─ 8. HOME_LABEL      ← ls -Zd $HOME
    ├─ 9. mkdir ~/.txsu; chown/chmod/chcon
    ├─10. cp /system/bin/ns ~/.txsu/ns
    │     cp /system/bin/child ~/.txsu/child
    │     chown/chmod/chcon both
    ├─11. export all TXSU_* state vars
    └─ exec /system/bin/unshare -m ~/.txsu/ns
                │
                ▼
        ~/.txsu/ns  (uid=0, new private mount namespace)
                │
                ├─ A. mount -o rslave rootfs /
                ├─ B. build: su -W -p -g TUID -G gid... -Z CONTEXT TUID
                └─ exec /system/bin/su [...] -c "/system/bin/sh ~/.txsu/child"
                            │
                            ▼
                    ~/.txsu/child  (uid=TERMUX_UID, u:r:untrusted_app_27:s0:cA,cB,cC,cD)
                            │
                            ├─ A. Restore TERM, SSH_*, LANG from TXSU_*
                            ├─ B. Export HOME, PREFIX, PWD, PATH, TMPDIR, USER
                            ├─ C. cd $HOME || exit 1
                            ├─ D. Unset SHELL, LD_PRELOAD, LD_LIBRARY_PATH, MAIL, etc.
                            ├─ E. Source $PREFIX/etc/termux/termux.env
                            ├─ F. Reassert HOME/PREFIX/PATH
                            ├─ G. Export TERMUX__*, TERMUX_APP__*
                            └─ exec $PREFIX/bin/login
                                        │
                                        ▼
                                $PREFIX/bin/login
                                        │
                                        ├─ MOTD
                                        ├─ ~/.termux/shell (chsh)
                                        ├─ termux-exec (LD_PRELOAD)
                                        ├─ termux-login.sh
                                        └─ exec SHELL -l
```

---

### SELinux reconstruction

#### Domain (TARGET_SDK bucket)

```
TARGET_SDK    domain
34+           untrusted_app
32–33         untrusted_app_32
30–31         untrusted_app_30
29            untrusted_app_29
26–28         untrusted_app_27   ← Termux (targetSdk=28)
else          untrusted_app_25
```

Approximation of Android `seapp_contexts` — correct for Termux on API 26–34.

#### MCS categories (LEVELFROM_ALL)

From AOSP `android_seapp.c`:

```
C1 = APP_OFFSET & 255
C2 = 256 + ((APP_OFFSET >> 8) & 255)
C3 = 512 + (USER_ID & 255)
C4 = 768 + ((USER_ID >> 8) & 255)
→ u:r:<domain>:s0:c<C1>,c<C2>,c<C3>,c<C4>
```

UID 10172, USER_ID 0 → `u:r:untrusted_app_27:s0:c172,c256,c512,c768`. Recomputed on every run.

---

### Supplementary GIDs

| Source | GIDs |
|---|---|
| `dumpsys package com.termux` | Permission GIDs (e.g. 3003=inet) |
| APP_OFFSET + 20000 | Cache GID |
| APP_OFFSET + 50000 | Shared GID |
| 9997 | `AID_EVERYBODY` |
| 1077 | `AID_EXTERNAL_STORAGE` |

`9997` and `1077` are stable Android AIDs from `android_filesystem_config.h`, observed in native Termux on the reference device.

Reference device: `uid=10172 groups=10172,1077,3003,9997,20172,50172 context=u:r:untrusted_app_27:s0:c172,c256,c512,c768`

---

### Mount namespace

`unshare -m` creates a private namespace; `ns` runs `mount -o rslave rootfs /`, mirroring Zygote:

```c
unshare(CLONE_NEWNS);
mount("rootfs", "/", nullptr, MS_SLAVE | MS_REC, nullptr);
```

Converts root propagation from `shared` → `slave`. Topologically identical to a live Termux process — no donor required.

---

### KernelSU transition (ns)

```sh
su -W -p -g TUID -G gid1 -G gid2 ... -Z CONTEXT TUID -c "/system/bin/sh ~/.txsu/child"
```

| Flag | Effect |
|---|---|
| `-W` | No-wrapper — preserves SSH PTY |
| `-p` | Preserve `TXSU_*` env |
| `-G` (repeated) | Supplementary GIDs — **repeated, not comma-separated** |
| `-Z` | Exact SELinux process context |

---

### Environment (child)

**Terminal/session** (from `TXSU_*`): `TERM`, `COLORTERM`, `TERM_PROGRAM`, `SSH_TTY/CLIENT/CONNECTION`, `LANG`, `LC_*`

**Termux filesystem**: `HOME`, `PREFIX`, `PWD`, `PATH=$PREFIX/bin`, `TMPDIR`, `USER`, `LOGNAME`

**`TERMUX__*`**: `ROOTFS_DIR`, `HOME`, `PREFIX`, `PROJECT_DIR`, `CORE_DIR`, `APPS_DIR`, `CACHE_DIR`

**`TERMUX_APP__*`**: `PACKAGE_NAME`, `UID`, `TARGET_SDK`, `VERSION_NAME/CODE`, `APK_PATH`, `DATA_DIR`, `SE_FILE_CONTEXT`, `SE_PROCESS_CONTEXT`, `IS_DEBUGGABLE_BUILD`, `USER_ID`; `TXSU_DONORLESS=1`

`TERMUX_APP__PID` intentionally not set.

**Unset before `termux.env`**: `SHELL`, `MAIL`, `OLDPWD`, `BASH_ENV`, `ENV`, `LD_LIBRARY_PATH`, `LD_PRELOAD`

---

### Diagnostic modes

| Flag | Effect |
|---|---|
| `--identity` | Print UID, context, ns, HOME label, file creation test → bash |
| `--env` | Print full env + id + context → bash |
| `--clean` | `bash --noprofile --norc -i` |
| `--debug` | Write `~/.txsu.debug` |

Bypass `$PREFIX/bin/login` entirely — isolates runtime defects from shell config.

---

### Reference device

```
Android: 16 · Termux: 0.119.0-beta.3 · targetSdk: 28
UID: 10172 · domain: untrusted_app_27
context: u:r:untrusted_app_27:s0:c172,c256,c512,c768
groups:  10172, 1077, 3003, 9997, 20172, 50172
```

---

### Troubleshooting

| Symptom | Fix |
|---|---|
| `missing ~/.txsu/ns` | Flash latest release — old module installed |
| `rslave setup failed` | Kernel lacks mount namespace support |
| `cannot label helper` | SELinux issue — check `dmesg \| grep avc` |
| Wrong identity | `txsu --identity` |
| Wrong environment | `txsu --env` |
| Shell config issue | `txsu --clean` |

---

## 📄 License

MIT
