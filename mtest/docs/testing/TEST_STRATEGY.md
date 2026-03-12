# TEST_STRATEGY.md

## 1. Мета

Цей документ описує тестову стратегію для MQTT-брокера на ESP32-S3 з урахуванням еволюції:

- від `Single broker`
- до `Primary/Standby`
- і далі до `Federated multi-broker`

Ключова мета тестування:
- забезпечити стабільність core-логіки
- не допустити регресій при зростанні архітектури
- ізолювати platform-specific ризики від domain logic
- зробити перевірку поведінки відтворюваною
- виявляти проблеми SRAM/PSRAM, черг, QoS, routing і federation до запуску на реальному залізі

---

## 2. Головні принципи тестування

1. **Core test first**
   - спочатку перевіряється доменна логіка, потім платформа

2. **Deterministic over ad-hoc**
   - тести повинні бути повторюваними й детермінованими

3. **Host-first validation**
   - максимальна кількість логіки перевіряється без ESP32 hardware

4. **Bounded resource testing**
   - ліміти пам’яті, черг і payload перевіряються явно

5. **Regression-safe evolution**
   - додавання federation не повинно ламати single broker behavior

6. **Failure-paths are first-class**
   - помилкові сценарії тестуються так само серйозно, як і happy path

---

## 3. Піраміда тестування

```text
                    +----------------------+
                    |   Soak / Longevity   |
                    +----------------------+
                    | Fault / Chaos / HA   |
                    +----------------------+
                    |  Multi-node Sim      |
                    +----------------------+
                    | Integration Tests    |
                    +----------------------+
                    | Unit / Property      |
                    +----------------------+
```

### Рівні тестування

- **Unit tests**
  - перевірка дрібних правил і state transitions

- **Property tests**
  - перевірка інваріантів на великій кількості варіантів

- **Integration tests**
  - перевірка взаємодії модулів

- **Simulation tests**
  - перевірка multi-node/federation сценаріїв

- **Fault/chaos tests**
  - перевірка збоїв, reorder, duplicates, disconnects

- **Soak tests**
  - перевірка витоків, деградації, накопичення помилок

---

## 4. Scope тестування

### Що повинно тестуватись обов’язково

- topic matching
- subscription index behavior
- router policy behavior
- routing decisions
- ACL decisions
- retained semantics
- QoS1 state machine
- session lifecycle
- queue overflow behavior
- reconnect behavior
- persistence restore
- federation metadata propagation
- anti-loop / dedup behavior
- read-model snapshot behavior
- reducer/effect flow behavior
- async operation lifecycle behavior

### Що не можна вважати “достатньо перевіреним” без тестів

- порядок доставки
- робота при повторних publish
- поведінка при timeout/retry
- робота bridge/federation
- поведінка при відновленні після перезапуску
- контроль лімітів пам’яті та черг
- snapshot consistency for app-facing APIs
- explicit async completion/timeout behavior

---

## 5. Розділення тестового контуру

### 5.1. Host-side tests

Запускаються без ESP32 і покривають:
- domain logic
- subscription index
- router policy
- routing
- retained
- QoS transitions
- dedup
- ACL
- federation policies
- config validation
- config version migration
- read-model builders/coordinator
- reducer/effect execution logic
- async operation result store

Це основний контур швидкого зворотного зв’язку.

---

### 5.2. Platform integration tests

Запускаються з ESP-IDF або platform adapter layer і покривають:
- transport adapter
- timers
- storage backends
- reconnect behavior
- task coordination
- platform error propagation

---

### 5.3. Hardware tests

Запускаються на реальних ESP32-S3 і покривають:
- Wi-Fi instability
- memory pressure
- task scheduling side effects
- actual throughput/latency
- watchdog interactions
- flash/NVS persistence behavior

---

## 6. Unit tests

Unit tests повинні бути наймасовішим класом тестів.

### 6.1. Topic matching

Перевірити:
- exact match
- single-level wildcard
- multi-level wildcard
- пусті сегменти
- некоректні filters
- edge cases по namespace

### 6.2. Routing engine

Перевірити:
- локальну доставку
- кілька matching subscriptions
- відсутність збігів
- route policy allow/deny
- local-only topics
- remote-exportable topics

### 6.3. Subscription index

Перевірити:
- add/remove subscription
- duplicate subscription handling
- owner-based lookup
- wildcard index correctness
- restore consistency after session resume
- local vs remote subscription ownership

