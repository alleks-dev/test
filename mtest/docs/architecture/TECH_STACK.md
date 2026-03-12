# TECH_STACK.md

## 1. Purpose

This document defines the recommended technical stack for the ESP32-S3 MQTT broker, which is expected to evolve:

- from `single-broker mode`
- to `Primary/Standby`
- and later to `federated multi-broker mode`

Core stack requirements:

- controlled runtime footprint
- clean modular architecture
- high testability
- suitability for long-term evolution
- predictable SRAM/PSRAM usage
- strong integration with ESP32-S3 and ESP-IDF

---

## 2. Recommended baseline stack

### Primary choice

- **ESP-IDF 5.x**
- **C++20** for most custom components
- **C** or thin C-style wrappers for selected low-level adapters
- **CMake**
- **ESP-IDF components-based structure**
- **host-side tests + ESP-IDF integration tests + hardware tests**
- **MQTT 5-ready protocol architecture with staged feature rollout**

---

## 3. Core stack principle

The project is not built as a monolithic firmware file, but as:

> **modular components + clean core + ports/adapters + bounded runtime policies**

This means:
- core logic does not depend directly on ESP-IDF
- ESP-IDF is used through adapters
- the build must support separate testing of core and platform levels
- only a controlled subset of C++/STL is allowed
- the protocol model must support MQTT 5 extension points without full feature commitment in the MVP

---

## 4. Language choice

## 4.1. Primary language

**C++20** is the recommended primary language for the project.

### Why C++20

- it expresses the domain model well
- it fits ports/adapters architecture well
- it provides safer and clearer abstractions than C
- it simplifies unit testing of core logic
- it fits routing, state machines, and policy modules well
- it allows modern embedded code without a heavy runtime

### Why not unrestricted modern C++

Because ESP32-S3 firmware requires:
- strict memory control
- controlled binary size
- predictable latency
- minimal hidden allocations
- minimal runtime magic

Therefore the project uses an **embedded-safe subset of C++20**.

---

## 4.2. Where C is allowed

C is acceptable for:
- thin wrappers over ESP-IDF C APIs
- low-level transport glue
- storage glue
- ISR-adjacent helper code
- platform binding layers

That means:
- **architecture and domain logic use C++**
- **low-level edge code may use C or C-shaped C++ when appropriate**

## 4.3. MQTT protocol policy

Recommendation:
- build the broker as `MQTT 5-ready`
- do not try to implement all of MQTT 5 in the first production milestone

This means:
- the packet parser/serializer must support an extensible property model
- reason-code-oriented protocol responses should be designed in from the beginning
- optional MQTT 5 features are introduced incrementally when there is test and resource justification
- a stable MQTT 3.1.1-compatible path remains the priority in early stages

---

## 5. Language-standard policy

### Recommended

- **C++20** for custom components

### Acceptable

- **C++17** for conservative components when justified

### Not recommended as the primary mode

- relying on the compiler default standard without explicit build policy
- mixing different style rules across components without explicit documentation

---

## 6. Allowed C++ subset

## 6.1. Allowed language features

- `enum class`
- `constexpr`
- `constinit`
- `static_assert`
- `noexcept`
- move semantics
- `using` aliases
- strongly typed `struct` / `class`
- RAII for small controlled resources
- `final` / `override`
- `[[nodiscard]]`
- `std::byte`

---

## 6.2. Allowed utility types

- `std::array`
- `std::span`
- `std::string_view`
- `std::optional`
- `std::variant`
- `std::tuple` - used sparingly
- `std::pair` - used sparingly
- `std::bitset`
- `std::unique_ptr` - not in hot paths and only with explicit ownership policy

---

## 6.3. Allowed STL containers with restrictions

### Allowed only outside hot paths

- `std::vector`
- `std::string`
- `std::map`
- `std::unordered_map`
- `std::deque`

### Where they may be used

- config parsing
- management/API layer
- diagnostics
- simulation layer
- host-side tests
- tooling
- startup-only initialization code

### Where they are undesirable or forbidden

- packet receive path
- routing hot path
- QoS inflight critical paths
- bounded delivery queues
- latency-sensitive delivery loops

---

## 7. Forbidden or discouraged features

