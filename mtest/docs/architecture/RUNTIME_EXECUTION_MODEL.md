# RUNTIME_EXECUTION_MODEL.md

## 1. Purpose

This document defines the runtime execution model for the MQTT broker.

Its goals are to:
- prevent `broker_core` from becoming a God object
- separate state transitions from side effects
- define a single-writer ownership model for mutable runtime state

This document aligns with:
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/architecture/EVENT_CONTRACTS.md`
- `docs/architecture/DEPENDENCY_RULES.md`

---

## 2. Core execution principle

Recommended model:
- `commands/events in`
- `state transition`
- `effect plan out`
- `effect execution outside the core reducer path`

This means:
- core decides what must happen
- runtime/adapters execute side effects
- effect completion returns as an explicit event/result

---

## 3. Single-writer policy

Authoritative mutable runtime state must have one writer within one logical execution path.

This is required for:
- deterministic transitions
- easier reasoning about ordering
- easier host-side testing

Forbidden:
- multiple independent writers for session/QoS/routing state without an explicit coordination model
- hidden mutation from adapter callbacks

---

## 4. Runtime roles

### 4.1. Core reducer

The reducer:
- accepts a validated command/event
- reads current state
- returns an updated state fragment or transition result
- produces an effect plan

### 4.2. Effect executor

The executor:
- performs transport/storage/logging/federation side effects
- must not make policy decisions instead of the reducer
- returns completion/error events to the runtime flow

### 4.3. Event bus or event sink

Event publication:
- must be explicit
- may be a synchronous local bus or a deterministic sink
- must not create a hidden reentrant mutation path into core

---

## 5. Side-effect boundaries

Side effects include:
- transport send/close
- persistence write/load
- metrics/logging/tracing emission
- federation forward
- timer/retry scheduling

The core path must not:
- perform blocking I/O
- directly own scheduler/timer primitives
- hide retry loops inside state-transition logic

---

## 6. Ordering rules

Deterministic ordering must be guaranteed for:
- connect
- subscribe/unsubscribe
- publish
- QoS retry/ack
- disconnect
- session cleanup

When an effect completes asynchronously:
- completion must return as an explicit event/result
- the subsequent state update must not be an implicit callback mutation

---

## 7. Module consequences

`broker_core`:
- coordinates the flow, but must not own all projection/mapping helpers inline

`protocol_mqtt`:
- prepares commands/events, but does not execute orchestration policy

`routing`, `acl`, `session`, `qos`, `retained`:
- must have deterministic contracts
- must not launch runtime side effects implicitly

---

## 8. Testability rules

The execution model must allow:
- reducer tests without ESP-IDF/runtime threads
- a fake effect executor
- fake clock/timer signals
- deterministic verification of effect-plan ordering
- replay tests for command/event sequences

---

## 9. Anti-patterns

Forbidden:
- callback-driven hidden state mutation
- blocking storage/network I/O inside reducer logic
- mixing inline DTO mapping and orchestration in one runtime class
- ad-hoc retry loops without an explicit state/effect model
