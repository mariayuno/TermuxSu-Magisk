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

---

## 📄 License

MIT
