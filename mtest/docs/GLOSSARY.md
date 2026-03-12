# Glossary

This glossary defines the canonical terminology for the ESP32-S3 MQTT broker documentation set.

Its goals are to:
- keep architecture and planning documents consistent
- reduce naming drift between modules, tests, and governance rules
- define preferred spellings for recurring technical terms

## 1. Usage rules

- Use the canonical term from this document in normative text.
- Keep code identifiers unchanged when they already follow a separate naming convention.
- Use hyphenated compound modifiers in prose when they function as adjectives.
- Prefer shorter forms in running text when the meaning is already defined here.

## 2. Broker modes and topology

- `single-broker mode`
  Preferred term for the initial deployment and architectural baseline.

- `federated multi-broker mode`
  Preferred term for the later topology where multiple brokers cooperate.

- `federation`
  Acceptable short form when the context already implies `federated multi-broker mode`.

## 3. Architecture layers and seams

- `core`
  The domain and policy logic that must remain independent from ESP-IDF and platform adapters.

- `ports`
  Stable interfaces consumed by the core and implemented by adapters or runtime components.

- `adapters`
  Implementations that bridge ports to ESP-IDF, storage, transport, diagnostics, or test doubles.

- `app/runtime layer`
  The orchestration layer that wires the broker, exposes runtime-facing APIs, and coordinates non-core behavior.

- `runtime facade`
  The narrow application-facing surface used for status, inspection, and admin operations.

## 4. Read-model terminology

- `read model`
  Preferred noun phrase for a published, query-oriented view of broker state.

- `read-model`
  Preferred adjectival form, for example `read-model cache`, `read-model coordinator`, `read-model tests`.

- `snapshot builder`
  Component that produces immutable snapshots for runtime/API consumers.

- `read-model coordinator`
  Component that invalidates, rebuilds, and publishes read models.

## 5. Async operation terminology

- `async operation`
  Preferred short form in running text.

- `asynchronous operation model`
  Acceptable full form for titles or formal definitions.

- `operation result store`
  Canonical component name for request/result tracking of non-immediate operations.

- `request_id`
  Canonical request identity field for async operation tracking.

## 6. Testing and access terminology

- `host-side tests`
  Preferred term for tests that run outside ESP-IDF on the host machine.

- `hardware tests`
  Preferred term for tests that execute on real ESP32-S3 hardware.

- `test-only access headers`
  Canonical term for separate headers such as `*_test_access.hpp`.

- `platform leakage`
  Canonical term for unwanted dependencies from core/contracts into ESP-IDF or platform-specific code.

## 7. Protocol and storage terminology

- `MQTT 5-ready`
  Preferred term for architecture that supports MQTT 5 extension points without full feature completion in the MVP.

- `subscription index`
  Canonical term for the structure used to match subscriptions efficiently.

- `router policy`
  Canonical term for policy that influences route selection or route permission outcomes.

- `retained store`
  Canonical term for retained-message persistence and lookup.

## 8. Style notes

- Prefer `single-broker mode` over `Single broker`, `single broker`, or other capitalized variants.
- Prefer `federated multi-broker mode` over `Federated multi-broker` in normative prose.
- Prefer `read model` as a noun and `read-model` as an adjective.
- Prefer `async operation` in running text; reserve `asynchronous operation` for formal headings when useful.
- Prefer lowercase prose terms unless the term begins a heading or sentence.
