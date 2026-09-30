## v1.8

- fix: set fscreate before exec so all file creates get correct SELinux app_data_file context (f27b2d8)

## v1.7

- fix: wrap chsh to restore SELinux MCS context on ~/.termux/shell (89dad06)
- docs: fix unsourced/stale claims (termux-exec, Play Store, networking, storage, LANG, GID rationale) (39f7b7b)

## v1.6

- docs: align README with script (soft SGID, -c mode, PATH, env claims); fix LANG default expansion (6227c11)

## v1.5

- feat: -c passthrough, soft SGID, TERMUX__UID fix, SUPP_GROUPS cleanup (c342cec)

## v1.5

- feat: add `-c` command passthrough for non-interactive use (`txsu -c "cmd"`)
- fix: `SGID` (`/storage`) is now a soft failure — warns and continues instead of dying
- fix: `TERMUX__UID` now uses pre-computed `$TUID` directly instead of a subshell `$(id -u)`
- fix: `$SUPP_GROUPS` built dynamically; intentional unquoted word splitting documented
- docs: update README to reflect all of the above

## v1.4

- fix: remove tsu alias (conflicts with tsu tool) (35f8f4e)
- docs: restore static badges outside VERSION_BADGE block, add aliases table (4dd9f23)

## v1.3

- chore: trigger release (19cc4f1)
- fix: awk must print VERSION_BADGE_END marker, not consume it (5db2f21)
- fix: restore VERSION_BADGE_END marker (8e82f46)
- fix: set txsu executable (644->755), add aliases termsu termux txsh tsu trmx via customize.sh (ee9392d)
- chore: trigger release build (bd41b4d)
- docs: bump README to v1.3, add VERSION_BADGE_END marker (8f1fa4f)
- fix: add missing update-binary (Magisk module_installer.sh) required for valid flashable zip (a1c1a38)

## v1.2

- fix: module id -> TermuxSu to match repo name, fix artifact naming, fix root context wording (0d0dcd8)
- fix: remove misleading app names from root context description (ac834ba)
- fix: remove SSH references, declarative subtitle, correct sudo/tsu claim, ANDROID_ASSETS note, LD_LIBRARY_PATH wording (af97ce5)
- fix: clean header — remove ASCII art, remove SSH, proper HTML, fix subtitle (fe6eed8)
- fix: replace broken SVG title with ASCII+h1, fix badges, add author (eba3362)

## v1.1

- feat: add CI release pipeline, update.json, CHANGELOG, fix README header and install section (834ed6e)
- docs: fix header sizing, upgrade env construction to tables (ec8273c)
- docs: clarify chsh mechanism in prerequisite note (c054872)
- docs: add try-now one-liner and two permanent install methods (4166c40)
- fix: correct 6 factual errors in script and docs (633e75d)
- feat: shell fallback (zsh→bash); docs: full flowchart README rewrite (3a227fb)
- docs: restructure README for public audience (c97b9c6)
- chore: update module description (8b0e4d2)
- chore: remove unused sepolicy.rule — inet group fix made it unnecessary (858192d)
- docs: remove SELinux section — not used, not proven necessary (6095374)
- docs: rich hurdle 4 — PATH duplication proof, ZDOTDIR, login shell, sudo fix (2592dec)
- docs: rich hurdle 3 — live device proof, group table, stat-based detection rationale (cbc65ea)
- docs: rich hurdle 2 — full network stack analysis, DNS failure breakdown, correct fix (47df969)
- docs: rich hurdle 1 — full flowcharts, failure table, design rationale (6126afe)
- docs: rich README with all 4 hurdles fully documented (e9121cd)
- feat: final txsu from ChatGPT log + docs — README.md (630cd2c)
- feat: final txsu from ChatGPT log + docs — system/bin/txsu (bd0da6e)
- feat: fresh rebuild — README.md (8390f22)
- feat: fresh rebuild — META-INF/com/google/android/updater-script (ab0bf6b)
- feat: fresh rebuild — sepolicy.rule (55c9d12)
- feat: fresh rebuild — module.prop (a22162d)
- feat: fresh rebuild — system/bin/txsu (8d44753)
- chore: nuke update.json (22adefe)
- chore: nuke system/bin/txsu (b670c61)
- chore: nuke service.sh (193702c)
- chore: nuke sepolicy.rule (ef2d91d)
- chore: nuke module.prop (f547480)
- chore: nuke README.md (15fcb93)
- chore: nuke META-INF/com/google/android/updater-script (92af307)
- chore: nuke META-INF/com/google/android/update-binary (4ab236d)
- chore: nuke CHANGELOG.md (b33f58f)
- chore: nuke .gitignore (1ad5721)
- chore: nuke .github/workflows/release.yml (0f462b9)

## v1.0

- Initial release
- Shell detection: reads ~/.termux/shell, falls back to bash then zsh
- Dynamic GID detection via stat for inet and storage groups
- ZDOTDIR only set for zsh + XDG layout users
- Uses libtermux-exec.so (stable symlink) for LD_PRELOAD
- Removes hardcoded TERMUX__USER_ID
