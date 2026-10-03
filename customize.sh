# TermuxSu — post-install customization
# Runs as root inside the Magisk/KSU/APatch installer.

MODPATH="${MODPATH}"

# Main controller
set_perm "$MODPATH/system/bin/txsu"   root root 0755

# Helpers — must be executable; owned by root at module level,
# but the controller will chown/chcon them to the Termux UID at runtime.
set_perm "$MODPATH/system/bin/ns"     root root 0755
set_perm "$MODPATH/system/bin/child"  root root 0755

# Symlinks
ALIASES="termsu termux txsh trmx"
for name in $ALIASES; do
  ln -sf txsu "$MODPATH/system/bin/$name"
  set_perm "$MODPATH/system/bin/$name" root root 0755
done

ui_print "- txsu installed (ns + child helpers)"
ui_print "- aliases: $ALIASES"
