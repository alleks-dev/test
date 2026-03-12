# TEST_STRATEGY.md

## 1. Purpose

This document defines the testing strategy for the ESP32-S3 MQTT broker with the expected evolution:

- from `single-broker mode`
- to `Primary/Standby`
- and later to `federated multi-broker mode`

Core goals of testing:
- guarantee core-logic stability
- prevent regressions as the architecture grows
- isolate platform-specific risks from domain logic
- make behavior verification reproducible
- detect SRAM/PSRAM, queue, QoS, routing, and federation issues before real hardware deployment

---

## 2. Core testing principles

1. **Core test first**
   - domain logic is verified before the platform

2. **Deterministic over ad-hoc**
   - tests must be reproducible and deterministic

3. **Host-first validation**
   - as much logic as possible is verified without ESP32 hardware

4. **Bounded resource testing**
   - memory, queue, and payload limits are tested explicitly

5. **Regression-safe evolution**
   - adding federation must not break single-broker behavior

6. **Failure paths are first-class**
   - failure scenarios are tested as seriously as happy paths

---

## 3. Testing pyramid

```text
                    +----------------------+
                    |   Soak / Longevity   |
                    +----------------------+
                    | Fault / Chaos / HA   |
                    +----------------------+
                    |  Multi-node Sim      |
                    +----------------------+
                    | Integration Tests    |
                    +----------------------+
                    | Unit / Property      |
                    +----------------------+
```

### Testing levels

- **Unit tests**
  - verification of small rules and state transitions

- **Property tests**
  - invariants checked across many combinations

- **Integration tests**
  - verification of interaction across modules

- **Simulation tests**
  - verification of multi-node/federation scenarios

- **Fault/chaos tests**
  - verification of failures, reordering, duplicates, and disconnects

- **Soak tests**
  - verification of leaks, degradation, and accumulated errors

---

## 4. Testing scope

### What must always be tested

- topic matching
- subscription index behavior
- router policy behavior
- routing decisions
- ACL decisions
- retained semantics
- QoS1 state machine
- session lifecycle
- queue overflow behavior
- reconnect behavior
- persistence restore
- federation metadata propagation
- anti-loop / dedup behavior
- read-model snapshot behavior
- reducer/effect flow behavior
- async operation lifecycle behavior

### What must never be considered “sufficiently verified” without tests

- delivery ordering
- behavior under repeated publish operations
- timeout/retry behavior
- bridge/federation behavior
- restart/recovery behavior
- memory and queue limit enforcement
- snapshot consistency for app-facing APIs
- explicit async completion/timeout behavior

---

## 5. Test-scope separation

### 5.1. Host-side tests

Run without ESP32 and cover:
- domain logic
- subscription index
- router policy
- routing
- retained
- QoS transitions
- dedup
- ACL
- federation policies
- config validation
- config version migration
- read-model builders/coordinator
- reducer/effect execution logic
- async operation result store

This is the primary fast-feedback loop.

---

### 5.2. Platform integration tests

Run with ESP-IDF or the platform adapter layer and cover:
- transport adapter
- timers
- storage backends
- reconnect behavior
- task coordination
- platform error propagation

---

### 5.3. Hardware tests

Run on real ESP32-S3 hardware and cover:
- Wi-Fi instability
- memory pressure
- task-scheduling side effects
- actual throughput/latency
- watchdog interactions
- flash/NVS persistence behavior

---

## 6. Unit tests

Unit tests must be the largest class of tests.

### 6.1. Topic matching

Verify:
- exact match
- single-level wildcard
- multi-level wildcard
- empty segments
- invalid filters
- namespace edge cases

### 6.2. Routing engine

Verify:
- local delivery
- multiple matching subscriptions
- no matches
- route policy allow/deny
- local-only topics
- remote-exportable topics

### 6.3. Subscription index

Verify:
- add/remove subscription
- duplicate subscription handling
- owner-based lookup
- wildcard index correctness
- restore consistency after session resume
- local vs remote subscription ownership

### 6.4. Router policy

Verify:
- allow/deny route decisions
- local-only topic enforcement
- remote-export eligibility
- policy behavior for remote-origin messages
- policy behavior under scoped namespaces

