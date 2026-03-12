# DEPENDENCY_RULES.md

## 1. Мета

Цей документ фіксує допустимі залежності між модулями MQTT-брокера для ESP32-S3.

Його ціль:
- запобігти architectural drift під час реалізації
- зробити модульні межі перевірюваними
- дати основу для code review, CMake wiring і include policy

Документ узгоджується з:
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/TECH_STACK.md`
- `docs/architecture/CODING_GUIDELINES.md`
- `docs/architecture/MODULE_CONTRACTS.md`

---

## 2. Основний принцип

Залежності повинні прямувати:
- від `app/runtime` до `core` і `ports`
- від `adapters` до `ports`
- від `core` до `domain types` і `ports`

Залежності не повинні прямувати:
- від `core` до `adapters`
- від `core` до ESP-IDF/platform APIs
- від `ports` до `core`
- від `ports` до `adapters`

---

## 3. Логічні шари

Використовуємо такі логічні групи:
- `domain model`
- `core modules`
- `ports`
- `adapters`
- `app/runtime`
- `diagnostics`
- `tests`

### 3.1. `domain model`

Включає:
- `Message`
- `Subscription`
- `DeliveryTarget`
- shared enums/status/domain identifiers

### 3.2. `core modules`

Включає:
- `broker_core`
- `protocol_mqtt`
- `routing`
- `acl`
- `session`
- `retained`
- `qos`
- `federation`

### 3.3. `ports`

Включає:
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

Включає:
- `transport_tcp`
- `storage_nvs`
- `storage_psram`
- `bridge_link`
- `logger`
- `metrics`
- `tracing`
- platform-specific glue

### 3.5. `app/runtime`

Включає:
- `node_runtime`
- `config_loader`
- `admin_api`
- `app_main`

---

## 4. Dependency matrix

### 4.1. `domain model`

Може залежати від:
- standard utility types
- other domain types

Не може залежати від:
- `core modules`
- `ports`
- `adapters`
- `app/runtime`
- ESP-IDF/platform APIs

### 4.2. `ports`

Можуть залежати від:
- `domain model`
- standard utility types

Не можуть залежати від:
- `core modules`
- `adapters`
- `app/runtime`
- ESP-IDF/platform headers

### 4.3. `core modules`

Можуть залежати від:
- `domain model`
- `ports`
- other `core modules`, якщо це явно дозволено нижче

Не можуть залежати від:
- `adapters`
- `app/runtime`
- ESP-IDF/platform APIs
- concrete diagnostics backends

### 4.4. `adapters`

Можуть залежати від:
- `ports`
- `domain model`, якщо це потрібно для port payloads/contracts
- platform APIs

Не можуть залежати від:
- `app/runtime` business logic
- внутрішні core implementation details поза port contracts

### 4.5. `app/runtime`

Може залежати від:
- `core modules`
- `ports`
- `adapters`
- config/model utilities

Не повинна:
- містити дублікат domain/policy logic
- напряму вирішувати routing/ACL/QoS semantics

### 4.6. `diagnostics`

`diagnostics` як фізичний компонент відповідає за:
- `logger`
- `metrics`
- `tracing`

Може залежати від:
- `ports`
- `domain model`
- platform APIs, якщо це backend adapter

Не може змушувати `core` знати backend details.

---

## 5. Allowed core-to-core dependencies

### 5.1. `broker_core`

Може залежати від:
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

Може залежати від:
- `domain model`
- lightweight protocol packet model

Не повинен залежати від:
- `routing`
- `acl`
- `session`
- `retained`
- `qos`
- `federation`

Примітка:
- orchestration і виклик інших модулів робить `broker_core`, не `protocol_mqtt`

### 5.3. `routing`

Може залежати від:
- `domain model`
- `ISubscriptionIndex`
- `IAclPolicy`
- `IRouterPolicy`

Не повинен залежати від:
- `transport` adapters
- storage adapters
- `session` implementation details

### 5.4. `acl`

Може залежати від:
- `domain model`
- config/policy model

Не повинен залежати від:
- transport/session internals
- adapter code

### 5.5. `session`

Може залежати від:
- `domain model`
- `ISessionStore`

Може взаємодіяти з:
- `ISubscriptionIndex` через `broker_core` orchestration

Не повинен напряму залежати від:
- `routing`
- `transport` adapters

### 5.6. `retained`

Може залежати від:
- `domain model`
- `IRetainedStore`

Не повинен залежати від:
- adapter implementations
- transport concerns

### 5.7. `qos`

Може залежати від:
- `domain model`
- `IClock`

Не повинен залежати від:
- transport adapters
- storage adapters

### 5.8. `federation`

Може залежати від:
- `domain model`
- `IFederationLink`
- `IRouterPolicy`

Не повинен залежати від:
- конкретного broker-link transport implementation
- app/runtime wiring

---

## 6. Include policy

### 6.1. Core headers

Core headers:
- можуть include-ити domain headers
- можуть include-ити port headers
- не можуть include-ити ESP-IDF headers
- не можуть include-ити adapter headers

### 6.2. Port headers

Port headers:
- можуть include-ити domain headers
- не можуть include-ити core private headers
- не можуть include-ити platform headers

### 6.3. Adapter headers

Adapter headers:
- можуть include-ити port headers
- можуть include-ити platform headers
- не повинні expose-ити platform handles через public contracts core-facing API

### 6.4. App/runtime headers

App/runtime:
- можуть include-ити core, ports, adapters
- не повинні створювати нові крос-залежності між core modules через shared god header

---

## 7. CMake dependency policy

Для ESP-IDF `components/`:
- `ports` не `REQUIRES` core modules
- core components `REQUIRES` only `ports` and strictly needed sibling core contracts
- adapter components `REQUIRES` `ports` and platform/runtime libs
- `main`/runtime component збирає все разом

Bad examples:
- `routing` depends on `transport_tcp`
- `ports` depends on `routing`
- `protocol_mqtt` depends on `storage_nvs`

Good examples:
- `routing` depends on `ports`
- `storage_nvs` depends on `ports`
- `main` depends on `broker_core`, `routing`, `ports`, `transport_tcp`, `storage_nvs`

---

## 8. Test dependency rules

### 8.1. Host tests

Можуть залежати від:
- `domain model`
- `core modules`
- fake/mock implementations of `ports`
- broader STL/test tooling

Не повинні залежати від:
- real ESP-IDF runtime
- concrete hardware/network stack

### 8.2. Integration tests

Можуть залежати від:
- `core modules`
- `ports`
- selected real adapters

### 8.3. Simulation tests

Можуть залежати від:
- `core modules`
- fake `IFederationLink`
- fake clock
- controlled multi-node harness

### 8.4. Hardware tests

Можуть залежати від:
- full runtime wiring
- platform adapters
- real hardware behavior

---

## 9. Forbidden dependency patterns

Заборонено:
- `core -> adapter`
- `core -> ESP-IDF`
- `routing -> socket descriptor`
- `acl -> session socket identity`
- `protocol_mqtt -> routing policy decision`
- `ports -> platform headers`
- `tests -> hidden real time sleeps for core timing logic`
- `app/runtime -> duplicated domain rules`

---

## 10. Review checklist

При рев’ю кожної зміни перевіряти:
1. Чи не з’явилась нова залежність `core -> adapter`
2. Чи не почав `ports` тягнути platform/core implementation details
3. Чи не з’явився god-module через convenience include
4. Чи не порушено host-side testability
5. Чи не змішано policy і mechanism
6. Чи узгоджується CMake `REQUIRES` з цим документом

---

## 11. Definition of Done

Правила залежностей вважаються зафіксованими, якщо:
- кожен модуль можна однозначно віднести до одного logical layer
- всі міжмодульні залежності проходять через дозволені контракти
- core можна збирати і тестувати без adapters/platform runtime
- adapters можна замінювати без переписування core
- review/CMake/include policy не суперечать цим правилам
