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

### Що не можна вважати “достатньо перевіреним” без тестів

- порядок доставки
- робота при повторних publish
- поведінка при timeout/retry
- робота bridge/federation
- поведінка при відновленні після перезапуску
- контроль лімітів пам’яті та черг

---

## 5. Розділення тестового контуру

### 5.1. Host-side tests

Запускаються без ESP32 і покривають:
- domain logic
- routing
- retained
- QoS transitions
- dedup
- ACL
- federation policies
- config validation

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

### 6.3. Retained store

Перевірити:
- створення retained
- overwrite retained
- видалення retained через empty payload
- retained delivery новому subscriber
- scoped retained policy

### 6.4. QoS1 state machine

Перевірити:
- publish accepted
- inflight registration
- ack completion
- retry after timeout
- duplicate handling
- cleanup after disconnect

### 6.5. Session manager

Перевірити:
- new session creation
- clean session
- persistent session resume
- restore subscriptions
- restore inflight metadata
- cleanup rules

### 6.6. ACL engine

Перевірити:
- allow publish
- deny publish
- allow subscribe
- deny subscribe
- default deny behavior
- scoped ACL rules

### 6.7. Federation policy

Перевірити:
- should_forward
- should_drop
- import/export filtering
- scope mapping
- anti-loop markers
- dedup checks

---

## 7. Property-based tests

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

## 8. Integration tests

Integration tests перевіряють взаємодію кількох модулів.

### 8.1. Protocol + Session + Routing

Сценарії:
- client connect
- subscribe
- publish
- message routed to matching subscribers
- disconnect

### 8.2. Protocol + Retained

Сценарії:
- publish retained
- new subscriber connects
- retained delivered
- retained updated
- retained deleted

### 8.3. Protocol + QoS1

Сценарії:
- publish with qos1
- inflight create
- ack received
- inflight cleanup
- timeout then retry

### 8.4. Session + Persistence

Сценарії:
- persist session snapshot
- restart broker
- restore session
- restore subscriptions
- recover retained metadata

### 8.5. Routing + Federation policy

Сценарії:
- local only route
- forward-eligible message
- remote-origin message rejected by anti-loop
- namespace export/import rules

---

## 9. Simulation tests

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

## 10. Fault and chaos tests

Ці тести потрібні, щоб система була готова до реального світу.

### 10.1. Network fault tests

Перевірити:
- short disconnect
- long disconnect
- reconnect storm
- partial packet loss
- reordering
- delayed ack

### 10.2. Storage fault tests

Перевірити:
- failed write
- partial snapshot
- corrupted persisted state
- storage full
- slow storage backend

### 10.3. Memory pressure tests

Перевірити:
- queue almost full
- retained limit reached
- payload too large
- PSRAM exhaustion
- SRAM budget crossing
- allocator fragmentation symptoms

### 10.4. Federation fault tests

Перевірити:
- broker link down
- broker link returns stale data
- duplicated subscription announcements
- repeated remote reconnects
- partial topology visibility

---

## 11. Soak and longevity tests

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

## 12. Performance tests

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

## 13. Memory-focused tests

Оскільки платформа resource-constrained, пам’ять — частина контракту.

### 13.1. SRAM tests

Перевіряти:
- usage after startup
- usage under active subscriptions
- usage under QoS1 load
- high-water mark under reconnects

### 13.2. PSRAM tests

Перевіряти:
- retained storage growth
- queue slab usage
- payload buffering pressure
- snapshot buffer pressure

### 13.3. Budget assertions

У тестах мають бути порогові перевірки:
- max clients budget
- max retained budget
- max queue depth budget
- max payload budget

---

## 14. Regression test suites

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

## 15. Test data strategy

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

## 16. Clock and timing strategy

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

## 17. CI strategy

### На кожному PR

Запускати:
- unit tests
- static checks
- config validation
- core integration tests

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

## 18. Hardware test matrix

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

## 19. Observability requirements for tests

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

## 20. Testability requirements for code

Код вважається тестопридатним, якщо:

1. Core запускається без ESP-IDF runtime.
2. Clock можна підмінити.
3. Storage можна підмінити.
4. Transport можна підмінити.
5. Federation link можна підмінити.
6. Memory budgets можна спостерігати.
7. Logs/metrics доступні з тестів.

---

## 21. Definition of Done для тестової стратегії

Тестова стратегія вважається реалізованою, якщо:

1. Є повний unit coverage для critical core logic.
2. Є integration tests для session/qos/retained/routing.
3. Є simulation tests для broker link і federation.
4. Є fault tests для reconnect, storage і memory pressure.
5. Є soak tests мінімум на 24 години перед release.
6. Є окремі бюджети й порогові перевірки для N8R2 і N16R8.
7. Кожен баг має regression test.

---

## 22. Підсумок

Хороша тестова стратегія для цього проєкту — це не просто набір тестів, а багаторівнева система перевірки, де:

- core логіка масово тестується на host-машині
- platform-specific ризики перевіряються окремо
- federation вводиться через simulation до реального заліза
- помилкові сценарії тестуються на рівні з happy path
- пам’ять, черги, retry і reconnect розглядаються як частина контракту системи

Такий підхід дозволяє безпечно рости від `Single broker` до `Federated multi-broker` без втрати стабільності.