### 6.5. Retained store

Verify:
- retained creation
- retained overwrite
- retained deletion through empty payload
- retained delivery to a new subscriber
- scoped retained policy

### 6.6. QoS1 state machine

Verify:
- publish accepted
- inflight registration
- ack completion
- retry after timeout
- duplicate handling
- cleanup after disconnect

### 6.7. Session manager

Verify:
- new session creation
- clean session behavior
- persistent session resume
- subscription restore
- inflight metadata restore
- cleanup rules

### 6.8. ACL engine

Verify:
- allow publish
- deny publish
- allow subscribe
- deny subscribe
- default deny behavior
- scoped ACL rules

### 6.9. Federation policy

Verify:
- should_forward
- should_drop
- import/export filtering
- scope mapping
- anti-loop markers
- dedup checks

### 6.10. Config versioning

Verify:
- parse current schema version
- migrate previous supported version to current schema
- sequential migration across multiple versions
- reject unsupported future schema version
- reject unsupported legacy schema version
- apply documented defaults only for optional fields
- reject missing required fields after migration

### 6.11. Event model

Verify:
- correct event emission for `ClientConnected`, `ClientDisconnected`, `PublishReceived`
- correct event emission for `SubscriptionAdded`, `SubscriptionRemoved`, `RetainedUpdated`
- correct event emission for `RouteResolved`, `DeliveryRequested`, `ForwardRequested`
- correct event emission for `RemotePublishReceived`
- no unexpected event emission on rejected/failed operations
- correct event payload for IDs, `origin`, `scope`, and route metadata
- deterministic event ordering in single-threaded test scenarios

### 6.12. Read-model behavior

Verify:
- snapshot build for empty state
- snapshot rebuild after relevant state changes
- no live mutable state leakage through app-facing snapshots
- bounded snapshot size under configured limits
- deterministic DTO/view content for the same input state

### 6.13. Reducer and effect flow

Verify:
- a validated command/event produces a deterministic transition result
- the effect plan is emitted explicitly and in deterministic order
- the reducer path does not require real I/O or platform runtime
- effect completion is handled as an explicit event/result, not hidden callback mutation
- no side effects are executed inline when the contract requires planning only

### 6.14. Async-operation behavior

Verify:
- `request_id` generation uniqueness
- queued -> in_progress -> completed flow
- failure flow with explicit terminal status
- timeout flow with a fake clock
- bounded operation-result-store behavior
- completed/expired operation cleanup rules

---

## 7. MQTT 5 readiness tests

This section defines which MQTT 5 capability areas must receive tests during staged rollout.

### 7.1. Must-have later

When these capabilities are introduced, add:
- reason-code correctness tests
- session-expiry behavior tests
- message-expiry propagation/drop tests
- receive-maximum enforcement tests
- maximum-packet-size acceptance/rejection tests
- topic-alias tests if the feature is enabled in a specific profile

### 7.2. Maybe later

If these capabilities are implemented, add:
- user-properties parse/serialize tests
- response-topic / correlation-data mapping tests
- content-type and payload-format-indicator tests
- subscription-identifier propagation tests

### 7.3. Definitely not MVP

The MVP must not require:
- full packet-property matrix tests for every MQTT 5 packet type
- shared-subscription behavior tests
- request/response convenience feature suites
- optimization-only MQTT 5 feature benchmarks without proven need

### 7.4. General rule

Every new MQTT 5 capability must receive:
- unit tests for protocol semantics
- integration tests for broker behavior
- a memory-budget review for `N8R2` and `N16R8` profiles
- regression tests before the feature is enabled by default

---

## 8. Property-based tests

Where there are many combinations, a property-oriented approach is preferred.

### Recommended areas

- topic matching
- subscription filters
- route-decision invariants
- dedup rules
- anti-loop rules
- queue policy correctness

### Example invariants

- a message must not be delivered to a target that ACL forbids
- anti-loop policy must not allow infinite forwarding loops
- retained storage must not contain more than one active value per topic key
- queue size must never exceed the configured limit

---

## 9. Integration tests

Integration tests verify interaction across multiple modules.

### 9.1. Protocol + Session + Routing

