#!/bin/sh
# check.sh — consistency checker for TermuxSu repo
PASS=0; FAIL=0; WARN=0
G='\033[0;32m'; RED='\033[0;31m'; Y='\033[0;33m'; N='\033[0m'; B='\033[1m'
ok()   { PASS=$((PASS+1)); printf "${G}PASS${N}  %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); printf "${RED}FAIL${N}  %s\n" "$1"; }
warn() { WARN=$((WARN+1)); printf "${Y}WARN${N}  %s\n" "$1"; }
bar()  { d=$((PASS+FAIL+WARN)); printf "\r["; i=0; while [ $i -lt $((d*40/(d+1))) ]; do printf "#"; i=$((i+1)); done; while [ $i -lt 40 ]; do printf "-"; i=$((i+1)); done; printf "] %d  " "$d"; }

printf "${B}TermuxSu consistency check${N}\n\n"

# Files
bar; [ -f system/bin/txsu ]   && ok "txsu exists"   || fail "txsu missing"
bar; [ -f system/bin/ns ]     && ok "ns exists"     || fail "ns missing"
bar; [ -f system/bin/child ]  && ok "child exists"  || fail "child missing"
bar; [ -f module.prop ]       && ok "module.prop"   || fail "module.prop missing"
bar; [ -f update.json ]       && ok "update.json"   || fail "update.json missing"
bar; [ -f customize.sh ]      && ok "customize.sh"  || fail "customize.sh missing"
bar; [ -f CHANGELOG.md ]      && ok "CHANGELOG.md"  || fail "CHANGELOG.md missing"
bar; [ -f META-INF/com/google/android/update-binary ] && ok "update-binary" || fail "update-binary missing"

# Syntax
bar; sh -n system/bin/txsu  2>/dev/null && ok "txsu syntax ok"  || fail "txsu syntax error"
bar; sh -n system/bin/ns    2>/dev/null && ok "ns syntax ok"    || fail "ns syntax error"
bar; sh -n system/bin/child 2>/dev/null && ok "child syntax ok" || fail "child syntax error"

# Version consistency
VP=$(grep '^version='     module.prop | cut -d= -f2)
VC=$(grep '^versionCode=' module.prop | cut -d= -f2)
VJ=$(grep '"version"'     update.json | sed 's/.*": *"//;s/".*//')
CJ=$(grep '"versionCode"' update.json | sed 's/.*": *//;s/[^0-9].*//')
bar; [ "$VP" = "$VJ" ] && ok "version matches ($VP)" || fail "version mismatch: prop=$VP json=$VJ"
bar; [ "$VC" = "$CJ" ] && ok "versionCode matches ($VC)" || fail "versionCode mismatch: prop=$VC json=$CJ"

# README markers for CI
bar; grep -q '<!-- VERSION_BADGE_START -->'   README.md && ok "VERSION_BADGE marker"   || fail "VERSION_BADGE marker missing"
bar; grep -q '<!-- INSTALL_ONELINER_START -->' README.md && ok "INSTALL_ONELINER marker" || fail "INSTALL_ONELINER marker missing"

# customize.sh covers all three binaries
bar; grep -q 'system/bin/ns'    customize.sh && ok "customize.sh sets ns"    || fail "customize.sh missing ns"
bar; grep -q 'system/bin/child' customize.sh && ok "customize.sh sets child" || fail "customize.sh missing child"

# Controller exports required vars
for v in TXSU_UID TXSU_CONTEXT TXSU_GROUPS TXSU_HOME TXSU_PREFIX TXSU_DATA; do
    bar; grep -q "export $v=" system/bin/txsu && ok "txsu exports $v" || fail "txsu missing export $v"
done

# ns reads required vars
for v in TXSU_UID TXSU_GROUPS TXSU_CONTEXT TXSU_HOME; do
    bar; grep -q "$v" system/bin/ns && ok "ns uses $v" || fail "ns missing $v"
done

# child reads required vars and calls login
bar; grep -q 'TXSU_DATA'   system/bin/child && ok "child uses TXSU_DATA"   || fail "child missing TXSU_DATA"
bar; grep -q 'termux.env'  system/bin/child && ok "child sources termux.env" || fail "child missing termux.env"
bar; grep -q 'bin/login'   system/bin/child && ok "child calls login"      || fail "child missing login call"

# No stale libtxsu-fscreate in script
bar; grep -q 'libtxsu-fscreate' system/bin/txsu && fail "stale fscreate lib in txsu" || ok "no stale fscreate lib"

# unshare in controller
bar; grep -q 'unshare' system/bin/txsu && ok "txsu calls unshare" || fail "txsu missing unshare"

# rslave in ns
bar; grep -q 'rslave' system/bin/ns && ok "ns does rslave" || fail "ns missing rslave"

# -Z in ns (SELinux context switch)
bar; grep -q '\-Z' system/bin/ns && ok "ns passes -Z context" || fail "ns missing -Z"

printf "\r%-60s\n\n" " "
printf "${B}Results: ${G}%d passed${N}  ${RED}%d failed${N}  ${Y}%d warnings${N}  (%d total)\n" \
    "$PASS" "$FAIL" "$WARN" "$((PASS+FAIL+WARN))"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
