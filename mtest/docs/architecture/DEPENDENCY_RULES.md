# DEPENDENCY_RULES.md

## 1. Purpose

This document defines the allowed dependencies between MQTT-broker modules for ESP32-S3.

Its goals are to:
- prevent architectural drift during implementation
- make module boundaries verifiable
- provide a basis for code review, CMake wiring, and include policy

This document aligns with:
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/TECH_STACK.md`
- `docs/architecture/CODING_GUIDELINES.md`
- `docs/architecture/MODULE_CONTRACTS.md`

---

## 2. Core principle

Dependencies must flow:
- from `app/runtime` to `core` and `ports`
- from `adapters` to `ports`
- from `core` to `domain types` and `ports`

Dependencies must not flow:
- from `core` to `adapters`
- from `core` to ESP-IDF/platform APIs
- from `ports` to `core`
- from `ports` to `adapters`

---

## 3. Logical layers

We use the following logical groups:
- `domain model`
- `core modules`
- `ports`
- `adapters`
- `app/runtime`
- `diagnostics`
- `tests`

### 3.1. `domain model`

Includes:
- `Message`
- `Subscription`
- `DeliveryTarget`
- shared enums/status/domain identifiers

### 3.2. `core modules`

Includes:
- `broker_core`
- `protocol_mqtt`
- `routing`
- `acl`
- `session`
- `retained`
- `qos`
- `federation`

### 3.3. `ports`

Includes:
- `ITransportEndpoint`
- `ITransportListener`
- `ISessionStore`
- `IRetainedStore`
- `ISubscriptionIndex`
- `IAclPolicy`
- `IRouterPolicy`
- `IClock`
- `ILogger`
- `IMetrics`
- `IFederationLink`

### 3.4. `adapters`

Includes:
- `transport_tcp`
- `storage_nvs`
- `storage_psram`
- `bridge_link`
- `logger`
- `metrics`
- `tracing`
- platform-specific glue

### 3.5. `app/runtime`

Includes:
- `node_runtime`
- `config_loader`
- `runtime_facade`
- `read_model_coordinator`
- `operation_result_store`
- `admin_api`

---

## 4. Dependency matrix

### 4.1. `domain model`

May depend on:
- standard utility types
- other domain types

May not depend on:
- `core modules`
- `ports`
- `adapters`
- `app/runtime`
- ESP-IDF/platform APIs

### 4.2. `ports`

May depend on:
- `domain model`
- standard utility types

May not depend on:
- `core modules`
- `adapters`
- `app/runtime`
- ESP-IDF/platform headers

### 4.3. `core modules`

May depend on:
- `domain model`
- `ports`
- other `core modules`, if explicitly allowed below

May not depend on:
- `adapters`
- `app/runtime`
- ESP-IDF/platform APIs
- concrete diagnostics backends

### 4.4. `adapters`

May depend on:
- `ports`
- `domain model`, if needed for port payloads/contracts
- platform APIs

May not depend on:
- `app/runtime` business logic
- internal core implementation details outside port contracts

### 4.5. `app/runtime`

May depend on:
- `core modules`
- `ports`
- `adapters`
- config/model utilities

Must not:
- contain duplicate domain/policy logic
- decide routing/ACL/QoS semantics directly

### 4.6. `diagnostics`

The physical `diagnostics` component is responsible for:
- `logger`
- `metrics`
- `tracing`

It may depend on:
- `ports`
- `domain model`
- platform APIs if it is a backend adapter

It must not force `core` to know backend details.

---

## 5. Allowed core-to-core dependencies

### 5.1. `broker_core`

May depend on:
- `protocol_mqtt`
- `routing`
- `acl`
- `session`
- `retained`
- `qos`
- `federation`
- `ports`
- `domain model`

### 5.2. `protocol_mqtt`

May depend on:
- `domain model`
- lightweight protocol packet model

Must not depend on:
- `routing`
- `acl`
- `session`
- `retained`
- `qos`
- `federation`

Note:
- orchestration and calls to other modules are owned by `broker_core`, not by `protocol_mqtt`

### 5.3. `routing`

May depend on:
- `domain model`
- `ISubscriptionIndex`
- `IAclPolicy`
- `IRouterPolicy`

Must not depend on:
- transport adapters
- storage adapters
- `session` implementation details

### 5.4. `acl`

May depend on:
- `domain model`
- config/policy model

Must not depend on:
- transport/session internals
- adapter code

### 5.5. `session`

May depend on:
- `domain model`
- `ISessionStore`

Must not depend on:
- storage adapter details
- transport platform handles

### 5.6. `retained`

May depend on:
- `domain model`
- `IRetainedStore`

Must not depend on:
- storage adapter implementation details
- transport code

### 5.7. `qos`

May depend on:
- `domain model`
- `IClock`

Must not depend on:
- transport adapter details
- scheduler/task APIs directly

### 5.8. `federation`

May depend on:
- `domain model`
- `IFederationLink`
- `IRouterPolicy`

Must not depend on:
- concrete bridge transport implementation
- socket APIs

---

## 6. App/runtime dependency rules

### 6.1. `runtime_facade`

May depend on:
- read-model DTOs/builders/coordinator
- operation result store
- app/runtime-safe contracts

Must not depend on:
- raw mutable core state layout
- adapter internals bypassing core/runtime boundaries

### 6.2. `read_model_coordinator`

May depend on:
- app/runtime DTOs
- snapshot builders
- runtime summaries/state notifications

Must not depend on:
- web/admin serialization details
- platform APIs not required by the runtime boundary

### 6.3. `operation_result_store`

May depend on:
- result/status DTOs
- clock abstractions where required

Must not depend on:
- transport/storage adapter internals
- long-lived domain-state ownership

---

## 7. Include policy

### 7.1. Public headers

Public headers must:
- include only what they need
- avoid platform leakage
- compile standalone in host builds

### 7.2. Forbidden includes

Forbidden in `core` or `ports` public headers:
- ESP-IDF headers
- FreeRTOS headers
- lwIP headers
- socket headers
- NVS types/handles

### 7.3. Test-only access

If test-only access is required:
- use a separate `*_test_access.hpp`
- do not place macro-gated test hooks in production headers

---

## 8. CMake dependency policy

At the build-graph level:
- each core module should be a separate component where practical
- adapters depend on ports, not the other way around
- app/runtime may wire everything together
- forbidden dependencies must be caught mechanically where possible

---

## 9. Test dependency rules

### 9.1. Host tests

Host tests may depend on:
- core modules
- domain model
- ports
- fake adapters
- broader STL/test tooling

Host tests must not require:
- ESP-IDF runtime
- platform sockets/tasks/NVS

### 9.2. Integration tests

Integration tests may depend on:
- runtime wiring
- real or semi-real adapters
- bounded platform layers

### 9.3. Simulation tests

Simulation tests may depend on:
- fake federation links
- fake nodes
- fake clocks
- deterministic event capture

---

## 10. Forbidden patterns

Forbidden:
- core including adapter headers
- ports including platform headers
- adapter logic deciding domain policy
- app/runtime bypassing core contracts to mutate internal domain state
- public API exposing live mutable runtime internals

---

## 11. Review checklist

Every dependency-sensitive change must be reviewed for:
- direction of dependency
- header leakage
- ownership boundary
- test seam quality
- whether the change should be represented as a port instead of a direct dependency

---

## 12. Definition of Done for dependency rules

Dependency rules are considered established if:
- logical layers are explicit
- allowed core-to-core dependencies are explicit
- app/runtime seams are defined separately from core
- include policy is explicit
- the rules are usable for review, CMake wiring, and automated checks
