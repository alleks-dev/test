# MODULE_CONTRACTS.md

## 1. Purpose

This document defines the normative module contracts for the ESP32-S3 MQTT broker.

Its role is to:
- turn architectural principles into concrete module boundaries
- reduce the risk of architectural drift during implementation startup
- define inputs/outputs, ownership, errors, threading, and testability expectations

This document aligns with:
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/TECH_STACK.md`
- `docs/architecture/CODING_GUIDELINES.md`
- `docs/testing/TEST_STRATEGY.md`
- `docs/planning/ROADMAP.md`
- `docs/architecture/READ_MODEL_STRATEGY.md`
- `docs/architecture/RUNTIME_EXECUTION_MODEL.md`
- `docs/architecture/ASYNC_OPERATION_MODEL.md`

---

## 2. General contract rules

### 2.1. Dependency rule

Core modules:
- do not depend on ESP-IDF
- do not pull in socket/task/storage handles
- interact only through domain types and ports

Adapters:
- depend on ports
- may depend on platform APIs
- must not make architectural policy decisions instead of core

Application/runtime:
- assembles modules
- configures adapters and policies
- does not duplicate core business logic

### 2.2. Error contract

For inter-module APIs:
- return structured status/results, not `bool` without context
- policy/validation errors must be explicit
- unexpected failures must not be masked by silent fallbacks

### 2.3. Ownership contract

Every module must explicitly define:
- who owns input buffers
- whether borrow/view semantics are allowed
- when copy/retain is required
- when ownership transfer is forbidden

### 2.4. Threading contract

By default, core contracts are:
- deterministic
- thread-agnostic
- suitable for host-side tests

If a module is not thread-safe:
- that must be documented explicitly
- synchronization must not leak through the API

### 2.5. Read-model contract

App-facing APIs:
- must return snapshots, DTOs, or bounded query results
- must not expose mutable live internals
- must be built through dedicated facade/builder/coordinator seams where needed

### 2.6. Async operation contract

If an API starts a non-immediate operation:
- there must be a `request_id` or equivalent operation identity
- completion/error must be observable through an explicit result contract
- timeout/failure state must not remain implicit

---

## 3. Base domain types

### 3.1. `Message`

Contains at least:
- `topic`
- `payload_ref`
- `qos`
- `retain`
- `timestamp`
- `origin`
- `scope`
- `route_flags`
- `message_id` or dedup ID
- `protocol_meta_ref` as an optional reference

Contract:
- this is a domain object, not an MQTT packet
- payload should preferably be passed as a bounded reference/view
- `origin` and `scope` are mandatory for routing/federation correctness

### 3.2. `Subscription`

Contains:
- `filter`
- `qos`
- `owner_type`
- `owner_id`
- `scope`
- `flags`

Contract:
- ownership must be abstract, not socket-based
- local/remote/internal owners are supported from day one

### 3.3. `DeliveryTarget`

An abstract delivery destination:
- local client
- remote broker
- internal system target

Contract:
- routing operates on `DeliveryTarget`
- transport details are not part of the target contract

---

## 4. Core module contracts

### 4.1. `broker_core`

Responsibility:
- orchestrates protocol/session/retained/QoS/routing/ACL/federation
- lifecycle of the broker node
- publication of domain events

Inputs:
- validated commands/events from protocol/runtime/adapters
- configured ports and policy implementations

Outputs:
- route/delivery actions
- persistence/session actions
- emitted domain events
- status/results for the caller

Ownership:
- does not own transport/platform handles
- may own composition-root references to module instances

Errors:
- orchestration conflicts
- invalid state transitions
- dependency failures propagated from ports/modules

Threading:
- single-thread deterministic core path preferred
- async orchestration outside the contract

Testability:
- must run on a host without ESP-IDF runtime

Allowed dependencies:
- domain types
- core modules
- ports

Runtime/application note:
- app-facing access to broker state must go through runtime facade/read-model seams
- async admin/runtime operations must not be hidden inside `broker_core` without an explicit request/result contract

### 4.2. `protocol_mqtt`

Responsibility:
- parse/serialize MQTT packets
- packet-level protocol semantics
- connect/subscribe/publish/ack flow handling
- extensible MQTT 5 property/reason-code handling

Inputs:
- raw byte spans/buffers
- protocol config limits

Outputs:
- parsed packet model
- protocol commands/events for broker core
- serialized outbound packets

Ownership:
- the parser must not copy payload unnecessarily
- serialized buffers must be bounded and explicit

Errors:
- malformed packet
- unsupported protocol feature
- limit violation
- incompatible property combination

Threading:
- reentrant only if explicitly implemented
- deterministic parse/serialize behavior required

Testability:
- host-side unit/property tests are mandatory

Allowed dependencies:
- domain-neutral packet structures
- ports only if strictly needed for clock/limit abstraction

### 4.3. `routing`

Responsibility:
- topic matching
- route resolution
- delivery planning
- local vs remote forwarding eligibility

Inputs:
- `Message`
- subscription views/index lookups
- router policy decisions
- ACL decisions where required by flow

Outputs:
- `RoutePlan`
- `DeliveryTarget` list or an equivalent bounded plan
- emitted route-related events

Ownership:
- routing does not own transport endpoints
- route outputs reference abstract targets only

Errors:
- invalid namespace/scope
- policy deny
- inconsistent subscription state

Threading:
- deterministic and side-effect minimal

Testability:
- must run with fake `ISubscriptionIndex`, `IRouterPolicy`, and `IAclPolicy`

Allowed dependencies:
- domain types
- `ISubscriptionIndex`
- `IAclPolicy`
- `IRouterPolicy`

### 4.4. `acl`

Responsibility:
- publish/subscribe authorization
- namespace-aware ACL matching
- default-deny behavior

Inputs:
- subject/client identity
- operation type
- topic/filter/scope
- policy config

Outputs:
- allow/deny result with an explicit reason

Ownership:
- does not own session transport state
- works on abstract identity and policy data

Errors:
- invalid rule set
- policy evaluation failure

Threading:
- deterministic, pure-function style preferred

Testability:
- unit tests for allow/deny/default-deny/scoped rules are mandatory

Allowed dependencies:
- domain types
- config/policy model

### 4.5. `session`

Responsibility:
- session lifecycle
- restore/resume
- subscription ownership association
- client-associated protocol state

Inputs:
- connect/disconnect commands
- clean/persistent session flags
- persistence restore data

Outputs:
- session state updates
- restore result
- session lifecycle events

Ownership:
- owns session control state
- does not own the persistent storage backend

Errors:
- invalid resume
- inconsistent persisted state
- resource limit exceeded

Threading:
- external synchronization is hidden behind the module boundary

Testability:
- a fake `ISessionStore` is sufficient for host-side tests

Allowed dependencies:
- domain types
- `ISessionStore`

### 4.6. `retained`

Responsibility:
- retained semantics
- retained lookup
- retained update/delete behavior

Inputs:
- `Message`
- retained update commands
- subscription/filter lookup requests

Outputs:
- retained query results
- retained mutation results
- `RetainedUpdated` event on accepted changes

Ownership:
- owns retained metadata handling
- payload storage ownership is delegated through `IRetainedStore`

Errors:
- storage failure
- invalid retained mutation
- limit exceeded

Threading:
- deterministic logic separate from storage synchronization

Testability:
- fake `IRetainedStore` is mandatory

Allowed dependencies:
- domain types
- `IRetainedStore`

### 4.7. `qos`

Responsibility:
- QoS1 inflight tracking
- retry timing state
- ack-driven state transitions

Inputs:
- publish accepted events
- ack events
- timeout ticks/clock queries

Outputs:
- inflight updates
- retry decisions
- completion/cleanup decisions

Ownership:
- owns inflight control metadata
- does not own wall-clock implementation

Errors:
- duplicate/inconsistent ack
- inflight state corruption
- limit exceeded

Threading:
- time-dependent but deterministic with a fake clock

Testability:
- no real sleep; fake `IClock` is required

Allowed dependencies:
- domain types
- `IClock`

### 4.8. `federation`

Responsibility:
- bridge policy
- remote subscription propagation
- dedup / anti-loop handling
- route scoping

Inputs:
- `Message`
- route decisions
- federation link state
- namespace/policy config

Outputs:
- forward/drop decisions
- remote publication/subscription actions
- federation-related events

Ownership:
- does not own transport implementation
- operates on an abstract broker-link contract

Errors:
- policy conflict
- dedup metadata inconsistency
- unsupported topology state

Threading:
- deterministic policy layer preferred

Testability:
- fake `IFederationLink` and fake nodes/simulation are required

Allowed dependencies:
- domain types
- `IFederationLink`
- `IRouterPolicy`

### 4.9. `runtime_facade`

Responsibility:
- expose the app-facing runtime API
- return snapshots, DTOs, and bounded query results
- isolate admin/inspection consumers from concrete runtime internals

Inputs:
- published read models
- operation result lookups
- normalized runtime/application requests

Outputs:
- status/config/session/diagnostics snapshots
- bounded operation-status responses

Ownership:
- does not transfer ownership of live mutable runtime state
- may return copies or immutable views as documented by the contract

Errors:
- snapshot unavailable
- operation not found
- invalid app-facing request

Threading:
- may be called from the application/runtime layer
- must not require caller-owned locks

Testability:
- host-side tests must verify stable snapshot/result behavior

Allowed dependencies:
- read-model seams
- async operation seams
- domain-safe DTO types

### 4.10. `read_model_coordinator`

Responsibility:
- manage invalidate/rebuild/publish flow for read models
- coordinate snapshot builders
- publish stable app-facing snapshots after relevant runtime changes

Inputs:
- relevant state-change notifications
- state fragments and runtime summaries needed for projection

Outputs:
- published snapshots
- rebuild/invalidate decisions

Ownership:
- does not own authoritative domain state
- owns only read-model caches/storage allowed by the memory policy

Errors:
- snapshot rebuild failure
- bounded cache/storage overflow

Threading:
- must preserve deterministic publication behavior
- must not expose mutable cache internals to consumers

Testability:
- host-side tests must verify rebuild triggers and snapshot stability

Allowed dependencies:
- snapshot builders
- domain-safe snapshot DTOs
- runtime/application utilities

### 4.11. `operation_result_store`

Responsibility:
- generate `request_id` for async operations
- track queued/in-progress/completed/failed/timed-out operations
- expose a bounded poll/query contract for operation results

Inputs:
- operation submission metadata
- completion/error updates
- timeout signals

Outputs:
- request identifiers
- current operation status
- terminal result/error payloads where applicable

Ownership:
- owns bounded transient operation-tracking state
- must not absorb long-lived domain state

Errors:
- queue/store full
- unknown request ID
- timeout or failed operation terminal status

Threading:
- must preserve explicit terminal states and deterministic query semantics

Testability:
- host-side tests must verify request ID generation, timeout handling, and cleanup

Allowed dependencies:
- domain-safe result/status DTOs
- clock/timer abstraction where needed

---

## 5. Port contracts

### 5.1. `ITransportEndpoint`

Responsibility:
- abstract bidirectional endpoint for packet I/O

Contract:
- no socket descriptor leakage
- bounded send/receive semantics
- explicit connection-state reporting

### 5.2. `ITransportListener`

Responsibility:
- abstract accept/listen surface for inbound endpoints

Contract:
- returns abstract endpoints
- the platform accept loop must stay outside core

### 5.3. `ISessionStore`

Responsibility:
- persist/load session snapshots and related session metadata

Contract:
- versioned snapshot support is expected
- platform storage details must stay outside core

### 5.4. `IRetainedStore`

Responsibility:
- persist/load retained payloads and metadata

Contract:
- retained storage must be bounded and observable for tests

### 5.5. `ISubscriptionIndex`

Responsibility:
- add/remove/query subscriptions
- provide matching views for routing

Contract:
- does not expose transport/session platform details
- supports local and remote owners

### 5.6. `IAclPolicy`

Responsibility:
- abstract authorization policy evaluation

Contract:
- default deny must be representable
- failure-to-evaluate must be visible to the caller

### 5.7. `IRouterPolicy`

Responsibility:
- abstract route-policy decisions

Contract:
- local-only/export/import/scoping decisions remain externalized from routing mechanism

### 5.8. `IClock`

Responsibility:
- abstract time source / timeout trigger source

Contract:
- fake/injectable implementation is mandatory

### 5.9. `ILogger`

Responsibility:
- structured logging sink

Contract:
- no hidden formatting assumptions in core
- fields such as module/event/result/reason must be representable

### 5.10. `IMetrics`

Responsibility:
- counter/gauge/telemetry sink

Contract:
- metric calls must not force core to know backend details

### 5.11. `IFederationLink`

Responsibility:
- abstract broker-to-broker communication surface

Contract:
- no topology-specific assumptions in core
- supports fake/simulated implementations for tests

---

## 6. Event contract

Base domain events:
- `ClientConnected`
- `ClientDisconnected`
- `PublishReceived`
- `SubscriptionAdded`
- `SubscriptionRemoved`
- `RetainedUpdated`
- `RouteResolved`
- `DeliveryRequested`
- `ForwardRequested`
- `RemotePublishReceived`

Contract:
- payload/meta of every event must be testable
- events must not depend on platform handles
- event emission must be deterministic in host-side tests
- reject/error paths must not emit extra success-like events

---

## 7. Configuration contract

`config_loader` contract:
- reads a versioned config schema
- performs deterministic migrations to the current schema
- returns a normalized config model
- fails fast on incompatible schema/version

Configuration must define:
- protocol limits
- memory budgets
- queue limits
- retained limits
- federation policy
- logging/metrics policy
- persistence policy

---

## 8. Implementation note

If a future code module cannot briefly answer the following questions:
- what does it accept
- what does it return
- what does it own
- what does it depend on
- how is it tested

then its contract is not yet clear enough for a clean implementation.
