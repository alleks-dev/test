# CONFIG_SCHEMA.md

## 1. Мета

Цей документ фіксує canonical runtime config schema для MQTT-брокера на ESP32-S3.

Його цілі:
- визначити єдину логічну структуру runtime config
- зробити `config_loader` і migration rules однозначними
- прив’язати config до memory budgets, tests і feature rollout policy

Документ не фіксує конкретний serialization format назавжди.
JSON, YAML, binary blob або NVS-backed representation допустимі, якщо вони відображають цей schema contract.

---

## 2. Загальні правила

- runtime config повинен мати явне поле `schema_version`
- config loader читає config, мігрує його до current schema і повертає normalized config model
- validation виконується після migration і до runtime wiring
- unsupported future/legacy schema versions повинні відхилятися fail-fast
- unknown required fields або invalid values повинні відхилятися fail-fast
- optional fields дозволені лише з documented defaults

---

## 3. Top-level schema

Canonical top-level object:

```text
BrokerConfig
  schema_version
  profile
  node
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
```

---

## 4. Top-level fields

### 4.1. `schema_version`

Type:
- unsigned integer

Required:
- yes

Rules:
- current version must be explicit
- migration path must be deterministic

### 4.2. `profile`

Type:
- enum/string

Allowed values initially:
- `n8r2`
- `n16r8`

Required:
- yes

Rules:
- selects baseline memory/queue limits
- does not override explicit hard validation rules

### 4.3. `node`

Contains:
- `node_id`
- `site_id`
- `zone_id`
- `role`

Required:
- yes

Rules:
- `role` initially supports `single`, later `primary`, `standby`, `federated`
- namespace-related ids must comply with documented namespace contract

---

## 5. Section schema

### 5.1. `protocol`

Required fields:
- `max_payload_size`
- `max_topic_length`
- `receive_maximum`
- `allow_mqtt5_features`

Optional fields:
- `keepalive_min_sec`
- `keepalive_max_sec`
- `topic_alias_max`
- `max_packet_size`

Rules:
- `allow_mqtt5_features=false` is valid for early deployments
- MQTT 5-related fields may exist before full feature rollout
- all size fields are bounded and validated

### 5.2. `memory`

Required fields:
- `sram_soft_limit`
- `sram_hard_limit`
- `psram_soft_limit`
- `psram_hard_limit`

Optional fields:
- `allocation_strategy`
- `event_buffer_budget`
- `diagnostics_budget`

Rules:
- values must align with `docs/architecture/MEMORY_BUDGETS.md`
- hard limit must always be greater than or equal to soft limit

### 5.3. `queues`

Required fields:
- `max_queue_depth_per_client`
- `max_total_queued_messages`

Optional fields:
- `drop_policy`
- `retry_queue_limit`

Rules:
- queue settings must be bounded
- overflow policy must be explicit, never implicit

### 5.4. `retained`

Required fields:
- `max_retained_messages`
- `max_retained_payload_bytes`

Optional fields:
- `scoped_retained_enabled`
- `retained_eviction_policy`

Rules:
- retained delete semantics remain protocol-driven, not config-driven
- scoped retained settings must align with namespace contract

### 5.5. `session`

Required fields:
- `max_clients`
- `persistent_sessions_enabled`
- `max_inflight_qos1`

Optional fields:
- `session_expiry_default_sec`
- `resume_policy`

Rules:
- if persistent sessions are disabled, related persistence settings must still validate coherently

### 5.6. `acl`

Required fields:
- `default_policy`
- `ruleset_version`

Optional fields:
- `namespace_scoped_rules`
- `remote_broker_policy`

Rules:
- `default_policy` must initially support `deny`
- ACL config must not depend on socket identities

### 5.7. `routing`

Required fields:
- `local_delivery_enabled`
- `remote_forwarding_enabled`

Optional fields:
- `local_only_prefixes`
- `exportable_prefixes`
- `route_scope_policy`

Rules:
- route scoping must align with namespace contract
- routing config must remain mechanism-free

### 5.8. `federation`

Required fields:
- `enabled`

Optional fields:
- `mode`
- `export_rules`
- `import_rules`
- `anti_loop_enabled`
- `dedup_window_sec`

