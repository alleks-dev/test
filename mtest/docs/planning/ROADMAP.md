# ROADMAP.md

## 1. Goal

This document defines the staged development roadmap for the ESP32-S3 MQTT broker so that the system evolves:

- from `single-broker mode`
- to `Primary/Standby`
- and later to `federated multi-broker mode`

The key goal of the roadmap is to:
- move incrementally
- avoid breaking the architecture as the system grows
- preserve testability and modularity
- control SRAM/PSRAM budgets
- introduce complexity in stages, not all at once

---

## 2. Overall strategy

The correct growth path for this project is:

1. **stable core first**
2. **then observability and control**
3. **then bridge / broker-link**
4. **then selective federation**
5. **only after that production federation / HA profiles**

That means we do not start with a cluster.
We first build **one very clean node** that:
- tests well
- has clear domain models
- is ready for remote origin / remote target
- is not architecturally tied to single-only assumptions
- is MQTT 5-ready at the architectural level without requiring full MQTT 5 implementation in the MVP

---

## 3. Architectural goals of the roadmap

At every stage we must verify that the system preserves the following properties:

- core does not depend on ESP-IDF details
- the MQTT packet model does not leak into the domain layer
- routing is not tied to socket implementation
- session / retained / QoS do not depend on a specific topology
- transport / storage / federation are plugged in through interfaces
- every new feature is covered by tests

---

## 4. Prioritization principles

### 4.1. Correctness before scale

Correct semantics first:
- connect
- subscribe
- publish
- retained
- QoS1
- session restore

Scaling comes later.

### 4.2. Observability before federation

Before adding inter-node logic, the system must already have:
- logs
- metrics
- traces
- debug hooks

### 4.3. Single-node stability before multi-node behavior

The single-broker mode must first become reliable:
- no leaks
- no hangs
- no chaotic retries
- controlled memory usage

### 4.4. Federation through policy, not rewrite

Federation must appear as:
- new policies
- new adapters
- new route decisions

not as a rewrite of the core.

---

## 5. Stage 0 - Foundations

### Goal

Establish the technical foundation before writing a large amount of code.

### Stage results

- aligned domain model
- a unified logical/physical directory structure
- coding guidelines
- architecture guidelines
- test strategy
- config philosophy
- config versioning strategy
- namespace strategy

### Deliverables

- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/CODING_GUIDELINES.md`
- `docs/architecture/TECH_STACK.md`
- `docs/testing/TEST_STRATEGY.md`
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/architecture/DEPENDENCY_RULES.md`
- `docs/governance/ARCH_COMPLIANCE_MATRIX.md`
- `docs/governance/ADR_EXCEPTIONS.md`
- `docs/governance/TEAM_WORKFLOW.md`
- `docs/governance/ARCH_CHECKS.md`
- `docs/architecture/READ_MODEL_STRATEGY.md`
- `docs/architecture/RUNTIME_EXECUTION_MODEL.md`
- `docs/architecture/ASYNC_OPERATION_MODEL.md`
- `docs/architecture/MEMORY_BUDGETS.md`
- `docs/architecture/CONFIG_SCHEMA.md`
- `docs/architecture/ERROR_MODEL.md`
- `docs/architecture/EVENT_CONTRACTS.md`
- `docs/architecture/API_HEADERS_PLAN.md`
- `docs/governance/CI_RULES.md`
- `scripts/check_arch_invariants.sh`
- `scripts/run_blocking_local_checks.sh`
- `docs/planning/ROADMAP.md`
- base domain type definitions
- agreed naming conventions
- agreed module boundaries

### Exit criteria

- the team agrees on system layers
- `Message`, `Subscription`, and `DeliveryTarget` are fixed
- `origin`, `scope`, and `flags` are fixed
- high-level memory budgets are fixed
- a minimal project skeleton exists
- an architecture compliance matrix with `rule_id` values exists
- an exception process for temporary deviations exists
- a local architecture check bundle exists
- documented read-model, runtime-execution, and async operation strategies exist

---

## 6. Stage 1 - Clean single-broker core

### Goal

Build the minimal, clean, correct broker core for a single node.

### Scope