## 7.1. Forbidden

- exceptions as normal control flow
- RTTI
- `dynamic_cast`
- `typeid`
- `std::shared_ptr` in core
- `iostream`
- `std::regex`
- uncontrolled `new/delete`
- hidden heap allocations in packet paths
- large template-heavy abstractions without real value

---

## 7.2. Strongly discouraged

- `std::function` in hot paths
- deep inheritance hierarchies
- macro-based polymorphism where normal interfaces are sufficient
- template metaprogramming as an architectural style
- implicit ownership transfer
- exception-like error behavior through `abort()` or silent `return false`

---

## 8. Memory policy

## 8.1. SRAM

The following should live in internal SRAM:
- task stacks
- hot routing metadata
- transport/session control state
- frequently accessed indexes
- small fixed control structures
- QoS control/state-machine data

---

## 8.2. PSRAM

The following should live in PSRAM:
- payload buffers
- retained payload storage
- bounded queue slabs
- cold session state
- diagnostics/history buffers
- snapshots/checkpoints
- large temporary buffers that are not latency-critical

---

## 8.3. Allocation policy

The project must have a policy to:
- minimize heap allocation in hot paths
- use bounded pools/slabs/ring buffers
- avoid allocator-fragmentation-driven design
- define separate budgets for `N8R2` and `N16R8`

---

## 9. Build system

## 9.1. Primary build

- **CMake**
- **ESP-IDF build system**
- **idf_component_register(...)**
- components-based organization

### Why this choice

- natural ESP-IDF integration
- good modular separation
- separate compile options per component
- convenient dependency graph
- natural support for multi-component firmware

---

## 9.2. Build profiles

Recommended profiles:
- `sdkconfig.defaults`
- `sdkconfig.defaults.n8r2`
- `sdkconfig.defaults.n16r8`
- `sdkconfig.defaults.debug`
- `sdkconfig.defaults.release`

### Profile purpose

- different memory budgets
- different queue limits
- different logging levels
- different diagnostics knobs
- different transport/persistence/federation feature flags

Build/profile policy does not replace runtime config schema versioning:
- `sdkconfig.defaults*` define platform/build defaults
- runtime `config_loader` must work with a versioned config schema and migration rules

---

## 9.3. Runtime application seams

At the physical-stack level, the following must be designed in from the beginning:
- a narrow `runtime facade` for app-facing consumers
- a `read-model coordinator` and dedicated snapshot builders for published views
- an `operation result store` for non-immediate runtime/admin actions

These seams:
- are not part of protocol/routing/session core
- belong to the runtime/application layer
- must be host-testable without ESP-IDF runtime

---

## 10. Recommended compile policy

### For custom C++ components

- `-std=gnu++20`
- `-Wall`
- `-Wextra`
- `-Werror`
- `-Wshadow`
- `-Wconversion`
- `-Wdouble-promotion`
- `-Wformat=2`
- `-Wnon-virtual-dtor`

### Additionally, if the team is ready

- `-Wold-style-cast`
- `-Wpedantic`

---

## 10.1. Runtime policy

### Recommended

- exceptions **OFF**
- RTTI **OFF**
- logging level per build profile
- asserts in debug/test profiles
- bounded config validation at startup
- version-aware config loading before runtime wiring

---

## 11. Recommended directory structure

This is the **physical implementation** of the logical modular structure defined in `docs/architecture/ARCHITECTURE.md`.
The logical `/core`, `/ports`, `/adapters`, and `/app` are mapped here into `components/`, `main/`, and `test/` according to the ESP-IDF component model.

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

## 12. Module roles

## 12.1. `broker_core`

Responsible for:
- orchestration of domain logic
- node lifecycle
- coordination across routing/ACL/session/QoS/retained

It must not contain ESP-IDF details.

---

## 12.2. `protocol_mqtt`

Responsible for:
- packet parsing
- packet serialization
- MQTT-level protocol semantics
- extensible handling of MQTT 5 properties/reason codes

It must not decide high-level routing policy.

---

## 12.3. `routing`

Responsible for:
- topic matching
- delivery planning
- route decisions
- local vs remote forwarding eligibility

---

## 12.4. `acl`

