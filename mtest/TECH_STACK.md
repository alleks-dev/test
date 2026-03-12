# TECH_STACK.md

## 1. Мета

Цей документ фіксує рекомендований технічний стек для MQTT-брокера на ESP32-S3, який має еволюціонувати:

- від `Single broker`
- до `Primary/Standby`
- і далі до `Federated multi-broker`

Ключові вимоги до стеку:

- контрольований runtime footprint
- чиста модульна архітектура
- висока тестованість
- придатність до довгого розвитку
- передбачуване використання SRAM/PSRAM
- хороша інтеграція з ESP32-S3 та ESP-IDF

---

## 2. Рекомендований базовий стек

### Основний вибір

- **ESP-IDF 5.x**
- **C++20** для більшості власних компонентів
- **C** або thin C-style wrappers для окремих low-level adapter-ів
- **CMake**
- **ESP-IDF components-based structure**
- **host-side tests + ESP-IDF integration tests + hardware tests**
- **MQTT 5-ready protocol architecture with staged feature rollout**

---

## 3. Головний принцип стеку

Проєкт будується не як “монолітний firmware-файл”, а як:

> **modular components + clean core + ports/adapters + bounded runtime policies**

Тобто:
- core логіка не залежить напряму від ESP-IDF
- ESP-IDF використовується через adapters
- build має підтримувати окреме тестування core і platform-рівня
- дозволена лише контрольована підмножина C++/STL
- protocol model має допускати MQTT 5 extension points без повного feature commitment у MVP

---

## 4. Вибір мови

## 4.1. Основна мова

**C++20** — рекомендована основна мова проєкту.

### Чому саме C++20

- зручно виражати domain model
- добре підходить для ports/adapters architecture
- дає безпечніші й читабельніші абстракції, ніж C
- спрощує unit testing core-логіки
- добре підходить для routing, state machines, policy modules
- дозволяє писати modern embedded code без важкого runtime

### Чому не “повний сучасний C++ без обмежень”

Тому що firmware для ESP32-S3 потребує:
- строгого контролю пам’яті
- контрольованого binary size
- передбачуваних latency
- мінімуму прихованих алокацій
- мінімуму runtime-магії

Отже використовується **embedded-safe subset of C++20**.

---

## 4.2. Де допустимий C

C допустимий для:
- thin wrappers над ESP-IDF C API
- low-level transport glue
- storage glue
- ISR-adjacent helper code
- platform binding layers

Тобто:
- **архітектура і доменна логіка — C++**
- **low-level edge code — за потреби C або C-shaped C++**

## 4.3. MQTT protocol policy

Рекомендація:
- будувати broker як `MQTT 5-ready`
- не намагатися реалізувати весь MQTT 5 у першому production milestone

Це означає:
- packet parser/serializer повинен допускати extensible property model
- reason-code oriented protocol responses бажано закласти відразу
- optional MQTT 5 features вводяться поетапно, коли є тестове й ресурсне обґрунтування
- MQTT 3.1.1-compatible stable path залишається пріоритетом для ранніх етапів

---

## 5. Політика по стандарту мови

### Рекомендовано

- **C++20** для власних компонентів

### Допустимо

- **C++17** для окремих conservative-компонентів, якщо це виправдано

### Не рекомендується як основний режим

- “пливти” на дефолтному стандарті компілятора без фіксації в build policy
- змішувати різні правила стилю між компонентами без явного документування

---

## 6. Дозволена підмножина C++

## 6.1. Дозволені мовні фічі

- `enum class`
- `constexpr`
- `constinit`
- `static_assert`
- `noexcept`
- move semantics
- `using` aliases
- strongly typed `struct` / `class`
- RAII для малих контрольованих ресурсів
- `final` / `override`
- `[[nodiscard]]`
- `std::byte`

---

## 6.2. Дозволені utility-типи

- `std::array`
- `std::span`
- `std::string_view`
- `std::optional`
- `std::variant`
- `std::tuple` — помірно
- `std::pair` — помірно
- `std::bitset`
- `std::unique_ptr` — не в hot-path і лише з чіткою ownership-політикою

---

