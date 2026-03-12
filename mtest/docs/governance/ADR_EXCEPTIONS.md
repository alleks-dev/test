# ADR_EXCEPTIONS.md

## 1. Purpose

This document defines a single process for temporary exceptions to architecture rules.

It exists to:
- prevent architectural debt from being hidden as a "temporary solution"
- make exceptions visible and time-bounded
- tie every exception to a concrete `rule_id`

This document aligns with:
- `docs/governance/ARCH_COMPLIANCE_MATRIX.md`
- `docs/governance/CI_RULES.md`
- `docs/governance/TEAM_WORKFLOW.md`

---

## 2. When an exception is allowed

An exception is allowed only if all of the following are true:
- it is required to unblock a real development step
- the temporary deviation is localized
- the impact is understood and documented
- there is a concrete removal plan

An exception is not allowed for:
- vague "we will fix it later"
- convenience without technical justification
- bypassing a `blocker` rule without an owner and expiry

---

## 3. Required fields

Every exception must contain:
- `exception_id`
- `rule_id`
- `status`
- `owner`
- `created_on`
- `expires_on`
- `scope`
- `justification`
- `rollback_plan`
- `verification_plan`

---

## 4. Normative template

```text
exception_id: EXC-YYYY-NN
rule_id: ARCH-000
status: proposed | approved | expired | removed
owner: team-or-person
created_on: YYYY-MM-DD
expires_on: YYYY-MM-DD
scope: module/file/PR scope
justification: short technical reason
rollback_plan: exact removal plan
verification_plan: checks/tests that confirm safe temporary use
```

---

## 5. Approval policy

- `blocker` rules require explicit reviewer approval
- `major` rules require at least one owner and an issue/task reference
- `minor` rules may be accepted only if they do not affect correctness or safety

An exception without `expires_on` is invalid.

---

## 6. Expiry policy

- once `expires_on` is reached, the exception is automatically considered expired
- an expired exception blocks new merges in the affected scope
- extending an exception requires a new review

---

## 7. Registry

There are currently no active exceptions.

When exceptions appear, they must be added below in this document.

---

## 8. Active exceptions

`none`