Scenarios:
- client connect
- `ClientConnected` emitted
- subscribe
- `SubscriptionAdded` emitted
- subscription index updated
- publish
- `PublishReceived` and `RouteResolved` emitted in deterministic order
- message routed to matching subscribers
- `DeliveryRequested` emitted for resolved local targets
- disconnect
- `ClientDisconnected` emitted

### 9.2. Protocol + Retained

Scenarios:
- publish retained
- new subscriber connects
- retained delivered
- retained updated
- retained deleted

### 9.3. Protocol + QoS1

Scenarios:
- publish with QoS1
- inflight create
- ack received
- inflight cleanup
- timeout then retry

### 9.4. Session + Persistence

Scenarios:
- persist session snapshot
- restart broker
- restore session
- restore subscriptions
- recover retained metadata

### 9.5. Config loader + Validation

Scenarios:
- load current config
- load previous supported config and migrate to current
- reject incompatible config version
- reject invalid normalized config

### 9.6. Read models + runtime facade

Scenarios:
- runtime state changes
- read-model coordinator rebuilds the affected snapshot
- facade returns a stable snapshot
- the caller does not observe live mutable internals
- the snapshot remains bounded under configured limits

### 9.7. Runtime reducer + effect executor

Scenarios:
- a command enters the reducer path
- a deterministic effect plan is produced
- the effect executor performs side effects outside the reducer
- completion/error returns as an explicit event/result
- resulting state and emitted events remain deterministic

### 9.8. Async operation flow

Scenarios:
- the caller submits an async operation
- runtime allocates `request_id`
- the operation result store exposes `queued` / `in_progress`
- completion publishes the final result
- timeout transitions to a terminal timeout state

### 9.9. Routing + Federation policy

Scenarios:
- local-only route
- forward-eligible message
- remote-origin message rejected by anti-loop
- namespace export/import rules
- `ForwardRequested` emitted only when federation policy allows forwarding

### 9.10. Event sequencing and capture

Scenarios:
- rejected publish does not emit delivery/forward events
- retained update emits `RetainedUpdated` exactly once per accepted change
- remote publish path emits `RemotePublishReceived` before forward/delivery decisions
- event capture in tests is deterministic and does not depend on real timing

---

## 10. Simulation tests

Simulation tests are needed for the federation path.

### Minimal simulation harness

Must be able to:
- create node A
- create node B
- create a fake federation link
- control a fake clock
- model packet loss
- model duplicates
- model reordering
- model temporary disconnects

### Scenarios to test

- broker A forwards to broker B
- broker B subscribes and receives a remote message
- duplicate remote publish is dropped
- loop prevention works
- reconnect restores link behavior
- partial topology degradation

---

## 11. Fault and chaos tests

These tests are required for real-world robustness.

### 11.1. Network fault tests

Verify:
- short disconnect
- long disconnect
- reconnect storm
- partial packet loss
- reordering
- delayed ACK

### 11.2. Storage fault tests

Verify:
- failed write
- partial snapshot
- corrupted persisted state
- storage full
- slow storage backend

### 11.3. Memory pressure tests

Verify:
- queue almost full
- retained limit reached
- payload too large
- PSRAM exhaustion
- SRAM budget crossing
- allocator fragmentation symptoms

### 11.4. Federation fault tests

Verify:
- broker link down
- broker link returns stale data
- duplicated subscription announcements
- repeated remote reconnects
- partial topology visibility

---

## 12. Soak and longevity tests

These tests must run for a long duration.

### Goals

- detect memory leaks
- detect state accumulation bugs
- detect stuck inflight items
- detect route-table growth bugs
- verify reconnect stability

### Minimum durations

- 1 hour - smoke longevity
- 8 hours - nightly soak
- 24 hours - pre-release soak
- 72 hours - architecture milestone soak

### Collect during soak tests

- heap usage
- high-water marks
- queue occupancy
- reconnect counts
- retry counts
- dedup drops
- retained count stability
- session count stability

---

## 13. Performance tests

Performance tests do not replace correctness tests.

### What to measure

- publish latency
- end-to-end delivery latency
- throughput
- queue growth rate
- reconnect recovery time
- retained lookup time
- routing cost vs subscription count

