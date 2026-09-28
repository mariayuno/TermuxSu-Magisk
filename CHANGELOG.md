## v2.0.4

- fix: add missing setcurrent permission + collapse rules with {} syntax (a8658cd)

## v2.0.3

- docs: add SELinux policy section with security note (8cbdacb)

## v2.0.2

- feat: add sepolicy.rule for runcon transition (all root managers + all SDK variants) (d031dc1)

## v2.0.1

- fix: runcon probe-before-exec fallback + typo guard for utrusted_app (d5b8b99)

## v2.0.0

- fix: support vMAJOR.MINOR.PATCH, smart bump via [major]/[minor] commit flags (e18bf91)
- fix: align update.json version to v1.0.0 (6c5c2b8)
- fix: align version to vMAJOR.MINOR.PATCH format (ccf43c2)
- ci: add autobuild release workflow for TermuxSu-Magisk (850a28a)
- remove test file (49c98c1)
- test .github dir (c178562)
- docs: initial changelog (fe303ff)
- chore: add update.json for module manager OTA (c77a21b)
- docs: add CI marker sections for auto-updating badges and install banner (3b4fe5b)
- txsu: cache layer — instant load from /data/adb/txsu/cache, redetect on stale/version change/UID change/--refresh, fallback to su - (0b96b0f)
- txsu: fully device-agnostic — live proc env, dynamic SELinux, DNS from getprop, no hardcoded values (0ee3e56)
- README: full docs — how it works, compatibility, install (956ea7a)
- update-binary: improved installer UI (998092c)
- service.sh: cleaner with log tag (01dfa0e)
- txsu: full rewrite with real probe data — LD_PRELOAD, UID via ls, DNS guard, arg forwarding (734366a)
- add README (195fdb3)
- add .gitignore (b156cd0)
- add service.sh (c7708d7)
- add system/bin/txsu (1a03982)
- add META-INF/com/google/android/updater-script (cd5be52)
- add META-INF/com/google/android/update-binary (98e72cc)
- add module.prop (b1686c9)
- Initial commit (a7cc81a)

## v1.0

- Initial release
- txsu: invoke Termux shell from root with full context, LD_PRELOAD, SELinux, DNS
- Cache layer at /data/adb/txsu/cache with auto-invalidation
- Fallback to su - when Termux not installed
- Fully device-agnostic: no hardcoded UIDs, contexts, DNS, or shell paths
