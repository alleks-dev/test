# MODULE_CONTRACTS.md

## 1. Мета

Цей документ фіксує нормативні контракти модулів MQTT-брокера для ESP32-S3.

Його роль:
- перетворити архітектурні принципи в конкретні модульні межі
- зменшити ризик architectural drift під час старту реалізації
- зафіксувати inputs/outputs, ownership, errors, threading і testability expectations

Документ узгоджується з:
- `ARCHITECTURE.md`
- `TECH_STACK.md`
- `CODING_GUIDELINES.md`
- `TEST_STRATEGY.md`
- `ROADMAP.md`
- `READ_MODEL_STRATEGY.md`
- `RUNTIME_EXECUTION_MODEL.md`
- `ASYNC_OPERATION_MODEL.md`

---

## 2. Загальні правила контрактів

### 2.1. Dependency rule

Core modules:
- не залежать від ESP-IDF
- не тягнуть socket/task/storage handles
- взаємодіють лише через domain types і ports

Adapters:
- залежать від ports
- можуть залежати від platform APIs
- не приймають архітектурних policy-рішень замість core

Application/runtime:
- збирає модулі
- конфігурує adapters і policies
- не дублює бізнес-логіку core

### 2.2. Error contract

Для міжмодульних API:
- повертати structured status/result, а не `bool` без контексту
- помилки policy/validation мають бути явними
- unexpected failure не повинен маскуватися silent fallback-ом

### 2.3. Ownership contract

Кожен модуль повинен явно визначати:
- хто володіє вхідними буферами
- чи дозволено borrow/view semantics
- коли потрібне copy/retain
- коли ownership transfer заборонений

### 2.4. Threading contract

За замовчуванням core contracts:
- deterministic
- thread-agnostic
- придатні до host-side tests

Якщо модуль не є thread-safe:
- це повинно бути явно задокументовано
- synchronization не повинен “протікати” через API

### 2.5. Read-model contract

App-facing APIs:
- повинні повертати snapshots, DTOs або bounded query results
- не повинні розкривати mutable live internals
- повинні будуватися через dedicated facade/builder/coordinator seams where needed

### 2.6. Async operation contract

Якщо API запускає non-immediate operation:
- повинен існувати `request_id` або equivalent operation identity
- completion/error має бути observable через explicit result contract
- timeout/failure state не повинен залишатися implicit

---

## 3. Базові domain types

### 3.1. `Message`

Містить щонайменше:
- `topic`
- `payload_ref`
- `qos`
- `retain`
- `timestamp`
- `origin`
- `scope`
- `route_flags`
- `message_id` або dedup id
- `protocol_meta_ref` як optional reference

Контракт:
- це domain object, не MQTT packet
- payload бажано передавати як bounded reference/view
- `origin` і `scope` є обов’язковими для routing/federation correctness

### 3.2. `Subscription`

Містить:
- `filter`
- `qos`
- `owner_type`
- `owner_id`
- `scope`
- `flags`

Контракт:
- ownership має бути abstract, не socket-based
- local/remote/internal owners підтримуються відразу

### 3.3. `DeliveryTarget`

Абстракція delivery destination:
- local client
- remote broker
- internal system target

Контракт:
- routing працює з `DeliveryTarget`
- transport details не входять у target contract

---

## 4. Core module contracts

### 4.1. `broker_core`

Responsibility:
- orchestration between protocol/session/retained/qos/routing/acl/federation
- lifecycle of broker node
- publication of domain events

Inputs:
- validated commands/events from protocol/runtime/adapters
- configured ports and policy implementations

Outputs:
- route/delivery actions
- persistence/session actions
- emitted domain events
- status/results for caller

Ownership:
- не володіє transport/platform handles
- може володіти composition root references to module instances

Errors:
- orchestration conflicts
- invalid state transitions
- dependency failures propagated from ports/modules

Threading:
- single-thread deterministic core path preferred
- async orchestration outside the contract

Testability:
- повинен запускатися на host без ESP-IDF runtime

Allowed dependencies:
- domain types
- core modules
- ports

Runtime/application note:
- app-facing access to broker state must go through runtime facade/read-model seams
- async admin/runtime operations must not be hidden inside broker_core without explicit request/result contract

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
- parser не повинен без потреби копіювати payload
- serialized buffers повинні бути bounded and explicit

Errors:
- malformed packet
- unsupported protocol feature
- limit violation
- incompatible property combination

Threading:
- reentrant only if explicitly implemented
- deterministic parse/serialize behavior required

Testability:
- host-side unit/property tests mandatory

Allowed dependencies:
- domain-neutral packet structures
- ports only if strictly needed for clocks/limits abstraction

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
- `DeliveryTarget` list or equivalent bounded plan
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
- must run with fake `ISubscriptionIndex`, `IRouterPolicy`, `IAclPolicy`

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
- allow/deny result with explicit reason

Ownership:
- does not own session transport state
- works on abstract identity and policy data

