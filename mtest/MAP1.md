Щоб підняти архітектуру з `8.5` до `9.5`, потрібні не нові ідеї, а перехід від хорошої документації до enforceable design.

1. Згенерувати мінімальний skeleton-код під `components/` і `include/ports/`, який реально дотримується [MODULE_CONTRACTS.md](/home/alex/dev/mtest/MODULE_CONTRACTS.md:1) і [DEPENDENCY_RULES.md](/home/alex/dev/mtest/DEPENDENCY_RULES.md:1).

2. Зафіксувати public API headers для всіх портів і ключових core-модулів.
Потрібні хоча б чернеткові інтерфейси для `ISubscriptionIndex`, `IAclPolicy`, `IRouterPolicy`, `IFederationLink`, `IClock`, `ILogger`, `IMetrics`.

3. Додати enforcement у CI.
Мінімум:
- перевірка forbidden includes/dependencies
- host-side build core без ESP-IDF
- базові unit tests
- перевірка config migration tests

4. Створити reference test harnesses.
Потрібні:
- fake clock
- fake transport endpoint
- fake session/retained stores
- fake federation link
- deterministic event capture sink

5. Формалізувати event transport contract.
Зараз event model є, але варто окремо описати `event sink / event bus / dispatcher` rules, щоб `broker_core` не став god-orchestrator із розмитими side effects.

6. Зафіксувати dependency policy на рівні CMake/component graph.
Тобто не лише в документах, а й у реальних `REQUIRES`/`PRIV_REQUIRES` правилах.

7. Визначити 2-3 architectural ADR для найризикованіших рішень.
Наприклад:
- MQTT 5 rollout policy
- persistence boundary
- event model execution model

Найбільший приріст дадуть саме пункти `1`, `3`, `4`. Після них архітектура стане не просто правильно описаною, а practically enforceable.