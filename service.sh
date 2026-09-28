#!/system/bin/sh
# service.sh — TermuxSu-Magisk
# Runs late-boot (Magisk stage: service).
# Creates /system/bin/termux symlink → txsu.

TXSU="/system/bin/txsu"
ALIAS="/system/bin/termux"

if [ -f "$TXSU" ]; then
  if [ ! -e "$ALIAS" ]; then
    ln -sf "$TXSU" "$ALIAS" && \
      log -t TermuxSu-Magisk "Created alias: $ALIAS -> $TXSU"
  fi
else
  log -t TermuxSu-Magisk "ERROR: $TXSU not found — module may not be installed correctly"
fi
