// This is a generated file - do not edit.
//
// Generated from wifican.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use respStatusDescriptor instead')
const RespStatus$json = {
  '1': 'RespStatus',
  '2': [
    {'1': 'RESP_NONE', '2': 0},
    {'1': 'RESP_SUCCESS', '2': 1},
    {'1': 'RESP_FAIL', '2': 2},
  ],
};

/// Descriptor for `RespStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List respStatusDescriptor = $convert.base64Decode(
    'CgpSZXNwU3RhdHVzEg0KCVJFU1BfTk9ORRAAEhAKDFJFU1BfU1VDQ0VTUxABEg0KCVJFU1BfRk'
    'FJTBAC');

@$core.Deprecated('Use rmtCmdListDescriptor instead')
const RmtCmdList$json = {
  '1': 'RmtCmdList',
  '2': [
    {'1': 'RMT_CMD_NONE', '2': 0},
    {'1': 'RMT_CMD_LCD_TEST', '2': 1},
    {'1': 'RMT_CMD_GPS_TEST', '2': 2},
    {'1': 'RMT_CMD_BT_TEST', '2': 3},
    {'1': 'RMT_CMD_BLE_TEST', '2': 4},
    {'1': 'RMT_CMD_WIFI_TEST', '2': 5},
    {'1': 'RMT_CMD_SPKR_TEST', '2': 6},
    {'1': 'RMT_CMD_MIC_TEST', '2': 7},
    {'1': 'RMT_CMD_MCU_CAL', '2': 8},
    {'1': 'RMT_CMD_VIN', '2': 9},
    {'1': 'RMT_CMD_PROV', '2': 10},
    {'1': 'RMT_CMD_SW_UPDATE', '2': 11},
    {'1': 'RMT_CMD_ESIM_TEST', '2': 12},
  ],
};

/// Descriptor for `RmtCmdList`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtCmdListDescriptor = $convert.base64Decode(
    'CgpSbXRDbWRMaXN0EhAKDFJNVF9DTURfTk9ORRAAEhQKEFJNVF9DTURfTENEX1RFU1QQARIUCh'
    'BSTVRfQ01EX0dQU19URVNUEAISEwoPUk1UX0NNRF9CVF9URVNUEAMSFAoQUk1UX0NNRF9CTEVf'
    'VEVTVBAEEhUKEVJNVF9DTURfV0lGSV9URVNUEAUSFQoRUk1UX0NNRF9TUEtSX1RFU1QQBhIUCh'
    'BSTVRfQ01EX01JQ19URVNUEAcSEwoPUk1UX0NNRF9NQ1VfQ0FMEAgSDwoLUk1UX0NNRF9WSU4Q'
    'CRIQCgxSTVRfQ01EX1BST1YQChIVChFSTVRfQ01EX1NXX1VQREFURRALEhUKEVJNVF9DTURfRV'
    'NJTV9URVNUEAw=');

@$core.Deprecated('Use rmtSubCmdLcdDescriptor instead')
const RmtSubCmdLcd$json = {
  '1': 'RmtSubCmdLcd',
  '2': [
    {'1': 'RMT_SUB_CMD_LCD_NONE', '2': 0},
    {'1': 'RMT_SUB_CMD_LCD_TEST_START', '2': 1},
    {'1': 'RMT_SUB_CMD_LCD_TEST_STOP', '2': 2},
  ],
};

/// Descriptor for `RmtSubCmdLcd`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtSubCmdLcdDescriptor = $convert.base64Decode(
    'CgxSbXRTdWJDbWRMY2QSGAoUUk1UX1NVQl9DTURfTENEX05PTkUQABIeChpSTVRfU1VCX0NNRF'
    '9MQ0RfVEVTVF9TVEFSVBABEh0KGVJNVF9TVUJfQ01EX0xDRF9URVNUX1NUT1AQAg==');

@$core.Deprecated('Use rmtSubCmdGpsDescriptor instead')
const RmtSubCmdGps$json = {
  '1': 'RmtSubCmdGps',
  '2': [
    {'1': 'RMT_SUB_CMD_GPS_NONE', '2': 0},
    {'1': 'RMT_SUB_CMD_GPS_TEST_START', '2': 1},
    {'1': 'RMT_SUB_CMD_GPS_TEST_STOP', '2': 2},
  ],
};

/// Descriptor for `RmtSubCmdGps`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtSubCmdGpsDescriptor = $convert.base64Decode(
    'CgxSbXRTdWJDbWRHcHMSGAoUUk1UX1NVQl9DTURfR1BTX05PTkUQABIeChpSTVRfU1VCX0NNRF'
    '9HUFNfVEVTVF9TVEFSVBABEh0KGVJNVF9TVUJfQ01EX0dQU19URVNUX1NUT1AQAg==');

@$core.Deprecated('Use rmtSubCmdBtDescriptor instead')
const RmtSubCmdBt$json = {
  '1': 'RmtSubCmdBt',
  '2': [
    {'1': 'RMT_SUB_CMD_BT_NONE', '2': 0},
    {'1': 'RMT_SUB_CMD_BT_TEST_START', '2': 1},
    {'1': 'RMT_SUB_CMD_BT_TEST_STOP', '2': 2},
  ],
};

