# Flutter source and third-party notices

This archive contains the Flutter source, generated protocol bindings, Android/iOS project files, tests, and sanitized catalog data needed to review and build OpenOLA. It does not require adjacent Kotlin or desktop source folders. Personal mTLS identities and signing material are intentionally excluded; secure vehicle Wi-Fi diagnostics require a separately authorized development identity configured locally.

Some protocol definitions and catalogs were derived from separately maintained project sources. The public archive includes only the files required by this Flutter project. Rights to redistribute vendor-derived imagery, extracted catalogs, and protocol data have not been established by this source package; review those assets before redistribution beyond this repository.

The earlier desktop glass interface informed Flutter layout proportions and material colors. The widgets and themes are implemented in this project.

Inter variable font is from the [Google Fonts Inter directory](https://github.com/google/fonts/tree/main/ofl/inter), SIL Open Font License 1.1; bundled license: `assets/INTER-LICENSE.txt`. Cupertino icons come from Flutter's package. No SF Symbols binary or proprietary Apple font was copied.

| Package | Purpose |
|---|---|
| Flutter, cupertino_icons | Rendering/widgets/icons |
| grpc, protobuf, fixnum, async | Existing gRPC wire protocol |
| shared_preferences | Theme, tool and connection defaults |
| flutter_reactive_ble, permission_handler | Free BLE and Android permissions |
| pointycastle, crypto | Existing BLE crypto formats |
| file_picker, share_plus | Native document export/share |
| mobile_scanner | QR address scan |
| flutter_test, flutter_lints | Local validation |
| protoc_plugin, flutter_launcher_icons | Source generation |

Resolved versions/transitive dependencies are in `pubspec.lock` and the QA inventory. Flutter generates dependency license notices; retain them for distribution. No commercial BLE package or paid cloud service is used. Audit full notices and existing asset ownership when preparing the public repository.

`proto/google/protobuf/empty.proto` retains its upstream notice; it is the protobuf include used by the old build. Generated stubs retain generator headers.

For 0.4.0 and later, cell gauge language, the OCV estimate curve, configuration reference bytes, and recording schema were adapted into Dart from separate diagnostic source. These are source-derived interpretations, not newly validated hardware behavior. The S1X live-parameter maps are presented as read-only references: CAN values require an exact active-decoder match, and the map does not invent UDS request addresses. `path_provider` 2.1.6 is used for app-local recording storage.
