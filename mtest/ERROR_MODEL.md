# ERROR_MODEL.md

## 1. Мета

Цей документ фіксує єдину модель помилок для MQTT-брокера на ESP32-S3.

Його цілі:
- уніфікувати error handling між core, ports, adapters і runtime
- відокремити recoverable та unrecoverable failures
- зробити помилки придатними для logs, metrics, tests і policy decisions

Документ узгоджується з:
- `CODING_GUIDELINES.md`
- `TECH_STACK.md`
- `MODULE_CONTRACTS.md`
- `TEST_STRATEGY.md`

---

## 2. Основні принципи

- ніяких silent failures
- `bool` без контексту не використовується для значущих API
- errors повертаються як structured `Status` або `Result<T, E>`
- policy failures повинні бути явними
- adapters не повинні губити platform errors при трансляції в domain-level model

---

## 3. Канонічні типи результату

### 3.1. `Status`

Використовувати для:
- operations without return payload
- validation
- command execution

Містить щонайменше:
- `code`
- `severity`
- `module`
- `reason`
- `retryable`

### 3.2. `Result<T, E>` або `Expected<T, E>`

Використовувати для:
- parse results
- lookups
- load/restore operations
- route/plan generation

Містить:
- successful payload `T`
- structured error `E`

### 3.3. `ResultCode`

Повинен бути bounded enum, а не stringly-typed error set.

---

## 4. Error classes

### 4.1. `ValidationError`

Приклади:
- invalid config field
- invalid topic/filter
- malformed MQTT packet
- unsupported property combination

Зазвичай:
- recoverable for system
- reject current request/config/input

### 4.2. `PolicyError`

Приклади:
- ACL deny
- route policy deny
- federation policy deny

Зазвичай:
- fail-closed
- not a crash condition
- should be visible in metrics/logging

### 4.3. `ResourceLimitError`

Приклади:
- queue full
- retained limit reached
- inflight limit reached
- memory budget exceeded

Зазвичай:
- recoverable
- explicit reject/degrade
- should increment limit-reject metrics

### 4.4. `StorageError`

Приклади:
- failed write
- corrupted snapshot
- partial restore
- unsupported persistence version

Зазвичай:
- may be recoverable or degraded
- never silently ignored

### 4.5. `TransportError`

Приклади:
- send failure
- receive failure
- connection closed
- timeout

Зазвичай:
- adapter-level recoverable
- mapped to reconnect/cleanup behavior, not hidden retry loops

### 4.6. `StateError`

Приклади:
- invalid session resume
- unexpected ack
- duplicate/inconsistent inflight transition
- impossible internal state

Зазвичай:
- higher severity than validation/policy errors
- may indicate bug or corrupted state

### 4.7. `DependencyError`

Приклади:
- clock unavailable
- metrics backend failed
- logger backend unavailable
- required port implementation missing

Зазвичай:
- startup fail-fast або controlled degradation, залежно від component criticality

---

## 5. Severity levels

### 5.1. `Debug`

Для:
- expected rejects in negative tests
- noisy internal non-critical signals

### 5.2. `Info`

Для:
- expected protocol/policy outcomes
- normal connection closure

### 5.3. `Warning`

Для:
- recoverable resource pressure
- config fallback to documented default
- transient storage/transport issues

### 5.4. `Error`

Для:
- failed operation
- invalid persistent state
- repeated transport/storage failures
- impossible request acceptance

### 5.5. `Critical`

Для:
- startup-blocking config/schema errors
- unrecoverable state corruption
- broken invariants that invalidate runtime correctness

---

## 6. Retryability rules

### Retryable by default

- transient transport failures
- queue pressure after backoff
- temporary storage busy conditions

### Not retryable by default

- config validation errors
- schema version mismatch
- ACL/policy deny
- malformed packet
- unsupported feature/protocol combination

### Important rule

Retryability must be explicit in `Status`/error object.
Callers must not guess based on message text.

---

## 7. Fail-fast vs fail-closed vs degrade

### 7.1. Fail-fast

Застосовується для:
- incompatible config schema
- missing required config
- unsupported platform/runtime prerequisites
- invariant-breaking startup state