/// Descriptor for `RmtSubCmdBt`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtSubCmdBtDescriptor = $convert.base64Decode(
    'CgtSbXRTdWJDbWRCdBIXChNSTVRfU1VCX0NNRF9CVF9OT05FEAASHQoZUk1UX1NVQl9DTURfQl'
    'RfVEVTVF9TVEFSVBABEhwKGFJNVF9TVUJfQ01EX0JUX1RFU1RfU1RPUBAC');

@$core.Deprecated('Use rmtSubCmdBleDescriptor instead')
const RmtSubCmdBle$json = {
  '1': 'RmtSubCmdBle',
  '2': [
    {'1': 'RMT_SUB_CMD_BLE_NONE', '2': 0},
    {'1': 'RMT_SUB_CMD_BLE_TEST_START', '2': 1},
    {'1': 'RMT_SUB_CMD_BLE_TEST_STOP', '2': 2},
  ],
};

/// Descriptor for `RmtSubCmdBle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtSubCmdBleDescriptor = $convert.base64Decode(
    'CgxSbXRTdWJDbWRCbGUSGAoUUk1UX1NVQl9DTURfQkxFX05PTkUQABIeChpSTVRfU1VCX0NNRF'
    '9CTEVfVEVTVF9TVEFSVBABEh0KGVJNVF9TVUJfQ01EX0JMRV9URVNUX1NUT1AQAg==');

@$core.Deprecated('Use rmtSubCmdWifiDescriptor instead')
const RmtSubCmdWifi$json = {
  '1': 'RmtSubCmdWifi',
  '2': [
    {'1': 'RMT_SUB_CMD_WIFI_NONE', '2': 0},
    {'1': 'RMT_SUB_CMD_WIFI_TEST_START', '2': 1},
    {'1': 'RMT_SUB_CMD_WIFI_TEST_STOP', '2': 2},
  ],
};

/// Descriptor for `RmtSubCmdWifi`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtSubCmdWifiDescriptor = $convert.base64Decode(
    'Cg1SbXRTdWJDbWRXaWZpEhkKFVJNVF9TVUJfQ01EX1dJRklfTk9ORRAAEh8KG1JNVF9TVUJfQ0'
    '1EX1dJRklfVEVTVF9TVEFSVBABEh4KGlJNVF9TVUJfQ01EX1dJRklfVEVTVF9TVE9QEAI=');

@$core.Deprecated('Use rmtSubCmdSpkrDescriptor instead')
const RmtSubCmdSpkr$json = {
  '1': 'RmtSubCmdSpkr',
  '2': [
    {'1': 'RMT_SUB_CMD_SPKR_NONE', '2': 0},
    {'1': 'RMT_SUB_CMD_SPKR_TEST_START', '2': 1},
    {'1': 'RMT_SUB_CMD_SPRK_TEST_STOP', '2': 2},
  ],
};

/// Descriptor for `RmtSubCmdSpkr`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtSubCmdSpkrDescriptor = $convert.base64Decode(
    'Cg1SbXRTdWJDbWRTcGtyEhkKFVJNVF9TVUJfQ01EX1NQS1JfTk9ORRAAEh8KG1JNVF9TVUJfQ0'
    '1EX1NQS1JfVEVTVF9TVEFSVBABEh4KGlJNVF9TVUJfQ01EX1NQUktfVEVTVF9TVE9QEAI=');

@$core.Deprecated('Use rmtSubCmdMicDescriptor instead')
const RmtSubCmdMic$json = {
  '1': 'RmtSubCmdMic',
  '2': [
    {'1': 'RMT_SUB_CMD_MIC_NONE', '2': 0},
    {'1': 'RMT_SUB_CMD_MIC_TEST_START', '2': 1},
    {'1': 'RMT_SUB_CMD_MIC_TEST_STOP', '2': 2},
  ],
};

/// Descriptor for `RmtSubCmdMic`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtSubCmdMicDescriptor = $convert.base64Decode(
    'CgxSbXRTdWJDbWRNaWMSGAoUUk1UX1NVQl9DTURfTUlDX05PTkUQABIeChpSTVRfU1VCX0NNRF'
    '9NSUNfVEVTVF9TVEFSVBABEh0KGVJNVF9TVUJfQ01EX01JQ19URVNUX1NUT1AQAg==');

@$core.Deprecated('Use rmtSubCmdMcuCalDescriptor instead')
const RmtSubCmdMcuCal$json = {
  '1': 'RmtSubCmdMcuCal',
  '2': [
    {'1': 'RMT_SUB_CMD_MCU_NONE', '2': 0},
    {'1': 'RMT_SUB_CMD_MCU_CAL_START', '2': 1},
    {'1': 'RMT_SUB_CMD_MCU_CAL_STOP', '2': 2},
  ],
};

