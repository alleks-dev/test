# ARCH_CHECKS.md

## 1. Мета

Цей документ описує набір автоматичних архітектурних перевірок для репозиторію.

Його цілі:
- зробити `docs/governance/ARCH_COMPLIANCE_MATRIX.md` виконуваним на практиці
- визначити мінімальний check bundle для локального запуску і CI
- дати специфікацію для `scripts/check_arch_invariants.sh`

Документ узгоджується з:
- `docs/governance/ARCH_COMPLIANCE_MATRIX.md`
- `docs/governance/CI_RULES.md`
- `docs/governance/TEAM_WORKFLOW.md`

---

## 2. Базовий набір checks

Мінімальний набір автоматичних архітектурних перевірок:
- forbidden includes in `core`
- forbidden includes in `ports`
- forbidden `core -> adapter` references
- composition-root checks for `main/app_main`
- macro-gated test hook detection in public headers
- presence/layout checks for `*_test_access.hpp` where test-only access is needed

---

## 3. Mapping to rule IDs

- `ARCH-001`: no platform headers in `core`
- `ARCH-002`: no adapter references in `core`
- `ARCH-003`: no platform headers in `ports`
- `ARCH-006`: no routing dependency on transport/storage adapters
- `ARCH-008`: no macro-gated test hooks in production headers

---

## 4. Script contract

`scripts/check_arch_invariants.sh` повинен:
- завершуватись `0`, якщо blocker violations відсутні
- завершуватись non-zero, якщо знайдено blocker violations
- показувати `rule_id`, file path і короткий remediation hint
- працювати локально без мережевих залежностей
- коректно пропускати code-level checks, якщо skeleton ще не створений

---

## 5. PR-level expectations

На PR рівні обов'язкові:
- grep/static checks
- header layout checks
- forbidden dependency checks

На nightly/pre-release можуть додаватися:
- compile graph checks
- richer include dependency analysis
- generated dependency report

---

## 6. Reporting contract

Output перевірок повинен бути придатним для CI parsing і ручного review:

```text
[ARCH-003] blocker: platform header leaked into port
file: components/ports/include/clock_port.hpp
detail: found include <freertos/FreeRTOS.h>
fix: replace with abstract domain or port contract type
```

---

## 7. Future extensions

Коли з'явиться реальний skeleton-код, варто додати:
- CMake graph validation
- standalone public-header compile job
- include dependency dump by component
- optional whitelist/exception integration from `docs/governance/ADR_EXCEPTIONS.md`