## 6.3. Дозволені STL-контейнери з обмеженнями

### Дозволені лише поза hot-path

- `std::vector`
- `std::string`
- `std::map`
- `std::unordered_map`
- `std::deque`

### Де можна їх використовувати

- config parsing
- management/API layer
- diagnostics
- simulation layer
- host-side tests
- tooling
- startup-only initialization code

### Де небажано або заборонено

- packet receive path
- routing hot-path
- QoS inflight critical paths
- bounded delivery queues
- latency-sensitive delivery loops

---

## 7. Заборонені або небажані фічі

## 7.1. Заборонено

- exceptions як нормальний control flow
- RTTI
- `dynamic_cast`
- `typeid`
- `std::shared_ptr` у core
- `iostream`
- `std::regex`
- безконтрольний `new/delete`
- приховані heap allocations у packet path
- великі template-heavy абстракції без реальної потреби

---

## 7.2. Сильно не рекомендується

- `std::function` у hot-path
- deep inheritance hierarchies
- macro-based polymorphism там, де вистачає нормальних інтерфейсів
- template metaprogramming як стиль архітектури
- implicit ownership transfer
- exception-like error behavior через `abort()` або “silent return false”

---

## 8. Memory policy

## 8.1. SRAM

У внутрішній SRAM повинні жити:

- task stacks
- hot routing metadata
- transport/session control state
- frequently accessed indexes
- small fixed control structures
- QoS control/state machine data

---

## 8.2. PSRAM

У PSRAM повинні жити:

- payload buffers
- retained payload storage
- bounded queue slabs
- cold session state
- diagnostics/history buffers
- snapshots/checkpoints
- великі тимчасові буфери, які не є latency-critical

---

## 8.3. Allocation policy

У проєкті має бути policy:

- мінімізувати heap allocation у hot-path
- використовувати bounded pools/slabs/ring buffers
- уникати allocator-fragmentation-driven дизайну
- мати окремі бюджети для N8R2 і N16R8

---

## 9. Build system

## 9.1. Основний build

- **CMake**
- **ESP-IDF build system**
- **idf_component_register(...)**
- components-based organization

### Причини вибору

- природна інтеграція з ESP-IDF
- добрий поділ на модулі
- окремі compile options для компонентів
- зручний dependency graph
- природна підтримка multi-component firmware

---

## 9.2. Build profiles

Рекомендується мати:

- `sdkconfig.defaults`
- `sdkconfig.defaults.n8r2`
- `sdkconfig.defaults.n16r8`
- `sdkconfig.defaults.debug`
- `sdkconfig.defaults.release`

### Призначення профілів

- різні memory budgets
- різні queue limits
- різні logging levels
- різні diagnostics knobs
- різні transport/persistence/federation feature flags

Build/profile policy не замінює runtime config schema versioning:
- `sdkconfig.defaults*` задають platform/build defaults
- runtime `config_loader` повинен працювати з versioned config schema і migration rules

---

## 9.3. Runtime application seams

На рівні physical stack потрібно відразу закласти:
- вузький `runtime facade` для app-facing consumers
- `read model coordinator` і dedicated snapshot builders для published views
- `operation result store` для non-immediate runtime/admin actions

Ці seams:
- не є частиною protocol/routing/session core
- належать до runtime/application layer
- повинні бути host-testable без ESP-IDF runtime

---

## 10. Recommended compile policy

### Для власних C++ компонентів

- `-std=gnu++20`
- `-Wall`
- `-Wextra`
- `-Werror`
- `-Wshadow`
- `-Wconversion`
- `-Wdouble-promotion`
- `-Wformat=2`
- `-Wnon-virtual-dtor`

### Додатково, якщо команда готова

- `-Wold-style-cast`
- `-Wpedantic`

---

## 10.1. Runtime policy

### Рекомендовано

- exceptions **OFF**
- RTTI **OFF**
- logging level per build profile
- asserts у debug/test профілях
- bounded config validation на startup
- version-aware config loading before runtime wiring

---

## 11. Рекомендована структура директорій

Це **фізична реалізація** логічної модульної структури з `ARCHITECTURE.md`.
Логічні `/core`, `/ports`, `/adapters`, `/app` відображаються тут у `components/`,
`main/` і `test/` відповідно до ESP-IDF component model.