/// Descriptor for `RmtSubCmdMcuCal`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtSubCmdMcuCalDescriptor = $convert.base64Decode(
    'Cg9SbXRTdWJDbWRNY3VDYWwSGAoUUk1UX1NVQl9DTURfTUNVX05PTkUQABIdChlSTVRfU1VCX0'
    'NNRF9NQ1VfQ0FMX1NUQVJUEAESHAoYUk1UX1NVQl9DTURfTUNVX0NBTF9TVE9QEAI=');

@$core.Deprecated('Use rmtSubCmdVinDescriptor instead')
const RmtSubCmdVin$json = {
  '1': 'RmtSubCmdVin',
  '2': [
    {'1': 'RMT_SUB_CMD_VIN_NONE', '2': 0},
    {'1': 'RMT_SUB_CMD_VIN_GET', '2': 1},
    {'1': 'RMT_SUB_CMD_VIN_SET', '2': 2},
  ],
};

/// Descriptor for `RmtSubCmdVin`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtSubCmdVinDescriptor = $convert.base64Decode(
    'CgxSbXRTdWJDbWRWaW4SGAoUUk1UX1NVQl9DTURfVklOX05PTkUQABIXChNSTVRfU1VCX0NNRF'
    '9WSU5fR0VUEAESFwoTUk1UX1NVQl9DTURfVklOX1NFVBAC');

@$core.Deprecated('Use rmtSubCmdProvDescriptor instead')
const RmtSubCmdProv$json = {
  '1': 'RmtSubCmdProv',
  '2': [
    {'1': 'RMT_SUB_CMD_PROV_NONE', '2': 0},
    {'1': 'RMT_SUB_CMD_PROV_START', '2': 1},
    {'1': 'RMT_SUB_CMD_PROV_STOP', '2': 2},
  ],
};

/// Descriptor for `RmtSubCmdProv`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtSubCmdProvDescriptor = $convert.base64Decode(
    'Cg1SbXRTdWJDbWRQcm92EhkKFVJNVF9TVUJfQ01EX1BST1ZfTk9ORRAAEhoKFlJNVF9TVUJfQ0'
    '1EX1BST1ZfU1RBUlQQARIZChVSTVRfU1VCX0NNRF9QUk9WX1NUT1AQAg==');

@$core.Deprecated('Use rmtSubCmdSwUpdateDescriptor instead')
const RmtSubCmdSwUpdate$json = {
  '1': 'RmtSubCmdSwUpdate',
  '2': [
    {'1': 'RMT_SUB_CMD_SW_UPDATE_NONE', '2': 0},
    {'1': 'RMT_SUB_CMD_SW_UPDATE_START', '2': 1},
    {'1': 'RMT_SUB_CMD_SW_UPDATE_STOP', '2': 2},
  ],
};

/// Descriptor for `RmtSubCmdSwUpdate`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtSubCmdSwUpdateDescriptor = $convert.base64Decode(
    'ChFSbXRTdWJDbWRTd1VwZGF0ZRIeChpSTVRfU1VCX0NNRF9TV19VUERBVEVfTk9ORRAAEh8KG1'
    'JNVF9TVUJfQ01EX1NXX1VQREFURV9TVEFSVBABEh4KGlJNVF9TVUJfQ01EX1NXX1VQREFURV9T'
    'VE9QEAI=');

@$core.Deprecated('Use rmtSubCmdEsimDescriptor instead')
const RmtSubCmdEsim$json = {
  '1': 'RmtSubCmdEsim',
  '2': [
    {'1': 'RMT_SUB_CMD_ESIM_NONE', '2': 0},
    {'1': 'RMT_SUB_CMD_ESIM_TEST_START', '2': 1},
    {'1': 'RMT_SUB_CMD_ESIM_TEST_STOP', '2': 2},
  ],
};

/// Descriptor for `RmtSubCmdEsim`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtSubCmdEsimDescriptor = $convert.base64Decode(
    'Cg1SbXRTdWJDbWRFc2ltEhkKFVJNVF9TVUJfQ01EX0VTSU1fTk9ORRAAEh8KG1JNVF9TVUJfQ0'
    '1EX0VTSU1fVEVTVF9TVEFSVBABEh4KGlJNVF9TVUJfQ01EX0VTSU1fVEVTVF9TVE9QEAI=');

@$core.Deprecated('Use rmtCmdRespStatusDescriptor instead')
const RmtCmdRespStatus$json = {
  '1': 'RmtCmdRespStatus',
  '2': [
    {'1': 'RMT_CMD_RESP_NONE', '2': 0},
    {'1': 'RMT_CMD_RESP_SUCCESS', '2': 1},
    {'1': 'RMT_CMD_RESP_FAIL', '2': 2},
  ],
};

/// Descriptor for `RmtCmdRespStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rmtCmdRespStatusDescriptor = $convert.base64Decode(
    'ChBSbXRDbWRSZXNwU3RhdHVzEhUKEVJNVF9DTURfUkVTUF9OT05FEAASGAoUUk1UX0NNRF9SRV'
    'NQX1NVQ0NFU1MQARIVChFSTVRfQ01EX1JFU1BfRkFJTBAC');

