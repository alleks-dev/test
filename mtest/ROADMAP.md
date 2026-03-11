# ROADMAP.md

## 1. Мета

Цей документ описує покрокову дорожню карту розвитку MQTT-брокера для ESP32-S3 так, щоб система еволюціонувала:

- від `Single broker`
- до `Primary/Standby`
- і далі до `Federated multi-broker`

Ключова мета roadmap:
- рухатись інкрементально
- не ламати архітектуру при рості
- зберігати тестованість і модульність
- контролювати SRAM/PSRAM бюджети
- переводити складність у систему поетапно, а не одразу

---

## 2. Загальна стратегія

Правильний розвиток цього проєкту має виглядати так:

1. **спочатку стабільне ядро**
2. **потім спостережуваність і контроль**
3. **потім bridge / broker-link**
4. **потім selective federation**
5. **лише після цього production federation / HA профілі**

Тобто ми не починаємо з кластера.  
Ми спочатку будуємо **один дуже чистий вузол**, який:
- добре тестується
- має чіткі доменні моделі
- готовий до remote-origin / remote-target
- не залежить архітектурно від single-only assumptions
- є MQTT 5-ready на рівні архітектури, але без обов’язкової повної MQTT 5 реалізації в MVP

---

## 3. Архітектурні цілі roadmap

На кожному етапі треба перевіряти, що система зберігає такі властивості:

- core не залежить від ESP-IDF деталей
- MQTT packet model не протікає в domain layer
- routing не прив’язаний до socket implementation
- session / retained / QoS не залежать від конкретної топології
- transport / storage / federation підключаються через інтерфейси
- вся нова функціональність покривається тестами

---

## 4. Принципи пріоритезації

### 4.1. Correctness before scale
Спочатку правильна семантика:
- connect
- subscribe
- publish
- retained
- QoS1
- session restore

Потім масштабування.

### 4.2. Observability before federation
Перш ніж додавати міжвузлову логіку, треба мати:
- logs
- metrics
- traces
- debug hooks

### 4.3. Single-node stability before multi-node behavior
Спочатку single broker має бути надійним:
- без витоків
- без зависань
- без хаотичних retry
- з контрольованою пам’яттю

### 4.4. Federation through policy, not rewrite
Federation повинна з’являтися як:
- нові policy
- нові adapters
- нові route decisions

А не як повна перебудова core.

---

## 5. Етап 0 — Foundations

### Ціль
Зафіксувати технічний фундамент до написання великого обсягу коду.

### Результати етапу
- узгоджена доменна модель
- єдина logical/physical структура директорій
- coding guidelines
- architecture guidelines
- test strategy
- config philosophy
- config versioning strategy
- namespace strategy

### Deliverables
- `ARCHITECTURE.md`
- `CODING_GUIDELINES.md`
- `TECH_STACK.md`
- `TEST_STRATEGY.md`
- `MODULE_CONTRACTS.md`
- `DEPENDENCY_RULES.md`
- `ROADMAP.md`
- базові domain type definitions
- agreed naming conventions
- agreed module boundaries

### Exit criteria
- команда погодила шари системи
- зафіксовані `Message`, `Subscription`, `DeliveryTarget`
- зафіксовані `origin`, `scope`, `flags`
- зафіксовані memory budgets high-level
- є мінімальний skeleton проекту

---

## 6. Етап 1 — Clean Single Broker Core

### Ціль
Побудувати мінімальне, чисте, правильне ядро брокера для одного вузла.

### Обсяг
- protocol engine
- qos engine
- session manager
- retained store
- subscription index
- acl engine
- routing engine
- transport abstraction
- storage interfaces
- runtime wiring

### Що має працювати
- client connect/disconnect
- subscribe/unsubscribe
- publish
- retained
- QoS 0
- QoS 1
- clean session
- basic persistent session semantics
- базові protocol limits

### MQTT policy для ранніх етапів
- core і protocol engine повинні бути `MQTT 5-ready`
- MVP не зобов’язаний підтримувати весь MQTT 5 feature set
- нові MQTT 5 capabilities додаються лише поетапно з тестами і budget review

MQTT 5 readiness profile:
- `must-have later`: reason codes, session expiry, message expiry, receive maximum, maximum packet size
- `maybe later`: user properties, response topic / correlation data, topic aliases, subscription identifiers
- `definitely not MVP`: full packet-property coverage, shared subscriptions, optimization-heavy protocol features without measured value

### Чого ще не робимо
- federation
- multi-node route propagation
- failover
- topology management
- складні bridge policies

### Deliverables
- working single broker
- host-side core tests
- minimal platform adapter
- basic metrics counters
- configuration loader

### Exit criteria
- стабільна робота single broker у basic сценаріях
- всі critical unit tests зелені
- core не залежить напряму від ESP-IDF
- routing не залежить від sockets
- retained/QoS/session працюють у deterministic tests

---

## 7. Етап 2 — Resource Control and Observability

