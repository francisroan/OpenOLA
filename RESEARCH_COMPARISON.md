# OpenOLA research comparison and repair findings

**Review date:** 30 October 2026
**Scope:** the two Reddit threads supplied by the project owner, their linked public repositories, and the GUI/APK/repair material staged in this repository. This is a source and document review, not a new physical scooter test.

## What the public projects cover

The two discussions concern different generations and software surfaces. Treating them as one confirmed system would overstate the evidence.

| Source | Reported scope | What the source supports | What it does not establish |
|---|---|---|---|
| [Gen 1 open dashboard discussion](https://www.reddit.com/r/olaelectric/comments/1xj99i8/opensource_dash_platform_for_the_ola_s1_pro_gen_1/) | An unofficial dashboard platform for S1 Pro Gen 1 | A community dashboard SDK and related developer/reference material exist. The SDK describes a host-controlled UI boundary, including host-owned warning/passcode UI and a constrained vehicle-action interface. | Compatibility with later generations, arbitrary vehicle control, or proof that every catalogued signal/action has been observed physically. |
| [Diagnostics security discussion](https://www.reddit.com/r/olaelectric/comments/1xhil2z/i_found_a_potential_security_vulnerability_in_the/) | A diagnostics service on an S1 Pro Gen 3 | The author reports root command execution on the tested head unit. The author separates that result from unverified claims about specific CAN actions or physical effects. | Gen 1 compatibility, fleet-wide exposure, or specific physical behavior from commands that were not reproduced. |

## Connected project map

- [ola-s1-rea](https://github.com/itsmobsys/ola-s1-rea) is a head-unit research notebook and Android tool. Its documented E2/Gen 1 unit and software image are distinct from the Gen 3 Reddit report. Its repository has continued to receive releases; old Reddit status text should not be treated as current project status.
- [ola-dash-sdk](https://github.com/abhi245y/ola-dash-sdk) is an experimental Gen 1 dashboard SDK. Its repository documentation describes host-owned safety UI, display-focused plugins, and constrained vehicle requests.
- [ola-can-reference](https://github.com/abhi245y/ola-can-reference) is a Gen 1 CAN/service catalog tied to a stated HVDP software profile. It asks contributors to separate recovered definitions from physically validated behavior.
- [ola-dev-skill](https://github.com/abhi245y/ola-dev-skill) provides contribution/developer guardrails for those projects, including limits on adding vehicle-control behavior.
- The dashboard thread also links [Axiom](https://codeberg.org/pitzel/axiom). Its project page could not be reviewed with the available research connector; this comparison makes no technical claim about it.
- The [Ola Reverse Engineering Community](https://github.com/Ola-Reverse-Engineering-Community) profile emphasizes owner-authorized work, measured findings, and avoiding leaked credentials or personal data. Its public profile alone does not establish a formal review or intake process.

## Where OpenOLA fits

OpenOLA is a separate owner-oriented diagnostics and repair-support project with several user-interface/build targets. The Windows GUI, Kotlin Android app, active Flutter app, and legacy Android app are different projects with different build histories. The active phone app is `mobile/`; `apk/` is a separate Kotlin rebuild, and `android/` is historical. Do not call these interchangeable builds.

The local documentation records source-level diagnostic and repair functions and older owner-unit validation. That history is useful as a test lead, but it does not prove the current staged revision builds, installs, or behaves the same on every model. Keep model year, head-unit/app version, ECU/module version, and test result attached to every repair claim.

## Known bugs, inconsistencies, and repair risks

These are items visible in the checked-in project notes or documentation mismatches. They are not claims that every current build reproduces the issue.

1. **GUI documentation drift:** `GUI_README.md` and the present desktop source do not agree on the feature inventory and some operation behavior. Reconcile the docs against the source before release. The GUI notes also state that the final state/meaning of a lock/unlock routine response is not fully established; do not treat an acknowledgement as proof of physical state.
2. **Uncertain outcomes:** a timeout or lost connection can leave an action's physical outcome unknown. The GUI notes say not to automatically retry uncertain writes/actions. Test that the UI communicates `unknown`, requires a fresh user decision, and never replays after reconnect.
3. **Read/write boundary:** performance-setting writes are documented as read-only pending deliberate enablement. A mapped torque structure is ambiguous, and several road-speed/power meanings remain unverified. Preserve these as unsupported/unknown; do not guess units or map a display label to a vehicle parameter.
4. **Connection instability:** desktop notes record separate gRPC timeouts and ECU access refusals. A timeout is not evidence that a CAN definition is wrong. Test reconnect, stale-data handling, and clear separation of transport errors from ECU refusals.
5. **Flutter validation document is stale:** the validation page records that no APK was built, but a local arm64 release APK is dated 26 October 2026. The artifact's exact source revision, install result, signature, and device validation were not established in this review.
6. **Legacy app ambiguity:** `android/`, `apk/`, and `mobile/` can be mistaken for the same app. The public README and build instructions should consistently name the active Flutter source and label the Kotlin and legacy projects separately.
7. **Physical validation gap:** current source tests and a successful build cannot verify vehicle compatibility, repair outcomes, persistent changes, or recovery behavior. Those need owner-authorized controlled tests on named model/software combinations.

## Repair-oriented test plan

Run these only on owned or explicitly authorized equipment, with the vehicle safely parked and an independent way to restore the documented baseline.

| Priority | Test | Pass evidence to record |
|---|---|---|
| P0 | Clean build of Windows GUI, Kotlin APK, and Flutter APK from their documented source directories | Commit/hash, OS, toolchain versions, dependency lock state, exact command, build result, artifact SHA-256, package ID/version, and signing fingerprint. |
| P0 | Offline/demo behavior | GUI and app open without a scooter or radio/network connection; demo data is clearly labelled and no live action is sent. |
| P0 | Disconnect, timeout, reconnect, and stale data | Every view marks old readings stale, distinguishes missing from zero, and does not silently show stale data as current. A timed-out action is shown as unknown and is not replayed. |
| P0 | Read-only repair workflow | Record baseline scan, selected controller, fault codes, units, timestamps, and report export. Verify no identifiers are exported by default and the report preserves unknown/missing values. |
| P1 | Confirmation and cancellation | Select, review, cancel, and confirm flows; no action is sent on row selection or navigation. Confirm prompts display the exact target and consequence. |
| P1 | Safe one-shot action lifecycle | On an owner test unit, verify preconditions, ECU response, immediate readback, physical observation, output-off/cleanup, timeout behavior, and no automatic repeat. Stop if action response and physical state disagree. |
| P1 | Repair persistence and recovery | For any supported repair/write, record pre/post values, restart/reboot persistence, recovery path, and rollback evidence. Do not infer success from an acknowledgement alone. |
| P1 | Platform coverage | Test supported Android phone, app upgrade/reinstall, permission denial, native save/share, and iOS on Mac/Xcode before claiming those platforms. |
| P2 | Model/profile replication | Repeat only with explicit owner permission; record model/year, head-unit software, controller firmware, app build, conditions, and evidence type. Keep each hardware/software profile separate. |

## Evidence labels for contributions

Label each finding as **static source observation**, **transport/protocol observation**, **controller accepted/rejected**, **physical result observed**, or **independently replicated**. Include the model/software profile and raw-data provenance where safe. A UI message, source definition, or successful compile alone is not physical validation.

## References

- [Gen 1 open dashboard Reddit discussion](https://www.reddit.com/r/olaelectric/comments/1xj99i8/opensource_dash_platform_for_the_ola_s1_pro_gen_1/)
- [Gen 3 diagnostics Reddit discussion](https://www.reddit.com/r/olaelectric/comments/1xhil2z/i_found_a_potential_security_vulnerability_in_the/)
- Public repositories linked above: [ola-dash-sdk](https://github.com/abhi245y/ola-dash-sdk), [ola-can-reference](https://github.com/abhi245y/ola-can-reference), [ola-dev-skill](https://github.com/abhi245y/ola-dev-skill), [ola-s1-rea](https://github.com/itsmobsys/ola-s1-rea).
