# OLAS1 control BLE: pairing investigation (2026-09-12)

## Corrected architecture

User identifies OLAS1 as the separate control BLE module, distinct from Android music/calls Bluetooth. Consumer app evidence agrees: CurrentPairingStatus defines BCM_BLE_PAIRED, MEDIA_BLE_PAIRED and ALL_PAIRED separately. VehicleBleEntity holds separate proximity and media addresses/services; proximity has dedicated RX/TX characteristic configuration.

The CAN database defines CommandFromBLE at decimal 1698 (0x6A2), DLC 8, with an eight-bit Command at bit 0. It provides no command enum here. This supports a vehicle command interface but does not prove which processor hosts it, the physical module-to-controller link, or a pairing-confirmation command. Vehicle_HMI_State at 0x6CC contains PassCode_Auth_Status; its name alone does not establish that it refers to BLE rather than the scooter unlock passcode. Neither frame should be replayed to approve pairing.

## Recovered phone-side sequence

1. Load vehicle-specific proximity address/service/RX/TX configuration (VehicleBleEntity; BleManagerImpl.initializeServices around lines 1232-1268).
2. Establish a Bluetooth GATT connection. Connection alone is not application authorization.
3. Poll BluetoothDevice bond state. The connected callback starts readGattBondState; its success branch proceeds when bonded, it waits while bonding and reports unbonded/rejected states. This is the phone's Bluetooth bond state for the remote device, NOT proof that the scooter-side radio is Android.
4. Request a seed. The callback computes a key locally via Fc.b.b(seed, LEVEL1, BLE), saves key material and sends a seed-authentication key.
5. Check authentication grant and AES authentication results; encrypted direct commands carry LOCK/UNLOCK/TRUNK actions afterward.

Evidence: consumer_app/core.repo.ble.signal.manager.BleManagerImpl$connectDevice$2$1.txt (seed calculation around 1371-1382; grant checks 1468 onward; bonding 1957 onward), BleManagerImpl$readGattBondState$2.txt; domain.domainModels.ble.command.CurrentPairingStatus.txt; domain.domainModels.home.VehicleBleEntity.txt.

## Offline and computer support

The inspected seed computation and cryptographic handshake are local. Bluetooth bonding is a local radio protocol. Existing cached configuration may permit offline use; this does not establish that fresh account onboarding, vehicle association and configuration retrieval work without cloud. No successful offline first-pairing test has been performed.

A computer with suitable BLE hardware and OS support could implement this central-client protocol, but requires correct vehicle configuration, bonding, authentication and packet handling. Any Bluetooth device cannot automatically control the scooter; media-only Bluetooth support is insufficient.

## Hardware identity and PIN approval

User supplied BlueNRG-M25A. ST sources found BLUENRG-M2SA (letter S), based on BlueNRG-2; exact marking remains to be confirmed. Do not silently equate these part numbers.

ST PM0257 describes Just Works, passkey entry and numeric comparison, selected from firmware-configured I/O capabilities and authentication requirements. The existence of Just Works support does not mean Ola enables it. A phone cannot assume it can downgrade a module requiring authenticated pairing. If requirements cannot be met, the stack may reject pairing.

The app files do not contain the scooter/module firmware that controls the missing PIN display or remote confirmation. No verified auto-accept command was found in the extracted app command enums, ODX or Wi-Fi proto. ST stack APIs are firmware interfaces, not commands exposed by OLAS1 over BLE or the diagnostic bridge. A no-input/no-output firmware change is not an established repair path and would not remove Ola application authentication.

Earlier advice to use Android music Bluetooth settings to approve OLAS1 was based on conflating the two devices and is withdrawn. The dashboard might render module pairing UI, but its forwarding path remains unverified.

## Next diagnostic capture

Use one ordinary OLAS1 pairing attempt, recording phone-side Bluetooth HCI/bond events and concurrent passive Wi-Fi CAN traffic. Keep existing bonds intact rather than clearing them as a diagnostic shortcut. Record whether the phone requests PIN entry, displays a matching-number confirmation, or fails without either. Needed evidence: SMP pairing capabilities/authentication requirements, pairing failure reason or timeout, and whether the phone ever reaches BONDED. This distinguishes a missing dashboard confirmation from a link/bond failure before investigating Ola seed authentication. No raw CAN injection or key retries are needed for this capture.

No radio connection, pairing attempt, module reset or firmware change was performed during this investigation.

## Primary hardware references

- ST BlueNRG-M2 datasheet: https://www.st.com/resource/en/datasheet/bluenrg-m2.pdf
- ST PM0257 (BlueNRG-1/2 stack pairing/security): https://www.st.com/resource/en/programming_manual/dm00294449-bluenrg-1-bluenrg-2-ble-stack-v2-x-programming-guidelines-stmicroelectronics.pdf
