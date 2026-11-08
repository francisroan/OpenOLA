# Diagnostic pages and offline-app feasibility — 12 September 2026

## Inspected evidence

`tools/inspect_system_pages.py` extracts relevant bytecode from `notes/base.apk`
into `system_pages/` without executing the APK or connecting to the vehicle.
`LiveSignalsViewModel` references the bundled `live_parameters` resource.
`SignatureVerifierRepository.verifyFileSignature` calls `SignatureVerifier.checkSignature`
with `OEM_FOTA_pre_public.cer`. `SoftwareDownloadUrlRepository` contains separate
software version and download-URL paths. Existing ADB and report repositories also
depend on backend services. The precise complete login-navigation patch has not
been traced or implemented.

## What is now exposed

The GUI navigation is Overview, ECU tests, Live signals, Diagnostics, Update,
and Components. Existing actuator/session logic is unchanged.

Live signals → App details opens all 194 original live-parameter entries
(112 marked CAN, 82 marked UDS), plus all 310 ODX read definitions
(BMS 213, VCU 67, MCU 30). Full definitions and source hashes are retained in
`SYSTEM_DETAILS_CATALOG.json`. No definition is discarded because it lacks a DID.
308 ODX definitions have exactly a service byte plus a two-byte DID and can be
requested individually. The other two are visible but not sent.

Details include battery digital inputs/outputs, AFE fault and overcurrent inputs,
DC/DC supply states, cell-voltage deviation and VCU/BMS authentication status.
The original resource also supplies conversion descriptions for some bitfields.
All source metadata is displayed. CAN entries show a matching received snapshot
when available. UDS entries lacking an explicit DID remain unresolved; matching
names is not sufficient evidence for inventing a request.

UDS reads use existing bounded request handling, display raw payload and receipt
time, and never automatically enter a session or unlock. They are requested
snapshots, not continuous live values. Live display is paused before UDS reads;
Start live restores broadcast reception. Generic decoding is deliberately not
inferred from incomplete or conflicting ODX metadata.

Diagnostics has separate BMS/VCU/MCU stored-DTC reads, including the existing code
description and status flags, and a shortcut to broadcast fault signals. Fault
filtering includes inhibit, derate, timeout, disconnect, overcurrent and voltage
terms. A zero value is not proof of health; stale/unreceived values remain unknown.
No new fault clearing, ECU reset or configuration write is performed.

Update exposes GetSwVersion, GetAospVersion, GetVehicleIdentifiers and
SwUpdateCheckStatus as explicit reads. Unsupported endpoint errors are surfaced.
Firmware transfer, cache clearing, provisioning and upgrade triggers are not
enabled. Their presence in the proto does not establish firmware compatibility.

## Can the original app be rebuilt without login?

Technically plausible as a modified/re-signed APK, but not established by merely
skipping the login screen. Decompiled bytecode is not a ready-to-build Android
source project. Navigation, session/user assumptions, diagnostic passcode flow,
report uploads, download URLs and other cloud dependencies need an offline path.
The proven local gRPC/UDS connection supports such an offline implementation; it
does not grant access to cloud services or reproduce their six-digit code.
Service mode and ECU security access are separate from cloud authentication.

A modified APK must be signed. Without the original signing identity it cannot
ordinarily replace the original installed app as an update; a separate application
identity is preferable for preserving the original. See Android's official
[app signing documentation](https://developer.android.com/studio/publish/app-signing).
Signature-dependent integrations may need changes. Firmware verification should
be preserved; removing phone-app login does not make firmware packages available.

For the later APK phase, a separate offline app built around our now-tested
protocol is more maintainable than a patched obfuscated APK. No APK rebuild or
login modification was attempted in this change.

## Validation

Windows offline GUI smoke passed at 1180×820 and 1000×720, including all navigation
pages, offline telemetry/filtering and clean close. Additional catalog UI regression
passed: all 504 entries retained, selection never transmits, empty search disables
Read. Tests used bundled Python outside the sandbox to initialize Tcl/Tk. New
identifier/update reads have not been tested against the scooter.
