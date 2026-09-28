## v1.0

- Initial release
- txsu: invoke Termux shell from root with full context, LD_PRELOAD, SELinux, DNS
- Cache layer at /data/adb/txsu/cache with auto-invalidation
- Fallback to su - when Termux not installed
- Fully device-agnostic: no hardcoded UIDs, contexts, DNS, or shell paths
