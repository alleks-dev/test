# CODING_GUIDELINES.md

## 1. Purpose

This document defines coding rules for the ESP32-S3 MQTT broker so that the code remains:

- modular
- readable
- testable
- resource-aware
- suitable for evolution from `single-broker mode` to `federated multi-broker mode`

---

## 2. Core principles

1. **Core first, platform second**
2. **Domain model before packet model**
3. **Interfaces before implementations**
4. **Deterministic logic before asynchronous orchestration**
5. **Explicit metadata over hidden assumptions**
6. **Testability is a feature**
7. **Memory placement is part of the design**

---

## 3. General code rules

### 3.1. One module, one responsibility

Every module must have one clear reason to change.

### 3.2. Do not mix abstraction levels

Do not:
- parse an MQTT packet
- update session state
- decide routing
- write to a socket

in a single function.

### 3.3. Minimal global state

Global variables are allowed only for:
- compile-time constants
- platform bootstrap
- very small immutable configuration

### 3.4. Explicit ownership

Every buffer, object, and descriptor must have a clear owner.

---

## 4. Rules for architectural layers

### 4.1. Core

Core must not directly depend on:
- ESP-IDF headers
- FreeRTOS primitives
- lwIP details
- NVS APIs
- socket descriptors

Core depends only on domain interfaces.

### 4.2. Adapters

Adapters:
- translate platform-specific logic into domain interfaces
- do not contain routing business rules or QoS semantics

### 4.3. Application layer

The application layer:
- assembles dependencies
- configures runtime
- wires policy implementations
- does not contain packet-parsing logic

---

## 5. Naming conventions

### 5.1. Types

- `PascalCase` for types and structs
- examples: `BrokerCore`, `MessageView`, `SubscriptionEntry`

### 5.2. Functions

- `snake_case` or one consistent style across the entire project
- examples: `route_publish`, `session_resume`, `retained_store_put`

### 5.3. Interfaces

Use prefix `I`:
- `ITransportEndpoint`
- `IRetainedStore`
- `IFederationLink`

### 5.4. Struct fields

Field names must be short and unambiguous:
- `origin`
- `scope`
- `owner_id`
- `qos`
- `retain`
- `flags`

---

## 6. Function rules

### 6.1. A function should do one thing

Bad:
- parse + validate + route + persist + deliver

Good:
- `parse_publish_packet`
- `validate_publish`
- `route_message`
- `persist_retained_if_needed`
- `schedule_delivery`

### 6.2. Size limits

Preferred:
- 40-60 lines for a normal function
- longer functions only if that genuinely improves readability

### 6.3. Arguments

If there are more than 4-5 arguments:
- group them into a config/context struct

### 6.4. Side effects

Side effects must be obvious from the function name and contract.

---

## 7. Domain model rules

### 7.1. MQTT packet != domain object

Never drag packet-level structures through all layers.

### 7.2. Message metadata are mandatory

Every message must contain:
- `origin`
- `scope`
- `route_flags`
- `timestamp` or equivalent ordering metadata

### 7.3. Subscription metadata are mandatory

A subscription must contain:
- filter
- QoS
- owner type
- owner ID
- federation-related flags

---

## 8. Error handling

### 8.1. No silent errors

Every error must be:
- returned explicitly
- or logged
- or accumulated in metrics

### 8.2. Error codes over ad-hoc booleans

Better:
- `enum ResultCode`
- `Status`
- `Expected<T, E>`

Worse:
- plain `true/false` without context

### 8.3. Fail closed for policy

If ACL/policy cannot be evaluated:
- block by default, do not allow by default

---

## 9. Memory management guidelines

### 9.1. SRAM is for the hot path

Internal RAM should hold:
- frequently accessed indexes
- session control data
- hot routing metadata
- task stacks
- small fixed control structures

### 9.2. PSRAM is for cold/bulk data

PSRAM should hold:
- payload buffers
- retained payload storage
- queue slabs
- diagnostics/history buffers
- large temporary serialization buffers

### 9.3. Uncontrolled allocation is forbidden

Do not:
- use unbounded `malloc/new` in packet paths
- build logic around heap fragmentation

### 9.4. Prefer

- fixed pools
- slab allocators
- bounded ring buffers
- preallocated queues

---

## 10. Concurrency guidelines

### 10.1. Minimize shared mutable state

Where possible, prefer:
- message passing
- command queues
- immutable views

### 10.2. Locking policy

Locking must be:
- short
- localized
- documented

### 10.3. Do not hold a lock during

- network I/O
- storage I/O
- callback execution
- logging with unpredictable latency

### 10.4. Deterministic ordering

Key state transitions must have a predictable order:
- connect
- subscribe
- publish
- ack
- disconnect
- session cleanup

---

## 11. Logging rules

