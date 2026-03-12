# ADR_EXCEPTIONS.md

## 1. Мета

Цей документ задає єдиний процес для тимчасових винятків із архітектурних правил.

Він потрібен для того, щоб:
- не маскувати architectural debt як "тимчасове рішення"
- робити винятки видимими й обмеженими в часі
- пов'язувати кожен виняток з конкретним `rule_id`

Документ узгоджується з:
- `ARCH_COMPLIANCE_MATRIX.md`
- `CI_RULES.md`
- `TEAM_WORKFLOW.md`

---

## 2. Коли виняток допустимий

Виняток допустимий лише якщо одночасно виконуються всі умови:
- без нього неможливо розблокувати реальний крок розробки
- тимчасове рішення локалізоване
- impact зрозумілий і документований
- є конкретний план видалення винятку

Виняток не допустимий для:
- невизначеного "потім виправимо"
- зручності без технічного обгрунтування
- обходу `blocker` правила без owner і expiry

---

## 3. Обов'язкові поля винятку

Кожен виняток повинен містити:
- `exception_id`
- `rule_id`
- `status`
- `owner`
- `created_on`
- `expires_on`
- `scope`
- `justification`
- `rollback_plan`
- `verification_plan`

---

## 4. Нормативний шаблон

```text
exception_id: EXC-YYYY-NN
rule_id: ARCH-000
status: proposed | approved | expired | removed
owner: team-or-person
created_on: YYYY-MM-DD
expires_on: YYYY-MM-DD
scope: module/file/PR scope
justification: short technical reason
rollback_plan: exact removal plan
verification_plan: checks/tests that confirm safe temporary use
```

---

## 5. Approval policy

- `blocker` rules вимагають явного reviewer approval
- `major` rules вимагають хоча б одного owner і issue/task reference
- `minor` rules можуть бути прийняті тільки якщо не впливають на correctness або safety

Exception без `expires_on` недійсний.

---

## 6. Expiry policy

- при досягненні `expires_on` виняток автоматично вважається простроченим
- прострочений виняток блокує merge нових змін у відповідному scope
- продовження винятку потребує нового review

---

## 7. Registry

На поточному етапі активних винятків немає.

При появі винятків вони повинні додаватися нижче в цьому документі.

---

## 8. Active exceptions

`none`
