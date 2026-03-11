# ARCHITECTURE.md

## 1. Мета

Цей документ описує цільову архітектуру MQTT-брокера для ESP32-S3 з еволюційним шляхом:

- від `Single broker`
- до `Primary/Standby`
- і далі до `Federated multi-broker`

Ключова вимога: система має зростати **без архітектурного зламу**, зберігаючи:

- чисту модульність
- передбачувану поведінку
- легкотестованість
- контрольоване використання SRAM/PSRAM
- незалежність core-логіки від ESP-IDF деталей

---

## 2. Архітектурний принцип

Проєктуємо не “один брокер на все”, а:

> **broker core + transport/storage/platform adapters + optional federation layer**

Поточне single-node розгортання має бути лише однією конфігурацією системи, а не обмеженням архітектури.

### Головна ідея

Локальне ядро брокера не повинно знати, чи працює воно:
- як одиночний вузол
- як primary
- як standby
- як federated node

---

## 3. Цілі архітектури

1. **Single broker first**
   - система повинна спочатку бути простою і стабільною

2. **Federation ready**
   - внутрішня модель повинна підтримувати remote-origin і remote-target

3. **Testability first**
   - більшість логіки повинна тестуватись на host-машині без ESP32

4. **Strict separation of concerns**
   - protocol, routing, state, storage, platform — окремо

5. **Resource awareness**
   - hot-path у внутрішній RAM
   - cold data та великі буфери — у PSRAM

6. **MQTT 5-ready, not MQTT 5-complete on day one**
   - архітектура повинна допускати MQTT 5 properties і reason codes без переписування core

---

## 4. Шари системи

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

## 5. Опис шарів

### 5.1. Application / Config / Management API

Відповідає за:
- конфігурацію вузла
- запуск runtime
- metrics / diagnostics
- admin commands
- policy setup
- config schema versioning / migration

`config_loader` повинен:
- читати `schema_version`
- виконувати послідовні migration steps до current schema
- валідовувати нормалізований config до старту runtime
- fail-fast завершувати запуск при несумісній схемі

Не повинен містити MQTT core-логіку.

---

### 5.2. Federation / Bridge / Replication Policies

Відповідає за:
- policy export/import topic-ів
- bridge rules
- remote subscription announcement
- anti-loop logic
- route scoping
- optional replication/failover behavior

На ранніх етапах може бути no-op реалізацією.

---

### 5.3. Routing Engine / Topic Resolution / ACL

Відповідає за:
- matching subscription filters
- route decision
- local delivery
- remote forwarding decision
- namespace control
- ACL enforcement

Критично: routing не повинен бути прив’язаний до сокетів.

---

### 5.4. Session Manager / Retained Store / QoS Engine

Відповідає за:
- client sessions
- session resumption
- inflight state
- QoS1 retransmit state
- retained storage
- subscription ownership

Працює через storage interfaces, а не напряму через platform-specific код.

---

### 5.5. MQTT Protocol Engine

Відповідає за:
- parse MQTT packets
- serialize MQTT packets
- connect / subscribe / publish / ack handling
- keepalive protocol semantics

Архітектурне рішення:
- protocol layer проєктується як `MQTT 5-ready`
- MVP не вимагає повної реалізації всього MQTT 5 surface area
- packet/property model має бути extensible для MQTT 5 fields
- reason codes і optional properties повинні додаватися без зміни domain boundaries

MQTT 5 readiness profile:
- `must-have later`: reason codes, session expiry, message expiry, receive maximum, maximum packet size, topic alias support where justified
- `maybe later`: user properties, response topic / correlation data, content type, payload format indicator, subscription identifiers
- `definitely not MVP`: full property matrix for every packet type, shared subscriptions, request/response convenience features, optimization-heavy MQTT 5 features without proven need

Не вирішує:
- route policy
- storage policy
- federation policy

---

### 5.6. Transport Adapters

Приклади:
- TCP client endpoint
- internal loopback endpoint
- broker-to-broker link
- test transport

Core працює через transport abstraction.

---

### 5.7. Platform Layer

Залежить від ESP-IDF і надає:
- sockets
- timers
- tasks
- synchronization primitives
- NVS / LittleFS / other storage
- logging hooks
- metrics backend

---

## 6. Внутрішня доменна модель

### 6.1. Message

Внутрішній message object, не рівний MQTT packet.

Повинен містити щонайменше:
- topic
- payload reference
- qos
- retain flag
- timestamp
- origin
- scope
- route flags
- message/dedup id
- optional protocol metadata reference

#### Origin

Обов’язковий атрибут:
- local client
- local service
- remote broker
- recovered persisted message

Без `origin` неможливо коректно додати federation.

---

### 6.2. Subscription

Повинна містити:
- filter
- qos
- owner type
- owner id
- scope
- flags

#### Owner type