```text
project/
  CMakeLists.txt
  partitions.csv
  sdkconfig.defaults
  sdkconfig.defaults.n8r2
  sdkconfig.defaults.n16r8
  sdkconfig.defaults.debug
  sdkconfig.defaults.release

  main/
    CMakeLists.txt
    app_main.cpp

  components/
    broker_core/
      CMakeLists.txt
      include/broker_core/
      src/

    protocol_mqtt/
      CMakeLists.txt
      include/protocol_mqtt/
      src/

    routing/
      CMakeLists.txt
      include/routing/
      src/

    acl/
      CMakeLists.txt
      include/acl/
      src/

    session/
      CMakeLists.txt
      include/session/
      src/

    retained/
      CMakeLists.txt
      include/retained/
      src/

    qos/
      CMakeLists.txt
      include/qos/
      src/

    federation/
      CMakeLists.txt
      include/federation/
      src/

    ports/
      CMakeLists.txt
      include/ports/
      src/
      transport_endpoint_port.hpp
      transport_listener_port.hpp
      session_store_port.hpp
      retained_store_port.hpp
      subscription_index_port.hpp
      acl_policy_port.hpp
      router_policy_port.hpp
      clock_port.hpp
      logger_port.hpp
      metrics_port.hpp
      federation_link_port.hpp

    transport_tcp/
      CMakeLists.txt
      include/transport_tcp/
      src/

    storage_nvs/
      CMakeLists.txt
      include/storage_nvs/
      src/

    storage_psram/
      CMakeLists.txt
      include/storage_psram/
      src/

    diagnostics/
      CMakeLists.txt
      include/diagnostics/
      src/

    platform_runtime/
      CMakeLists.txt
      include/platform_runtime/
      src/

    app_runtime/
      CMakeLists.txt
      include/app_runtime/
      src/

  test/
    host/
    integration/
    simulation/
    hardware/
```

---

## 12. Ролі модулів

## 12.1. `broker_core`

Відповідає за:
- orchestration доменної логіки
- життєвий цикл вузла
- координацію між routing/acl/session/qos/retained

Не повинен містити ESP-IDF details.

---

## 12.2. `protocol_mqtt`

Відповідає за:
- packet parsing
- packet serialization
- MQTT-level protocol semantics
- extensible handling of MQTT 5 properties/reason codes

Не повинен вирішувати high-level routing policy.

---

## 12.3. `routing`

Відповідає за:
- topic matching
- delivery planning
- route decision
- local vs remote forwarding eligibility

---

## 12.4. `acl`

Відповідає за:
- publish/subscribe authorization
- namespace-aware ACL matching
- default-deny policy evaluation

---

## 12.5. `session`

Відповідає за:
- session lifecycle
- restore/resume
- client-associated protocol state

---

## 12.6. `retained`

Відповідає за:
- retained storage semantics
- retained lookup
- retained update/delete behavior

---

## 12.7. `qos`

Відповідає за:
- QoS1 inflight state
- retry tracking
- ack-driven state transitions

---

## 12.8. `federation`

Відповідає за:
- bridge policies
- remote subscription propagation
- dedup / anti-loop metadata
- route scoping

---

## 12.9. `app_runtime`

Відповідає за:
- runtime facade
- read model coordinator
- snapshot builders for app-facing views
- async operation result store

Не повинен:
- тягнути protocol/routing/session business logic у facade layer
- повертати live mutable internals назовні
- змішувати side-effect execution policy з DTO mapping без окремих seams

---

## 12.10. `ports`

Містить:
- чисті інтерфейси
- доменні контракти
- базові abstract types

Не тягне ESP-IDF headers.

---

## 12.11. `transport_*`, `storage_*`, `platform_*`

Це adapters, які:
- перекладають platform API у доменні інтерфейси
- не повинні містити бізнес-логіки broker core

---

## 13. Interface policy

## 13.1. Основні порти

Рекомендується мати такі інтерфейси:

