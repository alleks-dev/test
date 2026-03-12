# ASYNC_OPERATION_MODEL.md

## 1. Purpose

This document defines the asynchronous operation model for the MQTT broker.

Its goals are to:
- make async admin/runtime operations testable and deterministic
- avoid chaotic callback-only APIs
- provide a basis for request/result tracking, polling, and diagnostics

This document aligns with:
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/architecture/ERROR_MODEL.md`
- `docs/architecture/READ_MODEL_STRATEGY.md`
- `docs/architecture/RUNTIME_EXECUTION_MODEL.md`

---

## 2. When an async operation model is required

It is required for operations that:
- do not complete immediately
- depend on transport/storage/runtime scheduling
- may need retry, timeout, or later completion

Examples:
- config apply
- persistence flush/recovery
- bridge/federation reconnect actions
- administrative runtime operations

---

## 3. Core contract

Every asynchronous operation must have:
- `request_id`
- `operation_type`
- `submitted_at`
- current `status`
- optional `result payload`
- optional `error/status code`

Recommended states:
- `queued`
- `in_progress`
- `completed`
- `failed`
- `timed_out`
- `cancelled`

---

## 4. Operation result store

The system must have a separate `operation result store` or equivalent seam that:
- generates `request_id`
- accepts completions/results
- allows bounded query/poll by `request_id`
- does not mix unrelated operation families without reason

This store:
- is not a business-policy engine
- must not know platform details
- must be bounded by config/memory policy

---

## 5. Integration with runtime

Recommended flow:
1. the caller submits an operation
2. runtime validates it and creates a `request_id`
3. an executor/process performs the work
4. completion/error is published back
5. the result store exposes final status to the caller or facade

Async completion must not update caller-visible state "magically" without request/result traceability.

---

## 6. Polling and notification policy

Allowed models:
- bounded polling by `request_id`
- event-driven notification
- hybrid model

Not allowed:
- ad-hoc global flags
- raw pointer callbacks as the only contract
- shared mutable output buffers owned by the caller

---

## 7. Error and timeout rules

Every async operation must have:
- an explicit timeout policy
- an explicit error/status code on failure
- a deterministic terminal state

If completion never arrives:
- the operation transitions to `timed_out`
- the caller must not wait indefinitely

---

## 8. Testability rules

Required tests:
- unique request ID generation
- success/failure completion paths
- timeout transition with a fake clock
- bounded queue/store behavior
- cleanup of completed/expired records

---

## 9. Anti-patterns

Forbidden:
- async APIs without request/result identity
- completion only through logs
- unbounded result queues
- mixing transient operation state with long-lived domain state
