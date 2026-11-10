/// Compile-time edition switches. Flutter supplies the selected flavor value,
/// so the public debug test build is enabled only by an explicit per-feature
/// define. These are packaging controls, not scooter-side authorization.
const _publicDebugFlavor =
    String.fromEnvironment('FLUTTER_APP_FLAVOR') == 'public';

const identityWritesAvailable = _publicDebugFlavor && bool.fromEnvironment(
  'OPENOLA_IDENTITY_WRITES',
  defaultValue: false,
);

/// Narrow gate for the Gen1 S1 Pro VCU variant test. This intentionally does
/// not enable VIN, odometer, or battery identity writes.
const vcuVariantWritesAvailable = _publicDebugFlavor && bool.fromEnvironment(
  'OPENOLA_VCU_VARIANT_WRITE',
  defaultValue: false,
);

const blePairingAvailable = _publicDebugFlavor && bool.fromEnvironment(
  'OPENOLA_BLE_PAIRING',
  defaultValue: false,
);
