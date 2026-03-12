# API_HEADERS_PLAN.md

## 1. Мета

Цей документ описує план створення public API headers для MQTT-брокера.

Його цілі:
- перевести модульні контракти в конкретні `include/` файли
- зафіксувати мінімальний набір headers для першого compileable skeleton
- не допустити platform leakage в public API
- відокремити production API від test-only access seams

Документ узгоджується з:
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/architecture/DEPENDENCY_RULES.md`
- `docs/planning/SKELETON_PLAN.md`
- `docs/architecture/CODING_GUIDELINES.md`
- `docs/governance/ARCH_COMPLIANCE_MATRIX.md`

---

## 2. Загальні правила

- public headers описують contracts, а не implementation details
- headers у `include/ports/` не включають ESP-IDF/platform headers
- headers у `include/*` повинні бути самодостатніми настільки, наскільки це можливо
- initial APIs можуть бути мінімальними, але не повинні суперечити модульним контрактам
- імена типів: `PascalCase`
- імена функцій/методів: `snake_case` або вибраний єдиний стиль

---

## 3. Root include layout

Початковий layout:

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
```

---

## 4. Перші domain headers

Ці headers повинні бути створені першими, бо на них спираються ports і core.

### 4.1. `message.hpp`

Повинен містити:
- `Message`
- `MessageId`
- `MessageOrigin`
- `PayloadRef`
- `RouteFlags`
- optional protocol metadata reference type

### 4.2. `subscription.hpp`

Повинен містити:
- `Subscription`
- `SubscriptionOwnerType`
- `SubscriptionId` if needed

### 4.3. `delivery_target.hpp`

Повинен містити:
- `DeliveryTarget`
- `DeliveryTargetType`

### 4.4. `result.hpp`

Повинен містити:
- `ResultCode`
- `Severity`
- `Status`
- `Result<T, E>` або `Expected<T, E>` wrapper choice

### 4.5. `domain_event.hpp`

Повинен містити:
- `DomainEventType`
- `DomainEvent`
- common event metadata fields

---

## 5. Перші port headers

### 5.1. `transport_endpoint_port.hpp`

Повинен оголошувати:
- `ITransportEndpoint`
- endpoint state/result primitives

Minimal methods to draft:
- `send(...)`
- `receive(...)`
- `close()`
- `state()`

### 5.2. `transport_listener_port.hpp`

Повинен оголошувати:
- `ITransportListener`

Minimal methods to draft:
- `accept()`
- `state()`

### 5.3. `session_store_port.hpp`

Повинен оголошувати:
- `ISessionStore`
- session snapshot value types

Minimal methods to draft:
- `load_session(...)`
- `store_session(...)`
- `delete_session(...)`

### 5.4. `retained_store_port.hpp`

Повинен оголошувати:
- `IRetainedStore`
- retained entry metadata types

Minimal methods to draft:
- `load_retained(...)`
- `store_retained(...)`
- `delete_retained(...)`

### 5.5. `subscription_index_port.hpp`

Повинен оголошувати:
- `ISubscriptionIndex`
- lookup result/view types

Minimal methods to draft:
- `add_subscription(...)`
- `remove_subscription(...)`
- `match_subscriptions(...)`

### 5.6. `acl_policy_port.hpp`

Повинен оголошувати:
- `IAclPolicy`
- `AclDecision`

Minimal methods to draft:
- `can_publish(...)`
- `can_subscribe(...)`

### 5.7. `router_policy_port.hpp`

Повинен оголошувати:
- `IRouterPolicy`
- `RoutePolicyDecision`

Minimal methods to draft:
- `should_deliver_local(...)`
- `should_forward_remote(...)`

### 5.8. `clock_port.hpp`

Повинен оголошувати:
- `IClock`
- timestamp/duration types chosen for project

Minimal methods to draft:
- `now()`

### 5.9. `logger_port.hpp`

Повинен оголошувати:
- `ILogger`
- log record/value types

Minimal methods to draft:
- `log(...)`

### 5.10. `metrics_port.hpp`

Повинен оголошувати:
- `IMetrics`

Minimal methods to draft:
- `increment_counter(...)`
- `set_gauge(...)`

### 5.11. `federation_link_port.hpp`

Повинен оголошувати:
- `IFederationLink`
- federation message envelope if needed

Minimal methods to draft:
- `send_remote_publish(...)`
- `send_subscription_update(...)`
- `state()`

---

## 6. Перші core public headers

### 6.1. `broker_core.hpp`

Повинен оголошувати:
- `BrokerCore`
- minimal construction/configuration boundary

Не повинен:
- expose ESP-IDF/runtime handles

### 6.2. `protocol_mqtt.hpp`

Повинен оголошувати:
- protocol parse/serialize entry points
- protocol config limit struct

### 6.3. `routing.hpp`

Повинен оголошувати:
- `RoutePlan`
- `route_message(...)`

### 6.4. `acl.hpp`

Повинен оголошувати:
- ACL evaluation entry points if module has public surface beyond port

### 6.5. `session.hpp`

Повинен оголошувати:
- session create/resume/update API

### 6.6. `retained.hpp`

Повинен оголошувати:
- retained put/get/delete API

### 6.7. `qos.hpp`

Повинен оголошувати:
- QoS inflight/retry API

### 6.8. `federation.hpp`

Повинен оголошувати:
- federation policy entry points

---

## 7. Include policy for first headers

### Allowed in domain headers

- standard utility headers
- other domain headers

### Allowed in port headers

- domain headers
- `result.hpp`

### Not allowed in port headers

- adapter headers
- ESP-IDF headers
- socket/task/storage native types

### Allowed in core public headers

- domain headers
- port headers

### Not allowed in core public headers

- adapter headers
- ESP-IDF headers
- platform-specific typedef leakage

---

## 8. Forward declaration policy

Prefer forward declarations when:
- only pointer/reference/interface handle is needed
- it reduces compile-time coupling

Prefer full include when:
- value semantics require complete type
- template wrapper or inline methods need full definition

Do not use forward declarations to hide broken layering.

---

## 9. First-pass signature policy

На першому проході API signatures повинні:
- бути мінімальними
- повертати `Status` або `Result<T, E>`
- використовувати bounded views/refs instead of uncontrolled ownership transfer
- уникати більше ніж 4-5 scalar args without context struct

---

## 10. Header creation order

Рекомендований порядок:
1. `result.hpp`
2. `message.hpp`
3. `subscription.hpp`
4. `delivery_target.hpp`
5. `domain_event.hpp`
6. all `ports/*.hpp`
7. `routing.hpp`
8. `acl.hpp`
9. `session.hpp`
10. `retained.hpp`
11. `qos.hpp`
12. `protocol_mqtt.hpp`
13. `federation.hpp`
14. `broker_core.hpp`

Reason:
- result/domain types unblock all other headers
- ports stabilize public boundaries
- `broker_core.hpp` should be composed after dependent surfaces exist

---

## 11. First review checklist

При рев’ю перших API headers перевіряти:
1. Чи немає ESP-IDF/platform includes у domain/ports/core headers
2. Чи не протікають socket/storage/task handles
3. Чи використовуються structured result types
4. Чи відповідають names/contracts `docs/architecture/MODULE_CONTRACTS.md`
5. Чи не став header “god header” для кількох layer boundaries

---

## 12. Definition of Done

API headers plan вважається реалізованим, якщо:
- усі first-pass public headers створені
- вони компілюються в host build
- ports/core headers не порушують dependency rules
- signatures достатні для створення stub implementations і fake adapters
