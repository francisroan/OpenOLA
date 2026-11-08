# OpenOLA knowledge base — publication review copy

This folder gathers the project’s substantive engineering notes in one place for review. The documents are dated snapshots: later code may differ. None of these notes proves that a repair works on every scooter. The most current MCU replacement analysis is dated 8 November 2026.

## Vehicle diagnostics and component repair

- [Capabilities catalog](CAPABILITIES_CATALOG.md) — collected app and diagnostic capability inventory.
- [Component replacement and offline limits](COMPONENT_REPLACEMENT_OFFLINE_2026-11-08.md) — VCU, BMS, MCU and cloud boundaries.
- [Component pairing and calibration](COMPONENT_PAIRING_CALIBRATION.md) and [pairing investigation](OLAS1_PAIRING_INVESTIGATION.md) — observed workflow versus unresolved steps.
- [MCU firmware selection](MCU_FIRMWARE_SELECTION_2026-11-08.md), [APK comparison](MCU_REPLACEMENT_APK_COMPARISON_2026-11-08.md), [variant audit](MCU_VARIANT_REPLACEMENT_AUDIT_2026-11-08.md), and [service-centre trial](MCU_SERVICE_CENTRE_TRIAL_2026-11-08.md) — local file branches, transport differences, and validation gates.
- [Offline system pages](SYSTEM_PAGES_OFFLINE.md) and [health dashboard](GUI_HEALTH_DASHBOARD.md) — interface and data-source findings.
- [S1 Air fault readout](S1_AIR_FAULT_READOUT_2026-11-08.md) — the three owner-shared MCU codes, status and evidence limits without a vehicle identifier.

## Charging research

- [Charging protocol](CHARGING_PROTOCOL.md), [CAN capture notes](CHARGE_CAN_CAPTURE.md), [charger specification notes](OLA_CHARGING_PROTOCOL_SPEC.md), [vendor-spec summary](CHARGER_VENDOR_SPEC.md), and [charger development handoff](CHARGER_DEV_HANDOFF.md).

## Evidence and gaps

The private workspace also holds raw APK extracts, binaries, full captures, personal vehicle identifiers, client identities, and security-sensitive Bluetooth/ADB research. Those items are not copied into this review folder. This is the **full curated publication knowledge base**, not a dump of private evidence. The APK contains no proof of physical MCU compatibility; the component notes mark static analysis, connected readout, and physical validation separately.

Before publication, review each document for third-party rights, outdated statements, exact vehicle identifiers, access material, and links to private workspace files. The proposed README and [changelog](../CHANGELOG.md) describe the app release gates.