@$core.Deprecated('Use vehicleOperationStateDescriptor instead')
const VehicleOperationState$json = {
  '1': 'VehicleOperationState',
  '2': [
    {'1': 'VEHICLE_OP_STATE_NONE', '2': 0},
    {'1': 'VEHICLE_OP_STATE_MFG', '2': 1},
    {'1': 'VEHICLE_OP_STATE_CUST', '2': 2},
    {'1': 'VEHICLE_OP_STATE_SERVICE', '2': 3},
    {'1': 'VEHICLE_OP_STATE_DECOMMISSIONED', '2': 4},
  ],
};

/// Descriptor for `VehicleOperationState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List vehicleOperationStateDescriptor = $convert.base64Decode(
    'ChVWZWhpY2xlT3BlcmF0aW9uU3RhdGUSGQoVVkVISUNMRV9PUF9TVEFURV9OT05FEAASGAoUVk'
    'VISUNMRV9PUF9TVEFURV9NRkcQARIZChVWRUhJQ0xFX09QX1NUQVRFX0NVU1QQAhIcChhWRUhJ'
    'Q0xFX09QX1NUQVRFX1NFUlZJQ0UQAxIjCh9WRUhJQ0xFX09QX1NUQVRFX0RFQ09NTUlTU0lPTk'
    'VEEAQ=');

@$core.Deprecated('Use swUpdateStateDescriptor instead')
const SwUpdateState$json = {
  '1': 'SwUpdateState',
  '2': [
    {'1': 'SW_UPDATE_STATE_NONE', '2': 0},
    {'1': 'SW_UPDATE_STATE_IDLE', '2': 1},
    {'1': 'SW_UPDATE_STATE_UPLOAD_INITIALIZED', '2': 2},
    {'1': 'SW_UPDATE_STATE_UPLOAD_IN_PROGRESS', '2': 3},
    {'1': 'SW_UPDATE_STATE_UPLOAD_SUCCESS', '2': 4},
    {'1': 'SW_UPDATE_STATE_UPLOAD_FAILED', '2': 5},
    {'1': 'SW_UPDATE_STATE_INSTALLING_SYSTEM', '2': 6},
    {'1': 'SW_UPDATE_STATE_INSTALLING_BCM', '2': 7},
    {'1': 'SW_UPDATE_STATE_INSTALLING_BMS', '2': 8},
    {'1': 'SW_UPDATE_STATE_INSTALLING_BLE', '2': 9},
    {'1': 'SW_UPDATE_STATE_INSTALLING_MCU', '2': 10},
    {'1': 'SW_UPDATE_STATE_INSTALLING_AOSP', '2': 11},
    {'1': 'SW_UPDATE_STATE_REBOOTING', '2': 12},
    {'1': 'SW_UPDATE_STATE_SUCCESS', '2': 13},
    {'1': 'SW_UPDATE_STATE_FAILED', '2': 14},
  ],
};

/// Descriptor for `SwUpdateState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List swUpdateStateDescriptor = $convert.base64Decode(
    'Cg1Td1VwZGF0ZVN0YXRlEhgKFFNXX1VQREFURV9TVEFURV9OT05FEAASGAoUU1dfVVBEQVRFX1'
    'NUQVRFX0lETEUQARImCiJTV19VUERBVEVfU1RBVEVfVVBMT0FEX0lOSVRJQUxJWkVEEAISJgoi'
    'U1dfVVBEQVRFX1NUQVRFX1VQTE9BRF9JTl9QUk9HUkVTUxADEiIKHlNXX1VQREFURV9TVEFURV'
    '9VUExPQURfU1VDQ0VTUxAEEiEKHVNXX1VQREFURV9TVEFURV9VUExPQURfRkFJTEVEEAUSJQoh'
    'U1dfVVBEQVRFX1NUQVRFX0lOU1RBTExJTkdfU1lTVEVNEAYSIgoeU1dfVVBEQVRFX1NUQVRFX0'
    'lOU1RBTExJTkdfQkNNEAcSIgoeU1dfVVBEQVRFX1NUQVRFX0lOU1RBTExJTkdfQk1TEAgSIgoe'
    'U1dfVVBEQVRFX1NUQVRFX0lOU1RBTExJTkdfQkxFEAkSIgoeU1dfVVBEQVRFX1NUQVRFX0lOU1'
    'RBTExJTkdfTUNVEAoSIwofU1dfVVBEQVRFX1NUQVRFX0lOU1RBTExJTkdfQU9TUBALEh0KGVNX'
    'X1VQREFURV9TVEFURV9SRUJPT1RJTkcQDBIbChdTV19VUERBVEVfU1RBVEVfU1VDQ0VTUxANEh'
    'oKFlNXX1VQREFURV9TVEFURV9GQUlMRUQQDg==');