### Measure separately

- single-broker mode
- broker under memory pressure
- broker with persistence enabled
- federated forwarding mode

---

## 14. Memory-focused tests

Because the platform is resource-constrained, memory is part of the contract.

### 14.1. SRAM tests

Verify:
- usage after startup
- usage under active subscriptions
- usage under QoS1 load
- high-water mark under reconnects

### 14.2. PSRAM tests

Verify:
- retained storage growth
- queue slab usage
- payload buffering pressure
- snapshot buffer pressure

### 14.3. Budget assertions

Tests must contain threshold assertions for:
- max clients budget
- max retained budget
- max queue depth budget
- max payload budget

---

## 15. Regression test suites

After every discovered bug, a regression test must be added.

### Mandatory rule

Every fixed bug must have:
- a short scenario description
- a minimal reproducible test
- the expected correct behavior

### Regression categories

- protocol
- routing
- retained
- QoS
- persistence
- federation
- memory
- reconnect
- ACL

---

## 16. Test-data strategy

### Test data must be

- small for unit tests
- representative for integration tests
- parameterized for property tests
- controlled for deterministic replay

### Required datasets

- valid topic cases
- invalid topic cases
- ACL matrices
- retained overwrite cases
- QoS retry cases
- federation dedup cases

---

## 17. Clock and timing strategy

### Forbidden

- real `sleep()` in most unit/integration tests
- non-deterministic timeout waiting without explicit time control

### Required

- injectable clock
- manual time advance
- explicit timeout triggers
- reproducible scheduling

This is critical for:
- QoS retry
- reconnect logic
- session timeout
- federation link recovery

---

## 18. CI strategy

### On every PR

Run:
- unit tests
- static checks
- config validation
- config migration tests
- core integration tests
- read-model tests
- reducer/effect-flow tests
- async-operation tests

### Nightly

Run:
- extended integration tests
- simulation tests
- memory budget tests
- short soak tests

### Before release

Run:
- full regression suite
- hardware integration suite
- long soak tests
- performance baselines
- federation fault scenarios

---

## 19. Hardware test matrix

Minimum required hardware targets:
- ESP32-S3 `N8R2`
- ESP32-S3 `N16R8`

### On each platform verify

- single broker
- retained-heavy load
- QoS1 load
- reconnect storms
- persistence restore
- basic bridge/federation mode

### Specifically for `N8R2`

- tighter memory limits
- smaller queue budgets
- retained pressure
- PSRAM sensitivity

### Specifically for `N16R8`

- larger retained sets
- deeper queues
- standby/federation scenarios
- longer soak modes

---

## 20. Observability requirements for tests

To make tests useful, the system must provide:
- counters
- event traces
- structured logs
- memory high-water marks
- queue fill telemetry
- retry counters
- dedup counters
- route-decision traces

Without this, fault and soak tests are hard to analyze.

---

## 21. Testability requirements for code

Code is considered testable if:

1. Core runs without ESP-IDF runtime.
2. Clock can be substituted.
3. Storage can be substituted.
4. Transport can be substituted.
5. Federation link can be substituted.
6. Memory budgets can be observed.
7. Logs/metrics are accessible from tests.

---

## 22. Definition of Done for the testing strategy

The testing strategy is considered implemented if:

1. There is full unit coverage for critical core logic.
2. There are integration tests for session/QoS/retained/routing.
3. There are dedicated test areas for read models, reducer/effect flow, and async operations.
4. There are simulation tests for broker link and federation.
5. There are fault tests for reconnect, storage, and memory pressure.
6. There are soak tests of at least 24 hours before release.
7. There are separate budgets and threshold checks for `N8R2` and `N16R8`.
8. Every bug has a regression test.

---

## 23. Summary

A good testing strategy for this project is not just a set of tests, but a multi-layer verification system where:
- core logic is tested extensively on a host machine
- platform-specific risks are verified separately
- federation is introduced through simulation before real hardware
- failure scenarios are tested as seriously as happy paths
- memory, queues, retry, and reconnect are treated as part of the system contract

This approach makes it possible to grow safely from `single-broker mode` to `federated multi-broker mode` without losing stability.