### 6.4. Router policy

Перевірити:
- allow/deny route decisions
- local-only topic enforcement
- remote-export eligibility
- policy behavior for remote-origin messages
- policy behavior under scoped namespaces

### 6.5. Retained store

Перевірити:
- створення retained
- overwrite retained
- видалення retained через empty payload
- retained delivery новому subscriber
- scoped retained policy

### 6.6. QoS1 state machine

Перевірити:
- publish accepted
- inflight registration
- ack completion
- retry after timeout
- duplicate handling
- cleanup after disconnect

### 6.7. Session manager

Перевірити:
- new session creation
- clean session
- persistent session resume
- restore subscriptions
- restore inflight metadata
- cleanup rules

### 6.8. ACL engine

Перевірити:
- allow publish
- deny publish
- allow subscribe
- deny subscribe
- default deny behavior
- scoped ACL rules

### 6.9. Federation policy

Перевірити:
- should_forward
- should_drop
- import/export filtering
- scope mapping
- anti-loop markers
- dedup checks

### 6.10. Config versioning

Перевірити:
- parse current schema version
- migrate previous supported version to current schema
- sequential migration across multiple versions
- reject unsupported future schema version
- reject unsupported legacy schema version
- apply documented defaults only for optional fields
- reject missing required fields after migration

### 6.11. Event model

Перевірити:
- correct event emission for `ClientConnected`, `ClientDisconnected`, `PublishReceived`
- correct event emission for `SubscriptionAdded`, `SubscriptionRemoved`, `RetainedUpdated`
- correct event emission for `RouteResolved`, `DeliveryRequested`, `ForwardRequested`
- correct event emission for `RemotePublishReceived`
- no unexpected event emission on rejected/failed operations
- event payload correctness for ids, `origin`, `scope`, route metadata
- deterministic event ordering in single-threaded test scenarios

### 6.12. Read models

Перевірити:
- snapshot build for empty state
- snapshot rebuild after relevant state change
- no live mutable state leakage through app-facing snapshots
- bounded snapshot size under configured limits
- deterministic DTO/view content for the same input state

### 6.13. Reducer and effect flow

Перевірити:
- validated command/event produces deterministic transition result
- effect plan is emitted explicitly and in deterministic order
- reducer path does not require real I/O or platform runtime
- effect completion is handled as explicit event/result, not hidden callback mutation
- no side effects are executed inline where contract expects planning only

### 6.14. Async operations

Перевірити:
- `request_id` generation uniqueness
- queued -> in_progress -> completed path
- failure path with explicit terminal status
- timeout path with fake clock
- bounded operation result store behavior
- completed/expired operation cleanup rules

---

## 7. MQTT 5 readiness tests

Цей розділ фіксує, які MQTT 5 capability areas повинні отримати тести при поетапному rollout.

### 7.1. Must-have later

Коли ці можливості вводяться, обов’язково додати:
- reason code correctness tests
- session expiry behavior tests
- message expiry propagation/drop tests
- receive maximum enforcement tests
- maximum packet size acceptance/rejection tests
- topic alias tests, якщо feature ввімкнений у конкретному профілі

### 7.2. Maybe later

Якщо ці можливості будуть реалізовані, потрібні:
- user properties parse/serialize tests
- response topic / correlation data mapping tests
- content type and payload format indicator tests
- subscription identifier propagation tests

### 7.3. Definitely not MVP

До MVP не повинні вимагатися:
- full packet-property matrix tests for every MQTT 5 packet type
- shared subscription behavior tests
- request/response convenience feature suites
- optimization-only MQTT 5 feature benchmarks without proven need

### 7.4. Загальне правило

Кожна нова MQTT 5 capability повинна отримати:
- unit tests for protocol semantics
- integration tests for broker behavior
- memory-budget review for N8R2 and N16R8 profiles
- regression tests before feature is enabled by default

---

## 8. Property-based tests

Там, де є багато комбінацій, краще використовувати property-oriented підхід.

### Рекомендовані області

- topic matching
- subscription filters
- route decision invariants
- dedup rules
- anti-loop rules
- queue policy correctness

### Приклади інваріантів

- повідомлення не повинно бути доставлене target-у, якому ACL це забороняє
- anti-loop policy не повинна дозволяти нескінченне повторне форвардення
- retained store повинен мати не більше одного актуального value на topic key
- queue size ніколи не повинна перевищувати configured limit

---

## 9. Integration tests