Responsible for:
- publish/subscribe authorization
- namespace-aware ACL matching
- default-deny policy evaluation

---

## 12.5. `session`

Responsible for:
- session lifecycle
- restore/resume
- client-associated protocol state

---

## 12.6. `retained`

Responsible for:
- retained storage semantics
- retained lookup
- retained update/delete behavior

---

## 12.7. `qos`

Responsible for:
- QoS1 inflight state
- retry tracking
- ack-driven state transitions

---

## 12.8. `federation`

Responsible for:
- bridge policies
- remote subscription propagation
- dedup / anti-loop metadata
- route scoping

---

## 12.9. `app_runtime`

Responsible for:
- runtime facade
- read-model coordinator
- snapshot builders for app-facing views
- async operation result store

It must not:
- pull protocol/routing/session business logic into the facade layer
- return live mutable internals to consumers
- mix side-effect execution policy with DTO mapping without separate seams

---

## 12.10. `ports`

Contains:
- pure interfaces
- domain contracts
- base abstract types

It must not include ESP-IDF headers.

---

## 12.11. `transport_*`, `storage_*`, `platform_*`

These are adapters that:
- translate platform APIs into domain interfaces
- must not contain broker-core business logic

---

## 13. Interface policy

## 13.1. Core ports

Recommended interfaces:
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

## 13.2. Interface rules

- port headers must not contain ESP-IDF includes
- platform handles must not leak into core
- ownership/lifetime expectations must be documented
- interfaces must be small and specialized
- large "god interfaces" are forbidden

---

## 14. Error-handling policy

### Use

- `enum class ResultCode`
- `Status`
- an `Expected<T, E>`-like approach
- `[[nodiscard]]` for critical results

### Do not use

- exceptions as the primary mechanism
- `bool` without context for important APIs
- silent failure
- crashing instead of controlled failure where graceful degradation is possible

---

## 15. Logging and diagnostics stack

### Must-have

- structured logs
- counters
- memory high-water metrics
- queue occupancy metrics
- retry counters
- route decision traces
- federation diagnostics
- build-profile-controlled verbosity

### Where broader STL is acceptable

Specifically here:
- diagnostics
- config/model formatting
- test tooling
- simulation reporting

---

## 16. Testing stack

## 16.1. Host-side tests

For:
- routing
- retained
- session logic
- QoS logic
- ACL
- federation policy
- config validation

### Language
- C++20
- broader allowed STL
- mocks/fakes

---

## 16.2. Integration tests

For:
- transport adapters
- storage adapters
- runtime wiring
- reconnect behavior
- persistence behavior

---

## 16.3. Simulation tests

For:
- multi-node behavior
- bridge/federation
- packet loss
- duplicates
- reordering
- topology degradation

---

## 16.4. Hardware tests

For:
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

## 18.1. `N8R2` profile

Focus:
- smaller queues
- lower retained budgets
- conservative federation
- strict payload limits
- reduced diagnostics verbosity in release

---

## 18.2. `N16R8` profile

Focus:
- larger retained/session budgets
- larger queues
- practical standby/federation features
- richer diagnostics in debug profiles
- longer soak/performance targets

---

## 19. Definition of Done for the tech stack

The tech stack is considered correctly established if:

1. Core can be built and tested without a direct dependency on the ESP-IDF runtime.
2. All platform-specific APIs live in adapters.
3. The allowed C++ subset is documented and enforced.
4. Exceptions and RTTI are disabled by policy.
5. STL usage is controlled.
6. Separate build profiles exist for `N8R2` and `N16R8`.
7. Project structure matches the component model.
8. Memory policy explicitly accounts for SRAM vs PSRAM.
9. App-facing runtime seams are defined separately from core modules.

---

## 20. Summary

Recommended tech stack for this project:

- **ESP-IDF 5.x**
- **C++20** as the primary language
- **C** for selected low-level adapters where appropriate
- **components-based project structure**
- **strictly limited embedded-safe STL subset**
- **exceptions OFF**
- **RTTI OFF**
- **clear separation into core / ports / adapters**
- **host tests + integration tests + hardware tests**

This stack best supports:
- clean architecture
- modularity
- testability
- resource control
- evolution from `single-broker mode` to `federated multi-broker mode`
