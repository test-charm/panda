---
name: e2e-asil-report
description: >
  Generate ISO 26262-6 §10 Software Integration Test Report from e2e-tests/
  Cucumber BDD feature files. Trigger when user asks to generate ASIL testing
  documentation, ISO 26262 test report, software integration test report, or
  safety verification report from end-to-end tests. Also trigger when user
  mentions generating ASIL/ISO 26262 compliance docs from their test suite.
  The skill auto-detects the e2e-tests/ directory — if absent, it guides the
  user on what's needed instead of failing silently.
---

# E2E-to-ASIL Report Generator

Generate an ISO 26262-6:2018 §10 Software Integration Test Report from the
`e2e-tests/` Cucumber BDD feature files. This skill reads all `.feature`
files, classifies them into functional domains, maps scenarios to safety
requirements, and produces a structured markdown report at
`doc/software-integration-test-report.md`.

## Prerequisites check

Before doing anything else, verify the project has an `e2e-tests/` directory
with `.feature` files:

```
e2e-tests/src/test/resources/features/*.feature
```

If the directory or feature files are missing, stop and tell the user:
- What's missing (the `e2e-tests/` directory or the `.feature` files within it)
- That this skill needs Cucumber BDD feature files to work
- Suggest running `./setup.sh` and verifying the e2e-tests structure

## Workflow

### Step 1: Scan and classify all feature files

Read every `.feature` file under `e2e-tests/src/test/resources/features/`.
For each file, extract:

1. **Feature name** — the text after `Feature:` on the first content line
2. **Background** — any `Background:` block with shared setup
3. **Scenario count** — count all `Scenario:` lines
4. **Scenario names** — the text after each `Scenario:`
5. **Tags** — `@cuatro`, `@tres`, `@red`, `@body` tags on scenarios

Do NOT read the full scenario bodies (Given/When/Then) — only extract the
metadata above. The `grep` tool with patterns is the most efficient approach.

Use this classification scheme to group features:

| Domain | Key Patterns in Feature Name / Scenarios |
|--------|------------------------------------------|
| Safety & Heartbeat | safety, heartbeat, fault, relay, experience |
| CAN Communication | can_comms, can_health, can_bitrate, can_mode, can_loopback, can_ring, can_fd, fdcan, ignition_can |
| Power Management | power_save, deep_sleep, wfi_idle, bootkick |
| Board Initialization | board_init, clock_source |
| Boot / Reset | system_reset, bootloader |
| Peripheral IO & Fault | fan, ir_power, led, relay, siren, harness, gpio, som, interrupt_rate, tick_paths, uart |
| SPI & Version | spi_state, spi_version |
| Health & Version | health (but not can_health) |
| Body Firmware | body_* (body_main, body_bldc, body_can, etc.) |

### Step 2: Map scenarios to safety requirements

Assign each feature file to one or more safety requirements (SR-XXX).
Use this standard mapping:

```
SR-001 (Safety Mode)    → safety_mode.feature
SR-002 (Heartbeat)      → heartbeat.feature
SR-003 (Heartbeat Loss) → heartbeat_loss.feature, alternative_experience.feature
SR-004 (Permanent Fault)→ permanent_fault.feature
SR-005 (Relay Fault)    → relay_malfunction.feature
SR-006 (CAN Comms)      → can_comms, can_bitrate, can_fd_data_bitrate, can_mode,
                           can_loopback, can_ring_clear, fdcan_interrupt, ignition_can
SR-007 (CAN Health)     → can_health.feature, health.feature
SR-008 (Power Mgmt)     → power_save, deep_sleep, wfi_idle
SR-009 (Boot/Reset)     → bootkick, system_reset_bootloader, clock_source
SR-010 (Peripheral)     → fan_power, fan_cooldown, timer_fan, ir_power, led_pwm,
                           relay, siren, harness_detect, gpio_harness, som_gpio, uart_overwrite
SR-011 (Fault Detect)   → interrupt_rate, tick_paths
SR-012 (SPI)            → spi_state_machine, spi_version_packet
SR-013 (Board Init)     → board_init
SR-014 (Body FW)        → body_main, body_bldc, body_bldc_controller, body_can,
                           body_commands, body_shared_commands, body_dotstar
```

### Step 3: Generate the report

Read `references/report-template.md` for the full document structure.
Then generate `doc/software-integration-test-report.md` following that template,
replacing placeholder data with actual feature file analysis results.

Key rules when generating:
- **Use actual data**: Every scenario count, feature name, and domain grouping
  must come from the files you scanned in Step 1. Do not fabricate numbers.
- **Preserve the template structure**: Keep all sections, tables, and formatting
  from the template. Only replace the data cells.
- **Describe coverage honestly**: For each feature, write a 1-2 line summary of
  what it tests, derived from the scenario names you extracted.
- **Safety Function Matrix**: Update the scenario counts to match your scan.
- **Traceability Matrix**: Include all 14 SR rows with the correct feature files.

### Step 4: Summary

After writing the file, output a brief summary to the user:
- Total feature files processed
- Total scenarios found
- Domains covered
- Output file path

## Important notes

- The e2e tests use a fake-hardware approach: production C code compiled as
  `.dylib` + JNA. The report should note this in the Test Environment section.
- Body firmware (`@body` tag) is a separate build target with its own C entry
  point (`libpanda_body.c`). Treat it as a distinct domain.
- Multi-board tests (`@cuatro`, `@tres`, `@red`) should be noted but don't
  need separate requirement mappings — the board tags indicate variant coverage.
- If new feature files have been added since the template was created, classify
  them into the most appropriate domain and add them to the matrix.
- Do NOT modify the template reference file — it's the canonical template.
  Only modify the generated output.