### 11.1. Structured logging

Logs must be machine-useful.

Minimum fields:
- module
- event
- entity ID
- result
- reason/error code

### 11.2. Do not log excessive payload

Do not print full payloads by default.

### 11.3. Trace points

For complex scenarios, add trace events for:
- route decisions
- retained updates
- QoS retransmit
- remote forwarding
- anti-loop drops

---

## 12. Metrics rules

### Minimum metric set

- connected clients
- subscription count
- retained count
- inflight QoS1 count
- queue fill levels
- publish accepted/rejected
- ACL allow/deny
- forward count
- dedup drops
- retry count
- memory high-water marks

---

## 13. Testing rules

### 13.1. Every bugfix must come with a test

Do not fix behavior without a reproducible test.

### 13.2. Core tests are mandatory

Minimum coverage for:
- topic matching
- routing
- ACL decisions
- retained behavior
- QoS state transitions
- session restore
- federation metadata propagation

### 13.3. Property-oriented tests are welcome

Especially for:
- wildcard matching
- dedup logic
- anti-loop rules
- queue policies

### 13.4. Timing tests without real sleeps

Use an injectable/fake clock.

### 13.5. Event emission must be testable

The event model must allow:
- deterministic capture of emitted events in tests
- validation of payload/meta for each event
- validation that no extra events are emitted on reject/error paths

### 13.6. Test-only access must use dedicated seams

- production public headers must not contain macro-gated test APIs
- if tests need access to internal runtime state, expose it through a separate `*_test_access.hpp`
- test-only access headers must not become required dependencies for the production build

---

## 14. Code-review rules

Every PR must be reviewed for:
1. whether module boundaries were preserved
2. whether platform code leaked into core
3. whether packet-level and domain-level logic were mixed
4. whether hidden allocations appeared
5. whether ownership/lifetime were documented
6. whether tests exist
7. whether metrics/logging exist for the new behavior

---

## 15. Federation-ready coding rules

### 15.1. Never assume a local-only world

Every entity must support:
- local origin
- remote origin

### 15.2. Owner identity must be abstract

Do not tie subscription/delivery to a socket pointer.

### 15.3. Dedup support

Messages that can cross broker links must contain metadata for dedup/loop prevention.

### 15.4. Policy separate from mechanism

- mechanism: how to forward
- policy: what to forward

### 15.5. Follow the documented namespace contract

- topic naming, ACL scope, export/import rules, and route scoping must follow the documented namespace contract defined in `docs/architecture/ARCHITECTURE.md`
- core must not hardcode ad-hoc or local-only namespace conventions
- namespace extensions are allowed only through documented config/policy changes, not hidden code-path assumptions

---

## 16. Configuration guidelines

### Configuration must be

- explicit
- versioned
- bounded
- validated at startup

### Versioning strategy

- every config schema must have an explicit `schema_version` field
- `config_loader` must know supported versions and the current version
- migrations are allowed only forward: `vN -> vN+1`
- skipped intermediate versions must be migrated sequentially, not magically
- unknown critical fields or an incompatible major-version schema must fail fast at startup
- missing optional fields may be filled only with explicit documented defaults
- after migration, config must be normalized to the current schema before it is passed to runtime

### Separate sections must exist for

- protocol limits
- memory budgets
- queue limits
- retained limits
- federation policy
- logging/metrics
- persistence policy

### Config-versioning test requirements

- tests are required for current-version parsing
- tests are required for migration from previous supported versions
- tests are required for rejection of unsupported future/legacy versions
- tests are required for unknown required fields and missing required fields

---

## 17. Documentation rules

Every module must have a short header comment describing:
- responsibility
- inputs/outputs
- ownership expectations
- threading assumptions
- memory expectations

Every non-trivial algorithm must have:
- a short rationale comment
- not a line-by-line narration of the code

Architecture-governance documents are also normative:
- `docs/governance/ARCH_COMPLIANCE_MATRIX.md`
- `docs/governance/ADR_EXCEPTIONS.md`
- `docs/governance/TEAM_WORKFLOW.md`
- `docs/governance/ARCH_CHECKS.md`

---

## 18. Anti-patterns

### Forbidden anti-patterns

- God-object broker class
- direct socket pointers in routing tables
- unbounded dynamic allocation in packet paths
- hidden retry logic
- implicit ownership transfer
- packet structs leaking into the domain layer
- hardcoded single-node assumptions
- policy logic embedded in transport code

---

## 19. Recommended module contracts

### Example of good contracts

- `route_message(MessageView msg) -> RoutePlan`
- `deliver(RoutePlan plan) -> DeliveryResult`
- `retained_store_put(TopicKey key, PayloadRef payload, RetainedMeta meta)`
- `session_resume(ClientId id) -> SessionRestoreResult`