- `IClock`
- `ILogger`
- `IMetrics`
- `ITransportEndpoint`
- `ITransportListener`
- `ISessionStore`
- `IRetainedStore`
- `ISubscriptionIndex`
- `IAclPolicy`
- `IRouterPolicy`
- `IFederationLink`

---

## 13.2. Правила для інтерфейсів

- headers портів не повинні містити ESP-IDF includes
- platform handles не повинні “протікати” в core
- ownership/lifetime expectations повинні бути задокументовані
- interfaces мають бути маленькими й спеціалізованими
- великі “god interfaces” заборонені

---

## 14. Error handling policy

### Використовувати

- `enum class ResultCode`
- `Status`
- `Expected<T, E>`-подібний підхід
- `[[nodiscard]]` для критичних результатів

### Не використовувати

- exceptions як основний механізм
- `bool` без контексту для важливих API
- silent failure
- аварійне завершення замість контрольованої помилки там, де можлива деградація

---

## 15. Logging and diagnostics stack

### Обов’язково мати

- structured logs
- counters
- memory high-water metrics
- queue occupancy metrics
- retry counters
- route decision traces
- federation diagnostics
- build-profile-controlled verbosity

### Де допустимий “ширший” STL

Саме тут:
- diagnostics
- config/model formatting
- test tooling
- simulation reporting

---

## 16. Testing stack

## 16.1. Host-side tests

Для:
- routing
- retained
- session logic
- QoS logic
- ACL
- federation policy
- config validation

### Мова
- C++20
- широкий дозволений STL
- mocks/fakes

---

## 16.2. Integration tests

Для:
- transport adapters
- storage adapters
- runtime wiring
- reconnect behavior
- persistence behavior

---

## 16.3. Simulation tests

Для:
- multi-node behavior
- bridge/federation
- packet loss
- duplicates
- reordering
- topology degradation

---

## 16.4. Hardware tests

Для:
- Wi-Fi instability
- PSRAM pressure
- long-run soak
- watchdog interaction
- platform timing effects

---

## 17. Suggested component compile policy example

```cmake
idf_component_register(
    SRCS
        "src/broker_core.cpp"
        "src/message_router.cpp"
    INCLUDE_DIRS
        "include"
    REQUIRES
        ports
        routing
        acl
        session
        retained
        qos
        diagnostics
)

target_compile_options(${COMPONENT_LIB} PRIVATE
    -std=gnu++20
    -Wall
    -Wextra
    -Werror
    -Wconversion
    -Wshadow
    -Wdouble-promotion
    -Wformat=2
    -Wnon-virtual-dtor
)
```

---

## 18. Platform profiles

## 18.1. N8R2 profile

Фокус:
- smaller queues
- lower retained budgets
- conservative federation
- strict payload limits
- reduced diagnostics verbosity in release

---

## 18.2. N16R8 profile

Фокус:
- larger retained/session budgets
- bigger queues
- practical standby/federation features
- richer diagnostics in debug profiles
- longer soak/performance targets

---

## 19. Definition of Done для tech stack

Технічний стек вважається правильно зафіксованим, якщо:

1. Core можна збирати й тестувати без прямої залежності від ESP-IDF runtime.
2. Усі platform-specific API сидять у adapters.
3. C++ підмножина задокументована й дотримується.
4. Exceptions і RTTI вимкнені policy-wise.
5. STL використовується контрольовано.
6. Є окремі build profiles для N8R2 і N16R8.
7. Project structure відповідає component model.
8. Memory policy явно враховує SRAM vs PSRAM.
9. App-facing runtime seams зафіксовані окремо від core modules.

---

## 20. Підсумок

Рекомендований техстек для цього проєкту:

- **ESP-IDF 5.x**
- **C++20** як основна мова
- **C** для окремих low-level adapter-ів за потреби
- **components-based project structure**
- **строго обмежена embedded-safe підмножина STL**
- **exceptions OFF**
- **RTTI OFF**
- **чіткий поділ на core / ports / adapters**
- **host tests + integration tests + hardware tests**

Цей стек найкраще підтримує:
- чисту архітектуру
- модульність
- тестованість
- контроль ресурсів
- еволюцію від `Single broker` до `Federated multi-broker`
