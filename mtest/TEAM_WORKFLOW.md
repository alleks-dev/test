# TEAM_WORKFLOW.md

## 1. Мета

Цей документ фіксує практичний workflow команди навколо архітектурних правил, локальних перевірок і PR discipline.

Його цілі:
- зробити правила з документації щоденною робочою практикою
- дати мінімальний local verification bundle до PR
- прив'язати review до `rule_id`, а не до розмитих побажань

Документ узгоджується з:
- `ARCH_COMPLIANCE_MATRIX.md`
- `CI_RULES.md`
- `SKELETON_PLAN.md`
- `TEST_STRATEGY.md`
- `READ_MODEL_STRATEGY.md`
- `RUNTIME_EXECUTION_MODEL.md`
- `ASYNC_OPERATION_MODEL.md`

---

## 2. Source of truth

Архітектурним source of truth вважаються:
- `ARCHITECTURE.md`
- `MODULE_CONTRACTS.md`
- `DEPENDENCY_RULES.md`
- `ARCH_COMPLIANCE_MATRIX.md`
- `CONFIG_SCHEMA.md`
- `ERROR_MODEL.md`
- `EVENT_CONTRACTS.md`
- `READ_MODEL_STRATEGY.md`
- `RUNTIME_EXECUTION_MODEL.md`
- `ASYNC_OPERATION_MODEL.md`

Якщо код або PR їм суперечить, пріоритет мають ці документи.

---

## 3. Робочий цикл розробника

Перед зміною коду або skeleton structure розробник повинен:
- визначити affected module
- звірити relevant contracts і dependency rules
- зрозуміти, які `rule_id` можуть бути зачеплені

Під час зміни:
- не змішувати архітектурний refactor і behavior change без потреби
- додавати tests разом із новою поведінкою
- не вводити undocumented temporary bypass

Після зміни:
- запустити локальний check bundle
- перевірити, чи потрібне оновлення docs/contracts

---

## 4. Обов'язковий local verification bundle

Перед PR розробник повинен запустити:
- `scripts/run_blocking_local_checks.sh`
- host build relevant targets
- relevant unit tests
- config/schema related tests, якщо зачеплено config/runtime
- event tests, якщо змінено event emission behavior

Не дозволяється відкривати PR з формулюванням "CI нехай покаже".

---

## 5. PR policy

Кожен PR повинен:
- бути вузьким за scope
- посилатися на affected module(s)
- описувати зміну поведінки або зміну structure/contracts
- явно згадувати exception, якщо він потрібен

Якщо PR порушує правило з `ARCH_COMPLIANCE_MATRIX.md`, у ньому повинно бути:
- `rule_id`
- посилання на запис у `ADR_EXCEPTIONS.md`

---

## 6. Review policy

Reviewer повинен перевіряти:
- чи не зламано dependency boundaries
- чи є coverage для нової поведінки
- чи не потрапив platform code в core/public headers
- чи не з'явились macro-gated test hooks у production API

Коментарі рівня "looks fine" без перевірки rule-sensitive місць недостатні.

---

## 7. Definition of Ready

Задача готова до реалізації, якщо:
- зрозумілий affected module set
- визначені потрібні contracts/tests
- відомо, чи зачіпається config/error/event model

---

## 8. Definition of Done

Зміна вважається завершеною, якщо:
- локальні checks пройдені
- CI rules виконані
- affected docs/contracts оновлені
- немає неописаних архітектурних винятків

---

## 9. Workflow anti-patterns

Заборонено:
- "тимчасово" обійти правило без exception record
- додавати behavior без tests
- переносити policy logic у `main/app_main`
- змінювати public API без compile/test coverage