- local client
- remote broker
- internal service

---

### 6.3. DeliveryTarget

Абстракція одержувача:
- local client target
- remote broker target
- internal system target

Routing повинен працювати з `DeliveryTarget`, а не з `socket*`.

---

## 7. Подієва внутрішня модель

Внутрішня логіка повинна бути event-driven.

### Базові події

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

### Чому це важливо

Single broker:
- використовує лише локальні producers/consumers подій

Federated broker:
- додає remote event sources
- не ламає доменну модель

---

## 8. Ports and Adapters

Рекомендований стиль: **Hexagonal / Ports and Adapters**

### Основні порти

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

### Переваги

- core не залежить від ESP-IDF
- storage легко міняти
- federation можна вмикати поетапно
- тести можуть використовувати fake/mock adapters

---

## 9. Що заборонено хардкодити під single broker

### Заборонено

- вважати, що всі subscriptions належать лише локальним клієнтам
- вважати, що `publish origin` завжди локальний socket
- зберігати маршрути у вигляді списків сокетів
- змішувати MQTT packet model з domain model
- прив’язувати ACL лише до локальних session objects
- робити retained store без scope/namespace

### Потрібно

- зберігати ownership явно
- використовувати abstract ids
- тримати routing окремо від transport
- тримати federation metadata у моделі відразу

---

## 10. Namespace strategy

Federated архітектура потребує продуманого topic namespace.

### Рекомендація

```text
site/{site_id}/zone/{zone_id}/device/{device_id}/...
site/{site_id}/service/{service}/...
site/{site_id}/global/...
```

### Вигоди

- прості ACL
- прості export/import rules
- передбачуваний routing
- контроль локального vs глобального трафіку
- простіша агрегація

---

## 11. Еволюційний шлях

### Етап A — Clean Single Broker

Реалізувати:
- protocol engine
- qos engine
- session manager
- retained store
- subscription index
- acl engine
- routing engine
- transport abstraction
- storage interfaces

### Етап B — Observability

Додати:
- metrics
- event log
- trace points
- config model
- config schema versioning
- deterministic test hooks

### Етап C — Broker Link

Додати:
- point-to-point bridge
- export/import topic rules
- remote publish ingest
- origin tagging
- dedup metadata

### Етап D — Selective Federation

Додати:
- remote subscription propagation
- route policies
- anti-loop logic
- scoped retained policy

### Етап E — Production Federation

Додати:
- topology health
- reconnect logic
- failure isolation
- multi-node testing
- soak testing

---

## 12. Архітектурні профілі

### 12.1. Single Broker

Підходить для:
- N8R2
- невеликих локальних систем
- мінімальної складності

### 12.2. Primary / Standby

Підходить для:
- N16R8
- систем, де важлива доступність
- обмеженого failover without full federation

### 12.3. Federated Multi-Broker

Підходить для:
- N16R8
- кількох зон
- сегментованої системи
- масштабування без повного shared-state cluster

---

## 13. SRAM / PSRAM policy

### У внутрішній SRAM

Тримати:
- hot-path routing metadata
- task stacks
- transport/session control
- frequently accessed indexes
- QoS state machine control data

### У PSRAM

Тримати:
- payload buffers
- retained payload storage
- outbound queues
- session cold state
- diagnostics buffers
- snapshots/checkpoints

---

## 14. Тестова архітектура

Core повинен тестуватись окремо від платформи.

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

## 15. Єдина модель структури проєкту

Архітектурний документ фіксує **логічну модульну модель**, а `TECH_STACK.md`
описує її **фізичну реалізацію** у вигляді ESP-IDF `project/main/components/test`.

Тобто модель одна:
- логічні модулі визначають межі відповідальності
- фізичні `components/` є способом розкласти ці модулі в ESP-IDF build layout

### 15.1. Логічна модульна структура

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

/app
  node_runtime
  config_loader
  admin_api
```

### 15.2. Mapping у фізичну ESP-IDF структуру

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

## 16. Definition of Done для архітектури

Архітектура вважається здоровою, якщо:

1. Core можна запускати в unit/integration tests без ESP32 hardware.
2. MQTT packet model не протікає у доменний рівень.
3. Routing не залежить від socket implementation.
4. Federation можна додати без переписування session/qos/retained core.
5. Storage можна замінити без зміни бізнес-логіки.
6. Origin/target/scope є явними в доменній моделі.
7. Namespace правила зафіксовані до появи federation.

---

## 17. Підсумок

Правильний шлях розвитку:
- будувати **single-node deployment**
- але на базі **federation-ready broker core**

Не проєктувати “один брокер назавжди”, а проєктувати:
- чисте ядро
- чіткі інтерфейси
- подієву доменну модель
- незалежні transport/storage adapters

Тоді перехід від single broker до federated буде зміною топології і policy, а не переписуванням усієї системи.
