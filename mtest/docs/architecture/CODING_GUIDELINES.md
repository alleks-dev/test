# CODING_GUIDELINES.md

## 1. Мета

Цей документ задає правила розробки MQTT-брокера для ESP32-S3 так, щоб код залишався:

- модульним
- читабельним
- тестованим
- resource-aware
- придатним до еволюції від `Single broker` до `Federated multi-broker`

---

## 2. Базові принципи

1. **Core first, platform second**
2. **Domain model before packet model**
3. **Interfaces before implementations**
4. **Deterministic logic before asynchronous orchestration**
5. **Explicit metadata over hidden assumptions**
6. **Testability is a feature**
7. **Memory placement is part of design**

---

## 3. Загальні правила коду

### 3.1. Один модуль — одна відповідальність
Кожен модуль повинен мати одну чітку причину для зміни.

### 3.2. Заборонено змішувати рівні абстракції
Не можна:
- парсити MQTT packet
- оновлювати session
- вирішувати routing
- писати в socket

в одній функції.

### 3.3. Мінімум глобального стану
Глобальні змінні дозволені лише для:
- compile-time constants
- platform bootstrap
- very small immutable config

### 3.4. Explicit ownership
Кожен буфер, об’єкт і дескриптор повинен мати явного власника.

---

## 4. Правила для архітектурних шарів

### 4.1. Core
Core не повинен напряму залежати від:
- ESP-IDF headers
- FreeRTOS primitives
- lwIP details
- NVS API
- socket descriptors

Core залежить лише від domain interfaces.

### 4.2. Adapters
Adapters:
- перекладають platform-specific логіку в доменні інтерфейси
- не містять бізнес-правил маршрутизації чи QoS semantics

### 4.3. Application layer
Application layer:
- збирає залежності
- конфігурує runtime
- підключає policy implementations
- не містить packet parsing logic

---

## 5. Naming conventions

### 5.1. Типи
- `PascalCase` для типів і структур
- приклад: `BrokerCore`, `MessageView`, `SubscriptionEntry`

### 5.2. Функції
- `snake_case` або єдиний обраний стиль для всього проєкту
- приклад: `route_publish`, `session_resume`, `retained_store_put`

### 5.3. Інтерфейси
Префікс:
- `ITransportEndpoint`
- `IRetainedStore`
- `IFederationLink`

### 5.4. Поля структури
Назви повинні бути короткі й однозначні:
- `origin`
- `scope`
- `owner_id`
- `qos`
- `retain`
- `flags`

---

## 6. Правила для функцій

### 6.1. Функція має робити одну річ
Погано:
- parse + validate + route + persist + deliver

Добре:
- `parse_publish_packet`
- `validate_publish`
- `route_message`
- `persist_retained_if_needed`
- `schedule_delivery`

### 6.2. Обмеження по розміру
Бажано:
- до 40–60 рядків для звичайної функції
- довші функції тільки якщо це справді спрощує читання

### 6.3. Аргументи
Якщо аргументів більше ніж 4–5:
- об’єднувати у config/context struct

### 6.4. Side effects
Side effects мають бути очевидними з назви й контракту функції.

---

## 7. Domain model rules

### 7.1. MQTT packet != domain object
Ніколи не тягнути packet-level структури через усі шари.

### 7.2. Message metadata обов’язкові
Кожне повідомлення повинно мати:
- `origin`
- `scope`
- `route_flags`
- `timestamp` або equivalent ordering metadata

### 7.3. Subscription metadata обов’язкові
Підписка повинна містити:
- filter
- qos
- owner type
- owner id
- federation-related flags

---

## 8. Error handling

### 8.1. Ніяких “мовчазних” помилок
Кожна помилка повинна:
- повертатись явно
- або логуватись
- або накопичуватись у metrics

### 8.2. Error codes over ad-hoc booleans
Краще:
- `enum ResultCode`
- `Status`
- `Expected<T, E>`

Гірше:
- просто `true/false` без контексту

### 8.3. Fail closed for policy
Якщо ACL/policy не може бути оцінена:
- за замовчуванням блокувати, а не пропускати

---

## 9. Memory management guidelines

### 9.1. SRAM — для hot-path
У внутрішній RAM повинні жити:
- frequently accessed indexes
- session control data
- hot routing metadata
- task stacks
- small fixed-control structures

### 9.2. PSRAM — для cold/bulk data
У PSRAM:
- payload buffers
- retained payload storage
- queue slabs
- diagnostics/history buffers
- large temporary serialization buffers

### 9.3. Заборонено неконтрольоване виділення пам’яті
Не можна:
- безмежно malloc/new в packet path
- будувати логіку навколо фрагментації heap

### 9.4. Бажано використовувати
- fixed pools
- slab allocators
- bounded ring buffers
- preallocated queues

---

## 10. Concurrency guidelines

### 10.1. Мінімізувати shared mutable state
Де можливо:
- message passing
- command queues
- immutable views

### 10.2. Locking policy
Локінг має бути:
- коротким
- локалізованим
- документованим

### 10.3. Не тримати lock під час
- network I/O
- storage I/O
- callback execution
- logging with unpredictable latency

### 10.4. Deterministic ordering
Ключові state transitions повинні мати передбачуваний порядок:
- connect
- subscribe
- publish
- ack
- disconnect
- session cleanup

---

## 11. Logging rules

### 11.1. Structured logging
Логи мають бути машинно корисними.

Мінімум:
- module
- event
- entity id
- result
- reason/error code

### 11.2. Не логувати зайвий payload
Не виводити повні payload-и за замовчуванням.

