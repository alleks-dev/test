# ARCH_COMPLIANCE_MATRIX.md

## 1. Purpose

This document defines the machine-checkable architecture invariants for the ESP32-S3 MQTT broker.

Its goals are to:
- turn architecture rules into enforceable gates
- provide stable `rule_id` values for CI, review, and exception handling
- reduce architectural drift as the codebase grows

This document aligns with:
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DEPENDENCY_RULES.md`
- `docs/governance/CI_RULES.md`
- `docs/governance/ADR_EXCEPTIONS.md`
- `docs/governance/ARCH_CHECKS.md`

---

## 2. Severity policy

- `blocker`: merge must be blocked on PR
- `major`: merge may be allowed only through an explicit exception
- `minor`: fix in the same PR where practical, otherwise track explicitly

No violation should exist without a `rule_id`.

---

## 3. Compliance matrix

| Rule ID | Invariant | Scope | Severity | Primary enforcement |
|---|---|---|---|---|
| `ARCH-001` | `core` must not include ESP-IDF, FreeRTOS, lwIP, NVS, or socket headers | core modules | blocker | `scripts/check_arch_invariants.sh`, CI |
| `ARCH-002` | `core` must not depend on concrete adapters | core modules | blocker | `scripts/check_arch_invariants.sh`, review |
| `ARCH-003` | `ports` must not include platform-specific headers or types | ports/public API | blocker | `scripts/check_arch_invariants.sh`, header compile checks |
| `ARCH-004` | `app_main` and runtime must be the composition root, not a policy engine | app/runtime | blocker | review, runtime checks |
| `ARCH-005` | `protocol_mqtt` must not orchestrate routing/ACL/session logic | protocol | major | review, integration tests |
| `ARCH-006` | `routing` may depend only on `ISubscriptionIndex`, `IAclPolicy`, `IRouterPolicy`, and domain types | routing | blocker | `scripts/check_arch_invariants.sh`, tests |
| `ARCH-007` | test-only access to production internals must be exposed through separate `*_test_access.hpp` headers | headers/tests | major | review, header layout checks |
| `ARCH-008` | macro-gated test hooks in production public headers are forbidden | public headers | blocker | grep-based checks, review |
| `ARCH-009` | all public headers must compile standalone in a host environment | ports/core public API | blocker | CI header compile target |
| `ARCH-010` | every deviation from the matrix must have an ADR-style exception with owner, expiry, and rollback plan | whole repo | blocker | review, ADR registry |
| `ARCH-011` | `docs/architecture/CONFIG_SCHEMA.md`, `docs/architecture/ERROR_MODEL.md`, and `docs/architecture/MODULE_CONTRACTS.md` are the source of truth for runtime contracts | config/core contracts | major | review, tests |
| `ARCH-012` | new behavior must not be merged without corresponding unit/integration tests or compile checks | whole repo | blocker | CI, review |
| `ARCH-013` | event emission must be deterministic and testable through an explicit event sink/capture seam | core/event model | major | tests, review |
| `ARCH-014` | memory limits and config limits must not be bypassed through hardcoded local overrides | runtime/config | major | config validation, review |
| `ARCH-015` | the team workflow must run architecture checks locally before PR | developer workflow | minor | `docs/governance/TEAM_WORKFLOW.md`, review |
| `ARCH-016` | app-facing runtime APIs must not expose mutable live state; snapshots/DTOs are required | app/runtime/read models | major | review, tests |
| `ARCH-017` | async operations must have explicit request/result identity and a terminal status | runtime/admin operations | major | review, tests |
| `ARCH-018` | state transition logic and side effects must be separated by an execution-model boundary | core/runtime | major | review, tests |

---

## 4. Mapping to checks

- `ARCH-001`, `ARCH-002`, `ARCH-003`, `ARCH-006`, and `ARCH-008` must be checked automatically via `scripts/check_arch_invariants.sh`
- `ARCH-009` must be checked by a dedicated header-compile target in CI
- `ARCH-004`, `ARCH-005`, `ARCH-011`, `ARCH-013`, and `ARCH-014` require review and tests, not only grep/static checks
- `ARCH-010` is enforced through `docs/governance/ADR_EXCEPTIONS.md`

---

## 5. Violation reporting contract

Every violation must contain:
- `rule_id`
- affected module/file
- short message
- suggested remediation

Example format:

```text
[ARCH-001] blocker: core module includes platform header
file: components/routing/include/routing.hpp
detail: found include <freertos/FreeRTOS.h>
fix: move platform dependency into the adapter or runtime layer
```

---

## 6. Exception policy binding

Exceptions are allowed only if:
- there is a record in `docs/governance/ADR_EXCEPTIONS.md`
- `rule_id` is specified
- an owner is specified
- an expiry date is specified
- there is a closure plan

Without that, the rule is considered violated, not "temporarily bypassed".