### Ціль
Зробити систему придатною до реального development/debugging і контрольованою за ресурсами.

### Обсяг
- structured logging
- metrics
- event tracing
- queue telemetry
- heap / memory high-water marks
- config validation
- config schema versioning
- config migration support
- explicit limits for payload/topic/clients/queues

### Що має з’явитися
- counters for publish / deny / retry / drop
- retained count metrics
- inflight QoS1 metrics
- memory budget reporting
- tracing for route decisions
- tracing for retained updates
- tracing for queue overflow
- current config schema version
- migration path from previous supported config versions

### Deliverables
- observability module
- metrics port + adapter
- debug build profile
- config sanity checks
- versioned config loader
- config migration tests

### Exit criteria
- будь-яка критична подія має trace/log/metric
- memory pressure видно з runtime
- ліміти конфігурації явно перевіряються
- можна діагностувати queue overflow, retry storm, retained growth
- supported previous config versions мігруються детерміновано
- incompatible config versions fail-fast на startup

---

## 8. Етап 3 — Persistence Maturity

### Ціль
Стабілізувати логіку збереження стану до введення складніших топологій.

### Обсяг
- retained persistence
- session checkpoints
- restart recovery
- storage abstraction hardening
- corrupted state handling
- snapshot validation

### Що має працювати
- broker restart without catastrophic state loss
- retained restore
- selective session restore
- graceful handling of partial/corrupted persistence

### Deliverables
- persistence adapter(s)
- recovery tests
- storage fault tests
- snapshot format/versioning rules

### Exit criteria
- after restart retained data відновлюються правильно
- session restore не руйнує routing/QoS state
- corrupted storage не валить вузол
- persistence semantics формалізовані тестами

---

## 9. Етап 4 — Broker Link (Point-to-Point Bridge)

### Ціль
Додати мінімальний міжвузловий зв’язок без повної федерації.

### Обсяг
- broker-to-broker transport adapter
- remote publish ingest
- export/import topic rules
- origin tagging
- basic dedup metadata
- one-link integration tests

### Архітектурний сенс
Це проміжний крок між single broker і federated.  
Мета — не кластер, а **керований bridge**.

### Що має працювати
- broker A експортує частину topic-ів
- broker B імпортує ці topic-и
- remote-origin зберігається
- local routing і remote forwarding не конфліктують

### Deliverables
- `IFederationLink` implementation
- bridge config model
- export/import rule engine
- basic multi-node simulator

### Exit criteria
- один broker link працює стабільно
- dedup metadata не губиться
- remote-origin коректно проходить через system
- policy-driven forwarding працює в tests

---

## 10. Етап 5 — Selective Federation

### Ціль
Перейти від point-to-point bridge до керованої федерації кількох вузлів.

### Обсяг
- remote subscription propagation
- route scoping
- anti-loop logic
- namespace-aware forwarding
- federation policy engine
- multi-link simulation

### Що має працювати
- кілька broker links
- selective forwarding
- subscription announce between brokers
- no infinite routing loops
- predictable local-vs-remote route behavior

### Deliverables
- federation policy module
- remote subscription registry
- anti-loop metadata rules
- simulation tests for 2–3 nodes
- failure/reconnect federation tests

### Exit criteria
- multi-node routing відтворюваний у simulation
- anti-loop logic доведена тестами
- namespace policy працює стабільно
- single-node mode не зламаний

---

## 11. Етап 6 — Primary / Standby Profile

### Ціль
Додати профіль підвищеної доступності без повного shared-state cluster.

### Обсяг
- active/standby node roles
- health/heartbeat
- retained/session snapshot sync
- failover policy
- recovery behavior after role switch

### Важливе обмеження
Не намагатися одразу синхронізувати:
- увесь inflight state у реальному часі
- повну live-replication кожного publish

Primary/Standby має бути practical, не academic.

### Deliverables
- role manager
- heartbeat channel
- sync snapshot format
- standby restore logic
- failover tests

### Exit criteria
- primary/standby працює на N16R8 профілі
- failover сценарій проходить integration tests
- state sync обмежений і контрольований
- single broker core не переписувався заради standby

---

## 12. Етап 7 — Production Federation

### Ціль
Зробити federated deployment придатним до реальної експлуатації.

### Обсяг
- topology health monitoring
- link reconnect strategy
- degraded mode behavior
- policy conflict handling
- federation diagnostics
- production config profiles

### Що має бути
- зрозуміло, які topic-и локальні
- зрозуміло, які topic-и експортуються
- зрозуміло, як поводитися при частковому відпаданні вузлів
- є metrics/diagnostics для federation layer

### Deliverables
- production federation config
- route/failure playbooks
- topology diagnostics
- soak-tested federation profile

### Exit criteria
- federated mode працює в 2–5 вузлах у simulation та hardware tests
- деградація одного вузла не руйнує всю систему
- route loops виключені policy/test design
- metrics/logging достатні для експлуатації

---

