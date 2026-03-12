# ARCHITECTURE.md

## 1. Purpose

This document defines the target architecture of the ESP32-S3 MQTT broker with an evolutionary path:

- from `single-broker mode`
- to `Primary/Standby`
- and later to `federated multi-broker mode`

The key requirement is that the system must grow **without architectural breakage**, while preserving:

- clean modularity
- predictable behavior
- easy testability
- controlled SRAM/PSRAM usage
- independence of core logic from ESP-IDF details

---

## 2. Architectural principles

We do not design "one broker that does everything", but rather:

> **broker core + transport/storage/platform adapters + optional federation layer**

The current single-node deployment must be only one configuration of the system, not an architectural limitation.

### Core idea

The local broker core must not need to know whether it runs:
- as a single node
- as a primary node
- as a standby node
- as a federated node

---

## 3. Architecture goals

1. **Single-broker first**
   - the system must first be simple and stable

2. **Federation ready**
   - the internal model must support remote origin and remote target

3. **Testability first**
   - most logic must be testable on a host machine without ESP32 hardware

4. **Strict separation of concerns**
   - protocol, routing, state, storage, and platform are separate

5. **Resource awareness**
   - hot path data stays in internal RAM
   - cold data and large buffers stay in PSRAM

6. **MQTT 5-ready, not MQTT 5-complete on day one**
   - the architecture must support MQTT 5 properties and reason codes without rewriting core

---

## 4. System layers

```text
+--------------------------------------------------+
| Application / Config / Management API            |
+--------------------------------------------------+
| Federation / Bridge / Replication Policies       |
+--------------------------------------------------+
| Routing Engine / Topic Resolution / ACL          |
+--------------------------------------------------+
| Session Manager / Retained Store / QoS Engine    |
+--------------------------------------------------+
| MQTT Protocol Engine                             |
+--------------------------------------------------+
| Transport Adapters (TCP, local link, broker link)|
+--------------------------------------------------+
| Platform Layer (ESP-IDF, timers, storage, net)   |
+--------------------------------------------------+
```

---

## 5. Layer descriptions

### 5.1. Application / Config / Management API

Responsible for:
- node configuration
- runtime startup
- metrics / diagnostics
- admin commands
- policy setup
- config schema versioning / migration
- app-facing facade for status, inspection, and admin operations
- read-model publication and snapshot access
- async operation result tracking for non-immediate runtime/admin actions

`config_loader` must:
- read `schema_version`
- perform sequential migration steps to the current schema
- validate normalized config before runtime startup
- fail fast on incompatible schema versions

The application/runtime layer normatively includes:
- `runtime facade`, which returns snapshots or bounded query results instead of live mutable internals
- `read-model coordinator`, which manages rebuild/publish flow for app-facing views
- `operation result store`, which tracks `request_id`-based async operations and terminal statuses

It must not contain MQTT core logic.

---

### 5.2. Federation / Bridge / Replication Policies

Responsible for:
- topic export/import policy
- bridge rules
- remote subscription announcements
- anti-loop logic
- route scoping
- optional replication/failover behavior

At early stages, this layer may be a no-op implementation.

---

### 5.3. Routing Engine / Topic Resolution / ACL

Responsible for:
- matching subscription filters
- route decisions
- local delivery
- remote forwarding decisions
- namespace control
- ACL enforcement

Critical rule: routing must not be tied to sockets.

---

### 5.4. Session Manager / Retained Store / QoS Engine

Responsible for:
- client sessions
- session resumption
- inflight state
- QoS1 retransmit state
- retained storage
- subscription ownership

This layer works through storage interfaces, not directly through platform-specific code.

---

### 5.5. MQTT Protocol Engine

Responsible for:
- parsing MQTT packets
- serializing MQTT packets
- connect / subscribe / publish / ack handling
- keepalive protocol semantics

Architectural decision:
- the protocol layer is designed to be `MQTT 5-ready`
- the MVP does not require full implementation of the entire MQTT 5 surface area
- the packet/property model must be extensible for MQTT 5 fields
- reason codes and optional properties must be addable without changing domain boundaries

MQTT 5 readiness profile:
- `must-have later`: reason codes, session expiry, message expiry, receive maximum, maximum packet size, topic alias support where justified
- `maybe later`: user properties, response topic / correlation data, content type, payload format indicator, subscription identifiers
- `definitely not MVP`: full property matrix for every packet type, shared subscriptions, request/response convenience features, optimization-heavy MQTT 5 features without proven need

