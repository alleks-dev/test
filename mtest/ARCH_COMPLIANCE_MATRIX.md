# ARCH_COMPLIANCE_MATRIX.md

## 1. Мета

Цей документ фіксує machine-checkable архітектурні інваріанти MQTT-брокера для ESP32-S3.

Його цілі:
- перетворити архітектурні правила на enforceable gates
- дати стабільні `rule_id` для CI, review і exception process
- зменшити architectural drift під час росту кодової бази

Документ узгоджується з:
- `ARCHITECTURE.md`
- `DEPENDENCY_RULES.md`
- `CI_RULES.md`
- `ADR_EXCEPTIONS.md`
- `ARCH_CHECKS.md`

---

## 2. Severity policy

- `blocker`: merge must be blocked on PR
- `major`: merge may be allowed only through explicit exception
- `minor`: fix in the same PR where practical, otherwise track explicitly

Будь-яке порушення без `rule_id` не повинно існувати.

---

## 3. Compliance matrix

| Rule ID | Invariant | Scope | Severity | Primary enforcement |
|---|---|---|---|---|
| `ARCH-001` | `core` не включає ESP-IDF, FreeRTOS, lwIP, NVS або socket headers | core modules | blocker | `check_arch_invariants.sh`, CI |
| `ARCH-002` | `core` не залежить від concrete adapters | core modules | blocker | `check_arch_invariants.sh`, review |
| `ARCH-003` | `ports` не включають platform-specific headers або types | ports/public API | blocker | `check_arch_invariants.sh`, header compile checks |
| `ARCH-004` | `app_main` і runtime є composition root, а не policy engine | app/runtime | blocker | review, runtime checks |
| `ARCH-005` | `protocol_mqtt` не оркеструє routing/ACL/session logic | protocol | major | review, integration tests |
| `ARCH-006` | `routing` залежить тільки від `ISubscriptionIndex`, `IAclPolicy`, `IRouterPolicy` і domain types | routing | blocker | `check_arch_invariants.sh`, tests |
| `ARCH-007` | test-only access на production internals робиться через окремі `*_test_access.hpp` headers | headers/tests | major | review, header layout checks |
| `ARCH-008` | macro-gated test hooks у production public headers заборонені | public headers | blocker | grep-based checks, review |
| `ARCH-009` | усі public headers компілюються standalone у host environment | ports/core public API | blocker | CI header compile target |
| `ARCH-010` | будь-яке відхилення від матриці має ADR-style exception з owner, expiry і rollback plan | whole repo | blocker | review, ADR registry |
| `ARCH-011` | `CONFIG_SCHEMA.md`, `ERROR_MODEL.md`, `MODULE_CONTRACTS.md` є source-of-truth для runtime contracts | config/core contracts | major | review, tests |
| `ARCH-012` | нова поведінка не може бути merge-нута без відповідних unit/integration tests або compile checks | whole repo | blocker | CI, review |
| `ARCH-013` | event emission повинна бути deterministic і testable через явний event sink/capture seam | core/event model | major | tests, review |
| `ARCH-014` | memory limits і config limits не можуть обходитися hardcoded local overrides | runtime/config | major | config validation, review |
| `ARCH-015` | team workflow повинен запускати architecture checks локально перед PR | developer workflow | minor | `TEAM_WORKFLOW.md`, review |
| `ARCH-016` | app-facing runtime APIs не повинні розкривати mutable live state; потрібні snapshots/DTOs | app/runtime/read models | major | review, tests |
| `ARCH-017` | async operations повинні мати explicit request/result identity and terminal status | runtime/admin operations | major | review, tests |
| `ARCH-018` | state transition logic and side effects повинні бути розділені execution model boundary | core/runtime | major | review, tests |

---

## 4. Mapping to checks

- `ARCH-001`, `ARCH-002`, `ARCH-003`, `ARCH-006`, `ARCH-008` повинні перевірятися автоматично через `check_arch_invariants.sh`
- `ARCH-009` повинен перевірятися окремим header-compile target у CI
- `ARCH-004`, `ARCH-005`, `ARCH-011`, `ARCH-013`, `ARCH-014` частково вимагають review і tests, а не тільки grep/static checks
- `ARCH-010` перевіряється через `ADR_EXCEPTIONS.md`

---

## 5. Violation reporting contract

Кожне порушення повинно містити:
- `rule_id`
- affected module/file
- short message
- suggested remediation

Приклад формату:

```text
[ARCH-001] blocker: core module includes platform header
file: components/routing/include/routing.hpp
detail: found include <freertos/FreeRTOS.h>
fix: move platform dependency into adapter or runtime layer
```

---

## 6. Exception policy binding

Винятки дозволені лише якщо:
- є запис у `ADR_EXCEPTIONS.md`
- вказано `rule_id`
- вказано owner
- вказано expiry date
- є план закриття винятку

Без цього правило вважається порушеним, а не "тимчасово обійденим".