- protocol engine
- QoS engine
- session manager
- retained store
- subscription index
- ACL engine
- routing engine
- transport abstraction
- storage interfaces
- runtime wiring

### What must work

- client connect/disconnect
- subscribe/unsubscribe
- publish
- retained
- QoS 0
- QoS 1
- clean session
- basic persistent-session semantics
- basic protocol limits

### MQTT policy for early stages

- core and protocol engine must be `MQTT 5-ready`
- the MVP is not required to support the full MQTT 5 feature set
- new MQTT 5 capabilities are added only incrementally with tests and a budget review

MQTT 5 readiness profile:
- `must-have later`: reason codes, session expiry, message expiry, receive maximum, maximum packet size
- `maybe later`: user properties, response topic / correlation data, topic aliases, subscription identifiers
- `definitely not MVP`: full packet-property coverage, shared subscriptions, optimization-heavy protocol features without measured value

### What we do not build yet

- federation
- multi-node route propagation
- failover
- topology management
- complex bridge policies

### Deliverables

- working single-broker mode
- host-side core tests
- minimal platform adapter
- basic metrics counters
- configuration loader

### Exit criteria

- stable single-broker operation in basic scenarios
- all critical unit tests are green
- core does not depend directly on ESP-IDF
- routing does not depend on sockets
- retained/QoS/session behave deterministically in tests

---

## 7. Stage 2 - Resource Control and Observability

### Goal

Make the system suitable for real development/debugging and resource control.

### Scope

- structured logging
- metrics
- event tracing
- queue telemetry
- heap / memory high-water marks
- config validation
- config schema versioning
- config migration support
- explicit limits for payload/topic/clients/queues

### What must appear

- counters for publish / deny / retry / drop
- retained-count metrics
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

- every critical event has trace/log/metric visibility
- memory pressure is visible at runtime
- configuration limits are explicitly validated
- queue overflow, retry storms, and retained growth can be diagnosed
- supported previous config versions are migrated deterministically
- incompatible config versions fail fast at startup

---

## 8. Stage 3 - Persistence Maturity

### Goal

Stabilize state persistence before introducing more complex topologies.

### Scope

- retained persistence
- session checkpoints
- restart recovery
- storage abstraction hardening
- corrupted-state handling
- snapshot validation

### What must work

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

- retained data is restored correctly after restart
- session restore does not corrupt routing/QoS state
- corrupted storage does not bring down the node
- persistence semantics are formalized by tests

---

## 9. Stage 4 - Broker Link (Point-to-Point Bridge)

### Goal

Add minimal inter-node communication without full federation.

### Scope

- broker-to-broker transport adapter
- remote publish ingest
- export/import topic rules
- origin tagging
- basic dedup metadata
- one-link integration tests

### Architectural meaning

This is the intermediate step between single-broker mode and federation.
The goal is not a cluster, but a **controlled bridge**.

### What must work

- broker A exports a subset of topics
- broker B imports those topics
- remote origin is preserved
- local routing and remote forwarding do not conflict

### Deliverables

- `IFederationLink` implementation
- bridge config model
- export/import rule engine
- basic multi-node simulator

### Exit criteria

- one broker link operates stably
- dedup metadata is preserved
- remote origin flows correctly through the system
- policy-driven forwarding works in tests

---

## 10. Stage 5 - Selective Federation

### Goal

Move from a point-to-point bridge to controlled federation across multiple nodes.

### Scope

- remote subscription propagation
- route scoping
- anti-loop logic
- namespace-aware forwarding
- federation policy engine
- multi-link simulation

### What must work

- multiple broker links
- selective forwarding
- subscription announcements between brokers
- no infinite routing loops
- predictable local-vs-remote route behavior

### Deliverables

- federation policy module
- remote subscription registry
- anti-loop metadata rules
- simulation tests for 2-3 nodes
- failure/reconnect federation tests

### Exit criteria

- multi-node routing is reproducible in simulation
- anti-loop logic is proven by tests
- namespace policy behaves stably
- single-node mode is not broken

---

## 11. Stage 6 - Primary / Standby Profile

### Goal

Add a higher-availability profile without a full shared-state cluster.

