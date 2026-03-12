# CONFIG_SCHEMA.md

## 1. Purpose

This document defines the canonical runtime configuration schema for the MQTT broker.

Its goals are to:
- define one source of truth for runtime config structure
- make config loading/versioning/migration deterministic
- provide a stable basis for validation, testing, and profile-specific limits

This document aligns with:
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MEMORY_BUDGETS.md`
- `docs/architecture/ERROR_MODEL.md`
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/testing/TEST_STRATEGY.md`

---

## 2. Core principles

- runtime config is separate from build profiles
- config must be versioned
- config must be normalized before runtime wiring
- config validation is a startup gate
- config fields must be bounded and testable

---

## 3. Canonical top-level schema

The canonical top-level runtime schema is:

```text
BrokerConfig {
  schema_version
  protocol
  memory
  queues
  retained
  session
  acl
  routing
  federation
  persistence
  observability
  test_hooks
}
```

---

## 4. Field rules

### 4.1. General field rules

Every field must be classified as:
- required
- optional with explicit default
- optional but profile-constrained

No field may be:
- implicitly required by undocumented code
- interpreted differently depending on hidden platform state

### 4.2. Validation rules

Validation must cover:
- value range
- cross-field dependencies
- profile-specific budget compatibility
- feature-flag consistency

---

## 5. Schema sections

### 5.1. `schema_version`

Required.

Rules:
- integer version field
- interpreted only by the config loader/migration pipeline
- runtime must receive already-normalized current-schema config

### 5.2. `protocol`

Contains:
- max packet size
- max topic length
- max client ID length
- allowed QoS range if constrained by profile
- keepalive-related bounds if configured
- MQTT feature flags where needed

### 5.3. `memory`

Contains:
- selected memory profile
- SRAM/PSRAM limits exposed to runtime
- max payload buffer budget
- snapshot buffer budget
- diagnostics/history buffer budget if enabled

### 5.4. `queues`

Contains:
- max inbound queue depth
- max outbound queue depth
- max inflight QoS queue depth
- overflow policy where applicable

### 5.5. `retained`

Contains:
- retained enabled flag
- max retained entry count
- max retained payload size
- retained persistence enabled flag

### 5.6. `session`

Contains:
- persistent-session enable flag
- max session count
- max inflight per session
- session restore policy knobs if enabled

### 5.7. `acl`

Contains:
- ACL enable flag
- default policy
- rule-set source/config reference
- scoped namespace enforcement knobs where required

### 5.8. `routing`

Contains:
- local-only namespace rules
- export/import eligibility knobs
- dedup/anti-loop policy knobs where required

### 5.9. `federation`

Contains:
- federation enabled flag
- max remote links
- export/import policy selection
- anti-loop metadata requirements
- reconnect/retry policy bounds for link-level behavior

### 5.10. `persistence`

Contains:
- retained persistence enable flag
- session checkpoint enable flag
- snapshot version fields if needed
- recovery mode and corruption handling policy knobs

### 5.11. `observability`

Contains:
- logging level
- metrics enable flag
- tracing/diagnostics toggles
- memory-telemetry toggles if configurable

### 5.12. `test_hooks`

Contains:
- deterministic testing knobs that are allowed in non-production profiles only
- fake clock/test-only injection flags where explicitly supported

Rules:
- this section must not become a backdoor for production behavior
- test hooks must remain bounded and explicit

---

## 6. Example normalized schema shape

```text
BrokerConfig {
  schema_version: 3,
  protocol: { ... },
  memory: { ... },
  queues: { ... },
  retained: { ... },
  session: { ... },
  acl: { ... },
  routing: { ... },
  federation: { ... },
  persistence: { ... },
  observability: { ... },
  test_hooks: { ... }
}
```

---

## 7. Required vs optional fields

### Required fields

Required fields include at least:
- `schema_version`
- selected memory/profile identity or equivalent runtime memory constraints
- protocol limit section
- queue limit section
- observability baseline section

### Optional fields with explicit defaults

Allowed only if defaults are documented.

Examples:
- retained persistence enabled = false
- federation enabled = false
- tracing enabled = false in conservative profiles

### Optional but profile-constrained fields

These may be optional in the file, but the resulting normalized config must still satisfy the selected profile.

---

## 8. Versioning and migration rules

- every schema version must be explicitly supported or rejected
- migrations must be sequential: `vN -> vN+1`
- migration logic must normalize old fields into the current canonical schema
- unsupported future schemas must be rejected
- unsupported legacy schemas below the support window must be rejected
- unknown critical fields must fail fast

---

## 9. Cross-field validation rules

Examples of required cross-field checks:
- queue budgets must fit the selected memory profile
- retained max payload must not exceed protocol max packet size where applicable
- federation cannot be enabled if required remote-link budgets are zero
- session restore cannot be enabled without persistence support where required
- tracing-heavy observability cannot exceed the chosen diagnostics budget

---

## 10. Profile binding to memory budgets

The config loader/validator must verify that normalized config respects `docs/architecture/MEMORY_BUDGETS.md`.

At minimum:
- `N8R2` must reject oversized retained/session/queue settings
- `N16R8` may allow larger values, but still within declared hard limits

---

## 11. Error behavior

On config failure:
- startup must fail fast
- the error must indicate the schema section/field
- the error must distinguish parse failure, migration failure, and validation failure

---

## 12. Test expectations

The config schema is not complete unless tests exist for:
- current-version parse success
- previous-version migration success
- unsupported-version rejection
- missing required field rejection
- invalid cross-field combination rejection
- profile-specific memory-limit rejection

---

## 13. Definition of Done for the config schema

The config schema is considered established if:
- there is one canonical top-level runtime schema
- required and optional fields are explicit
- migration rules are documented
- cross-field validation rules are explicit
- profile-specific constraints are bound to memory budgets
- the config loader can normalize to one current schema before runtime startup
