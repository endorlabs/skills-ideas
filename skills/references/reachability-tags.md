# Reachability Tags Reference

Endor Labs does NOT use simple `FINDING_TAGS_REACHABLE`/`FINDING_TAGS_UNREACHABLE`. Reachability uses **two dimensions** in `finding_tags`:

## Dependency Reachability
- `FINDING_TAGS_REACHABLE_DEPENDENCY` — code imports/uses this dependency
- `FINDING_TAGS_UNREACHABLE_DEPENDENCY` — code does NOT use this dependency

## Function Reachability
- `FINDING_TAGS_REACHABLE_FUNCTION` — call path exists to vulnerable function
- `FINDING_TAGS_UNREACHABLE_FUNCTION` — no call path to vulnerable function
- `FINDING_TAGS_POTENTIALLY_REACHABLE_FUNCTION` — call path may exist, unconfirmed

## Other Tags
- `FINDING_TAGS_PHANTOM` — in lockfile but not installed
- `FINDING_TAGS_DIRECT` / `FINDING_TAGS_TRANSITIVE` — dependency type
- `FINDING_TAGS_FIX_AVAILABLE` / `FINDING_TAGS_UNFIXABLE` — fix status

## Display Mapping

| Dep Tag | Function Tag | Display As |
|---------|-------------|------------|
| REACHABLE_DEP | REACHABLE_FUNC | **Reachable** |
| REACHABLE_DEP | POTENTIALLY_REACHABLE_FUNC | **Potentially Reachable** |
| REACHABLE_DEP | UNREACHABLE_FUNC | **Dep Used, Func Unreachable** |
| UNREACHABLE_DEP | UNREACHABLE_FUNC | **Unreachable** |
| (PHANTOM) | Any | **Phantom** |
| REACHABLE_DEP | (none) | **Dep Reachable** |
| UNREACHABLE_DEP | (none) | **Dep Unreachable** |

Never report reachability as "undetermined" when these tags are present.
