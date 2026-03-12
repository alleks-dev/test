# MEMORY_BUDGETS.md

## 1. Purpose

This document defines the memory budget policy for the MQTT broker across the target ESP32-S3 profiles.

Its goals are to:
- make SRAM/PSRAM limits explicit
- define operational soft/hard limits
- provide a basis for config validation, tests, and profile-specific tuning

This document aligns with:
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/TECH_STACK.md`
- `docs/architecture/CONFIG_SCHEMA.md`
- `docs/testing/TEST_STRATEGY.md`

---

## 2. Core principles

- memory is part of the architecture contract
- every important queue/store/index must be bounded
- `N8R2` and `N16R8` are different operational profiles
- soft limits warn and shape tuning
- hard limits must not be exceeded by normalized configuration

---

## 3. Limit model

### 3.1. Soft limit

A soft limit means:
- the system should normally stay below it
- crossing it is a warning/tuning signal
- it may still be acceptable in debug/test or burst scenarios

### 3.2. Hard limit

A hard limit means:
- normalized config must not exceed it
- runtime must reject/stop growth before crossing it if possible
- tests should assert that the contract is respected

---

## 4. Placement policy

### 4.1. Internal SRAM

Prefer internal SRAM for:
- hot routing metadata
- task stacks
- frequently accessed indexes
- session/QoS control structures
- small fixed control blocks

### 4.2. PSRAM

Prefer PSRAM for:
- payload buffers
- retained payload storage
- large queue slabs
- cold session state
- diagnostics/history buffers
- published snapshots if not latency-critical

---

## 5. Profile definitions

## 5.1. `N8R2`

This is the conservative profile.

Recommended characteristics:
- smaller queues
- lower retained budgets
- lower session budgets
- minimal federation/standby expectations
- reduced diagnostics in release mode

### `N8R2` example working envelope

Target direction:
- clients: low-to-medium
- retained entries: conservative
- payload size: stricter
- snapshot buffers: bounded tightly
- queue depth: moderate and explicitly capped

## 5.2. `N16R8`

This is the broader-capacity profile.

Recommended characteristics:
- larger retained/session budgets
- deeper queues
- more practical federation/standby scenarios
- richer diagnostics in debug modes

### `N16R8` example working envelope

Target direction:
- clients: medium
- retained entries: medium/high relative to `N8R2`
- payload size: more permissive, still bounded
- snapshot buffers: larger but explicit
- queue depth: deeper than `N8R2`, still capped

---

## 6. Budget categories

The budget model must cover at least:
- max clients
- max subscriptions
- max retained entries
- max retained payload size
- max inflight QoS entries
- max queue depth
- max payload buffer size
- max topic length
- snapshot/read-model budget
- diagnostics/history budget
- async operation tracking budget

---

## 7. Required config fields

The runtime configuration must expose enough fields to bind memory behavior, including:
- memory profile identity
- queue limits
- retained limits
- session limits
- payload/topic limits
- diagnostics/snapshot budgets where relevant

---

## 8. Observability requirements

The system should expose at least:
- memory high-water marks
- queue occupancy
- retained count
- inflight count
- snapshot-buffer pressure where measurable
- operation-result-store occupancy where relevant

---

## 9. Test gates

Memory-budget work is incomplete unless tests exist for:
- queue limit enforcement
- retained limit enforcement
- payload/topic size limit enforcement
- profile-specific rejection of oversized configs
- pressure scenarios near soft/hard thresholds

---

## 10. Definition of Done for memory budgets

Memory budgets are considered established if:
- `N8R2` and `N16R8` profiles are separated
- soft/hard limits are conceptually explicit
- important data structures are bounded
- config schema can represent and validate the limits
- test strategy contains budget/pressure checks