Integration tests перевіряють взаємодію кількох модулів.

### 9.1. Protocol + Session + Routing

Сценарії:
- client connect
- `ClientConnected` emitted
- subscribe
- `SubscriptionAdded` emitted
- subscription index updated
- publish
- `PublishReceived` and `RouteResolved` emitted in deterministic order
- message routed to matching subscribers
- `DeliveryRequested` emitted for resolved local targets
- disconnect
- `ClientDisconnected` emitted

### 9.2. Protocol + Retained

Сценарії:
- publish retained
- new subscriber connects
- retained delivered
- retained updated
- retained deleted

### 9.3. Protocol + QoS1

Сценарії:
- publish with qos1
- inflight create
- ack received
- inflight cleanup
- timeout then retry

### 9.4. Session + Persistence

Сценарії:
- persist session snapshot
- restart broker
- restore session
- restore subscriptions
- recover retained metadata

### 9.5. Config loader + Validation

Сценарії:
- load current config
- load previous supported config and migrate to current
- reject incompatible config version
- reject invalid normalized config

### 9.6. Read models + Runtime facade

Сценарії:
- runtime state changes
- read model coordinator rebuilds affected snapshot
- facade returns stable snapshot
- caller does not observe live mutable internals
- snapshot remains bounded under configured limits

### 9.7. Runtime reducer + Effect executor

Сценарії:
- command enters reducer path
- deterministic effect plan is produced
- effect executor performs side effects outside reducer
- completion/error returns as explicit event/result
- resulting state and emitted events remain deterministic

### 9.8. Async operation flow

Сценарії:
- caller submits async operation
- runtime allocates `request_id`
- operation result store exposes `queued`/`in_progress`
- completion publishes final result
- timeout path transitions to terminal timeout state

### 9.9. Routing + Federation policy

Сценарії:
- local only route
- forward-eligible message
- remote-origin message rejected by anti-loop
- namespace export/import rules
- `ForwardRequested` emitted only when federation policy allows forwarding

### 9.10. Event sequencing and capture

Сценарії:
- rejected publish does not emit delivery/forward events
- retained update emits `RetainedUpdated` exactly once per accepted change
- remote publish path emits `RemotePublishReceived` before forward/delivery decisions
- event capture in tests is deterministic and does not depend on real timing

---

## 10. Simulation tests

Simulation tests потрібні для переходу до federation.

### Мінімальний simulation harness

Повинен уміти:
- створити node A
- створити node B
- створити fake federation link
- управляти fake clock
- моделювати packet loss
- моделювати duplicates
- моделювати reorder
- моделювати temporary disconnect

### Які сценарії тестувати

- broker A forward to broker B
- broker B subscribe then receive remote message
- duplicate remote publish dropped
- loop prevention works
- reconnect restores link behavior
- partial topology degradation

---

## 11. Fault and chaos tests

Ці тести потрібні, щоб система була готова до реального світу.

### 11.1. Network fault tests

Перевірити:
- short disconnect
- long disconnect
- reconnect storm
- partial packet loss
- reordering
- delayed ack

### 11.2. Storage fault tests

Перевірити:
- failed write
- partial snapshot
- corrupted persisted state
- storage full
- slow storage backend

### 11.3. Memory pressure tests

Перевірити:
- queue almost full
- retained limit reached
- payload too large
- PSRAM exhaustion
- SRAM budget crossing
- allocator fragmentation symptoms

### 11.4. Federation fault tests

Перевірити:
- broker link down
- broker link returns stale data
- duplicated subscription announcements
- repeated remote reconnects
- partial topology visibility

---

## 12. Soak and longevity tests

Ці тести повинні виконуватись довго.

### Цілі

- знайти memory leaks
- знайти state accumulation bugs
- знайти stuck inflight items
- знайти route table growth bugs
- перевірити стабільність reconnect behavior

### Мінімальні режими

- 1 година — smoke longevity
- 8 годин — nightly soak
- 24 години — pre-release soak
- 72 години — architecture milestone soak

### Під час soak тестів збирати

- heap usage
- high-water marks
- queue occupancy
- reconnect counts
- retry counts
- dedup drops
- retained count stability
- session count stability

---

## 13. Performance tests

Performance tests не замінюють correctness tests.

### Що вимірювати

- publish latency
- end-to-end delivery latency
- throughput
- queue growth rate
- reconnect recovery time
- retained lookup time
- routing cost vs subscriptions count

### Окремо вимірювати

