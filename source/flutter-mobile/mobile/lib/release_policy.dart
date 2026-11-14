/// Compile-time edition switches. Flutter supplies the selected flavor value,
/// so identity writes are enabled only for the explicitly opted-in Public or
/// Super package. These are packaging controls, not scooter-side authorization.
const _flavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');
const _writeCapableFlavor = _flavor == 'public' || _flavor == 'super';

const identityWritesAvailable = _writeCapableFlavor && bool.fromEnvironment(
  'OPENOLA_IDENTITY_WRITES',
  defaultValue: false,
);

/// Narrow gate for the Gen1 S1 Pro VCU variant test. This intentionally does
/// not enable VIN, odometer, or battery identity writes.
const vcuVariantWritesAvailable = _flavor == 'public' && bool.fromEnvironment(
  'OPENOLA_VCU_VARIANT_WRITE',
  defaultValue: false,
);

const blePairingAvailable = _flavor == 'public' && bool.fromEnvironment(
  'OPENOLA_BLE_PAIRING',
  defaultValue: false,
);