### 11.3. Trace points
Для складних сценаріїв додати trace events:
- route decision
- retained update
- qos retransmit
- remote forward
- anti-loop drop

---

## 12. Metrics rules

### Мінімальний набір метрик
- connected clients
- subscriptions count
- retained count
- inflight qos1 count
- queue fill levels
- publish accepted/rejected
- acl allow/deny
- forward count
- dedup drops
- retry count
- memory high-water marks

---

## 13. Testing rules

### 13.1. Кожен bugfix має йти з тестом
Не виправляти поведінку без відтворюваного тесту.

### 13.2. Core tests обов’язкові
Покриття мінімум для:
- topic matching
- routing
- ACL decisions
- retained behavior
- qos state transitions
- session restore
- federation metadata propagation

### 13.3. Property-oriented tests вітаються
Особливо для:
- wildcard matching
- dedup logic
- anti-loop rules
- queue policies

### 13.4. Timing tests без real sleeps
Використовувати injectable/fake clock.

### 13.5. Event emission must be testable
Подієва модель повинна дозволяти:
- deterministic capture emitted events in tests
- перевірку payload/meta кожної події
- перевірку відсутності зайвих подій при reject/error paths

### 13.6. Test-only access must use dedicated seams
- production public headers не повинні містити macro-gated test APIs
- якщо тестам потрібен доступ до internal runtime state, це робиться через окремий `*_test_access.hpp`
- test-only access headers не повинні ставати обов'язковими залежностями для production build

---

## 14. Code review rules

Кожен PR повинен перевірятися на:
1. Чи не порушено межі модулів
2. Чи не протікає platform code у core
3. Чи не змішано packet-level і domain-level логіку
4. Чи не з’явились hidden allocations
5. Чи задокументовані ownership/lifetime
6. Чи є тести
7. Чи є metrics/logging для нової поведінки

---

## 15. Federation-ready coding rules

### 15.1. Ніколи не припускати local-only world
Кожна сутність повинна допускати:
- local origin
- remote origin

### 15.2. Owner identity must be abstract
Не прив’язувати subscription/delivery до socket pointer.

### 15.3. Dedup support
Повідомлення, що можуть перетинати broker links, повинні мати metadata для dedup/loop prevention.

### 15.4. Policy separate from mechanism
- mechanism: як форвардити
- policy: що саме форвардити

### 15.5. Follow documented namespace contract
- topic naming, ACL scope, export/import rules і route scoping повинні відповідати documented namespace contract, зафіксованому в `docs/architecture/ARCHITECTURE.md`
- core не повинен хардкодити ad-hoc або local-only namespace conventions
- розширення namespace допускаються лише через documented config/policy changes, а не через приховані code-path assumptions

---

## 16. Configuration guidelines

### Конфіг має бути:
- явним
- versioned
- bounded
- validated at startup

### Стратегія versioning
- кожен config schema повинен мати явне поле `schema_version`
- `config_loader` повинен знати supported versions і current version
- міграції дозволені лише вперед: `vN -> vN+1`
- пропущені проміжні версії мігруються послідовно, а не “магічно”
- unknown critical fields або несумісна major-version схема повинні завершуватись fail-fast помилкою startup
- відсутні optional fields можуть заповнюватися лише явними documented defaults
- після міграції конфіг повинен бути нормалізований до current schema перед передачею в runtime

### Повинні бути окремі секції
- protocol limits
- memory budgets
- queue limits
- retained limits
- federation policy
- logging/metrics
- persistence policy

### Вимоги до тестування config versioning
- потрібні тести на parse current version
- потрібні тести на migration from previous supported versions
- потрібні тести на reject unsupported future/legacy versions
- потрібні тести на unknown required fields і missing required fields

---

## 17. Documentation rules

Кожен модуль повинен мати короткий header comment:
- responsibility
- inputs/outputs
- ownership expectations
- threading assumptions
- memory expectations

Кожен нетривіальний алгоритм повинен мати:
- короткий rationale comment
- а не покроковий переказ коду

Architecture-governance документи теж є нормативними:
- `docs/governance/ARCH_COMPLIANCE_MATRIX.md`
- `docs/governance/ADR_EXCEPTIONS.md`
- `docs/governance/TEAM_WORKFLOW.md`
- `docs/governance/ARCH_CHECKS.md`

---

## 18. Anti-patterns

### Заборонені anti-patterns
- God object broker class
- direct socket pointers in routing tables
- unbounded dynamic allocation in packet path
- hidden retry logic
- implicit ownership transfer
- packet structs leaked into domain layer
- hardcoded single-node assumptions
- policy logic embedded in transport code

---

## 19. Recommended module contracts

### Приклад хороших контрактів
- `route_message(MessageView msg) -> RoutePlan`
- `deliver(RoutePlan plan) -> DeliveryResult`
- `retained_store_put(TopicKey key, PayloadRef payload, RetainedMeta meta)`
- `session_resume(ClientId id) -> SessionRestoreResult`
- `federation_should_forward(const MessageView* msg) -> bool`

---

## 20. Definition of Done для коду

Код вважається готовим, якщо:
1. Є тести на core behavior
2. Немає порушення меж модулів
3. Немає uncontrolled allocation у hot path
4. Є logging/metrics hooks
5. Є documented ownership
6. Код допускає remote-origin / remote-target semantics
7. Конфігураційні ліміти явні й перевіряються

---

## 21. Підсумок

Правильний код для цього проєкту — це код, який:
- не прив’язаний до одного вузла
- не прив’язаний до одного transport
- не залежить від конкретного storage backend
- не ховає state transitions
- легко тестується без заліза
- поважає обмеження SRAM/PSRAM
- готовий до переходу від single broker до federated без переписування core
