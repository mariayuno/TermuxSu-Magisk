# TermuxSu

**Full native Termux shell from any root session.**

Reconstructs the complete Android app runtime — UID, GID, supplementary groups, SELinux process domain, MCS range, mount namespace, and Termux userspace — without a donor process.

<!-- VERSION_BADGE_START -->
<img alt="Version" src="https://img.shields.io/badge/version-v2.5-7c3aed?style=for-the-badge&logo=github&logoColor=white">
<!-- VERSION_BADGE_END -->

---

## ✅ Requirements

| Requirement | How to satisfy |
|---|---|
| Rooted Android | Magisk, KernelSU, ResuKiSU, or APatch |
| `/system/bin/su` | Provided automatically by any root implementation above |
| Termux | Install from **F-Droid or GitHub**, then **open it once** to bootstrap |
| `clang` | `pkg install clang` in Termux — required to build the SELinux preload library |

> ⚠️ **Prefer F-Droid or GitHub.** The Google Play build is experimental. Install from [F-Droid](https://f-droid.org/en/packages/com.termux/) or [GitHub releases](https://github.com/termux/termux-app/releases).

---

## ⚡ Try It Now — No Install Required

```sh
curl -fsSL https://raw.githubusercontent.com/mariayuno/TermuxSu-Magisk/main/system/bin/txsu -o /tmp/txsu && sh /tmp/txsu
```

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
curl -Lo /tmp/txsu.zip https://github.com/mariayuno/TermuxSu-Magisk/releases/latest/download/TermuxSu-v2.5.zip && /data/adb/ksud module install /tmp/txsu.zip
```

**Magisk**

```sh
curl -Lo /tmp/txsu.zip https://github.com/mariayuno/TermuxSu-Magisk/releases/latest/download/TermuxSu-v2.5.zip && magisk --install-module /tmp/txsu.zip
```

**APatch**

```sh
curl -Lo /tmp/txsu.zip https://github.com/mariayuno/TermuxSu-Magisk/releases/latest/download/TermuxSu-v2.5.zip && /data/adb/apd module install /tmp/txsu.zip
```

</td>
<td valign="top" align="right" width="30%">

<p align="right">
<img alt="Version" src="https://img.shields.io/badge/v2.5-7c3aed?style=for-the-badge&logo=github&logoColor=white"><br>
<img alt="Package" src="https://img.shields.io/badge/package-TermuxSu-v2.5.zip-2563eb?style=for-the-badge&logo=files&logoColor=white"><br>
<img alt="Version Code" src="https://img.shields.io/badge/version%20code-16-0891b2?style=for-the-badge">
</p>

</td>
</tr>
</table>

<!-- INSTALL_ONELINER_END -->

### Method 2 — Flash from Manager UI

Download the zip from [Releases](https://github.com/mariayuno/TermuxSu-Magisk/releases/latest) and flash via Magisk / KernelSU / APatch manager.

### Method 3 — No-Flash Persistent Install

```sh
curl -fsSL https://raw.githubusercontent.com/mariayuno/TermuxSu-Magisk/main/system/bin/txsu -o /data/adb/txsu && chmod 755 /data/adb/txsu
```

### Aliases

| Command | Notes |
|---|---|
| `txsu` | canonical name |
| `txsh` | shell-flavoured alias |
| `termsu` | long-form |
| `termux` | shorthand |
| `trmx` | compact |

---

## 🏗 Architecture

Three components:

```
txsu  (controller, runs as root)
  └── unshare -m → ns  (namespace stage, still root)
                    └── su -Z context → child  (Termux UID, untrusted_app_27)
                                          └── termux.env → $PREFIX/bin/login
                                                              └── user shell
```

- **`txsu`** discovers Android app identity, computes SELinux domain + MCS from target SDK and UID, reads package GIDs, labels helpers, and invokes `unshare -m`
- **`ns`** applies `mount -o rslave rootfs /` then switches credentials and SELinux context via KernelSU
- **`child`** establishes the Termux environment, sources `termux.env`, and hands off to `$PREFIX/bin/login`

Shell selection, `termux-exec`, and `termux-login.sh` are delegated entirely to Termux's own `login` binary.

---

## 📄 License

MIT