Errors:
- invalid rule set
- policy evaluation failure

Threading:
- deterministic, pure-function style preferred

Testability:
- unit tests for allow/deny/default-deny/scoped rules mandatory

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
- events for session lifecycle

Ownership:
- owns session control state
- does not own persistent storage backend

Errors:
- invalid resume
- inconsistent persisted state
- resource limit exceeded

Threading:
- external synchronization hidden behind module boundary

Testability:
- fake `ISessionStore` sufficient for host-side tests

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
- payload storage ownership delegated through `IRetainedStore`

Errors:
- storage failure
- invalid retained mutation
- limit exceeded

Threading:
- deterministic logic separate from storage synchronization

Testability:
- fake `IRetainedStore` mandatory

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
- time-dependent but deterministic with fake clock

Testability:
- no real sleep; fake `IClock` required

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
- operates on abstract broker link contract

Errors:
- policy conflict
- dedup metadata inconsistency
- unsupported topology state

Threading:
- deterministic policy layer preferred

Testability:
- fake `IFederationLink` and fake nodes/simulator required

Allowed dependencies:
- domain types
- `IFederationLink`
- `IRouterPolicy`

### 4.9. `runtime_facade`

Responsibility:
- expose app-facing runtime API
- return snapshots, DTOs and bounded query results
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
- may return copies or immutable views as documented by contract

Errors:
- snapshot unavailable
- operation not found
- invalid app-facing request

Threading:
- may be called from application/runtime layer
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
- owns only read-model caches/storage allowed by memory policy

Errors:
- snapshot rebuild failure
- bounded cache/storage overflow

Threading:
- must preserve deterministic publication behavior
- should not expose mutable cache internals to consumers

Testability:
- host-side tests must verify rebuild triggers and snapshot stability

Allowed dependencies:
- snapshot builders
- domain-safe snapshot DTOs
- runtime/application utilities

### 4.11. `operation_result_store`

Responsibility:
- generate `request_id` for async operations
- track queued/in-progress/completed/failed/timed_out operations
- expose bounded poll/query contract for operation results

Inputs:
- operation submission metadata
- completion/error updates
- timeout signals

Outputs:
- request identifiers
- current operation status
- terminal result/error payloads where applicable

Ownership:
- owns bounded transient operation tracking state
- must not absorb long-lived domain state

Errors:
- queue/store full
- unknown request id
- timeout or failed operation terminal status

Threading:
- must preserve explicit terminal states and deterministic query semantics

Testability:
- host-side tests must verify request id generation, timeout handling and cleanup

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
- explicit connection state reporting

### 5.2. `ITransportListener`

Responsibility:
- abstract accept/listen surface for inbound endpoints

Contract:
- returns abstract endpoints
- platform accept loop must stay outside core

### 5.3. `ISessionStore`

Responsibility:
- persist/load session snapshots and related session metadata

Contract:
- versioned snapshot support expected
- partial/corrupted restore must be representable

### 5.4. `IRetainedStore`

Responsibility:
- retained payload and retained metadata persistence

Contract:
- supports scoped retained semantics
- storage backend remains replaceable

### 5.5. `ISubscriptionIndex`

Responsibility:
- add/remove/query subscriptions
- wildcard and owner-aware lookup

Contract:
- deterministic lookup semantics
- local/remote/internal owners supported

### 5.6. `IAclPolicy`

Responsibility:
- evaluate publish/subscribe authorization

Contract:
- default deny on evaluation failure
- explicit reason/status preferred

### 5.7. `IRouterPolicy`

Responsibility:
- decide forwarding eligibility and routing scope policy

Contract:
- mechanism-free policy only
- local-only vs remote-export behavior explicit

### 5.8. `IClock`

Responsibility:
- time source for retries, expiry and tests

Contract:
- fake/injectable implementation mandatory

### 5.9. `ILogger`

Responsibility:
- structured logging sink

Contract:
- no hidden formatting assumptions in core
- fields like module/event/result/reason should be representable

### 5.10. `IMetrics`

Responsibility:
- counter/gauge/telemetry sink

Contract:
- metrics calls must not force core to know backend details

### 5.11. `IFederationLink`

Responsibility:
- abstract broker-to-broker communication surface

Contract:
- no topology-specific assumptions in core
- supports fake/simulated implementations for tests

---

## 6. Event contract

Базові доменні події:
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

Контракт:
- payload/meta кожної події повинні бути testable
- події не повинні залежати від platform handles
- event emission має бути deterministic у host-side tests
- reject/error paths не повинні емінити зайві success-like events

---

## 7. Configuration contract

`config_loader` contract:
- читає versioned config schema
- виконує deterministic migrations до current schema
- повертає normalized config model
- fail-fast відхиляє incompatible schema/version

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

Якщо майбутній кодовий модуль не може коротко відповісти на питання:
- що він приймає
- що повертає
- чим володіє
- від кого залежить
- як тестується

то його контракт ще не достатньо сформований для чистої реалізації.
