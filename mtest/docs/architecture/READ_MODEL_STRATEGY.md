# READ_MODEL_STRATEGY.md

## 1. Мета

Цей документ описує стратегію read-models для MQTT-брокера на ESP32-S3.

Його цілі:
- відокремити mutable core state від API/export views
- зробити зовнішні інтеграції залежними від stable snapshots, а не від live internals
- підготувати clean seams для `admin API`, diagnostics, federation views і future bridges

Документ узгоджується з:
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/architecture/EVENT_CONTRACTS.md`
- `docs/testing/TEST_STRATEGY.md`

---

## 2. Основний принцип

Зовнішні споживачі не повинні читати:
- live core state
- internal indexes
- runtime-owned mutable structures

Замість цього вони повинні читати:
- stable read snapshots
- DTO/view models
- bounded projection results

---

## 3. Read-model layers

Використовуємо три ролі:
- `runtime facade`
- `snapshot builder`
- `read model coordinator`

### 3.1. Runtime facade

Facade:
- дає вузький app-facing API
- не розкриває concrete runtime internals
- повертає snapshots або bounded query results

### 3.2. Snapshot builder

Snapshot builder:
- будує один конкретний DTO/view
- не володіє core state
- не виконує policy logic

### 3.3. Read model coordinator

Coordinator:
- керує invalidate/rebuild/publish flow для read models
- знає, коли snapshot потрібно оновити
- не повинен ставати God object з доменною логікою

---

## 4. Де це потрібно в MQTT broker

Read models потрібні щонайменше для:
- `admin_api` status/config/session snapshots
- diagnostics snapshots
- retained/session/federation inspection views
- bridge/export snapshots, якщо з'являться зовнішні consumers

---

## 5. Контракт snapshots

Кожен snapshot повинен бути:
- immutable after publication
- bounded by config/memory budgets
- придатний до host-side tests
- незалежний від platform types

Snapshot DTO не повинен:
- містити raw pointers на live runtime state
- вимагати lock ownership від caller
- повертати references на mutable internals

---

## 6. Publication model

Рекомендована модель:
- core/runtime змінює authoritative state
- coordinator отримує notification про relevant change
- builder оновлює snapshot
- facade повертає останню published version

Якщо snapshot дорогий:
- дозволено invalidate + lazy rebuild
- але caller все одно повинен отримувати stable result, а не доступ до live state

---

## 7. Integration rules

`admin_api` та інші зовнішні consumers:
- не повинні напряму читати session/routing/retained internals
- повинні залежати від facade або snapshot contracts

Core modules:
- не повинні залежати від web/admin DTO types

Adapters:
- можуть серіалізувати snapshots
- не повинні будувати доменні read models самостійно

---

## 8. Testability rules

Потрібні тести на:
- deterministic snapshot content
- rebuild after state change
- no stale/live reference leakage
- bounded output size under declared limits
- correct empty-state behavior

---

## 9. Anti-patterns

Заборонено:
- direct reads from live core state in API handlers
- DTO mapping inline inside large runtime orchestrator
- змішування write policy і read projection в одному класі
- exposing raw containers of internal state through public facade