@$core.Deprecated('Use swUpdateTriggerDescriptor instead')
const SwUpdateTrigger$json = {
  '1': 'SwUpdateTrigger',
  '2': [
    {'1': 'SW_UPDATE_TRIGGER_NONE', '2': 0},
    {'1': 'SW_UPDATE_TRIGGER_ALL', '2': 1},
    {'1': 'SW_UPDATE_TRIGGER_BCM', '2': 2},
    {'1': 'SW_UPDATE_TRIGGER_BMS', '2': 3},
    {'1': 'SW_UPDATE_TRIGGER_BLE', '2': 4},
    {'1': 'SW_UPDATE_TRIGGER_MCU', '2': 5},
    {'1': 'SW_UPDATE_TRIGGER_AOSP', '2': 6},
    {'1': 'SW_UPDATE_TRIGGER_HU', '2': 7},
  ],
};

/// Descriptor for `SwUpdateTrigger`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List swUpdateTriggerDescriptor = $convert.base64Decode(
    'Cg9Td1VwZGF0ZVRyaWdnZXISGgoWU1dfVVBEQVRFX1RSSUdHRVJfTk9ORRAAEhkKFVNXX1VQRE'
    'FURV9UUklHR0VSX0FMTBABEhkKFVNXX1VQREFURV9UUklHR0VSX0JDTRACEhkKFVNXX1VQREFU'
    'RV9UUklHR0VSX0JNUxADEhkKFVNXX1VQREFURV9UUklHR0VSX0JMRRAEEhkKFVNXX1VQREFURV'
    '9UUklHR0VSX01DVRAFEhoKFlNXX1VQREFURV9UUklHR0VSX0FPU1AQBhIYChRTV19VUERBVEVf'
    'VFJJR0dFUl9IVRAH');

@$core.Deprecated('Use systemCmdListDescriptor instead')
const SystemCmdList$json = {
  '1': 'SystemCmdList',
  '2': [
    {'1': 'SYS_CMD_NONE', '2': 0},
    {'1': 'SYS_CMD_SOM', '2': 1},
  ],
};

/// Descriptor for `SystemCmdList`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List systemCmdListDescriptor = $convert.base64Decode(
    'Cg1TeXN0ZW1DbWRMaXN0EhAKDFNZU19DTURfTk9ORRAAEg8KC1NZU19DTURfU09NEAE=');

@$core.Deprecated('Use registerDescriptor instead')
const Register$json = {
  '1': 'Register',
  '2': [
    {'1': 'can_ids', '3': 1, '4': 3, '5': 13, '10': 'canIds'},
  ],
};

/// Descriptor for `Register`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerDescriptor =
    $convert.base64Decode('CghSZWdpc3RlchIXCgdjYW5faWRzGAEgAygNUgZjYW5JZHM=');

@$core.Deprecated('Use responseDescriptor instead')
const Response$json = {
  '1': 'Response',
  '2': [
    {
      '1': 'status',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.wifican.RespStatus',
      '10': 'status'
    },
    {'1': 'status_msg', '3': 2, '4': 1, '5': 9, '10': 'statusMsg'},
  ],
};

/// Descriptor for `Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List responseDescriptor = $convert.base64Decode(
    'CghSZXNwb25zZRIrCgZzdGF0dXMYASABKA4yEy53aWZpY2FuLlJlc3BTdGF0dXNSBnN0YXR1cx'
    'IdCgpzdGF0dXNfbXNnGAIgASgJUglzdGF0dXNNc2c=');

@$core.Deprecated('Use cANPacketDescriptor instead')
const CANPacket$json = {
  '1': 'CANPacket',
  '2': [
    {'1': 'can_frame', '3': 1, '4': 1, '5': 12, '10': 'canFrame'},
  ],
};

/// Descriptor for `CANPacket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cANPacketDescriptor = $convert
    .base64Decode('CglDQU5QYWNrZXQSGwoJY2FuX2ZyYW1lGAEgASgMUghjYW5GcmFtZQ==');

@$core.Deprecated('Use rmtCmdReqDescriptor instead')
const RmtCmdReq$json = {
  '1': 'RmtCmdReq',
  '2': [
    {
      '1': 'cmd_id',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtCmdList',
      '10': 'cmdId'
    },
    {
      '1': 'sub_cmd_lcd',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtSubCmdLcd',
      '10': 'subCmdLcd'
    },
    {
      '1': 'sub_cmd_gps',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtSubCmdGps',
      '10': 'subCmdGps'
    },
    {
      '1': 'sub_cmd_bt',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtSubCmdBt',
      '10': 'subCmdBt'
    },
    {
      '1': 'sub_cmd_ble',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtSubCmdBle',
      '10': 'subCmdBle'
    },
    {
      '1': 'sub_cmd_wifi',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtSubCmdWifi',
      '10': 'subCmdWifi'
    },
    {
      '1': 'sub_cmd_spkr',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtSubCmdSpkr',
      '10': 'subCmdSpkr'
    },
    {
      '1': 'sub_cmd_mic',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtSubCmdMic',
      '10': 'subCmdMic'
    },
    {
      '1': 'sub_cmd_mcu_cal',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtSubCmdMcuCal',
      '10': 'subCmdMcuCal'
    },
    {
      '1': 'sub_cmd_vin',
      '3': 10,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtSubCmdVin',
      '10': 'subCmdVin'
    },
    {
      '1': 'sub_cmd_prov',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtSubCmdProv',
      '10': 'subCmdProv'
    },
    {
      '1': 'sub_cmd_esim',
      '3': 15,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtSubCmdEsim',
      '10': 'subCmdEsim'
    },
    {
      '1': 'sub_cmd_sw_update',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtSubCmdSwUpdate',
      '10': 'subCmdSwUpdate'
    },
    {'1': 'cmd_input_str', '3': 13, '4': 1, '5': 9, '10': 'cmdInputStr'},
    {'1': 'cmd_input_bytes', '3': 14, '4': 1, '5': 12, '10': 'cmdInputBytes'},
  ],
};