## 13. Етап 8 — Performance and Hardening

### Ціль
Полірування системи під реальні навантаження і довгу роботу.

### Обсяг
- performance profiling
- memory fragmentation checks
- latency measurements
- throughput measurements
- queue tuning
- soak testing
- watchdog hardening
- fault injection

### Що аналізувати
- publish latency
- retained lookup cost
- queue growth under burst
- reconnect recovery time
- heap high-water marks
- PSRAM pressure
- task starvation risks

### Deliverables
- benchmark reports
- budget-tuned configs
- hardening fixes
- long-run soak reports

### Exit criteria
- пройдені soak tests
- бюджет пам’яті не перевищується
- latency/throughput відповідають цілям
- fault scenarios не призводять до некерованої деградації

---

## 14. Платформні профілі roadmap

### 14.1. ESP32-S3 N8R2

Фокус:
- single broker
- tighter budgets
- conservative retained limits
- smaller queues
- limited bridge mode
- federation лише в дуже контрольованій формі

### Roadmap recommendation
- обов’язково проходити Етапи 0–4
- Етап 5 робити лише selective і lightweight
- Етап 6 не є пріоритетом
- production federation лише для малих сегментів

---

### 14.2. ESP32-S3 N16R8

Фокус:
- stronger single broker
- primary/standby practical
- selective federation practical
- larger retained/session budgets
- longer soak and HA scenarios

### Roadmap recommendation
- проходити всі етапи 0–8
- Етап 6 є реальним production-кандидатом
- Етап 7 має сенс для multi-zone systems

---

## 15. Test gates по етапах

### Після Етапу 1
- unit tests green
- core integration tests green
- single broker smoke tests green

### Після Етапу 2
- observability hooks validated
- memory metrics available
- config limit tests green

### Після Етапу 3
- restart recovery tests green
- corrupted persistence tests green

### Після Етапу 4
- two-node bridge simulation green
- origin/dedup integration green

### Після Етапу 5
- multi-node federation simulation green
- anti-loop regression suite green

### Після Етапу 6
- standby/failover tests green
- snapshot sync recovery green

### Після Етапу 7
- degraded topology tests green
- production config validation green

### Після Етапу 8
- soak tests green
- performance baseline accepted
- memory budget assertions green

---

## 16. Ризики roadmap

### Ризик 1 — передчасна складність
Спроба занадто рано додати:
- federation
- HA
- topology discovery

Результат:
- нестабільний core
- складні й неінформативні баги

### Ризик 2 — слабка observability
Якщо немає:
- metrics
- trace
- counters
- memory visibility

federation стане майже неможливо відлагодити.

### Ризик 3 — platform leakage в core
Якщо ESP-IDF деталі протечуть у core, будь-яка еволюція стане дорожчою.

### Ризик 4 — відсутність simulation layer
Без simulation:
- multi-node bugs знаходяться занадто пізно
- hardware-debug стає занадто дорогим

### Ризик 5 — відсутність strict config limits
Без жорстких лімітів на:
- queue depth
- retained count
- payload size
- clients count

система буде падати неявно під навантаженням.

---

## 17. Критерії успіху roadmap

Roadmap вважається успішним, якщо:

1. Single broker стабільний до появи federation.
2. Core не переписується при переході до bridge/federation.
3. Кожен етап має власні тестові gate-и.
4. На N8R2 і N16R8 існують окремі конфігураційні профілі.
5. Federation з’являється як policy/adapters extension, а не як архітектурний злам.
6. Пам’ять, черги та retry завжди залишаються під контролем.
7. Продукт можна дебажити в production-like режимі.

---

## 18. Рекомендований порядок реалізації модулів

```text
1. domain types
2. protocol engine
3. qos engine
4. session manager
5. retained manager
6. subscription index
7. acl engine
8. routing engine
9. transport abstraction
10. storage abstraction
11. runtime wiring
12. metrics/logging
13. persistence
14. broker link
15. federation policies
16. standby profile
17. production federation tooling
```

---

## 19. Мінімальний MVP

### MVP для N8R2
- single broker
- QoS0/1
- retained
- basic sessions
- strict limits
- metrics/logging
- restart recovery
- MQTT 5-ready architecture without full MQTT 5 feature matrix
- no commitment to nonessential MQTT 5 optional features

### MVP для N16R8
- усе з N8R2 MVP
- larger budgets
- bridge-ready core
- stronger persistence
- optional primary/standby preparation
- staged MQTT 5 feature rollout only where justified by use case

---

## 20. Підсумок

Ця roadmap навмисно веде від простого до складного:

- **спочатку ядро**
- **потім контроль і спостережуваність**
- **потім bridge**
- **потім federation**
- **потім HA і production hardening**

Такий порядок дозволяє:
- уникнути архітектурного боргу
- не ламати core при рості
- зберегти чисту модульність
- тримати проект придатним до тестування
- природно перейти від `Single broker` до `Federated multi-broker`
