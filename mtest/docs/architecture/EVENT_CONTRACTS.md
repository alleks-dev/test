# EVENT_CONTRACTS.md

## 1. Purpose

This document defines the canonical event contracts for the MQTT broker.

Its goals are to:
- make the event-driven model explicit and testable
- define stable event payload expectations
- prevent accidental event drift as the system grows toward federation

This document aligns with:
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MODULE_CONTRACTS.md`
- `docs/testing/TEST_STRATEGY.md`
- `docs/architecture/RUNTIME_EXECUTION_MODEL.md`

---

## 2. Canonical event envelope

Every event should have a canonical envelope with at least:
- `event_type`
- `timestamp` or equivalent ordering metadata
- `origin`
- `scope`
- entity identifiers relevant to the event
- optional `correlation_id` if the flow requires it

Events must not depend on:
- platform handles
- socket descriptors
- task IDs
- adapter-specific runtime objects

---

## 3. Base event set

The base event set is:
- `ClientConnected`
- `ClientDisconnected`
- `PublishReceived`
- `SubscriptionAdded`
- `SubscriptionRemoved`
- `RetainedUpdated`
- `RouteResolved`
- `DeliveryRequested`
- `ForwardRequested`
- `RemotePublishReceived`

---

## 4. Event contracts

### 4.1. `ClientConnected`

Emitted when:
- a client connection is accepted and the broker considers the client connected

Required payload:
- client identity
- session-clean/persistent information if relevant
- `origin`
- `scope`

Must not be emitted when:
- connect validation failed
- ACL/policy denied the connection if such policy exists

### 4.2. `ClientDisconnected`

Emitted when:
- the broker completes client disconnect processing

Required payload:
- client identity
- disconnect reason if available
- `origin`
- `scope`

Must not be emitted when:
- there was no accepted connected client in the first place

### 4.3. `PublishReceived`

Emitted when:
- a publish enters the broker domain flow and passes protocol-level acceptance

Required payload:
- message identity / dedup identity
- topic
- QoS/retain metadata where relevant
- `origin`
- `scope`

Must not be emitted when:
- the publish packet is malformed
- protocol validation rejects the publish before domain acceptance

### 4.4. `SubscriptionAdded`

Emitted when:
- a subscription is accepted and inserted into the subscription model/index

Required payload:
- subscription owner identity
- filter
- QoS
- `scope`

Must not be emitted when:
- ACL/policy denies the subscription
- the subscription add operation failed

### 4.5. `SubscriptionRemoved`

Emitted when:
- a subscription is successfully removed

Required payload:
- subscription owner identity
- filter or subscription identifier
- `scope`

Must not be emitted when:
- no matching subscription existed
- remove failed before becoming effective

### 4.6. `RetainedUpdated`

Emitted when:
- retained state is created, updated, or deleted through accepted retained semantics

Required payload:
- topic key
- mutation kind: create/update/delete if represented
- `scope`
- message identity where relevant

Must not be emitted when:
- retained mutation was rejected
- storage write failed before state became effective

### 4.7. `RouteResolved`

Emitted when:
- routing completes a route decision for an accepted message

Required payload:
- message identity
- route summary
- target counts or equivalent bounded metadata
- `origin`
- `scope`

Must not be emitted when:
- routing failed before a valid route plan existed

### 4.8. `DeliveryRequested`

Emitted when:
- local delivery is requested for one or more resolved targets

Required payload:
- message identity
- target identities or bounded target summary
- `scope`

Must not be emitted when:
- there are no local targets
- the route was denied/rejected

### 4.9. `ForwardRequested`

Emitted when:
- federation policy allows forwarding to a remote broker/link

Required payload:
- message identity
- forwarding target/link identity or bounded summary
- anti-loop/dedup metadata where relevant
- `origin`
- `scope`

Must not be emitted when:
- federation policy denies forwarding
- the route is local-only
- anti-loop logic drops the message

### 4.10. `RemotePublishReceived`

Emitted when:
- a remote-origin publish is ingested into the broker domain flow

Required payload:
- remote message identity or dedup identity
- remote source identity/link metadata where relevant
- `origin`
- `scope`

Must not be emitted when:
- remote ingest is rejected before domain acceptance

---

## 5. Ordering rules

### 5.1. Local publish path

Expected order:
1. `PublishReceived`
2. `RouteResolved`
3. `DeliveryRequested` and/or `ForwardRequested`

### 5.2. Subscribe path

Expected order:
1. subscription acceptance
2. `SubscriptionAdded`
3. retained/session cleanup side effects if relevant

### 5.3. Remote publish path

Expected order:
1. `RemotePublishReceived`
2. `RouteResolved`
3. local delivery and/or forwarding requests

### 5.4. Disconnect path

Expected order:
1. internal disconnect handling
2. `ClientDisconnected`
3. subscription/session cleanup side effects where relevant

---

## 6. No-event rules

Tests must verify that no success-like events are emitted for:
- rejected publish
- denied subscribe
- invalid config startup paths
- failed retained mutation before the mutation becomes effective
- failed route resolution before a route plan exists

---

## 7. Event-test expectations

Tests must verify:
- event emission occurs exactly where required
- event payload/meta are correct
- deterministic ordering for single-threaded/replayable flows
- reject/error paths do not emit extra events

---

## 8. Definition of Done for event contracts

Event contracts are considered established if:
- the base event set is explicit
- each event has emission conditions and no-event rules
- payload/meta requirements are defined
- ordering expectations are defined for key flows
- tests can assert emission, payload, and ordering deterministically
