# MEMORY_BUDGETS.md

## 1. Мета

Цей документ фіксує стартові memory budgets для MQTT-брокера на ESP32-S3.

Його цілі:
- задати практичні ліміти до початку реалізації
- відокремити SRAM-critical і PSRAM-friendly дані
- дати основу для config limits, tests і performance gates

Це не остаточні “максимуми заліза”, а нормативні робочі бюджети для безпечного старту.

---

## 2. Основні принципи

- hot-path data повинні жити в SRAM
- cold/bulk data повинні жити в PSRAM
- packet path не повинен покладатися на unbounded heap allocation
- усі бюджети повинні мати `soft limit` і `hard limit`
- N8R2 і N16R8 мають різні профілі, навіть якщо кодова база одна

---

## 3. Типи бюджетів

### 3.1. Soft limit

Рівень, який система може стабільно тримати в normal operation.

### 3.2. Hard limit

Рівень, після якого нові allocations/clients/messages повинні:
- відхилятися явно
- логуватися
- відображатися в metrics

---

## 4. SRAM / PSRAM policy

### 4.1. SRAM

У SRAM повинні жити:
- routing metadata
- subscription index hot structures
- session control state
- QoS inflight control data
- task stacks
- lock-free/bounded control queues
- frequently touched event metadata

### 4.2. PSRAM

У PSRAM повинні жити:
- payload buffers
- retained payload storage
- queue slabs
- cold session state
- diagnostics/history buffers
- snapshot/checkpoint buffers
- temporary serialization buffers that are not latency-critical

---

## 5. N8R2 working budget

Профіль:
- single broker first
- conservative retained usage
- limited bridge-ready operation

### 5.1. SRAM budget targets

- broker runtime core state: `<= 96 KB` soft, `<= 128 KB` hard
- task stacks total: `<= 48 KB` soft, `<= 64 KB` hard
- routing/subscription hot structures: `<= 24 KB` soft, `<= 32 KB` hard
- QoS/session hot control state: `<= 16 KB` soft, `<= 24 KB` hard

### 5.2. PSRAM budget targets

- payload/queue buffers: `<= 256 KB` soft, `<= 384 KB` hard
- retained payload storage: `<= 128 KB` soft, `<= 192 KB` hard
- diagnostics/history/snapshots: `<= 96 KB` soft, `<= 128 KB` hard

### 5.3. Functional limits

- max concurrently connected clients: `8` soft, `12` hard
- max retained messages: `128` soft, `192` hard
- max subscriptions total: `256` soft, `384` hard
- max inflight QoS1 entries: `32` soft, `48` hard
- max queue depth per client: `16` soft, `24` hard
- max payload size accepted by broker: `16 KB` soft, `24 KB` hard
- max topic length: `256 B` soft, `512 B` hard

---

## 6. N16R8 working budget

Профіль:
- stronger single broker
- practical bridge/federation preparation
- larger retained/session capacity

### 6.1. SRAM budget targets

- broker runtime core state: `<= 128 KB` soft, `<= 160 KB` hard
- task stacks total: `<= 64 KB` soft, `<= 80 KB` hard
- routing/subscription hot structures: `<= 40 KB` soft, `<= 56 KB` hard
- QoS/session hot control state: `<= 24 KB` soft, `<= 32 KB` hard

### 6.2. PSRAM budget targets

- payload/queue buffers: `<= 512 KB` soft, `<= 768 KB` hard
- retained payload storage: `<= 256 KB` soft, `<= 384 KB` hard
- diagnostics/history/snapshots: `<= 160 KB` soft, `<= 256 KB` hard

### 6.3. Functional limits

- max concurrently connected clients: `16` soft, `24` hard
- max retained messages: `256` soft, `384` hard
- max subscriptions total: `512` soft, `768` hard
- max inflight QoS1 entries: `64` soft, `96` hard
- max queue depth per client: `32` soft, `48` hard
- max payload size accepted by broker: `32 KB` soft, `48 KB` hard
- max topic length: `512 B` soft, `768 B` hard

---

## 7. Per-object budgeting assumptions

Ці оцінки потрібні для ранніх config calculations і tests.

### 7.1. Subscription entry

Цільова оцінка:
- hot metadata per subscription: `48-80 B`

### 7.2. Session control block

Цільова оцінка:
- hot session control: `96-160 B`

### 7.3. QoS inflight entry

Цільова оцінка:
- per-entry hot state: `48-96 B`

### 7.4. Retained metadata entry

Цільова оцінка:
- retained metadata without payload: `48-72 B`

### 7.5. Event record

Цільова оцінка:
- event metadata record: `32-64 B`

---

## 8. Budget enforcement policy

При досягненні `soft limit` система повинна:
- піднімати warning metric
- писати structured warning log
- зберігати high-water mark

При досягненні `hard limit` система повинна:
- відхиляти новий workload явно
- повертати explicit error/status
- не намагатися “тихо” виживати через неконтрольовані allocation retries

---

## 9. Config fields that must exist

У versioned runtime config повинні бути окремі поля для:
- `max_clients`
- `max_subscriptions`
- `max_retained_messages`
- `max_inflight_qos1`
- `max_queue_depth_per_client`
- `max_payload_size`
- `max_topic_length`
- `sram_soft_limit`
- `sram_hard_limit`
- `psram_soft_limit`
- `psram_hard_limit`

---

## 10. Required metrics

Система повинна збирати:
- SRAM high-water mark
- PSRAM high-water mark
- retained storage bytes
- queue slab bytes
- inflight count
- connected clients count
- subscriptions count
- allocation failures by category
- limit rejects by category

---

## 11. Test gates

### 11.1. Host/integration

Потрібні:
- budget calculation tests
- queue limit tests
- retained limit tests
- client/subscription limit tests
- QoS inflight limit tests
- payload/topic length reject tests

### 11.2. Hardware

Потрібні:
- SRAM high-water verification
- PSRAM pressure tests
- retained heavy-load tests
- reconnect under near-limit conditions
- long-run tests without unbounded growth

---

## 12. Change policy

Будь-яка зміна бюджетів повинна:
- бути явно відображена в config defaults/profiles
- супроводжуватися test updates
- супроводжуватися metrics threshold updates
- бути перевірена окремо для `N8R2` і `N16R8`

---

## 13. Initial implementation note

На першому milestone краще:
- стартувати нижче soft limits
- залишити запас для observability, config migration, MQTT 5-ready metadata
- піднімати ліміти лише після вимірів, а не припущень