- single broker mode
- broker under memory pressure
- broker with persistence enabled
- federated forwarding mode

---

## 14. Memory-focused tests

Оскільки платформа resource-constrained, пам’ять — частина контракту.

### 14.1. SRAM tests

Перевіряти:
- usage after startup
- usage under active subscriptions
- usage under QoS1 load
- high-water mark under reconnects

### 14.2. PSRAM tests

Перевіряти:
- retained storage growth
- queue slab usage
- payload buffering pressure
- snapshot buffer pressure

### 14.3. Budget assertions

У тестах мають бути порогові перевірки:
- max clients budget
- max retained budget
- max queue depth budget
- max payload budget

---

## 15. Regression test suites

Після кожного знайденого багу створюється regression test.

### Обов’язкове правило

Кожен виправлений баг повинен мати:
- короткий опис сценарію
- мінімальний відтворюваний тест
- очікувану правильну поведінку

### Категорії регресій

- protocol
- routing
- retained
- qos
- persistence
- federation
- memory
- reconnect
- ACL

---

## 16. Test data strategy

### Дані повинні бути

- малими для unit tests
- репрезентативними для integration tests
- параметризованими для property tests
- контрольованими для deterministic replay

### Повинні бути набори

- valid topic cases
- invalid topic cases
- ACL matrices
- retained overwrite cases
- qos retry cases
- federation dedup cases

---

## 17. Clock and timing strategy

### Заборонено

- реальні `sleep()` у більшості unit/integration tests
- недетерміновані timeout-based очікування без контролю часу

### Потрібно

- injectable clock
- manual time advance
- explicit timeout triggers
- reproducible scheduling

Це критично для:
- QoS retry
- reconnect logic
- session timeout
- federation link recovery

---

## 18. CI strategy

### На кожному PR

Запускати:
- unit tests
- static checks
- config validation
- config migration tests
- core integration tests
- read-model tests
- reducer/effect flow tests
- async operation tests

### Nightly

Запускати:
- extended integration tests
- simulation tests
- memory budget tests
- short soak tests

### Перед release

Запускати:
- full regression suite
- hardware integration suite
- long soak tests
- performance baselines
- federation fault scenarios

---

## 19. Hardware test matrix

Мінімально потрібно тестувати на:

- ESP32-S3 N8R2
- ESP32-S3 N16R8

### На кожній платформі перевірити

- single broker
- retained heavy load
- qos1 load
- reconnect storms
- persistence restore
- bridge/federation basic mode

### Окремо для N8R2

- tighter memory limits
- smaller queue budgets
- retained pressure
- PSRAM sensitivity

### Окремо для N16R8

- larger retained sets
- bigger queue depth
- standby/federation scenarios
- longer soak modes

---

## 20. Observability requirements for tests

Щоб тести були корисними, система повинна мати:

- counters
- event traces
- structured logs
- memory high-water marks
- queue fill telemetry
- retry counters
- dedup counters
- route decision traces

Без цього fault і soak тести важко аналізувати.

---

## 21. Testability requirements for code

Код вважається тестопридатним, якщо:

1. Core запускається без ESP-IDF runtime.
2. Clock можна підмінити.
3. Storage можна підмінити.
4. Transport можна підмінити.
5. Federation link можна підмінити.
6. Memory budgets можна спостерігати.
7. Logs/metrics доступні з тестів.

---

## 22. Definition of Done для тестової стратегії

Тестова стратегія вважається реалізованою, якщо:

1. Є повний unit coverage для critical core logic.
2. Є integration tests для session/qos/retained/routing.
3. Є окремі test areas для read-models, reducer/effect flow і async operations.
4. Є simulation tests для broker link і federation.
5. Є fault tests для reconnect, storage і memory pressure.
6. Є soak tests мінімум на 24 години перед release.
7. Є окремі бюджети й порогові перевірки для N8R2 і N16R8.
8. Кожен баг має regression test.

---

## 23. Підсумок

Хороша тестова стратегія для цього проєкту — це не просто набір тестів, а багаторівнева система перевірки, де:

- core логіка масово тестується на host-машині
- platform-specific ризики перевіряються окремо
- federation вводиться через simulation до реального заліза
- помилкові сценарії тестуються на рівні з happy path
- пам’ять, черги, retry і reconnect розглядаються як частина контракту системи

Такий підхід дозволяє безпечно рости від `Single broker` до `Federated multi-broker` без втрати стабільності.
