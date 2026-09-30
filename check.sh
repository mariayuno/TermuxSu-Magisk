#!/bin/sh
# check.sh — consistency checker for TermuxSu repo
# Run from the repo root.

PASS=0; FAIL=0; WARN=0
S=system/bin/txsu
R=README.md

# colours
G='\033[0;32m'; RED='\033[0;31m'; Y='\033[0;33m'; N='\033[0m'; B='\033[1m'

ok()   { PASS=$((PASS+1)); printf "${G}PASS${N}  %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); printf "${RED}FAIL${N}  %s\n" "$1"; }
warn() { WARN=$((WARN+1)); printf "${Y}WARN${N}  %s\n" "$1"; }

bar() {
    total=$((PASS+FAIL+WARN+1))
    done_=$((PASS+FAIL+WARN))
    width=40
    filled=$((done_*width/total))
    printf "\r["; i=0
    while [ $i -lt $filled ];  do printf "#"; i=$((i+1)); done
    while [ $i -lt $width ];   do printf "-"; i=$((i+1)); done
    printf "] %d/%d  " "$done_" "$total"
}

total_checks=40   # approximate; bar resets at end anyway

printf "${B}TermuxSu consistency check${N}\n\n"

# ── Files exist ──────────────────────────────────────────────────────────────
bar; [ -f "$S" ]             && ok "txsu exists"             || fail "txsu missing"
bar; [ -f "$R" ]             && ok "README.md exists"        || fail "README.md missing"
bar; [ -f module.prop ]      && ok "module.prop exists"      || fail "module.prop missing"
bar; [ -f update.json ]      && ok "update.json exists"      || fail "update.json missing"
bar; [ -f customize.sh ]     && ok "customize.sh exists"     || fail "customize.sh missing"
bar; [ -f CHANGELOG.md ]     && ok "CHANGELOG.md exists"     || fail "CHANGELOG.md missing"
bar; [ -f META-INF/com/google/android/update-binary ] \
                             && ok "update-binary exists"    || fail "update-binary missing"

# ── Script syntax ─────────────────────────────────────────────────────────────
bar; sh -n "$S" 2>/dev/null  && ok "txsu passes sh -n"       || fail "txsu syntax error"

# ── Version consistency ───────────────────────────────────────────────────────
VER_PROP=$(grep   '^version='     module.prop  | cut -d= -f2)
VER_CODE=$(grep   '^versionCode=' module.prop  | cut -d= -f2)
VER_JSON=$(grep   '"version"'     update.json  | sed 's/.*": *"//;s/".*//')
CODE_JSON=$(grep  '"versionCode"' update.json  | sed 's/.*": *//;s/[^0-9].*//')
VER_CLOG=$(grep   '^## v'        CHANGELOG.md | head -1 | awk '{print $2}')
VER_ZIP=$(grep    '"zipUrl"'      update.json  | sed 's/.*download\///;s/\/.*//')

bar; [ "$VER_PROP" = "$VER_JSON" ] \
    && ok  "version matches: module.prop=$VER_PROP update.json=$VER_JSON" \
    || fail "version mismatch: module.prop=$VER_PROP update.json=$VER_JSON"

bar; [ "$VER_CODE" = "$CODE_JSON" ] \
    && ok  "versionCode matches: $VER_CODE" \
    || fail "versionCode mismatch: module.prop=$VER_CODE update.json=$CODE_JSON"

bar; [ "$VER_PROP" = "$VER_CLOG" ] \
    && ok  "CHANGELOG top entry matches version: $VER_CLOG" \
    || warn "CHANGELOG top entry ($VER_CLOG) != module.prop ($VER_PROP)"

bar; [ "$VER_PROP" = "$VER_ZIP" ] \
    && ok  "update.json zipUrl version matches: $VER_ZIP" \
    || fail "update.json zipUrl version ($VER_ZIP) != module.prop ($VER_PROP)"

# duplicate ## headers in CHANGELOG
DUP=$(grep '^## ' CHANGELOG.md | sort | uniq -d)
bar; [ -z "$DUP" ] \
    && ok  "no duplicate CHANGELOG headers" \
    || warn "duplicate CHANGELOG headers: $DUP"

# ── README covers key script tokens ──────────────────────────────────────────
check_readme() { bar; grep -qF -- "$2" "$R" && ok "README covers: $1" || fail "README missing: $1 ($2)"; }

check_readme "die()"              'die() {'
check_readme "root check"         'id -u'
check_readme "TERMUX_DATA check"  '-d TERMUX_DATA'
check_readme "TERMUX_HOME check"  '-d TERMUX_HOME'
check_readme "TERMUX_EXEC check"  '-f TERMUX_EXEC'
check_readme "shell link check"   '-x "$TERMUX_SHELL_LINK"'
check_readme "readlink 2>/dev/null" 'readlink -f "$TERMUX_SHELL_LINK" 2>/dev/null'
check_readme "bash fallback"      '$TERMUX_PREFIX/bin/bash'
check_readme "zsh fallback"       '$TERMUX_PREFIX/bin/zsh'
check_readme "shell exe check"    'resolved shell'
check_readme "ZDOTDIR .config/zsh" '.config/zsh'
check_readme "soft SGID"          'continuing without it'
check_readme "-c parse"           'leading `-c CMD`'
check_readme "TXSU_CMD env"       '`TXSU_CMD` before calling `su`'
check_readme "SUPP_GROUPS"        '`SUPP_GROUPS`'
check_readme "unquoted split"     'intentionally left unquoted'
check_readme "TUID"               '`TUID`'
check_readme "LD_LIBRARY_PATH"    'LD_LIBRARY_PATH'
check_readme "cd failure"         'exit 1 if it fails'
check_readme "-c exec"            'SHELL -c'
check_readme "-l -i exec"         '-l -i'
check_readme "RC"                 '`RC`'
check_readme "exit message"       'shell exited with status'
check_readme "LANG default"       '${LANG:-en_US.UTF-8}'
check_readme "fscreate"           'fscreate'
check_readme "MCS categories"     'MCS'
check_readme "FSCREATE_CTX var"   '`FSCREATE_CTX`'

# ── Script has no stale strings ───────────────────────────────────────────────
stale_script() { bar; grep -qF -- "$2" "$S" && fail "stale in script: $1" || ok "not in script: $1"; }
stale_script "old chsh wrapper"   'chsh()'
stale_script "echo fscreate"      "echo '\$FSCREATE_CTX'"

# ── README has no stale strings ───────────────────────────────────────────────
stale_readme() { bar; grep -qF -- "$2" "$R" && fail "stale in README: $1" || ok "not in README: $1"; }
stale_readme "stopped receiving updates 2020"  'stopped receiving updates in 2020'
stale_readme "Proven empirically"              'Proven empirically'
stale_readme "Zygote assigns"                  'Zygote assigns'
stale_readme "GIDs are not fixed"              'GIDs are not fixed'
stale_readme "Previously this was backwards"   'Previously this was backwards'
stale_readme "Nothing is written to your system" 'Nothing is written to your system'
stale_readme "USER_ID block"                   'Why is TERMUX__USER_ID not set?'
stale_readme "chsh SELinux wrapper note"       'wraps `chsh` to fix the SELinux'

# ── details tag balance ───────────────────────────────────────────────────────
OPEN=$(grep -c '<details>' "$R")
CLOSE=$(grep -c '</details>' "$R")
bar; [ "$OPEN" = "$CLOSE" ] \
    && ok  "<details> tags balanced ($OPEN)" \
    || fail "<details> imbalance: $OPEN open $CLOSE close"

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS+FAIL+WARN))
printf "\r%-60s\n\n" " "   # clear bar line
printf "${B}Results: ${G}%d passed${N}  ${RED}%d failed${N}  ${Y}%d warnings${N}  (%d total)\n" \
    "$PASS" "$FAIL" "$WARN" "$TOTAL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
