# SKELETON_PLAN.md

## 1. Purpose

This document defines the practical plan for creating the first compilable skeleton code of the MQTT broker.

Its goals are to:
- translate the documentation set into a working project skeleton
- provide a clear order for creating `components/`, headers, and tests
- minimize improvisation during the first commits

---

## 2. Principles of the first skeleton milestone

- compileable structure first, behavior later
- core must build without ESP-IDF runtime
- ports are created before adapters
- fake/test adapters are created early to prove testability immediately
- no "temporary" violation of dependency rules

---

## 3. Goal of the first milestone

After the first skeleton milestone, the project must have:
- a valid ESP-IDF component structure
- host-buildable core/domain/ports
- public headers for the key port contracts
- minimal stub implementations for core modules
- a basic test harness
- the first unit tests green

Not required at this stage:
- real networking
- real storage backends
- production runtime behavior
- full MQTT protocol implementation

---

## 4. Structure to create first

### 4.1. Root files

Create:
- `CMakeLists.txt`
- `partitions.csv`
- `LICENSE`
- `sdkconfig.defaults`
- `sdkconfig.defaults.n8r2`
- `sdkconfig.defaults.n16r8`
- `sdkconfig.defaults.debug`
- `sdkconfig.defaults.release`

### 4.2. Main/runtime

Create:
- `main/CMakeLists.txt`
- `main/app_main.cpp`

The first `app_main` must:
- only assemble the runtime graph
- contain no business logic

### 4.3. Components

Create empty but valid `components/`:
- `broker_core`
- `protocol_mqtt`
- `routing`
- `acl`
- `session`
- `retained`
- `qos`
- `federation`
- `ports`
- `transport_tcp`
- `storage_nvs`
- `storage_psram`
- `diagnostics`
- `platform_runtime`
- `app_runtime`

---

## 5. Headers created first

### 5.1. Domain headers

First domain headers:
- `message.hpp`
- `subscription.hpp`
- `delivery_target.hpp`
- `result.hpp`
- `domain_event.hpp`

Each new source/header file created in the skeleton must start with:
- `// SPDX-License-Identifier: AGPL-3.0-only`

### 5.2. Port headers

First public port headers:
- `transport_endpoint_port.hpp`
- `transport_listener_port.hpp`
- `session_store_port.hpp`
- `retained_store_port.hpp`
- `subscription_index_port.hpp`
- `acl_policy_port.hpp`
- `router_policy_port.hpp`
- `clock_port.hpp`
- `logger_port.hpp`
- `metrics_port.hpp`
- `federation_link_port.hpp`

### 5.3. Core public headers

First core-facing headers:
- `broker_core.hpp`
- `protocol_mqtt.hpp`
- `routing.hpp`
- `acl.hpp`
- `session.hpp`
- `retained.hpp`
- `qos.hpp`
- `federation.hpp`

Rules:
- public headers expose contracts, not internal platform details
- initial methods may be stubbed, but signatures must respect `docs/architecture/MODULE_CONTRACTS.md`

### 5.4. Test-only access headers

If a module requires a test-only seam, create it separately:
- `broker_core_test_access.hpp`
- `session_test_access.hpp`
- `routing_test_access.hpp`

Rules:
- production code must not depend on these headers
- they do not replace normal public contracts
- they are used only where fake ports/black-box tests are insufficient

---

## 6. Module creation order

Recommended order:
1. domain types
2. result/error primitives
3. event primitives
4. port headers
5. `routing` stub
6. `acl` stub
7. `session` stub
8. `retained` stub
9. `qos` stub
10. `protocol_mqtt` stub
11. `federation` stub
12. `broker_core` stub
13. fake test adapters
14. runtime wiring stub
15. real platform-adapter scaffolding

Reason:
- domain and ports stabilize contracts
- fake test adapters enable host-side tests early
- `broker_core` should be assembled only after module contracts exist

---

## 7. Stub-implementation policy

First implementations may:
- return `ERR_UNSUPPORTED_FEATURE`
- return empty/no-op plans where the contract allows that
- log `not implemented` only in debug/test mode

First implementations may not:
- violate dependency rules
- pull ESP-IDF into core
- pretend success when the feature is not implemented

---

## 8. Test harness required immediately

### 8.1. Host test base

Create:
- fake `IClock`
- fake `ISubscriptionIndex`
- fake `IAclPolicy`
- fake `IRouterPolicy`
- fake `ISessionStore`
- fake `IRetainedStore`
- fake `IFederationLink`
- fake event-capture sink

### 8.2. Minimal integration harness

Create:
- in-memory runtime wiring for core modules
- no real socket/network/storage requirement

---

## 9. The first 10 tests

The first tests that must appear early:
1. topic-matching exact/wildcard basics
2. `ISubscriptionIndex` add/remove/query basics
3. `IAclPolicy` default-deny behavior
4. `IRouterPolicy` local-only vs exportable decision
5. `routing` returns a deterministic empty/no-match result
6. `retained` create/update/delete semantics
7. `qos` timeout logic with a fake clock
8. `config_loader` current-schema parse
9. `config_loader` previous-version migration
10. deterministic event-capture ordering for the publish path

---

## 10. First compilable milestone definition

The milestone is reached if:
- `components/` structure exists
- all public headers compile
- the host-side test target builds
- no core module includes ESP-IDF headers
- fake adapters satisfy the required ports
- the first 10 tests pass

---

## 11. Early CMake rules

- an architecture-check target must exist early, even if the codebase is still small
- `scripts/check_arch_invariants.sh` must be part of the local and CI bootstrap bundle

At the start:
- `ports` is an independent component
- each core module is a separate component where practical
- `diagnostics` is separate from core
- host test builds for domain/core/ports are independent of ESP-IDF runtime

Avoid:
- a monolithic `broker_core` component that absorbs all logic
- adapter code linked into the core test target

---

## 12. First runtime scope

The first runtime scope must be minimal:
- runtime graph assembly
- basic config loading
- basic diagnostics wiring
- no operational admin surface beyond what is needed for startup/testing

---

## 13. First milestone Definition of Done

The first skeleton milestone is complete if:
- the repository structure matches the architectural model
- the initial headers define the key contracts
- host-side fake adapters prove test seams exist
- CI/local scripts can verify the skeleton mechanically
- there is no architectural debt hidden as "temporary startup code"