/// Descriptor for `RmtCmdReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rmtCmdReqDescriptor = $convert.base64Decode(
    'CglSbXRDbWRSZXESKgoGY21kX2lkGAEgASgOMhMud2lmaWNhbi5SbXRDbWRMaXN0UgVjbWRJZB'
    'I1CgtzdWJfY21kX2xjZBgCIAEoDjIVLndpZmljYW4uUm10U3ViQ21kTGNkUglzdWJDbWRMY2QS'
    'NQoLc3ViX2NtZF9ncHMYAyABKA4yFS53aWZpY2FuLlJtdFN1YkNtZEdwc1IJc3ViQ21kR3BzEj'
    'IKCnN1Yl9jbWRfYnQYBCABKA4yFC53aWZpY2FuLlJtdFN1YkNtZEJ0UghzdWJDbWRCdBI1Cgtz'
    'dWJfY21kX2JsZRgFIAEoDjIVLndpZmljYW4uUm10U3ViQ21kQmxlUglzdWJDbWRCbGUSOAoMc3'
    'ViX2NtZF93aWZpGAYgASgOMhYud2lmaWNhbi5SbXRTdWJDbWRXaWZpUgpzdWJDbWRXaWZpEjgK'
    'DHN1Yl9jbWRfc3BrchgHIAEoDjIWLndpZmljYW4uUm10U3ViQ21kU3BrclIKc3ViQ21kU3Brch'
    'I1CgtzdWJfY21kX21pYxgIIAEoDjIVLndpZmljYW4uUm10U3ViQ21kTWljUglzdWJDbWRNaWMS'
    'PwoPc3ViX2NtZF9tY3VfY2FsGAkgASgOMhgud2lmaWNhbi5SbXRTdWJDbWRNY3VDYWxSDHN1Yk'
    'NtZE1jdUNhbBI1CgtzdWJfY21kX3ZpbhgKIAEoDjIVLndpZmljYW4uUm10U3ViQ21kVmluUglz'
    'dWJDbWRWaW4SOAoMc3ViX2NtZF9wcm92GAsgASgOMhYud2lmaWNhbi5SbXRTdWJDbWRQcm92Ug'
    'pzdWJDbWRQcm92EjgKDHN1Yl9jbWRfZXNpbRgPIAEoDjIWLndpZmljYW4uUm10U3ViQ21kRXNp'
    'bVIKc3ViQ21kRXNpbRJFChFzdWJfY21kX3N3X3VwZGF0ZRgMIAEoDjIaLndpZmljYW4uUm10U3'
    'ViQ21kU3dVcGRhdGVSDnN1YkNtZFN3VXBkYXRlEiIKDWNtZF9pbnB1dF9zdHIYDSABKAlSC2Nt'
    'ZElucHV0U3RyEiYKD2NtZF9pbnB1dF9ieXRlcxgOIAEoDFINY21kSW5wdXRCeXRlcw==');

@$core.Deprecated('Use rmtCmdRespDescriptor instead')
const RmtCmdResp$json = {
  '1': 'RmtCmdResp',
  '2': [
    {
      '1': 'cmd_id',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtCmdList',
      '10': 'cmdId'
    },
    {
      '1': 'resp_status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtCmdRespStatus',
      '10': 'respStatus'
    },
    {'1': 'resp_str', '3': 3, '4': 1, '5': 9, '10': 'respStr'},
    {'1': 'resp_bytes', '3': 4, '4': 1, '5': 12, '10': 'respBytes'},
  ],
};

/// Descriptor for `RmtCmdResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rmtCmdRespDescriptor = $convert.base64Decode(
    'CgpSbXRDbWRSZXNwEioKBmNtZF9pZBgBIAEoDjITLndpZmljYW4uUm10Q21kTGlzdFIFY21kSW'
    'QSOgoLcmVzcF9zdGF0dXMYAiABKA4yGS53aWZpY2FuLlJtdENtZFJlc3BTdGF0dXNSCnJlc3BT'
    'dGF0dXMSGQoIcmVzcF9zdHIYAyABKAlSB3Jlc3BTdHISHQoKcmVzcF9ieXRlcxgEIAEoDFIJcm'
    'VzcEJ5dGVz');

