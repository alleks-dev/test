# CI_RULES.md

## 1. Purpose

This document defines the mandatory CI rules for the ESP32-S3 MQTT broker.

Its goals are to:
- make architecture rules enforceable
- protect `core` from platform leakage and dependency drift
- provide a fast feedback loop for skeleton and core development

This document aligns with:
- `docs/testing/TEST_STRATEGY.md`
- `docs/architecture/DEPENDENCY_RULES.md`
- `docs/planning/SKELETON_PLAN.md`
- `docs/architecture/CODING_GUIDELINES.md`
- `docs/governance/ARCH_COMPLIANCE_MATRIX.md`
- `docs/governance/ADR_EXCEPTIONS.md`
- `docs/governance/ARCH_CHECKS.md`
- `docs/architecture/READ_MODEL_STRATEGY.md`
- `docs/architecture/RUNTIME_EXECUTION_MODEL.md`
- `docs/architecture/ASYNC_OPERATION_MODEL.md`

---

## 2. Core CI principles

- CI must verify not only correctness, but also architecture conformance
- host-side checks are mandatory from the first milestone
- every new behavior must come with tests or compile checks
- checks should be fast enough for PRs and deeper for nightly/release pipelines

---

## 3. Pipeline levels

We define three levels:
- `PR`
- `Nightly`
- `Pre-release`

---

## 4. PR checks

Every pull request must run:

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
- event capture/tests relevant to the changed module

### 4.4. Architecture checks

- no `core -> adapter` dependency
- no `core -> ESP-IDF` include leakage
- no `ports -> platform headers`
- CMake dependency graph does not violate `docs/architecture/DEPENDENCY_RULES.md`
- `scripts/check_arch_invariants.sh` passes
- violations are reported with stable `rule_id`
- `scripts/run_blocking_local_checks.sh` remains aligned with the documented local bundle

---

## 5. Nightly checks

Nightly must run everything from `PR` plus:
- extended integration tests
- simulation tests
- memory budget tests
- queue/limit tests under pressure
- error-model regression tests
- MQTT 5 readiness tests for implemented features
- short soak/longevity tests

---

## 6. Pre-release checks

Pre-release must run everything from `Nightly` plus:
- long soak tests
- hardware integration suite
- persistence recovery suite
- performance baseline verification
- degraded/fault scenarios
- `N8R2` and `N16R8` profile validation

---

## 7. Merge-blocking rules

Merge must be blocked if any of the following fail:
- host build
- unit tests
- config migration tests
- forbidden dependency/include checks
- public headers compile
- changed module has no corresponding test/compile coverage where required
- a blocker-rule violation has no approved exception in `docs/governance/ADR_EXCEPTIONS.md`

---

## 8. Required architecture checks

CI must have explicit checks for:
- `core` does not include adapter headers
- `core` does not include ESP-IDF headers
- `ports` does not include platform headers
- `protocol_mqtt` does not depend on routing/ACL/session/storage adapters
- `routing` does not depend on transport/storage adapters
- `main`/runtime is the composition root, not a policy engine
- production public headers do not contain macro-gated test hooks
- test-only runtime access is exposed only through dedicated `*_test_access.hpp` seams where needed
- app-facing APIs return snapshots/bounded results instead of live mutable runtime state where applicable
- async runtime operations use explicit request/result identity where applicable

Every architecture failure must reference a `rule_id` from `docs/governance/ARCH_COMPLIANCE_MATRIX.md`.

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
- read-model snapshot build/rebuild correctness
- reducer/effect plan determinism
- async operation request/result lifecycle

### 9.2. Integration

- protocol + session + routing
- config loader + validation
- read models + runtime facade
- runtime reducer + effect executor
- async operation flow
- routing + federation policy
- session + persistence

### 9.3. Resource safety

- queue limits
- payload/topic limits
- retained limits
- SRAM/PSRAM budget assertions where measurable

---

## 10. Public API checks

CI must verify that:
- all public headers compile standalone in a host environment
- no platform-specific type leaks through public headers
- public API names remain stable or are changed intentionally with review

---

## 11. Event and observability checks

For modules that change event-emission behavior, CI must run:
- event emission tests
- event ordering tests where relevant
- no-unexpected-event tests on reject/error paths

For modules that introduce new error paths or limits, CI must verify:
- log/metric hooks exist where required
- stable error/status codes remain testable

---

## 12. Memory and config checks

CI must verify:
- config fields required by `docs/architecture/CONFIG_SCHEMA.md`
- budget constraints from `docs/architecture/MEMORY_BUDGETS.md`
- no profile exceeds declared hard limits

Nightly/pre-release additionally:
- profile-specific behavior for `n8r2`
- profile-specific behavior for `n16r8`

---

## 13. Skeleton-phase rules

While the project is still in the skeleton stage, PR CI must minimally guarantee:
- all declared components compile
- all declared headers compile
- fake test adapters compile
- the first 10 tests from `docs/planning/SKELETON_PLAN.md` stay green once introduced

At the skeleton phase it is acceptable that:
- many APIs still return `ERR_UNSUPPORTED_FEATURE`

But it is not acceptable that:
- not-implemented code pretends success
- architecture rules are bypassed "temporarily"

---

## 14. Failure reporting policy

CI failure output must clearly show:
- which check failed
- whether the failure is compile/test/style/dependency/category
- which module/component is affected
- which `rule_id` was violated for architecture failures

Avoid:
- one giant opaque CI step
- mixing unrelated checks into one unlabeled job

---

## 15. Review policy

A reviewer should not approve if CI is green but:
- a dependency violation is known and ignored
- tests are clearly missing for changed behavior
- compile checks do not cover changed public API
- an architecture exception is undocumented or expired

Green CI is necessary, not sufficient.

---

## 16. Definition of Done

CI rules are considered established if:
- PR checks protect host-side correctness and architecture boundaries
- Nightly checks cover simulation and resource regressions
- Pre-release checks cover soak, hardware, and performance gates
- merge-blocking conditions are explicit
- CI enforces documentation contracts instead of merely describing them