It must not decide:
- route policy
- storage policy
- federation policy

---

### 5.6. Transport Adapters

Examples:
- TCP client endpoint
- internal loopback endpoint
- broker-to-broker link
- test transport

Core works through a transport abstraction.

---

### 5.7. Platform Layer

Depends on ESP-IDF and provides:
- sockets
- timers
- tasks
- synchronization primitives
- NVS / LittleFS / other storage
- logging hooks
- metrics backend

---

## 6. Runtime facade and read models

### 6.1. App-facing facade

All app-facing consumers:
- `admin_api`
- diagnostics/export views
- future bridge/inspection consumers

must depend on a narrow runtime facade instead of concrete mutable runtime internals.

The facade:
- returns snapshots, DTOs, or bounded query results
- does not expose lock ownership
- does not return references to live mutable state

### 6.2. Read-model seams

The read-model layer must contain separate roles:
- `snapshot builder`
- `read-model coordinator`
- facade-level published snapshot contracts

These seams are part of the application/runtime layer, not the domain core.

### 6.3. Async operation seam

Non-immediate runtime/admin operations must go through a separate async operation seam:
- `request_id`
- operation status
- terminal result/error
- bounded result storage/polling

This seam belongs to the application/runtime layer and must not be embedded into hot-path routing/session/QoS logic.

---

## 7. Internal domain model

### 7.1. Message

The internal message object is not the same as an MQTT packet.

It must contain at least:
- topic
- payload reference
- QoS
- retain flag
- timestamp
- origin
- scope
- route flags
- message/dedup ID
- optional protocol metadata reference

#### Origin

Mandatory attribute:
- local client
- local service
- remote broker
- recovered persisted message

Without `origin`, federation cannot be added correctly.

---

### 7.2. Subscription

Must contain:
- filter
- QoS
- owner type
- owner ID
- scope
- flags

#### Owner type

- local client
- remote broker
- internal service

---

### 7.3. DeliveryTarget

Abstract recipient:
- local client target
- remote broker target
- internal system target

Routing must operate on `DeliveryTarget`, not on `socket*`.

---

## 8. Internal event model

Internal logic must be event-driven.

### Base events

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

### Why this matters

Single-broker mode:
- uses only local event producers/consumers

Federated broker:
- adds remote event sources
- does not break the domain model

---

## 9. Ports and Adapters

Recommended style: **Hexagonal / Ports and Adapters**

### Core ports

- `ITransportEndpoint`
- `ITransportListener`
- `ISessionStore`
- `IRetainedStore`
- `ISubscriptionIndex`
- `IAclPolicy`
- `IRouterPolicy`
- `IFederationLink`
- `IClock`
- `ILogger`
- `IMetrics`

### Benefits

- core does not depend on ESP-IDF
- storage can be swapped easily
- federation can be introduced incrementally
- tests can use fake/mock adapters

---

## 10. What must not be hardcoded for single-broker mode

### Forbidden

- assuming all subscriptions belong only to local clients
- assuming `publish origin` is always a local socket
- storing routes as lists of sockets
- mixing MQTT packet model with domain model
- tying ACL only to local session objects
- implementing retained storage without scope/namespace

### Required

- store ownership explicitly
- use abstract IDs
- keep routing separate from transport
- keep federation metadata in the model from the beginning

---

## 11. Namespace strategy

A federated architecture requires a deliberate topic namespace.

### Recommendation

```text
site/{site_id}/zone/{zone_id}/device/{device_id}/...
site/{site_id}/service/{service}/...
site/{site_id}/global/...
```

### Benefits

- simpler ACL
- simpler export/import rules
- predictable routing
- control over local vs global traffic
- easier aggregation

---

## 12. Evolution path

### Stage A - Clean single-broker mode

Implement:
- protocol engine
- QoS engine
- session manager
- retained store
- subscription index
- ACL engine
- routing engine
- transport abstraction
- storage interfaces

### Stage B - Observability

Add:
- metrics
- event log
- trace points
- config model
- config schema versioning
- deterministic test hooks

### Stage C - Broker Link