@$core.Deprecated('Use navigationConfigDescriptor instead')
const NavigationConfig$json = {
  '1': 'NavigationConfig',
  '2': [
    {'1': 'VinNumber', '3': 1, '4': 1, '5': 9, '10': 'VinNumber'},
  ],
};

/// Descriptor for `NavigationConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List navigationConfigDescriptor = $convert.base64Decode(
    'ChBOYXZpZ2F0aW9uQ29uZmlnEhwKCVZpbk51bWJlchgBIAEoCVIJVmluTnVtYmVy');

@$core.Deprecated('Use vinDescriptor instead')
const Vin$json = {
  '1': 'Vin',
  '2': [
    {'1': 'VinNumber', '3': 1, '4': 1, '5': 9, '10': 'VinNumber'},
  ],
};

/// Descriptor for `Vin`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List vinDescriptor =
    $convert.base64Decode('CgNWaW4SHAoJVmluTnVtYmVyGAEgASgJUglWaW5OdW1iZXI=');

@$core.Deprecated('Use vehicleIdentifiersDescriptor instead')
const VehicleIdentifiers$json = {
  '1': 'VehicleIdentifiers',
  '2': [
    {'1': 'manifest_json', '3': 1, '4': 1, '5': 9, '10': 'manifestJson'},
  ],
};

/// Descriptor for `VehicleIdentifiers`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List vehicleIdentifiersDescriptor = $convert.base64Decode(
    'ChJWZWhpY2xlSWRlbnRpZmllcnMSIwoNbWFuaWZlc3RfanNvbhgBIAEoCVIMbWFuaWZlc3RKc2'
    '9u');

@$core.Deprecated('Use vehicleOperationModeDescriptor instead')
const VehicleOperationMode$json = {
  '1': 'VehicleOperationMode',
  '2': [
    {
      '1': 'cur_mode',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.wifican.VehicleOperationState',
      '10': 'curMode'
    },
    {'1': 'modified_ts', '3': 2, '4': 1, '5': 4, '10': 'modifiedTs'},
    {'1': 'modified_ts_str', '3': 3, '4': 1, '5': 9, '10': 'modifiedTsStr'},
    {'1': 'modified_by', '3': 4, '4': 1, '5': 9, '10': 'modifiedBy'},
  ],
};

/// Descriptor for `VehicleOperationMode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List vehicleOperationModeDescriptor = $convert.base64Decode(
    'ChRWZWhpY2xlT3BlcmF0aW9uTW9kZRI5CghjdXJfbW9kZRgBIAEoDjIeLndpZmljYW4uVmVoaW'
    'NsZU9wZXJhdGlvblN0YXRlUgdjdXJNb2RlEh8KC21vZGlmaWVkX3RzGAIgASgEUgptb2RpZmll'
    'ZFRzEiYKD21vZGlmaWVkX3RzX3N0chgDIAEoCVINbW9kaWZpZWRUc1N0chIfCgttb2RpZmllZF'
    '9ieRgEIAEoCVIKbW9kaWZpZWRCeQ==');

@$core.Deprecated('Use swUpdateStatusDescriptor instead')
const SwUpdateStatus$json = {
  '1': 'SwUpdateStatus',
  '2': [
    {
      '1': 'status',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.wifican.SwUpdateState',
      '10': 'status'
    },
    {'1': 'status_msg', '3': 2, '4': 1, '5': 9, '10': 'statusMsg'},
  ],
};

/// Descriptor for `SwUpdateStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List swUpdateStatusDescriptor = $convert.base64Decode(
    'Cg5Td1VwZGF0ZVN0YXR1cxIuCgZzdGF0dXMYASABKA4yFi53aWZpY2FuLlN3VXBkYXRlU3RhdG'
    'VSBnN0YXR1cxIdCgpzdGF0dXNfbXNnGAIgASgJUglzdGF0dXNNc2c=');

@$core.Deprecated('Use swUpdateFileMetadataReqDescriptor instead')
const SwUpdateFileMetadataReq$json = {
  '1': 'SwUpdateFileMetadataReq',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'size', '3': 2, '4': 1, '5': 13, '10': 'size'},
    {'1': 'csum', '3': 3, '4': 1, '5': 9, '10': 'csum'},
  ],
};

/// Descriptor for `SwUpdateFileMetadataReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List swUpdateFileMetadataReqDescriptor =
    $convert.base64Decode(
        'ChdTd1VwZGF0ZUZpbGVNZXRhZGF0YVJlcRISCgRuYW1lGAEgASgJUgRuYW1lEhIKBHNpemUYAi'
        'ABKA1SBHNpemUSEgoEY3N1bRgDIAEoCVIEY3N1bQ==');

