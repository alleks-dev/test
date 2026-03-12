# ASYNC_OPERATION_MODEL.md

## 1. Мета

Цей документ описує модель асинхронних операцій для MQTT-брокера.

Його цілі:
- зробити async admin/runtime operations testable і deterministic
- уникнути хаотичних callback-only APIs
- дати основу для request/result tracking, polling і diagnostics

Документ узгоджується з:
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/architecture/ERROR_MODEL.md`
- `docs/architecture/READ_MODEL_STRATEGY.md`
- `docs/architecture/RUNTIME_EXECUTION_MODEL.md`

---

## 2. Коли потрібна async operation model

Вона потрібна для операцій, які:
- не завершуються миттєво
- залежать від transport/storage/runtime scheduling
- можуть потребувати retry, timeout або later completion

Приклади:
- config apply
- persistence flush/recovery
- bridge/federation reconnect actions
- administrative runtime operations

---

## 3. Основний контракт

Асинхронна операція повинна мати:
- `request_id`
- `operation_type`
- `submitted_at`
- current `status`
- optional `result payload`
- optional `error/status code`

Рекомендовані стани:
- `queued`
- `in_progress`
- `completed`
- `failed`
- `timed_out`
- `cancelled`

---

## 4. Operation result store

Система повинна мати окремий `operation result store` або equivalent seam, який:
- генерує `request_id`
- приймає completions/results
- дозволяє bounded query/poll by `request_id`
- не змішує unrelated operation families без reason

Цей store:
- не є business-policy engine
- не повинен знати platform details
- повинен бути bounded by config/memory policy

---

## 5. Integration with runtime

Рекомендований flow:
1. caller submits operation
2. runtime validates and creates `request_id`
3. executor/process performs work
4. completion/error is published back
5. result store exposes final status to caller or facade

Async completion не повинно оновлювати caller-visible state "магічно" без request/result traceability.

---

## 6. Polling and notification policy

Допустимі моделі:
- bounded polling by `request_id`
- event-driven notification
- hybrid model

Недопустимі:
- ad-hoc global flags
- raw pointer callbacks as the only contract
- shared mutable output buffers owned by caller

---

## 7. Error and timeout rules

Кожна async operation повинна мати:
- explicit timeout policy
- explicit error/status code on failure
- deterministic terminal state

Якщо completion не приходить:
- operation переходить у `timed_out`
- caller не повинен чекати безмежно

---

## 8. Testability rules

Потрібні тести на:
- request id generation uniqueness
- success/failure completion paths
- timeout transition with fake clock
- bounded queue/store behavior
- cleanup of completed/expired records

---

## 9. Anti-patterns

Заборонено:
- async API без request/result identity
- completion only through logs
- unbounded result queues
- змішування transient operation state з long-lived domain state
