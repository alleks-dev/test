# API_HEADERS_PLAN.md

## 1. Purpose

This document defines the plan for creating public API headers for the MQTT broker.

Its goals are to:
- translate module contracts into concrete `include/` files
- define the minimal header set for the first compilable skeleton
- prevent platform leakage through the public API
- separate production API from test-only access seams

This document aligns with:
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/architecture/DEPENDENCY_RULES.md`
- `docs/planning/SKELETON_PLAN.md`
- `docs/architecture/CODING_GUIDELINES.md`
- `docs/governance/ARCH_COMPLIANCE_MATRIX.md`

---

## 2. General rules

- public headers define contracts, not implementation details
- headers in `include/ports/` must not include ESP-IDF/platform headers
- headers in `include/*` should be as self-contained as reasonably possible
- initial APIs may be minimal, but must not contradict module contracts
- every new header must start with `// SPDX-License-Identifier: AGPL-3.0-only`
- type names use `PascalCase`
- function/method names use `snake_case` or one consistently chosen project-wide style

---

## 3. Root include layout

Initial layout:

```text
components/
  ports/include/ports/
  broker_core/include/broker_core/
  protocol_mqtt/include/protocol_mqtt/
  routing/include/routing/
  acl/include/acl/
  session/include/session/
  retained/include/retained/
  qos/include/qos/
  federation/include/federation/
  app_runtime/include/app_runtime/
```

---

## 4. First domain headers

These headers must be created first because ports and core depend on them.

### 4.1. `message.hpp`

Must contain:
- `Message`
- `MessageId`
- `MessageOrigin`
- `PayloadRef`
- `RouteFlags`
- optional protocol metadata reference type

### 4.2. `subscription.hpp`

Must contain:
- `Subscription`
- `SubscriptionOwnerType`
- `SubscriptionId` if needed

### 4.3. `delivery_target.hpp`

Must contain:
- `DeliveryTarget`
- `DeliveryTargetType`

### 4.4. `result.hpp`

Must contain:
- `ResultCode`
- `Severity`
- `Status`
- `Result<T, E>` or `Expected<T, E>` wrapper choice

### 4.5. `domain_event.hpp`

Must contain:
- `DomainEventType`
- `DomainEvent`
- common event metadata fields

---

## 5. First port headers

### 5.1. `transport_endpoint_port.hpp`

Must declare:
- `ITransportEndpoint`
- endpoint state/result primitives

Minimal methods to draft:
- `send(...)`
- `receive(...)`
- `close()`
- `state()`

### 5.2. `transport_listener_port.hpp`

Must declare:
- `ITransportListener`

Minimal methods to draft:
- `accept()`
- `state()`

### 5.3. `session_store_port.hpp`

Must declare:
- `ISessionStore`
- session snapshot value types

Minimal methods to draft:
- `load_session(...)`
- `store_session(...)`
- `delete_session(...)`

### 5.4. `retained_store_port.hpp`

Must declare:
- `IRetainedStore`
- retained entry metadata types

Minimal methods to draft:
- `load_retained(...)`
- `store_retained(...)`
- `delete_retained(...)`

### 5.5. `subscription_index_port.hpp`

Must declare:
- `ISubscriptionIndex`
- subscription view or query result types

Minimal methods to draft:
- `add_subscription(...)`
- `remove_subscription(...)`
- `query_matching(...)`
- `query_by_owner(...)`

### 5.6. `acl_policy_port.hpp`

Must declare:
- `IAclPolicy`
- ACL decision result type

Minimal methods to draft:
- `can_publish(...)`
- `can_subscribe(...)`

### 5.7. `router_policy_port.hpp`

Must declare:
- `IRouterPolicy`
- route-policy decision/result types

Minimal methods to draft:
- `evaluate_route(...)`
- `should_forward(...)`

### 5.8. `clock_port.hpp`

Must declare:
- `IClock`
- time-point/tick abstraction as needed

Minimal methods to draft:
- `now_ms()`
- `monotonic_ms()` or one consistent clock contract

### 5.9. `logger_port.hpp`

Must declare:
- `ILogger`
- structured log field/value primitives where needed

Minimal methods to draft:
- `log(...)`

### 5.10. `metrics_port.hpp`

Must declare:
- `IMetrics`

Minimal methods to draft:
- `counter_inc(...)`
- `gauge_set(...)`
- `histogram_observe(...)` if included in the first metrics contract

### 5.11. `federation_link_port.hpp`

Must declare:
- `IFederationLink`
- remote message/subscription transfer result types

Minimal methods to draft:
- `send_remote_publish(...)`
- `send_remote_subscription(...)`
- `state()`

---

## 6. First app-runtime headers

### 6.1. `runtime_facade.hpp`

Must declare:
- app-facing runtime facade contract
- snapshot-returning API surface

Minimal methods to draft:
- `get_status_snapshot(...)`
- `get_config_snapshot(...)`
- `get_operation_status(...)`

### 6.2. `read_model_coordinator.hpp`

Must declare:
- read-model rebuild/publish coordination contract

Minimal methods to draft:
- `invalidate(...)`
- `rebuild_if_needed(...)`
- `publish(...)`

### 6.3. `operation_result_store.hpp`

Must declare:
- async operation request/result tracking contract

Minimal methods to draft:
- `next_request_id()`
- `publish_result(...)`
- `get_status(...)`
- `cleanup_expired(...)`

---

## 7. First core public headers

### 7.1. `broker_core.hpp`

Should expose:
- minimal broker lifecycle API
- command/event entry points
- runtime-independent construction contract

### 7.2. `protocol_mqtt.hpp`

Should expose:
- packet parse/serialize API
- protocol command/result types

### 7.3. `routing.hpp`

Should expose:
- routing entry point
- `RoutePlan`
- bounded route result types

### 7.4. `acl.hpp`

Should expose:
- ACL evaluation entry point if there is a concrete core ACL module API

### 7.5. `session.hpp`

Should expose:
- session lifecycle entry points
- restore result types

### 7.6. `retained.hpp`

Should expose:
- retained lookup/update/delete API

### 7.7. `qos.hpp`

Should expose:
- QoS inflight/retry state transition API

### 7.8. `federation.hpp`

Should expose:
- federation policy entry points
- forwarding decision/result types

---

## 8. Test-only access headers

If a module needs test-only access, it must be defined in a separate header, for example:
- `broker_core_test_access.hpp`
- `routing_test_access.hpp`
- `session_test_access.hpp`
- `protocol_mqtt_test_access.hpp`

Rules:
- production headers must not contain macro-gated test APIs
- test-only access headers are allowed only for internal state that cannot be tested cleanly through normal ports/contracts
- production code must not depend on them

---

## 9. Include policy

### 9.1. General policy

Public headers should:
- include only what they need
- prefer forward declarations when ownership and ABI allow it
- avoid transitive dependency explosions

### 9.2. Forbidden in public headers

- ESP-IDF headers
- FreeRTOS headers
- lwIP headers
- socket headers
- NVS handles/types
- platform-specific opaque runtime internals

### 9.3. Allowed in public headers

- standard fixed-size types
- bounded utility types from the approved STL subset
- domain-safe enums and structs
- other public contract headers where necessary

---

## 10. Standalone compile rule

All public headers must compile standalone in a host environment.

This means:
- a header must not rely on include order magic
- a header must not assume some platform header was included earlier
- a header must not require ESP-IDF build context to parse

This is a CI requirement, not a recommendation.

---

## 11. Forward declaration policy

Prefer forward declarations when:
- only pointers/references/views are exposed
- no inline methods require the full definition
- ownership/lifetime semantics remain clear

Do not use forward declarations when:
- the type is returned by value
- layout is part of the contract
- inlining requires full type knowledge

---

## 12. Header creation order

Recommended order:
1. domain headers
2. result/error primitives
3. event primitives
4. port headers
5. app-runtime headers
6. core public headers
7. test-only access headers where truly necessary

Reason:
- contracts must stabilize before concrete implementations
- app/runtime seams must be created before admin or inspection code depends on them
- test seams should be introduced only after normal public contracts are defined

---

## 13. Initial review checklist for headers

Every new public header should be reviewed for:
- does it expose only contract-level data
- does it leak platform types
- are ownership rules clear
- can it compile standalone
- does it preserve clean layering
- does it require a separate test-access header instead of a macro hook

---

## 14. Definition of Done for API headers plan

This plan is considered correctly established if:
- the first header set is ordered and scoped
- public headers are aligned with module contracts
- port headers are platform-free
- app-runtime seams are explicitly represented
- test-only access is separated from production API