### 7.2. Fail-closed

Застосовується для:
- ACL evaluation failure
- route/federation policy evaluation failure
- uncertain authorization state

### 7.3. Controlled degradation

Застосовується для:
- metrics backend unavailable
- tracing unavailable
- temporary persistence unavailability
- transport reconnect paths

---

## 8. Error code taxonomy

Приклад рекомендованих груп кодів:

- `OK`
- `ERR_INVALID_ARGUMENT`
- `ERR_INVALID_STATE`
- `ERR_POLICY_DENIED`
- `ERR_LIMIT_REACHED`
- `ERR_QUEUE_FULL`
- `ERR_STORAGE_IO`
- `ERR_STORAGE_CORRUPT`
- `ERR_TRANSPORT_IO`
- `ERR_TIMEOUT`
- `ERR_UNSUPPORTED_FEATURE`
- `ERR_SCHEMA_VERSION`
- `ERR_DEPENDENCY_UNAVAILABLE`
- `ERR_INTERNAL_BUG`

Правила:
- коди мають бути stable
- коди мають бути придатні для metrics dimensioning
- human-readable text не повинен бути єдиним carrier of meaning

---

## 9. Module-specific expectations

### 9.1. `protocol_mqtt`

Повинен повертати:
- parse/validation/protocol feature errors

Не повинен:
- маскувати malformed packet як empty success

### 9.2. `routing`

Повинен розрізняти:
- no matching route
- policy deny
- invalid scope/namespace
- inconsistent subscription index

### 9.3. `acl`

Повинен розрізняти:
- explicit deny
- evaluation failure

Failure path:
- always fail-closed

### 9.4. `session`

Повинен розрізняти:
- new session created
- resumed successfully
- resume rejected
- persisted state invalid

### 9.5. `retained`

Повинен розрізняти:
- retained updated
- retained deleted
- retained rejected by limits
- retained storage failure

### 9.6. `qos`

Повинен розрізняти:
- ack accepted
- duplicate ack
- timeout-triggered retry
- inflight state invalid

### 9.7. `federation`

Повинен розрізняти:
- forward allowed
- forward denied by policy
- drop by anti-loop
- link unavailable
- dedup conflict

---

## 10. Logging contract

Кожна значуща помилка повинна бути loggable з полями:
- `module`
- `code`
- `severity`
- `entity_id` або equivalent
- `result`
- `reason`
- `retryable`

Rules:
- policy deny не логувати як crash-like failure
- repeated transient failures should be rate-aware
- payload bodies не логувати за замовчуванням

---

## 11. Metrics contract

Для error paths повинні бути можливі counters/gauges:
- rejects by code
- ACL deny count
- route policy deny count
- queue full count
- storage failure count
- transport failure count
- schema/config validation failure count
- retry count
- degraded mode count

Metrics labels/dimensions must prefer stable error codes, not free-form text.

---

## 12. Test contract

Тести повинні покривати:
- exact error code for critical failures
- retryable vs non-retryable classification
- fail-fast startup errors
- fail-closed policy behavior
- degradation behavior where configured
- mapping of platform errors into structured domain-level errors

Bugfix rule:
- кожен виправлений error path повинен отримати regression test

---

## 13. Adapter translation rules

Adapters повинні:
- переводити platform/native errors у bounded domain-level codes
- не протягувати errno/socket/NVS internals у core APIs
- зберігати enough context for logs and metrics

Не допускається:
- adapter returns opaque `false`
- adapter throws away retryability information
- adapter converts every failure into one generic error

---

## 14. Startup error policy

Startup must fail immediately for:
- invalid or incompatible config
- unsupported schema version
- required component missing
- invalid memory budget configuration

Startup may continue in degraded mode for:
- optional diagnostics backend unavailable
- optional trace/event log backend unavailable

---

## 15. Definition of Done

Error model вважається прийнятим, якщо:
- кожен значущий API використовує structured result model
- recoverable vs unrecoverable paths відрізняються явно
- policy failures fail-closed
- startup validation failures fail-fast
- logs/metrics/tests можуть опиратися на stable error codes
