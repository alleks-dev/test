# ERROR_MODEL.md

## 1. Purpose

This document defines the canonical error model for the MQTT broker.

Its goals are to:
- provide one consistent approach to errors across modules
- prevent ad-hoc `bool`-style failures and silent fallbacks
- make errors testable, loggable, and suitable for metrics/telemetry

This document aligns with:
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/architecture/CODING_GUIDELINES.md`
- `docs/architecture/CONFIG_SCHEMA.md`
- `docs/testing/TEST_STRATEGY.md`

---

## 2. Core principles

- errors must be explicit
- error contracts must be stable
- policy failures must not be confused with transport/storage failures
- unexpected failures must not be silently downgraded to success-like results
- startup failures and runtime failures must be distinguishable

---

## 3. Canonical model

Use the following canonical concepts:
- `ResultCode`
- `Status`
- `Result<T, E>` or equivalent `Expected<T, E>`-style wrapper

General rule:
- operations that can fail for meaningful reasons must not return plain `bool`

---

## 4. Severity model

Every error should be classifiable by severity:
- `info` or non-failure observation where needed
- `warning`
- `error`
- `critical`

Severity does not replace the result code. It complements it.

---

## 5. Retryability model

Every relevant runtime error should be classifiable as:
- retryable
- non-retryable
- unknown/not-applicable

This is especially important for:
- transport failures
- persistence failures
- federation link failures
- async operation failures

---

## 6. Failure classes

### 6.1. `ValidationError`

Used for:
- invalid config
- malformed input at the contract boundary
- unsupported field combinations
- out-of-range values

### 6.2. `PolicyError`

Used for:
- ACL deny
- route policy deny
- namespace policy violation
- federation export/import deny

### 6.3. `ResourceLimitError`

Used for:
- queue limit reached
- payload too large
- retained/session budget exceeded
- operation result store full

### 6.4. `StorageError`

Used for:
- persistence write failure
- persistence read failure
- corrupted state detection
- snapshot validation failure

### 6.5. `TransportError`

Used for:
- endpoint closed
- send/receive failure
- reconnect failure
- broker-link transport failure

### 6.6. `StateError`

Used for:
- invalid state transition
- inconsistent QoS/session state
- broken invariants that make runtime behavior invalid

### 6.7. `DependencyError`

Used for:
- failure of an injected port/service
- unavailable required dependency
- a missing required runtime seam at startup

---

## 7. Startup error policy

Startup errors must be handled strictly.

Fail fast at startup for:
- invalid normalized config
- incompatible config schema version
- broken invariants that invalidate runtime correctness
- missing required runtime wiring

Do not continue startup in a partially valid state when correctness depends on the missing piece.

---

## 8. Runtime error policy

Runtime error handling should distinguish between:
- fail closed
- controlled degradation
- retryable transient failure
- terminal operation failure

### 8.1. Fail closed

Use for:
- ACL/policy evaluation failure
- unknown authorization state
- impossible namespace/routing decisions where unsafe forwarding could occur

### 8.2. Controlled degradation

Use for:
- optional diagnostics backend failure
- non-critical metrics emission failure
- limited federation-link degradation when local broker correctness remains intact

### 8.3. Retryable transient failure

Use for:
- reconnect attempts
- temporary transport failures
- bounded retry scheduling where the retry model is explicit and testable

### 8.4. Terminal operation failure

Use for:
- async operations that fail definitively
- invalid operation requests
- persistent resource-limit exhaustion without an allowed retry path

---

## 9. Logging and metrics policy for errors

Every important error path should define:
- whether it must be logged
- whether it must increment a metric/counter
- whether it must emit a trace/event for diagnostics

At minimum, the following should be observable:
- startup failures
- policy denials where operationally relevant
- storage failures
- reconnect/retry failures
- queue/memory limit hits
- async operation terminal failures

---

## 10. Adapter translation rules

Adapters may translate platform/library errors into the canonical error model, but they must not:
- leak raw platform error types into core contracts
- collapse all failures into one vague generic error
- pretend success on partial failure

Examples:
- socket/NVS/lwIP errors become `TransportError` or `StorageError`
- adapter-level parse/validation issues become `ValidationError` where appropriate

---

## 11. Config-loader error policy

`config_loader` must distinguish at least:
- parse failure
- migration failure
- unsupported version
- cross-field validation failure
- profile/budget violation

These must be testable independently.

---

## 12. Stable error taxonomy

The error taxonomy must remain stable enough for:
- tests
- logs
- metrics
- CI expectations
- future admin/runtime inspection APIs

That means a result code must not be changed casually if it affects observability or test contracts.

---

## 13. Result-code design guidance

Result codes should be:
- explicit
- domain-meaningful
- stable
- non-overlapping where practical

Bad examples:
- one `ERR_FAILED` for everything
- mixing policy denial and transport failure in the same code

Good examples:
- `ERR_ACL_DENY`
- `ERR_ROUTE_POLICY_DENY`
- `ERR_QUEUE_LIMIT`
- `ERR_STORAGE_WRITE`
- `ERR_TIMEOUT`
- `ERR_UNSUPPORTED_FEATURE`

---

## 14. Test expectations

The error model is incomplete unless tests exist for:
- fail-closed policy behavior
- startup fail-fast behavior
- explicit distinction of validation vs storage vs transport failures
- timeout vs terminal failure behavior for async operations
- stable result-code visibility in logs/metrics where required

---

## 15. Definition of Done for the error model

The error model is considered established if:
- plain `bool` is not the default failure contract for meaningful operations
- failure classes are explicit
- startup/runtime error policies are distinct
- retryability/terminal-state semantics are documented
- adapter translation rules are explicit
- tests can assert meaningful failure categories and result codes