Rules:
- if `enabled=false`, section still parses but federation runtime may stay no-op
- federation config must be valid even before production federation rollout

### 5.9. `persistence`

Required fields:
- `enabled`
- `store_type`

Optional fields:
- `snapshot_interval_sec`
- `session_checkpointing`
- `retained_persistence_enabled`

Rules:
- persistence config must support versioned snapshot format
- incompatible persistence settings must fail validation

### 5.10. `observability`

Required fields:
- `logging_level`
- `metrics_enabled`

Optional fields:
- `trace_enabled`
- `event_log_enabled`
- `high_water_reporting_enabled`

Rules:
- observability cannot silently enable unbounded buffers
- trace/event logging must remain budget-aware

### 5.11. `test_hooks`

Required:
- no in production config

Optional fields:
- `fake_clock_enabled`
- `deterministic_event_capture`
- `fault_injection_mode`

Rules:
- ignored or forbidden in production profiles unless explicitly enabled in debug/test mode

---

## 6. Required defaults

Documented defaults must exist for:
- `allow_mqtt5_features=false`
- `persistent_sessions_enabled=true`
- `metrics_enabled=true`
- `trace_enabled=false`
- `event_log_enabled=false`
- `remote_forwarding_enabled=false` for single-broker baseline
- `federation.enabled=false`

Defaults must not exist for:
- `schema_version`
- `profile`
- `node.node_id`
- `acl.default_policy`
- hard memory limits

---

## 7. Versioning and migration rules

### 7.1. Migration model

Allowed model:
- `vN -> vN+1` only
- sequential upgrades through intermediate versions

Not allowed:
- ad-hoc migration directly from any older version to latest without explicit steps

### 7.2. Normalization rules

After migration:
- config must be transformed to current schema shape
- deprecated aliases/field names must not remain in runtime model
- derived values must be explicit in normalized config if needed by runtime

### 7.3. Validation order

Validation order must be:
1. parse raw config
2. validate `schema_version`
3. migrate to current version
4. normalize schema
5. validate cross-field constraints
6. build runtime config object

---

## 8. Cross-field validation rules

The following must be validated explicitly:
- `sram_hard_limit >= sram_soft_limit`
- `psram_hard_limit >= psram_soft_limit`
- `max_payload_size <= max_packet_size` if `max_packet_size` exists
- `max_queue_depth_per_client <= max_total_queued_messages`
- `federation.enabled=false` with non-empty federation rules should either normalize safely or fail explicitly
- `profile=n8r2` must not exceed `N8R2` hard limits from `docs/architecture/MEMORY_BUDGETS.md`
- `profile=n16r8` must not exceed `N16R8` hard limits from `docs/architecture/MEMORY_BUDGETS.md`
- namespace-related routing/ACL/federation fields must remain internally consistent

---

## 9. Example normalized config shape

```text
BrokerConfig {
  schema_version: 3
  profile: "n8r2"
  node: { node_id, site_id, zone_id, role }
  protocol: { max_payload_size, max_topic_length, receive_maximum, allow_mqtt5_features, ... }
  memory: { sram_soft_limit, sram_hard_limit, psram_soft_limit, psram_hard_limit, ... }
  queues: { max_queue_depth_per_client, max_total_queued_messages, ... }
  retained: { max_retained_messages, max_retained_payload_bytes, ... }
  session: { max_clients, persistent_sessions_enabled, max_inflight_qos1, ... }
  acl: { default_policy, ruleset_version, ... }
  routing: { local_delivery_enabled, remote_forwarding_enabled, ... }
  federation: { enabled, ... }
  persistence: { enabled, store_type, ... }
  observability: { logging_level, metrics_enabled, ... }
  test_hooks: { ... }
}
```

---

## 10. Test expectations

`docs/testing/TEST_STRATEGY.md` must cover:
- current schema parse
- migration from previous supported versions
- invalid version rejection
- invalid normalized config rejection
- profile-specific budget validation
- namespace-related config consistency

---

## 11. Implementation note

На старті проекту:
- schema should stay intentionally small
- each new top-level field must justify its runtime cost
- config growth must go through versioning and migration rules, not through undocumented shortcuts
