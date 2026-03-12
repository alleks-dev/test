# READ_MODEL_STRATEGY.md

## 1. Purpose

This document defines the read-model strategy for the ESP32-S3 MQTT broker.

Its goals are to:
- separate mutable core state from API/export views
- make external integrations depend on stable snapshots rather than live internals
- create clean seams for `admin_api`, diagnostics, federation views, and future bridges

This document aligns with:
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/architecture/EVENT_CONTRACTS.md`
- `docs/testing/TEST_STRATEGY.md`

---

## 2. Core principle

External consumers must not read:
- live core state
- internal indexes
- runtime-owned mutable structures

Instead, they must read:
- stable read snapshots
- DTO/view models
- bounded projection results

---

## 3. Read-model layers

We use three roles:
- `runtime facade`
- `snapshot builder`
- `read-model coordinator`

### 3.1. Runtime facade

The facade:
- provides a narrow app-facing API
- does not expose concrete runtime internals
- returns snapshots or bounded query results

### 3.2. Snapshot builder

The snapshot builder:
- builds one specific DTO/view
- does not own core state
- does not execute policy logic

### 3.3. Read-model coordinator

The coordinator:
- manages invalidate/rebuild/publish flow for read models
- knows when a snapshot must be refreshed
- must not become a God object with domain logic

---

## 4. Where it is needed in the MQTT broker

Read models are required at least for:
- `admin_api` status/config/session snapshots
- diagnostics snapshots
- retained/session/federation inspection views
- bridge/export snapshots if external consumers are added

---

## 5. Snapshot contract

Every snapshot must be:
- immutable after publication
- bounded by config/memory budgets
- suitable for host-side tests
- independent of platform types

A snapshot DTO must not:
- contain raw pointers to live runtime state
- require lock ownership from the caller
- return references to mutable internals

---

## 6. Publication model

Recommended model:
- core/runtime changes authoritative state
- the coordinator receives a notification about the relevant change
- the builder refreshes the snapshot
- the facade returns the latest published version

If a snapshot is expensive:
- invalidate + lazy rebuild is allowed
- but the caller must still receive a stable result, not live-state access

---

## 7. Integration rules

`admin_api` and other external consumers:
- must not read session/routing/retained internals directly
- must depend on the facade or snapshot contracts

Core modules:
- must not depend on web/admin DTO types

Adapters:
- may serialize snapshots
- must not build domain read models on their own

---

## 8. Testability rules

Required tests:
- deterministic snapshot content
- rebuild after a state change
- no stale/live reference leakage
- bounded output size under declared limits
- correct empty-state behavior

---

## 9. Anti-patterns

Forbidden:
- direct reads from live core state in API handlers
- inline DTO mapping inside a large runtime orchestrator
- mixing write policy and read projection in one class
- exposing raw internal-state containers through the public facade
