# RUNTIME_EXECUTION_MODEL.md

## 1. Мета

Цей документ фіксує execution model для runtime MQTT-брокера.

Його цілі:
- не допустити перетворення `broker_core` у God object
- відділити state transitions від side effects
- задати single-writer ownership model для mutable runtime state

Документ узгоджується з:
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/architecture/EVENT_CONTRACTS.md`
- `docs/architecture/DEPENDENCY_RULES.md`

---

## 2. Основний execution принцип

Рекомендована модель:
- `commands/events in`
- `state transition`
- `effect plan out`
- `effect execution outside core reducer path`

Це означає:
- core вирішує, що повинно статися
- runtime/adapters виконують side effects
- effect completion повертається назад як explicit event/result

---

## 3. Single-writer policy

Authoritative mutable runtime state повинен мати одного writer-а в межах одного logical execution path.

Це потрібно для:
- deterministic transitions
- простішого reasoning про ordering
- легшого host-side testing

Заборонено:
- кілька незалежних writers на session/qos/routing state без явної coordination model
- hidden mutation з adapter callbacks

---

## 4. Runtime roles

### 4.1. Core reducer

Reducer:
- приймає validated command/event
- читає current state
- повертає updated state fragment або transition result
- формує effect plan

### 4.2. Effect executor

Executor:
- виконує transport/storage/logging/federation side effects
- не приймає policy decisions замість reducer
- повертає completion/error events у runtime flow

### 4.3. Event bus or event sink

Event publication:
- повинна бути explicit
- може бути synchronous local bus або deterministic sink
- не повинна створювати приховану reentrant mutation path у core

---

## 5. Side-effect boundaries

До side effects належать:
- transport send/close
- persistence write/load
- metrics/logging/tracing emission
- federation forward
- timers/retry scheduling

Core path не повинен:
- робити blocking I/O
- directly own scheduler/timer primitives
- ховати retry loops усередині state transition logic

---

## 6. Ordering rules

Потрібно гарантувати deterministic ordering для:
- connect
- subscribe/unsubscribe
- publish
- qos retry/ack
- disconnect
- session cleanup

Коли effect завершується асинхронно:
- completion повинно повертатися як explicit event/result
- state update після completion не повинно бути implicit callback mutation

---

## 7. Module consequences

`broker_core`:
- координує flow, але не повинен містити всі projection/mapping helpers inline

`protocol_mqtt`:
- готує commands/events, але не виконує orchestration policy

`routing`, `acl`, `session`, `qos`, `retained`:
- повинні мати deterministic contracts
- не повинні приховано запускати runtime side effects

---

## 8. Testability rules

Execution model повинен дозволяти:
- reducer tests без ESP-IDF/runtime threads
- fake effect executor
- fake clock/timer signals
- deterministic verification effect plan ordering
- replay tests for command/event sequences

---

## 9. Anti-patterns

Заборонено:
- callback-driven hidden state mutation
- blocking storage/network I/O inside reducer logic
- inline DTO mapping and orchestration mixed in one runtime class
- ad-hoc retry loops without explicit state/effect model
