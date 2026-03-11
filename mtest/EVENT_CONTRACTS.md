# EVENT_CONTRACTS.md

## 1. Мета

Цей документ фіксує canonical contracts для внутрішніх доменних подій MQTT-брокера.

Його цілі:
- зробити event-driven model однозначною перед реалізацією
- зафіксувати payload/meta для кожної події
- визначити emitter, trigger point, ordering rules і test expectations

Документ узгоджується з:
- `ARCHITECTURE.md`
- `TEST_STRATEGY.md`
- `CODING_GUIDELINES.md`
- `MODULE_CONTRACTS.md`

---

## 2. Загальні правила

- події є domain-level, не platform-level
- події не містять socket descriptors, task handles або ESP-IDF specific objects
- payload/meta кожної події повинні бути deterministic і testable
- event emission повинна бути можлива до capture у host-side tests
- reject/error paths не повинні емінити success-like events

---

## 3. Базові поля події

Кожна подія повинна мати щонайменше:
- `event_type`
- `timestamp`
- `entity_id` або equivalent primary id
- `origin`, якщо подія пов’язана з message/source
- `scope`, якщо подія пов’язана з routing/subscription/message flow

Опційно:
- `client_id`
- `subscription_id`
- `message_id`
- `route_id`
- `reason_code`
- `retryable`

---

## 4. Event envelope

Canonical logical shape:

```text
DomainEvent
  event_type
  timestamp
  entity_id
  origin?
  scope?
  payload
```

Rules:
- envelope має бути стабільний для event capture/tests
- payload shape може відрізнятися по event type
- event type не повинен визначатися через free-form string parsing у логіці core

---

## 5. Event contracts

### 5.1. `ClientConnected`

Emitter:
- `broker_core` або `session` через `broker_core`

When emitted:
- після успішного прийняття connect і створення/відновлення session context

Required payload:
- `client_id`
- `session_present`
- `clean_session` або equivalent flag

Must not be emitted when:
- connect rejected
- protocol validation failed

### 5.2. `ClientDisconnected`

Emitter:
- `broker_core` або `session`

When emitted:
- після зафіксованого disconnect/transport close/session cleanup trigger

Required payload:
- `client_id`
- `disconnect_reason`

Must not be emitted when:
- connect never completed successfully

### 5.3. `PublishReceived`

Emitter:
- `protocol_mqtt` via `broker_core`

When emitted:
- після успішного parse/validation publish request
- до routing decision

Required payload:
- `message_id`
- `topic`
- `qos`
- `retain`
- `origin`
- `scope`

Must not be emitted when:
- malformed publish packet
- ACL/policy reject happened before message acceptance

### 5.4. `SubscriptionAdded`

Emitter:
- `session` or subscription orchestration path via `broker_core`

When emitted:
- після успішного додавання subscription в `ISubscriptionIndex`

Required payload:
- `client_id` або `owner_id`
- `filter`
- `qos`
- `scope`

Must not be emitted when:
- subscribe rejected
- duplicate/no-op update intentionally not accepted as a new subscription

### 5.5. `SubscriptionRemoved`

Emitter:
- `session` or subscription orchestration path via `broker_core`

When emitted:
- після успішного видалення subscription

Required payload:
- `client_id` або `owner_id`
- `filter`
- `scope`

### 5.6. `RetainedUpdated`

Emitter:
- `retained`

When emitted:
- після accepted retained create/update/delete

Required payload:
- `topic`
- `scope`
- `operation` as `create|update|delete`

Must not be emitted when:
- retained mutation rejected
- storage write failed before state became effective

### 5.7. `RouteResolved`

Emitter:
- `routing`

When emitted:
- після побудови accepted `RoutePlan`

Required payload:
- `message_id`
- `route_target_count`
- `local_target_count`
- `remote_target_count`
- `scope`

Must not be emitted when:
- route denied before plan creation

### 5.8. `DeliveryRequested`

Emitter:
- `broker_core` after accepted routing result

When emitted:
- коли локальна доставка повинна бути виконана

Required payload:
- `message_id`
- `delivery_target_id`
- `delivery_target_type`

Rules:
- одна подія може означати один target request
- if batching is later introduced, batching rule must be documented explicitly

### 5.9. `ForwardRequested`

Emitter:
- `broker_core` / `federation`

When emitted:
- лише коли route/federation policy дозволяє remote forward

Required payload:
- `message_id`
- `federation_target_id`
- `scope`
- `origin`

Must not be emitted when:
- anti-loop drops message
- federation policy denies forward

### 5.10. `RemotePublishReceived`

Emitter:
- `federation`

When emitted:
- після accepted ingest of remote-origin publish
- до local re-routing

Required payload:
- `message_id`
- `origin=remote_broker`
- `remote_broker_id`
- `scope`

Must not be emitted when:
- remote message rejected by dedup/anti-loop before acceptance

---

## 6. Ordering rules

### 6.1. Local publish path

Preferred order:
1. `PublishReceived`
2. `RouteResolved`
3. `DeliveryRequested`
4. `ForwardRequested` if allowed

### 6.2. Subscribe path

Preferred order:
1. subscription accepted
2. `SubscriptionAdded`
3. retained lookup/delivery actions

### 6.3. Remote publish path

Preferred order:
1. `RemotePublishReceived`
2. `RouteResolved`
3. `DeliveryRequested`
4. `ForwardRequested` only if policy still allows

### 6.4. Disconnect path

Preferred order:
1. session cleanup start
2. `ClientDisconnected`
3. subscription/session cleanup side effects

If implementation needs a different order for a specific path, it must be documented and tested explicitly.

---

## 7. No-event rules

Ці події не повинні емінитися:
- `ClientConnected` on failed connect
- `PublishReceived` on malformed packet
- `SubscriptionAdded` on rejected subscribe
- `RetainedUpdated` on rejected retained write
- `RouteResolved` if no valid accepted route was produced
- `DeliveryRequested` if publish was rejected or no local targets exist
- `ForwardRequested` on anti-loop drop or policy deny

---

## 8. Test expectations

Для кожної події тести повинні перевіряти:
- emitted vs not emitted
- payload field correctness
- ordering relative to neighboring events
- deterministic capture without real timing dependence

Integration tests повинні перевіряти:
- publish path sequencing
- subscribe path sequencing
- retained update emission rules
- federation ingress and forward rules

---

## 9. Logging and metrics relation

Подія не є тим самим, що log line або metric point.

Rules:
- одна подія може породити log/metric, але не зобов’язана
- logs/metrics не повинні бути єдиним способом спостерігати domain events у tests
- event capture interface повинна залишатися окремою від logging backend

---

## 10. Change policy

Будь-яка нова доменна подія повинна:
- бути додана в `ARCHITECTURE.md`
- отримати payload contract тут
- отримати tests у `TEST_STRATEGY.md`
- бути оцінена на memory/observability impact

---

## 11. Definition of Done

Event contracts вважаються зафіксованими, якщо:
- усі базові 10 подій мають explicit payload contract
- ordering rules задокументовані для critical paths
- no-event rules сформульовані явно
- tests можуть детерміновано capture events без ESP-IDF runtime
