# Documentation Index

This directory contains the normative documentation set for the ESP32-S3 MQTT broker.

## Structure

Cross-document terminology reference:
- [GLOSSARY.md](/home/alex/dev/mtest/docs/GLOSSARY.md)


### `architecture/`

Architecture and technical contracts:
- [ARCHITECTURE.md](/home/alex/dev/mtest/docs/architecture/ARCHITECTURE.md)
- [TECH_STACK.md](/home/alex/dev/mtest/docs/architecture/TECH_STACK.md)
- [CODING_GUIDELINES.md](/home/alex/dev/mtest/docs/architecture/CODING_GUIDELINES.md)
- [MODULE_CONTRACTS.md](/home/alex/dev/mtest/docs/architecture/MODULE_CONTRACTS.md)
- [DEPENDENCY_RULES.md](/home/alex/dev/mtest/docs/architecture/DEPENDENCY_RULES.md)
- [CONFIG_SCHEMA.md](/home/alex/dev/mtest/docs/architecture/CONFIG_SCHEMA.md)
- [ERROR_MODEL.md](/home/alex/dev/mtest/docs/architecture/ERROR_MODEL.md)
- [EVENT_CONTRACTS.md](/home/alex/dev/mtest/docs/architecture/EVENT_CONTRACTS.md)
- [READ_MODEL_STRATEGY.md](/home/alex/dev/mtest/docs/architecture/READ_MODEL_STRATEGY.md)
- [RUNTIME_EXECUTION_MODEL.md](/home/alex/dev/mtest/docs/architecture/RUNTIME_EXECUTION_MODEL.md)
- [ASYNC_OPERATION_MODEL.md](/home/alex/dev/mtest/docs/architecture/ASYNC_OPERATION_MODEL.md)
- [API_HEADERS_PLAN.md](/home/alex/dev/mtest/docs/architecture/API_HEADERS_PLAN.md)
- [MEMORY_BUDGETS.md](/home/alex/dev/mtest/docs/architecture/MEMORY_BUDGETS.md)

### `governance/`

Enforcement rules and team process:
- [ARCH_COMPLIANCE_MATRIX.md](/home/alex/dev/mtest/docs/governance/ARCH_COMPLIANCE_MATRIX.md)
- [ADR_EXCEPTIONS.md](/home/alex/dev/mtest/docs/governance/ADR_EXCEPTIONS.md)
- [ARCH_CHECKS.md](/home/alex/dev/mtest/docs/governance/ARCH_CHECKS.md)
- [CI_RULES.md](/home/alex/dev/mtest/docs/governance/CI_RULES.md)
- [TEAM_WORKFLOW.md](/home/alex/dev/mtest/docs/governance/TEAM_WORKFLOW.md)

### `testing/`

Testing strategy:
- [TEST_STRATEGY.md](/home/alex/dev/mtest/docs/testing/TEST_STRATEGY.md)

### `planning/`

Roadmap and implementation planning:
- [ROADMAP.md](/home/alex/dev/mtest/docs/planning/ROADMAP.md)
- [SKELETON_PLAN.md](/home/alex/dev/mtest/docs/planning/SKELETON_PLAN.md)
- [MAP1.md](/home/alex/dev/mtest/docs/planning/MAP1.md)

## Recommended reading order

1. [ARCHITECTURE.md](/home/alex/dev/mtest/docs/architecture/ARCHITECTURE.md)
2. [TECH_STACK.md](/home/alex/dev/mtest/docs/architecture/TECH_STACK.md)
3. [GLOSSARY.md](/home/alex/dev/mtest/docs/GLOSSARY.md)
4. [MODULE_CONTRACTS.md](/home/alex/dev/mtest/docs/architecture/MODULE_CONTRACTS.md)
5. [DEPENDENCY_RULES.md](/home/alex/dev/mtest/docs/architecture/DEPENDENCY_RULES.md)
6. [TEST_STRATEGY.md](/home/alex/dev/mtest/docs/testing/TEST_STRATEGY.md)
7. [ARCH_COMPLIANCE_MATRIX.md](/home/alex/dev/mtest/docs/governance/ARCH_COMPLIANCE_MATRIX.md)
8. [CI_RULES.md](/home/alex/dev/mtest/docs/governance/CI_RULES.md)
9. [ROADMAP.md](/home/alex/dev/mtest/docs/planning/ROADMAP.md)

## Entry points by task

- If you are designing or changing architecture:
  [ARCHITECTURE.md](/home/alex/dev/mtest/docs/architecture/ARCHITECTURE.md),
  [MODULE_CONTRACTS.md](/home/alex/dev/mtest/docs/architecture/MODULE_CONTRACTS.md),
  [DEPENDENCY_RULES.md](/home/alex/dev/mtest/docs/architecture/DEPENDENCY_RULES.md)

- If you are changing runtime, config, or error behavior:
  [CONFIG_SCHEMA.md](/home/alex/dev/mtest/docs/architecture/CONFIG_SCHEMA.md),
  [ERROR_MODEL.md](/home/alex/dev/mtest/docs/architecture/ERROR_MODEL.md),
  [RUNTIME_EXECUTION_MODEL.md](/home/alex/dev/mtest/docs/architecture/RUNTIME_EXECUTION_MODEL.md),
  [ASYNC_OPERATION_MODEL.md](/home/alex/dev/mtest/docs/architecture/ASYNC_OPERATION_MODEL.md)

- If you are changing testable behavior:
  [TEST_STRATEGY.md](/home/alex/dev/mtest/docs/testing/TEST_STRATEGY.md),
  [EVENT_CONTRACTS.md](/home/alex/dev/mtest/docs/architecture/EVENT_CONTRACTS.md),
  [READ_MODEL_STRATEGY.md](/home/alex/dev/mtest/docs/architecture/READ_MODEL_STRATEGY.md)

- If you are changing governance or CI:
  [ARCH_COMPLIANCE_MATRIX.md](/home/alex/dev/mtest/docs/governance/ARCH_COMPLIANCE_MATRIX.md),
  [ARCH_CHECKS.md](/home/alex/dev/mtest/docs/governance/ARCH_CHECKS.md),
  [CI_RULES.md](/home/alex/dev/mtest/docs/governance/CI_RULES.md),
  [TEAM_WORKFLOW.md](/home/alex/dev/mtest/docs/governance/TEAM_WORKFLOW.md)
