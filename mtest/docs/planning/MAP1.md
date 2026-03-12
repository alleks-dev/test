To raise the architecture from `8.5` to `9.5`, the project does not need more ideas. It needs a transition from good documentation to enforceable design.

1. Generate a minimal skeleton codebase under `components/` and `include/ports/` that actually respects [MODULE_CONTRACTS.md](/home/alex/dev/mtest/docs/architecture/MODULE_CONTRACTS.md:1) and [DEPENDENCY_RULES.md](/home/alex/dev/mtest/docs/architecture/DEPENDENCY_RULES.md:1).

2. Freeze public API headers for all ports and key core modules.
At minimum, draft interfaces are needed for `ISubscriptionIndex`, `IAclPolicy`, `IRouterPolicy`, `IFederationLink`, `IClock`, `ILogger`, and `IMetrics`.

3. Add enforcement to CI.
Minimum set:
- forbidden include/dependency checks
- host-side core build without ESP-IDF
- basic unit tests
- config-migration test checks

4. Build reference test harnesses.
Needed:
- fake clock
- fake transport endpoint
- fake session/retained stores
- fake federation link
- deterministic event-capture sink

5. Formalize the event-transport contract.
The event model already exists, but `event sink / event bus / dispatcher` rules should be documented explicitly so that `broker_core` does not turn into a god orchestrator with blurry side effects.

6. Freeze dependency policy at the CMake/component-graph level.
Not only in documents, but also in real `REQUIRES` / `PRIV_REQUIRES` rules.

7. Define 2-3 architectural ADRs for the riskiest decisions.
For example:
- MQTT 5 rollout policy
- persistence boundary
- event-model execution model

The biggest gains come from items `1`, `3`, and `4`. After that, the architecture stops being only correctly described and becomes practically enforceable.
