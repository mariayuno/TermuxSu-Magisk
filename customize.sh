# TermuxSu — post-install customization
# Runs as root inside the Magisk/KSU/APatch installer.

MODPATH="${MODPATH}"

# Ensure txsu is executable
set_perm "$MODPATH/system/bin/txsu" root root 0755

# Symlinks — create them explicitly so they survive across all root impls
ALIASES="termsu termux txsh trmx"
for name in $ALIASES; do
  ln -sf txsu "$MODPATH/system/bin/$name"
  set_perm "$MODPATH/system/bin/$name" root root 0755
done

ui_print "- txsu installed, aliases: $ALIASES"
# aliases: termsu termux txsh trmx