### Scope

- active/standby node roles
- health/heartbeat
- retained/session snapshot sync
- failover policy
- recovery behavior after role switch

### Important limitation

Do not try to synchronize immediately:
- the entire inflight state in real time
- full live replication of every publish

Primary/Standby must be practical, not academic.

### Deliverables

- role manager
- heartbeat channel
- sync snapshot format
- standby restore logic
- failover tests

### Exit criteria

- primary/standby works on the `N16R8` profile
- failover passes integration tests
- state sync is limited and controlled
- the single-broker core was not rewritten for standby

---

## 12. Stage 7 - Production Federation

### Goal

Make federated deployment suitable for real operation.

### Scope

- topology health monitoring
- link reconnect strategy
- degraded-mode behavior
- policy conflict handling
- federation diagnostics
- production config profiles

### What must be clear

- which topics are local
- which topics are exported
- how to behave when part of the topology disappears
- what metrics/diagnostics exist for the federation layer

### Deliverables

- production federation config
- route/failure playbooks
- topology diagnostics
- soak-tested federation profile

### Exit criteria

- federated mode works across 2-5 nodes in simulation and hardware tests
- degradation of one node does not break the entire system
- route loops are excluded by policy/test design
- metrics/logging are sufficient for operation

---

## 13. Stage 8 - Performance and Hardening

### Goal

Polish the system for real workloads and long-term operation.

### Scope

- performance profiling
- memory fragmentation checks
- latency measurements
- throughput measurements
- queue tuning
- reconnect tuning
- configuration hardening
- watchdog-safe runtime behavior

### Deliverables

- performance baselines
- release profiles
- tuning recommendations for `N8R2` / `N16R8`
- hardening test suite

### Exit criteria

- publish latency is measurable and bounded in target scenarios
- queue tuning is documented
- long-running instability patterns are eliminated or understood
- release profiles are clearly separated from debug profiles

---

## 14. Testing policy across stages

At every stage:
- every new capability must come with new tests
- host-side core tests remain mandatory
- failure paths must be covered together with happy paths
- simulation must appear before serious federation/handover claims
- hardware tests must validate the target profiles before release

---

## 15. Memory policy across stages

The roadmap must never ignore memory budgets.

At every stage we must ask:
- what grows in SRAM
- what grows in PSRAM
- what becomes bounded
- what needs a profile-specific limit

For `N8R2`:
- keep the system conservative
- avoid large retained/session sets
- keep federation minimal or off by profile

For `N16R8`:
- allow broader retained/session sets
- allow standby/federation profiles
- keep diagnostics richer in debug modes

---

## 16. Migration policy across stages

A later stage must not invalidate earlier stages.

This means:
- federation cannot break single-broker correctness
- standby cannot require rewriting the core model
- observability cannot change business semantics
- persistence cannot leak storage details into the domain layer

If a feature requires rewriting earlier architectural boundaries, the roadmap is wrong.

---

## 17. Recommended implementation order inside Stage 1

Normative order for core modules:
1. domain types
2. protocol engine
3. QoS engine
4. session manager
5. retained store
6. subscription index
7. ACL engine
8. routing engine
9. transport abstraction
10. storage interfaces
11. runtime wiring

This order exists to preserve clean boundaries and host-side testability.

---

## 18. Risks to watch

High-risk areas:
- putting too much logic into `broker_core`
- letting ESP-IDF leak into core headers
- underestimating QoS retry complexity
- mixing federation policy into transport code
- unbounded retained/session growth
- introducing MQTT 5 features without full test/budget review

---

## 19. Definition of roadmap success

The roadmap is successful if:
- the system grows without architectural rewrites
- each stage leaves behind a stable, testable base
- single-node correctness remains intact through all later stages
- observability and resource control improve before topology complexity grows
- new deployment profiles are mostly a matter of wiring and policy, not core redesign

---

## 20. Summary

The correct development path for this project is:
- build one clean broker node first
- make it observable and bounded
- add point-to-point linkage
- then add selective federation
- only later add production-grade standby/federation profiles

This keeps the project technically honest and prevents the architecture from collapsing under early distributed-system complexity.