Add:
- point-to-point bridge
- export/import topic rules
- remote publish ingest
- origin tagging
- dedup metadata

### Stage D - Selective Federation

Add:
- remote subscription propagation
- route policies
- anti-loop logic
- scoped retained policy

### Stage E - Production Federation

Add:
- topology health
- reconnect logic
- failure isolation
- multi-node testing
- soak testing

---

## 13. Architecture profiles

### 13.1. Single-broker mode

Suitable for:
- `N8R2`
- small local systems
- minimal complexity

### 13.2. Primary / Standby

Suitable for:
- `N16R8`
- systems where availability matters
- limited failover without full federation

### 13.3. Federated multi-broker mode

Suitable for:
- `N16R8`
- multiple zones
- segmented systems
- scaling without a full shared-state cluster

---

## 14. SRAM / PSRAM policy

### In internal SRAM

Keep:
- hot-path routing metadata
- task stacks
- transport/session control
- frequently accessed indexes
- QoS state-machine control data

### In PSRAM

Keep:
- payload buffers
- retained payload storage
- outbound queues
- cold session state
- diagnostics buffers
- snapshots/checkpoints

---

## 15. Test architecture

Core must be testable separately from the platform.

### Unit-test domain

- topic matching
- routing decisions
- retained semantics
- QoS1 state transitions
- ACL
- origin/scope propagation
- bridge policy
- anti-loop

### Integration-test adapters

- sockets
- timers
- storage
- reconnect behavior
- queue overflow

### Simulation layer

- fake node A
- fake node B
- fake federation link
- clock control
- loss/reorder/duplication

---

## 16. Unified project structure model

The architecture document defines the **logical modular model**, while `docs/architecture/TECH_STACK.md` defines its **physical implementation** as an ESP-IDF `project/main/components/test` layout.

So there is one model:
- logical modules define responsibility boundaries
- physical `components/` are the way to map those modules into the ESP-IDF build layout

### 16.1. Logical modular structure

```text
/core
  broker_core
  message_model
  subscription_model
  routing_engine
  qos_engine
  session_manager
  retained_manager
  acl_engine
  federation_policy

/ports
  transport_port
  transport_listener_port
  storage_port
  subscription_index_port
  acl_port
  router_policy_port
  clock_port
  logger_port
  metrics_port
  federation_link_port

/adapters
  esp_transport
  tcp_transport
  nvs_storage
  psram_storage
  bridge_link
  logger
  metrics
  tracing

/app
  node_runtime
  config_loader
  runtime_facade
  read_model_coordinator
  operation_result_store
  admin_api
```

### 16.2. Mapping to the physical ESP-IDF structure

```text
project/
  main/
    app_main.cpp

  components/
    broker_core/        -> /core/broker_core
    protocol_mqtt/      -> protocol engine
    routing/            -> /core/routing_engine
    acl/                -> /core/acl_engine
    session/            -> /core/session_manager
    retained/           -> /core/retained_manager
    qos/                -> /core/qos_engine
    federation/         -> /core/federation_policy
    ports/              -> /ports/*
    transport_tcp/      -> /adapters/tcp_transport
    storage_nvs/        -> /adapters/nvs_storage
    storage_psram/      -> /adapters/psram_storage
    diagnostics/        -> logger + metrics + tracing adapters
    platform_runtime/   -> runtime/bootstrap/platform wiring

  test/
    host/
    integration/
    simulation/
    hardware/
```

---

## 17. Definition of Done for the architecture

The architecture is considered healthy if:

1. Core can run in unit/integration tests without ESP32 hardware.
2. The MQTT packet model does not leak into the domain layer.
3. Routing does not depend on socket implementation.
4. Federation can be added without rewriting the session/QoS/retained core.
5. Storage can be replaced without changing business logic.
6. Origin/target/scope are explicit in the domain model.
7. Namespace rules are fixed before federation appears.
8. App-facing APIs do not expose live mutable runtime state.
9. Async runtime/admin operations have explicit request/result identity.

---

## 18. Summary

The correct growth path is:
- build a **single-node deployment**
- but build it on top of a **federation-ready broker core**

Do not design "one broker forever". Design:
- a clean core
- clear interfaces
- an event-driven domain model
- independent transport/storage adapters

Then the transition from single-broker mode to federated mode becomes a topology and policy change, not a rewrite of the entire system.
