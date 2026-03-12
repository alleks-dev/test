# SKELETON_PLAN.md

## 1. Мета

Цей документ описує практичний план створення першого compileable skeleton-коду MQTT-брокера.

Його ціль:
- перевести документацію в робочий project skeleton
- дати чіткий порядок створення `components/`, headers і tests
- мінімізувати імпровізацію під час перших комітів

---

## 2. Принципи першого skeleton milestone

- спочатку compileable structure, потім behavior
- core повинен збиратися без ESP-IDF runtime
- ports створюються раніше за adapters
- fake/test adapters створюються рано, щоб одразу перевірити testability
- ніякого “тимчасового” порушення dependency rules

---

## 3. Ціль першого milestone

Після першого skeleton milestone проект повинен мати:
- валідну ESP-IDF component structure
- host-buildable core/domain/ports
- public headers для ключових port contracts
- мінімальні stub implementations для core modules
- базовий test harness
- перші unit tests green

Не вимагається на цьому етапі:
- реальна мережа
- реальний storage backend
- production runtime behavior
- full MQTT protocol implementation

---

## 4. Структура, яку створюємо першою

### 4.1. Root files

Створити:
- `CMakeLists.txt`
- `partitions.csv`
- `sdkconfig.defaults`
- `sdkconfig.defaults.n8r2`
- `sdkconfig.defaults.n16r8`
- `sdkconfig.defaults.debug`
- `sdkconfig.defaults.release`

### 4.2. Main/runtime

Створити:
- `main/CMakeLists.txt`
- `main/app_main.cpp`

Перший `app_main` повинен:
- лише збирати runtime graph
- не містити бізнес-логіки

### 4.3. Components

Створити порожні, але валідні `components/`:
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

---

## 5. Headers, які створюються першими

### 5.1. Domain headers

Перші domain headers:
- `message.hpp`
- `subscription.hpp`
- `delivery_target.hpp`
- `result.hpp`
- `domain_event.hpp`

### 5.2. Port headers

Перші public port headers:
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

Перші core-facing headers:
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
- initial methods may be stubbed but signatures must respect `MODULE_CONTRACTS.md`

### 5.4. Test-only access headers

Якщо модулю потрібен test-only seam, він повинен створюватися окремо:
- `broker_core_test_access.hpp`
- `session_test_access.hpp`
- `routing_test_access.hpp`

Rules:
- production code не повинен залежати від цих headers
- вони не замінюють нормальні public contracts
- вони використовуються лише там, де fake ports/black-box tests недостатні

---

## 6. Порядок створення модулів

Рекомендований порядок:
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
15. real platform adapters scaffolding

Reason:
- domain and ports stabilize contracts
- fake test adapters enable host-side tests early
- `broker_core` should be composed after module contracts exist

---

## 7. Stub implementation policy

Перші implementations можуть:
- повертати `ERR_UNSUPPORTED_FEATURE`
- повертати empty/no-op plans where contract allows
- логувати `not implemented` only in debug/test mode

Перші implementations не можуть:
- порушувати dependency rules
- тягнути ESP-IDF в core
- маскувати not-implemented state як успішну поведінку

---

## 8. Test harness, який потрібен одразу

### 8.1. Host test base

Створити:
- fake `IClock`
- fake `ISubscriptionIndex`
- fake `IAclPolicy`
- fake `IRouterPolicy`
- fake `ISessionStore`
- fake `IRetainedStore`
- fake `IFederationLink`
- fake event capture sink

### 8.2. Minimal integration harness

Створити:
- in-memory runtime wiring for core modules
- no real socket/network/storage requirement

---

## 9. Перші 10 тести

Перші тести, які мають з’явитися рано:
1. topic matching exact/wildcard basics
2. `ISubscriptionIndex` add/remove/query basics
3. `IAclPolicy` default deny behavior
4. `IRouterPolicy` local-only vs exportable decision
5. `routing` returns deterministic empty/no-match result
6. `retained` create/update/delete semantics
7. `qos` timeout logic with fake clock
8. `config_loader` current schema parse
9. `config_loader` previous version migration
10. event capture deterministic ordering for publish path

---

## 10. First compileable milestone definition

Milestone вважається досягнутим, якщо:
- `components/` structure exists
- all public headers compile
- host-side test target builds
- no core module includes ESP-IDF headers
- fake adapters satisfy required ports
- first 10 tests pass

---

## 11. Early CMake rules

- architecture check target повинен існувати рано, навіть якщо codebase ще мала
- `check_arch_invariants.sh` має входити в локальний і CI bootstrap bundle

На старті:
- `ports` independent component
- each core module separate component where practical
- `diagnostics` separate from core
- host test build for domain/core/ports independent from ESP-IDF runtime

Avoid:
- monolithic `broker_core` component that absorbs all logic
- adapter code linked into core test target

---

## 12. First runtime scope

Перший runtime scope повинен бути мінімальним:
- one in-process broker instance
- in-memory config
- fake/in-memory adapters where possible
- no Wi-Fi dependency
- no persistence dependency

---

## 13. Review checklist for skeleton PRs

Для кожного skeleton PR перевіряти:
1. Чи не порушено `DEPENDENCY_RULES.md`
2. Чи відповідають signatures `MODULE_CONTRACTS.md`
3. Чи є host-side buildability
4. Чи не з’явився platform leakage у core
5. Чи є хоча б один test або compile check на новий контракт

---

## 14. Next milestone after skeleton

Після skeleton milestone переходити до:
- real topic matching
- real subscription index behavior
- basic routing
- retained semantics
- QoS1 core state machine
- config loader implementation
- event emission wiring

---

## 15. Implementation note

Якщо під час створення skeleton виникає спокуса:
- “тимчасово” змішати adapter і core
- “тимчасово” прибрати port
- “тимчасово” покласти логіку в `app_main`

це сигнал, що skeleton plan порушується і треба виправити дизайн до написання коду, а не після.
