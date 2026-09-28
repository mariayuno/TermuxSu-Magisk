# TermuxSu-Magisk

**Magisk module** that lets you invoke a full [Termux](https://termux.dev) shell from any Android root shell — with correct user context, ownership, permissions, SELinux label, and working network/DNS.

## Why

When you `su` into root on Android and try to run Termux commands, things break:
- Wrong UID / file ownership
- Termux binaries can't find their prefix
- SELinux denials
- No network / DNS

`txsu` fixes all of that in one command.

## Install

1. Download the latest `.zip` from [Releases](../../releases)
2. Flash via Magisk Manager or MMRL
3. Reboot

## Usage

```sh
# From any root shell:
txsu                   # interactive Termux shell
txsu -c "pkg update"   # run one command
termux                 # alias for txsu
```

## How it works

1. Resolves Termux's UID from the package manager
2. Switches SELinux context via `runcon` to Termux's untrusted_app domain
3. Drops privileges to the Termux UID via `su <uid>`
4. Sets up the full Termux environment (`PREFIX`, `HOME`, `PATH`, `LD_LIBRARY_PATH`, etc.)
5. Ensures DNS (`resolv.conf`) is readable inside the Termux prefix for working network

## Binary & alias

| Path | Purpose |
|---|---|
| `/system/bin/txsu` | Main binary |
| `/system/bin/termux` | Symlink alias (created at boot via `service.sh`) |

## Requirements

- Android with Magisk (or KernelSU / APatch with compat)
- Termux installed (`com.termux`)
- Root shell access

## License

MIT © mariayuno
