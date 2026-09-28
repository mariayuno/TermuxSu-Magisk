#!/system/bin/sh
# service.sh - runs late in boot (after Termux data is accessible)
# Creates the 'termux' alias symlink for txsu

TXSU="/system/bin/txsu"
ALIAS="/system/bin/termux"

if [ -f "$TXSU" ] && [ ! -e "$ALIAS" ]; then
  ln -sf "$TXSU" "$ALIAS"
fi
