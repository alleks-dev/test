# TEAM_WORKFLOW.md

## 1. Purpose

This document defines the practical team workflow around architecture rules, local checks, and PR discipline.

Its goals are to:
- turn the documentation rules into daily engineering practice
- define the minimum local verification bundle before a PR
- tie reviews to `rule_id` values instead of vague expectations

This document aligns with:
- `docs/governance/ARCH_COMPLIANCE_MATRIX.md`
- `docs/governance/CI_RULES.md`
- `docs/planning/SKELETON_PLAN.md`
- `docs/testing/TEST_STRATEGY.md`
- `docs/architecture/READ_MODEL_STRATEGY.md`
- `docs/architecture/RUNTIME_EXECUTION_MODEL.md`
- `docs/architecture/ASYNC_OPERATION_MODEL.md`

---

## 2. Source of truth

The architecture source of truth is:
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/architecture/DEPENDENCY_RULES.md`
- `docs/governance/ARCH_COMPLIANCE_MATRIX.md`
- `docs/architecture/CONFIG_SCHEMA.md`
- `docs/architecture/ERROR_MODEL.md`
- `docs/architecture/EVENT_CONTRACTS.md`
- `docs/architecture/READ_MODEL_STRATEGY.md`
- `docs/architecture/RUNTIME_EXECUTION_MODEL.md`
- `docs/architecture/ASYNC_OPERATION_MODEL.md`

If code or a PR conflicts with these documents, the documents win.

---

## 3. Developer workflow

Before changing code or the skeleton structure, the developer must:
- identify the affected module
- check the relevant contracts and dependency rules
- understand which `rule_id` values may be affected

During the change:
- do not mix architectural refactoring and behavior changes unless necessary
- add tests together with new behavior
- do not introduce undocumented temporary bypasses

After the change:
- run the local check bundle
- verify whether docs/contracts must be updated

---

## 4. Required local verification bundle

Before opening a PR, the developer must run:
- `scripts/run_blocking_local_checks.sh`
- relevant host build targets
- relevant unit tests
- config/schema-related tests if config/runtime was touched
- event tests if event-emission behavior changed

Opening a PR with the assumption that "CI will show it" is not acceptable.

---

## 5. PR policy

Every PR must:
- be narrow in scope
- reference the affected module(s)
- describe either a behavior change or a structure/contract change
- explicitly mention an exception if one is required

If a PR violates a rule from `docs/governance/ARCH_COMPLIANCE_MATRIX.md`, it must include:
- the `rule_id`
- a reference to the entry in `docs/governance/ADR_EXCEPTIONS.md`

---

## 6. Review policy

The reviewer must check:
- whether dependency boundaries are still intact
- whether there is coverage for new behavior
- whether platform code leaked into core/public headers
- whether macro-gated test hooks appeared in production APIs

"Looks fine" is not a sufficient review for rule-sensitive changes.

---

## 7. Definition of Ready

A task is ready for implementation if:
- the affected module set is understood
- the needed contracts/tests are identified
- it is known whether config/error/event models are affected

---

## 8. Definition of Done

A change is complete if:
- local checks passed
- CI rules are satisfied
- affected docs/contracts were updated
- there are no undocumented architecture exceptions

---

## 9. Workflow anti-patterns

Forbidden:
- bypassing a rule "temporarily" without an exception record
- adding behavior without tests
- moving policy logic into `main/app_main`
- changing a public API without compile/test coverage
