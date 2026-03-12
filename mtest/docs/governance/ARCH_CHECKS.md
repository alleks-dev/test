# ARCH_CHECKS.md

## 1. Purpose

This document describes the automated architecture checks for the repository.

Its goals are to:
- make `docs/governance/ARCH_COMPLIANCE_MATRIX.md` executable in practice
- define the minimum local and CI check bundle
- provide the specification for `scripts/check_arch_invariants.sh`

This document aligns with:
- `docs/governance/ARCH_COMPLIANCE_MATRIX.md`
- `docs/governance/CI_RULES.md`
- `docs/governance/TEAM_WORKFLOW.md`

---

## 2. Baseline checks

Minimum automated architecture checks:
- forbidden includes in `core`
- forbidden includes in `ports`
- forbidden `core -> adapter` references
- composition-root checks for `main/app_main`
- macro-gated test hook detection in public headers
- presence and layout checks for `*_test_access.hpp` where test-only access is required

---

## 3. Mapping to rule IDs

- `ARCH-001`: no platform headers in `core`
- `ARCH-002`: no adapter references in `core`
- `ARCH-003`: no platform headers in `ports`
- `ARCH-006`: no routing dependency on transport/storage adapters
- `ARCH-008`: no macro-gated test hooks in production headers

---

## 4. Script contract

`scripts/check_arch_invariants.sh` must:
- exit with `0` when no blocker violations are present
- exit non-zero when blocker violations are found
- print `rule_id`, file path, and a short remediation hint
- run locally without network dependencies
- gracefully skip code-level checks when the skeleton does not exist yet

---

## 5. PR-level expectations

Required at PR level:
- grep/static checks
- header layout checks
- forbidden dependency checks

Nightly/pre-release may additionally include:
- compile graph checks
- richer include dependency analysis
- generated dependency reports

---

## 6. Reporting contract

Check output must be usable for both CI parsing and manual review:

```text
[ARCH-003] blocker: platform header leaked into port
file: components/ports/include/clock_port.hpp
detail: found include <freertos/FreeRTOS.h>
fix: replace with abstract domain or port contract type
```

---

## 7. Future extensions

When the real skeleton exists, add:
- CMake graph validation
- standalone public-header compile job
- per-component include dependency dumps
- optional whitelist/exception integration from `docs/governance/ADR_EXCEPTIONS.md`
