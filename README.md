# TermuxSu — txsu

Drop into a proper Termux shell from any root session.

## Usage

```sh
txsu
```

Run from any root shell (SSH, ADB, etc). Drops into Termux's zsh with correct UID, groups, env, and `LD_PRELOAD`.

## What it does

- Detects Termux UID/GID from data directory
- Adds `inet` and `storage` supplementary groups for network and sdcard access
- Sets all required `TERMUX_*` and `ANDROID_*` env vars
- Loads `libtermux-exec-ld-preload.so` so Termux binaries resolve correctly
- Launches `zsh -l -i` as a proper login shell

## Compatibility

- Magisk, KernelSU, ResuKiSU, APatch
- Android 7+ (all `untrusted_app` domain variants)

## SELinux

Ships a `sepolicy.rule` allowing the root manager domain to transition into the Termux app domain via `runcon`. Required for correct `fwmarkd` network routing.

> ⚠️ This allows `magisk`/`ksu` domains to transition into any `untrusted_app` domain — not only Termux. On a rooted device this is an acceptable trade-off, but be aware it weakens SELinux defence-in-depth.

## License

MIT © mariayuno
