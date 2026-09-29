## v1.0

- Initial release
- Shell detection: reads ~/.termux/shell, falls back to bash then zsh
- Dynamic GID detection via stat for inet and storage groups
- ZDOTDIR only set for zsh + XDG layout users
- Uses libtermux-exec.so (stable symlink) for LD_PRELOAD
- Removes hardcoded TERMUX__USER_ID