@$core.Deprecated('Use swUpdateFileMetadataRespDescriptor instead')
const SwUpdateFileMetadataResp$json = {
  '1': 'SwUpdateFileMetadataResp',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'size', '3': 2, '4': 1, '5': 13, '10': 'size'},
    {'1': 'csum', '3': 3, '4': 1, '5': 9, '10': 'csum'},
    {'1': 'transfer_status', '3': 4, '4': 1, '5': 9, '10': 'transferStatus'},
  ],
};

/// Descriptor for `SwUpdateFileMetadataResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List swUpdateFileMetadataRespDescriptor = $convert.base64Decode(
    'ChhTd1VwZGF0ZUZpbGVNZXRhZGF0YVJlc3ASEgoEbmFtZRgBIAEoCVIEbmFtZRISCgRzaXplGA'
    'IgASgNUgRzaXplEhIKBGNzdW0YAyABKAlSBGNzdW0SJwoPdHJhbnNmZXJfc3RhdHVzGAQgASgJ'
    'Ug50cmFuc2ZlclN0YXR1cw==');

@$core.Deprecated('Use swUpdateFileChunkDescriptor instead')
const SwUpdateFileChunk$json = {
  '1': 'SwUpdateFileChunk',
  '2': [
    {'1': 'chunk', '3': 1, '4': 1, '5': 12, '10': 'chunk'},
  ],
};

/// Descriptor for `SwUpdateFileChunk`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List swUpdateFileChunkDescriptor = $convert
    .base64Decode('ChFTd1VwZGF0ZUZpbGVDaHVuaxIUCgVjaHVuaxgBIAEoDFIFY2h1bms=');

@$core.Deprecated('Use swUpdateTriggerCmdDescriptor instead')
const SwUpdateTriggerCmd$json = {
  '1': 'SwUpdateTriggerCmd',
  '2': [
    {
      '1': 'trigger',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.wifican.SwUpdateTrigger',
      '10': 'trigger'
    },
  ],
};

/// Descriptor for `SwUpdateTriggerCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List swUpdateTriggerCmdDescriptor = $convert.base64Decode(
    'ChJTd1VwZGF0ZVRyaWdnZXJDbWQSMgoHdHJpZ2dlchgBIAEoDjIYLndpZmljYW4uU3dVcGRhdG'
    'VUcmlnZ2VyUgd0cmlnZ2Vy');

@$core.Deprecated('Use systemTestCmdDescriptor instead')
const SystemTestCmd$json = {
  '1': 'SystemTestCmd',
  '2': [
    {
      '1': 'cmd_id',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.wifican.SystemCmdList',
      '10': 'cmdId'
    },
    {'1': 'resp_str', '3': 2, '4': 1, '5': 9, '10': 'respStr'},
    {'1': 'resp_bytes', '3': 3, '4': 1, '5': 12, '10': 'respBytes'},
  ],
};

/// Descriptor for `SystemTestCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List systemTestCmdDescriptor = $convert.base64Decode(
    'Cg1TeXN0ZW1UZXN0Q21kEi0KBmNtZF9pZBgBIAEoDjIWLndpZmljYW4uU3lzdGVtQ21kTGlzdF'
    'IFY21kSWQSGQoIcmVzcF9zdHIYAiABKAlSB3Jlc3BTdHISHQoKcmVzcF9ieXRlcxgDIAEoDFIJ'
    'cmVzcEJ5dGVz');

@$core.Deprecated('Use systemTestRespDescriptor instead')
const SystemTestResp$json = {
  '1': 'SystemTestResp',
  '2': [
    {
      '1': 'cmd_id',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.wifican.SystemCmdList',
      '10': 'cmdId'
    },
    {
      '1': 'resp_status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.wifican.RmtCmdRespStatus',
      '10': 'respStatus'
    },
    {'1': 'resp_str', '3': 3, '4': 1, '5': 9, '10': 'respStr'},
    {'1': 'resp_bytes', '3': 4, '4': 1, '5': 12, '10': 'respBytes'},
  ],
};

/// Descriptor for `SystemTestResp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List systemTestRespDescriptor = $convert.base64Decode(
    'Cg5TeXN0ZW1UZXN0UmVzcBItCgZjbWRfaWQYASABKA4yFi53aWZpY2FuLlN5c3RlbUNtZExpc3'
    'RSBWNtZElkEjoKC3Jlc3Bfc3RhdHVzGAIgASgOMhkud2lmaWNhbi5SbXRDbWRSZXNwU3RhdHVz'
    'UgpyZXNwU3RhdHVzEhkKCHJlc3Bfc3RyGAMgASgJUgdyZXNwU3RyEh0KCnJlc3BfYnl0ZXMYBC'
    'ABKAxSCXJlc3BCeXRlcw==');

@$core.Deprecated('Use commandDescriptor instead')
const Command$json = {
  '1': 'Command',
  '2': [
    {'1': 'cmd_msg', '3': 1, '4': 1, '5': 9, '10': 'cmdMsg'},
  ],
};

/// Descriptor for `Command`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandDescriptor =
    $convert.base64Decode('CgdDb21tYW5kEhcKB2NtZF9tc2cYASABKAlSBmNtZE1zZw==');
