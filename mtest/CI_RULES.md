# CI_RULES.md

## 1. Мета

Цей документ фіксує обов’язкові CI правила для MQTT-брокера на ESP32-S3.

Його цілі:
- зробити архітектурні правила enforceable
- захистити core від platform leakage і dependency drift
- забезпечити швидкий feedback loop для skeleton/core development

Документ узгоджується з:
- `TEST_STRATEGY.md`
- `DEPENDENCY_RULES.md`
- `SKELETON_PLAN.md`
- `CODING_GUIDELINES.md`

---

## 2. Основні принципи CI

- CI повинен перевіряти не тільки correctness, а і architectural conformance
- host-side checks є обов’язковими з першого milestone
- будь-яка нова поведінка повинна супроводжуватися tests або compile checks
- checks повинні бути достатньо швидкими на PR і глибшими на nightly/release

---

## 3. Pipeline levels

Визначаємо три рівні:
- `PR`
- `Nightly`
- `Pre-release`

---

## 4. PR checks

Кожен pull request повинен запускати:

### 4.1. Build and compile

- host build for domain/core/ports
- compile of public headers
- compile of test targets

### 4.2. Static and style checks

- formatting check
- basic lint/static checks
- forbidden include/dependency checks

### 4.3. Tests

- unit tests
- config validation tests
- config migration tests
- event capture/tests relevant to changed module

### 4.4. Architecture checks

- no `core -> adapter` dependency
- no `core -> ESP-IDF` include leakage
- no `ports -> platform headers`
- CMake dependency graph does not violate `DEPENDENCY_RULES.md`

---

## 5. Nightly checks

Nightly pipeline повинен запускати все з `PR` плюс:

- extended integration tests
- simulation tests
- memory budget tests
- queue/limit tests under pressure
- error-model regression tests
- MQTT 5 readiness tests for implemented features
- short soak/longevity tests

---

## 6. Pre-release checks

Pre-release pipeline повинен запускати все з `Nightly` плюс:

- long soak tests
- hardware integration suite
- persistence recovery suite
- performance baseline verification
- degraded/fault scenarios
- N8R2 and N16R8 profile validation

---

## 7. Merge-blocking rules

Merge must be blocked if any of the following fail:
- host build
- unit tests
- config migration tests
- forbidden dependency/include checks
- public headers compile
- changed module has no corresponding test/compile coverage where required

---

## 8. Required architectural checks

CI повинен мати явні checks на:
- `core` does not include adapter headers
- `core` does not include ESP-IDF headers
- `ports` does not include platform headers
- `protocol_mqtt` does not depend on routing/acl/session/storage adapters
- `routing` does not depend on transport/storage adapters
- `main`/runtime is the composition root, not a policy engine

---

## 9. Required test groups

### 9.1. Core correctness

- topic matching
- subscription index
- router policy
- ACL default deny
- retained semantics
- QoS timeout/retry with fake clock
- config schema parse/migration
- event model emission/order

### 9.2. Integration

- protocol + session + routing
- config loader + validation
- routing + federation policy
- session + persistence

### 9.3. Resource safety

- queue limits
- payload/topic limits
- retained limits
- SRAM/PSRAM budget assertions where measurable

---

## 10. Public API checks

CI повинен перевіряти, що:
- all public headers compile standalone in host environment
- no platform-specific type leaks through public headers
- public API names remain stable or are changed intentionally with review

---

## 11. Event and observability checks

Для модулів, які змінюють event-emission behavior, CI повинен запускати:
- event emission tests
- event ordering tests where relevant
- no-unexpected-event tests on reject/error paths

Для модулів, які вводять нові error paths або limits, CI повинен перевіряти:
- log/metric hooks exist where required
- stable error/status codes remain testable

---

## 12. Memory and config checks

CI повинен перевіряти:
- config fields required by `CONFIG_SCHEMA.md`
- budget constraints from `MEMORY_BUDGETS.md`
- no profile exceeds declared hard limits

Nightly/pre-release additionally:
- profile-specific behavior for `n8r2`
- profile-specific behavior for `n16r8`

---

## 13. Skeleton-phase rules

Поки проект на skeleton stage, PR CI мінімально повинен гарантувати:
- all declared components compile
- all declared headers compile
- fake test adapters compile
- first 10 tests from `SKELETON_PLAN.md` stay green once introduced

At skeleton phase it is acceptable that:
- many APIs still return `ERR_UNSUPPORTED_FEATURE`

But it is not acceptable that:
- not-implemented code pretends success
- architectural rules are bypassed “temporarily”

---

## 14. Failure reporting policy

CI failure output повинно чітко показувати:
- which check failed
- whether failure is compile/test/style/dependency/category
- which module/component is affected

Avoid:
- one giant opaque CI step
- mixing unrelated checks into one unlabelled job

---

## 15. Review policy

Reviewer should not approve if CI is green but:
- dependency violation is known and ignored
- tests are clearly missing for changed behavior
- compile checks do not cover changed public API

Green CI is necessary, not sufficient.

---

## 16. Definition of Done

CI rules вважаються прийнятими, якщо:
- PR checks protect host-side correctness and architecture boundaries
- Nightly checks cover simulation/resource regressions
- Pre-release checks cover soak/hardware/performance gates
- merge-blocking conditions are explicit
- CI enforces documentation contracts instead of merely describing them
