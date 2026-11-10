// This is a generated file - do not edit.
//
// Generated from wifican.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Response statuses
class RespStatus extends $pb.ProtobufEnum {
  static const RespStatus RESP_NONE =
      RespStatus._(0, _omitEnumNames ? '' : 'RESP_NONE');
  static const RespStatus RESP_SUCCESS =
      RespStatus._(1, _omitEnumNames ? '' : 'RESP_SUCCESS');
  static const RespStatus RESP_FAIL =
      RespStatus._(2, _omitEnumNames ? '' : 'RESP_FAIL');

  static const $core.List<RespStatus> values = <RespStatus>[
    RESP_NONE,
    RESP_SUCCESS,
    RESP_FAIL,
  ];

  static final $core.List<RespStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RespStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RespStatus._(super.value, super.name);
}

/// List of main commands that can be invoked from client
class RmtCmdList extends $pb.ProtobufEnum {
  static const RmtCmdList RMT_CMD_NONE =
      RmtCmdList._(0, _omitEnumNames ? '' : 'RMT_CMD_NONE');
  static const RmtCmdList RMT_CMD_LCD_TEST =
      RmtCmdList._(1, _omitEnumNames ? '' : 'RMT_CMD_LCD_TEST');
  static const RmtCmdList RMT_CMD_GPS_TEST =
      RmtCmdList._(2, _omitEnumNames ? '' : 'RMT_CMD_GPS_TEST');
  static const RmtCmdList RMT_CMD_BT_TEST =
      RmtCmdList._(3, _omitEnumNames ? '' : 'RMT_CMD_BT_TEST');
  static const RmtCmdList RMT_CMD_BLE_TEST =
      RmtCmdList._(4, _omitEnumNames ? '' : 'RMT_CMD_BLE_TEST');
  static const RmtCmdList RMT_CMD_WIFI_TEST =
      RmtCmdList._(5, _omitEnumNames ? '' : 'RMT_CMD_WIFI_TEST');
  static const RmtCmdList RMT_CMD_SPKR_TEST =
      RmtCmdList._(6, _omitEnumNames ? '' : 'RMT_CMD_SPKR_TEST');
  static const RmtCmdList RMT_CMD_MIC_TEST =
      RmtCmdList._(7, _omitEnumNames ? '' : 'RMT_CMD_MIC_TEST');
  static const RmtCmdList RMT_CMD_MCU_CAL =
      RmtCmdList._(8, _omitEnumNames ? '' : 'RMT_CMD_MCU_CAL');
  static const RmtCmdList RMT_CMD_VIN =
      RmtCmdList._(9, _omitEnumNames ? '' : 'RMT_CMD_VIN');
  static const RmtCmdList RMT_CMD_PROV =
      RmtCmdList._(10, _omitEnumNames ? '' : 'RMT_CMD_PROV');
  static const RmtCmdList RMT_CMD_SW_UPDATE =
      RmtCmdList._(11, _omitEnumNames ? '' : 'RMT_CMD_SW_UPDATE');
  static const RmtCmdList RMT_CMD_ESIM_TEST =
      RmtCmdList._(12, _omitEnumNames ? '' : 'RMT_CMD_ESIM_TEST');

  static const $core.List<RmtCmdList> values = <RmtCmdList>[
    RMT_CMD_NONE,
    RMT_CMD_LCD_TEST,
    RMT_CMD_GPS_TEST,
    RMT_CMD_BT_TEST,
    RMT_CMD_BLE_TEST,
    RMT_CMD_WIFI_TEST,
    RMT_CMD_SPKR_TEST,
    RMT_CMD_MIC_TEST,
    RMT_CMD_MCU_CAL,
    RMT_CMD_VIN,
    RMT_CMD_PROV,
    RMT_CMD_SW_UPDATE,
    RMT_CMD_ESIM_TEST,
  ];

  static final $core.List<RmtCmdList?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 12);
  static RmtCmdList? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtCmdList._(super.value, super.name);
}

/// Sub commands for LCD Test
class RmtSubCmdLcd extends $pb.ProtobufEnum {
  static const RmtSubCmdLcd RMT_SUB_CMD_LCD_NONE =
      RmtSubCmdLcd._(0, _omitEnumNames ? '' : 'RMT_SUB_CMD_LCD_NONE');
  static const RmtSubCmdLcd RMT_SUB_CMD_LCD_TEST_START =
      RmtSubCmdLcd._(1, _omitEnumNames ? '' : 'RMT_SUB_CMD_LCD_TEST_START');
  static const RmtSubCmdLcd RMT_SUB_CMD_LCD_TEST_STOP =
      RmtSubCmdLcd._(2, _omitEnumNames ? '' : 'RMT_SUB_CMD_LCD_TEST_STOP');

  static const $core.List<RmtSubCmdLcd> values = <RmtSubCmdLcd>[
    RMT_SUB_CMD_LCD_NONE,
    RMT_SUB_CMD_LCD_TEST_START,
    RMT_SUB_CMD_LCD_TEST_STOP,
  ];

  static final $core.List<RmtSubCmdLcd?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtSubCmdLcd? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtSubCmdLcd._(super.value, super.name);
}

/// Sub commands for GPS Test
class RmtSubCmdGps extends $pb.ProtobufEnum {
  static const RmtSubCmdGps RMT_SUB_CMD_GPS_NONE =
      RmtSubCmdGps._(0, _omitEnumNames ? '' : 'RMT_SUB_CMD_GPS_NONE');
  static const RmtSubCmdGps RMT_SUB_CMD_GPS_TEST_START =
      RmtSubCmdGps._(1, _omitEnumNames ? '' : 'RMT_SUB_CMD_GPS_TEST_START');
  static const RmtSubCmdGps RMT_SUB_CMD_GPS_TEST_STOP =
      RmtSubCmdGps._(2, _omitEnumNames ? '' : 'RMT_SUB_CMD_GPS_TEST_STOP');

  static const $core.List<RmtSubCmdGps> values = <RmtSubCmdGps>[
    RMT_SUB_CMD_GPS_NONE,
    RMT_SUB_CMD_GPS_TEST_START,
    RMT_SUB_CMD_GPS_TEST_STOP,
  ];

  static final $core.List<RmtSubCmdGps?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtSubCmdGps? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtSubCmdGps._(super.value, super.name);
}

/// Sub commands for Bluetooth Test
class RmtSubCmdBt extends $pb.ProtobufEnum {
  static const RmtSubCmdBt RMT_SUB_CMD_BT_NONE =
      RmtSubCmdBt._(0, _omitEnumNames ? '' : 'RMT_SUB_CMD_BT_NONE');
  static const RmtSubCmdBt RMT_SUB_CMD_BT_TEST_START =
      RmtSubCmdBt._(1, _omitEnumNames ? '' : 'RMT_SUB_CMD_BT_TEST_START');
  static const RmtSubCmdBt RMT_SUB_CMD_BT_TEST_STOP =
      RmtSubCmdBt._(2, _omitEnumNames ? '' : 'RMT_SUB_CMD_BT_TEST_STOP');

  static const $core.List<RmtSubCmdBt> values = <RmtSubCmdBt>[
    RMT_SUB_CMD_BT_NONE,
    RMT_SUB_CMD_BT_TEST_START,
    RMT_SUB_CMD_BT_TEST_STOP,
  ];

  static final $core.List<RmtSubCmdBt?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtSubCmdBt? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtSubCmdBt._(super.value, super.name);
}

/// Sub commands for BLE Test
class RmtSubCmdBle extends $pb.ProtobufEnum {
  static const RmtSubCmdBle RMT_SUB_CMD_BLE_NONE =
      RmtSubCmdBle._(0, _omitEnumNames ? '' : 'RMT_SUB_CMD_BLE_NONE');
  static const RmtSubCmdBle RMT_SUB_CMD_BLE_TEST_START =
      RmtSubCmdBle._(1, _omitEnumNames ? '' : 'RMT_SUB_CMD_BLE_TEST_START');
  static const RmtSubCmdBle RMT_SUB_CMD_BLE_TEST_STOP =
      RmtSubCmdBle._(2, _omitEnumNames ? '' : 'RMT_SUB_CMD_BLE_TEST_STOP');

  static const $core.List<RmtSubCmdBle> values = <RmtSubCmdBle>[
    RMT_SUB_CMD_BLE_NONE,
    RMT_SUB_CMD_BLE_TEST_START,
    RMT_SUB_CMD_BLE_TEST_STOP,
  ];

  static final $core.List<RmtSubCmdBle?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtSubCmdBle? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtSubCmdBle._(super.value, super.name);
}

/// Sub commands for WiFi Test
class RmtSubCmdWifi extends $pb.ProtobufEnum {
  static const RmtSubCmdWifi RMT_SUB_CMD_WIFI_NONE =
      RmtSubCmdWifi._(0, _omitEnumNames ? '' : 'RMT_SUB_CMD_WIFI_NONE');
  static const RmtSubCmdWifi RMT_SUB_CMD_WIFI_TEST_START =
      RmtSubCmdWifi._(1, _omitEnumNames ? '' : 'RMT_SUB_CMD_WIFI_TEST_START');
  static const RmtSubCmdWifi RMT_SUB_CMD_WIFI_TEST_STOP =
      RmtSubCmdWifi._(2, _omitEnumNames ? '' : 'RMT_SUB_CMD_WIFI_TEST_STOP');

  static const $core.List<RmtSubCmdWifi> values = <RmtSubCmdWifi>[
    RMT_SUB_CMD_WIFI_NONE,
    RMT_SUB_CMD_WIFI_TEST_START,
    RMT_SUB_CMD_WIFI_TEST_STOP,
  ];

  static final $core.List<RmtSubCmdWifi?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtSubCmdWifi? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtSubCmdWifi._(super.value, super.name);
}

/// Sub commands for Speaker Test
class RmtSubCmdSpkr extends $pb.ProtobufEnum {
  static const RmtSubCmdSpkr RMT_SUB_CMD_SPKR_NONE =
      RmtSubCmdSpkr._(0, _omitEnumNames ? '' : 'RMT_SUB_CMD_SPKR_NONE');
  static const RmtSubCmdSpkr RMT_SUB_CMD_SPKR_TEST_START =
      RmtSubCmdSpkr._(1, _omitEnumNames ? '' : 'RMT_SUB_CMD_SPKR_TEST_START');
  static const RmtSubCmdSpkr RMT_SUB_CMD_SPRK_TEST_STOP =
      RmtSubCmdSpkr._(2, _omitEnumNames ? '' : 'RMT_SUB_CMD_SPRK_TEST_STOP');

  static const $core.List<RmtSubCmdSpkr> values = <RmtSubCmdSpkr>[
    RMT_SUB_CMD_SPKR_NONE,
    RMT_SUB_CMD_SPKR_TEST_START,
    RMT_SUB_CMD_SPRK_TEST_STOP,
  ];

  static final $core.List<RmtSubCmdSpkr?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtSubCmdSpkr? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtSubCmdSpkr._(super.value, super.name);
}

/// Sub commands for Mic Test
class RmtSubCmdMic extends $pb.ProtobufEnum {
  static const RmtSubCmdMic RMT_SUB_CMD_MIC_NONE =
      RmtSubCmdMic._(0, _omitEnumNames ? '' : 'RMT_SUB_CMD_MIC_NONE');
  static const RmtSubCmdMic RMT_SUB_CMD_MIC_TEST_START =
      RmtSubCmdMic._(1, _omitEnumNames ? '' : 'RMT_SUB_CMD_MIC_TEST_START');
  static const RmtSubCmdMic RMT_SUB_CMD_MIC_TEST_STOP =
      RmtSubCmdMic._(2, _omitEnumNames ? '' : 'RMT_SUB_CMD_MIC_TEST_STOP');

  static const $core.List<RmtSubCmdMic> values = <RmtSubCmdMic>[
    RMT_SUB_CMD_MIC_NONE,
    RMT_SUB_CMD_MIC_TEST_START,
    RMT_SUB_CMD_MIC_TEST_STOP,
  ];

  static final $core.List<RmtSubCmdMic?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtSubCmdMic? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtSubCmdMic._(super.value, super.name);
}

/// Sub commands for MCU Calibration
class RmtSubCmdMcuCal extends $pb.ProtobufEnum {
  static const RmtSubCmdMcuCal RMT_SUB_CMD_MCU_NONE =
      RmtSubCmdMcuCal._(0, _omitEnumNames ? '' : 'RMT_SUB_CMD_MCU_NONE');
  static const RmtSubCmdMcuCal RMT_SUB_CMD_MCU_CAL_START =
      RmtSubCmdMcuCal._(1, _omitEnumNames ? '' : 'RMT_SUB_CMD_MCU_CAL_START');
  static const RmtSubCmdMcuCal RMT_SUB_CMD_MCU_CAL_STOP =
      RmtSubCmdMcuCal._(2, _omitEnumNames ? '' : 'RMT_SUB_CMD_MCU_CAL_STOP');

  static const $core.List<RmtSubCmdMcuCal> values = <RmtSubCmdMcuCal>[
    RMT_SUB_CMD_MCU_NONE,
    RMT_SUB_CMD_MCU_CAL_START,
    RMT_SUB_CMD_MCU_CAL_STOP,
  ];

  static final $core.List<RmtSubCmdMcuCal?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtSubCmdMcuCal? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtSubCmdMcuCal._(super.value, super.name);
}

/// Sub commands for VIN number
class RmtSubCmdVin extends $pb.ProtobufEnum {
  static const RmtSubCmdVin RMT_SUB_CMD_VIN_NONE =
      RmtSubCmdVin._(0, _omitEnumNames ? '' : 'RMT_SUB_CMD_VIN_NONE');
  static const RmtSubCmdVin RMT_SUB_CMD_VIN_GET =
      RmtSubCmdVin._(1, _omitEnumNames ? '' : 'RMT_SUB_CMD_VIN_GET');
  static const RmtSubCmdVin RMT_SUB_CMD_VIN_SET =
      RmtSubCmdVin._(2, _omitEnumNames ? '' : 'RMT_SUB_CMD_VIN_SET');

  static const $core.List<RmtSubCmdVin> values = <RmtSubCmdVin>[
    RMT_SUB_CMD_VIN_NONE,
    RMT_SUB_CMD_VIN_GET,
    RMT_SUB_CMD_VIN_SET,
  ];

  static final $core.List<RmtSubCmdVin?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtSubCmdVin? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtSubCmdVin._(super.value, super.name);
}

/// Sub commands for Certificate Provisioning
class RmtSubCmdProv extends $pb.ProtobufEnum {
  static const RmtSubCmdProv RMT_SUB_CMD_PROV_NONE =
      RmtSubCmdProv._(0, _omitEnumNames ? '' : 'RMT_SUB_CMD_PROV_NONE');
  static const RmtSubCmdProv RMT_SUB_CMD_PROV_START =
      RmtSubCmdProv._(1, _omitEnumNames ? '' : 'RMT_SUB_CMD_PROV_START');
  static const RmtSubCmdProv RMT_SUB_CMD_PROV_STOP =
      RmtSubCmdProv._(2, _omitEnumNames ? '' : 'RMT_SUB_CMD_PROV_STOP');

  static const $core.List<RmtSubCmdProv> values = <RmtSubCmdProv>[
    RMT_SUB_CMD_PROV_NONE,
    RMT_SUB_CMD_PROV_START,
    RMT_SUB_CMD_PROV_STOP,
  ];

  static final $core.List<RmtSubCmdProv?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtSubCmdProv? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtSubCmdProv._(super.value, super.name);
}

/// Sub commands for software update
class RmtSubCmdSwUpdate extends $pb.ProtobufEnum {
  static const RmtSubCmdSwUpdate RMT_SUB_CMD_SW_UPDATE_NONE =
      RmtSubCmdSwUpdate._(
          0, _omitEnumNames ? '' : 'RMT_SUB_CMD_SW_UPDATE_NONE');
  static const RmtSubCmdSwUpdate RMT_SUB_CMD_SW_UPDATE_START =
      RmtSubCmdSwUpdate._(
          1, _omitEnumNames ? '' : 'RMT_SUB_CMD_SW_UPDATE_START');
  static const RmtSubCmdSwUpdate RMT_SUB_CMD_SW_UPDATE_STOP =
      RmtSubCmdSwUpdate._(
          2, _omitEnumNames ? '' : 'RMT_SUB_CMD_SW_UPDATE_STOP');

  static const $core.List<RmtSubCmdSwUpdate> values = <RmtSubCmdSwUpdate>[
    RMT_SUB_CMD_SW_UPDATE_NONE,
    RMT_SUB_CMD_SW_UPDATE_START,
    RMT_SUB_CMD_SW_UPDATE_STOP,
  ];

  static final $core.List<RmtSubCmdSwUpdate?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtSubCmdSwUpdate? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtSubCmdSwUpdate._(super.value, super.name);
}

/// Sub commands for ESIM Test
class RmtSubCmdEsim extends $pb.ProtobufEnum {
  static const RmtSubCmdEsim RMT_SUB_CMD_ESIM_NONE =
      RmtSubCmdEsim._(0, _omitEnumNames ? '' : 'RMT_SUB_CMD_ESIM_NONE');
  static const RmtSubCmdEsim RMT_SUB_CMD_ESIM_TEST_START =
      RmtSubCmdEsim._(1, _omitEnumNames ? '' : 'RMT_SUB_CMD_ESIM_TEST_START');
  static const RmtSubCmdEsim RMT_SUB_CMD_ESIM_TEST_STOP =
      RmtSubCmdEsim._(2, _omitEnumNames ? '' : 'RMT_SUB_CMD_ESIM_TEST_STOP');

  static const $core.List<RmtSubCmdEsim> values = <RmtSubCmdEsim>[
    RMT_SUB_CMD_ESIM_NONE,
    RMT_SUB_CMD_ESIM_TEST_START,
    RMT_SUB_CMD_ESIM_TEST_STOP,
  ];

  static final $core.List<RmtSubCmdEsim?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtSubCmdEsim? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtSubCmdEsim._(super.value, super.name);
}

/// Response status
class RmtCmdRespStatus extends $pb.ProtobufEnum {
  static const RmtCmdRespStatus RMT_CMD_RESP_NONE =
      RmtCmdRespStatus._(0, _omitEnumNames ? '' : 'RMT_CMD_RESP_NONE');
  static const RmtCmdRespStatus RMT_CMD_RESP_SUCCESS =
      RmtCmdRespStatus._(1, _omitEnumNames ? '' : 'RMT_CMD_RESP_SUCCESS');
  static const RmtCmdRespStatus RMT_CMD_RESP_FAIL =
      RmtCmdRespStatus._(2, _omitEnumNames ? '' : 'RMT_CMD_RESP_FAIL');

  static const $core.List<RmtCmdRespStatus> values = <RmtCmdRespStatus>[
    RMT_CMD_RESP_NONE,
    RMT_CMD_RESP_SUCCESS,
    RMT_CMD_RESP_FAIL,
  ];

  static final $core.List<RmtCmdRespStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RmtCmdRespStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RmtCmdRespStatus._(super.value, super.name);
}

/// Vehicle operation mode endpoints ----- START -----
class VehicleOperationState extends $pb.ProtobufEnum {
  static const VehicleOperationState VEHICLE_OP_STATE_NONE =
      VehicleOperationState._(0, _omitEnumNames ? '' : 'VEHICLE_OP_STATE_NONE');
  static const VehicleOperationState VEHICLE_OP_STATE_MFG =
      VehicleOperationState._(1, _omitEnumNames ? '' : 'VEHICLE_OP_STATE_MFG');
  static const VehicleOperationState VEHICLE_OP_STATE_CUST =
      VehicleOperationState._(2, _omitEnumNames ? '' : 'VEHICLE_OP_STATE_CUST');
  static const VehicleOperationState VEHICLE_OP_STATE_SERVICE =
      VehicleOperationState._(
          3, _omitEnumNames ? '' : 'VEHICLE_OP_STATE_SERVICE');
  static const VehicleOperationState VEHICLE_OP_STATE_DECOMMISSIONED =
      VehicleOperationState._(
          4, _omitEnumNames ? '' : 'VEHICLE_OP_STATE_DECOMMISSIONED');

  static const $core.List<VehicleOperationState> values =
      <VehicleOperationState>[
    VEHICLE_OP_STATE_NONE,
    VEHICLE_OP_STATE_MFG,
    VEHICLE_OP_STATE_CUST,
    VEHICLE_OP_STATE_SERVICE,
    VEHICLE_OP_STATE_DECOMMISSIONED,
  ];

  static final $core.List<VehicleOperationState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static VehicleOperationState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const VehicleOperationState._(super.value, super.name);
}

/// Software update system upgrade
class SwUpdateState extends $pb.ProtobufEnum {
  static const SwUpdateState SW_UPDATE_STATE_NONE =
      SwUpdateState._(0, _omitEnumNames ? '' : 'SW_UPDATE_STATE_NONE');
  static const SwUpdateState SW_UPDATE_STATE_IDLE =
      SwUpdateState._(1, _omitEnumNames ? '' : 'SW_UPDATE_STATE_IDLE');
  static const SwUpdateState SW_UPDATE_STATE_UPLOAD_INITIALIZED =
      SwUpdateState._(
          2, _omitEnumNames ? '' : 'SW_UPDATE_STATE_UPLOAD_INITIALIZED');
  static const SwUpdateState SW_UPDATE_STATE_UPLOAD_IN_PROGRESS =
      SwUpdateState._(
          3, _omitEnumNames ? '' : 'SW_UPDATE_STATE_UPLOAD_IN_PROGRESS');
  static const SwUpdateState SW_UPDATE_STATE_UPLOAD_SUCCESS = SwUpdateState._(
      4, _omitEnumNames ? '' : 'SW_UPDATE_STATE_UPLOAD_SUCCESS');
  static const SwUpdateState SW_UPDATE_STATE_UPLOAD_FAILED =
      SwUpdateState._(5, _omitEnumNames ? '' : 'SW_UPDATE_STATE_UPLOAD_FAILED');
  static const SwUpdateState SW_UPDATE_STATE_INSTALLING_SYSTEM =
      SwUpdateState._(
          6, _omitEnumNames ? '' : 'SW_UPDATE_STATE_INSTALLING_SYSTEM');
  static const SwUpdateState SW_UPDATE_STATE_INSTALLING_BCM = SwUpdateState._(
      7, _omitEnumNames ? '' : 'SW_UPDATE_STATE_INSTALLING_BCM');
  static const SwUpdateState SW_UPDATE_STATE_INSTALLING_BMS = SwUpdateState._(
      8, _omitEnumNames ? '' : 'SW_UPDATE_STATE_INSTALLING_BMS');
  static const SwUpdateState SW_UPDATE_STATE_INSTALLING_BLE = SwUpdateState._(
      9, _omitEnumNames ? '' : 'SW_UPDATE_STATE_INSTALLING_BLE');
  static const SwUpdateState SW_UPDATE_STATE_INSTALLING_MCU = SwUpdateState._(
      10, _omitEnumNames ? '' : 'SW_UPDATE_STATE_INSTALLING_MCU');
  static const SwUpdateState SW_UPDATE_STATE_INSTALLING_AOSP = SwUpdateState._(
      11, _omitEnumNames ? '' : 'SW_UPDATE_STATE_INSTALLING_AOSP');
  static const SwUpdateState SW_UPDATE_STATE_REBOOTING =
      SwUpdateState._(12, _omitEnumNames ? '' : 'SW_UPDATE_STATE_REBOOTING');
  static const SwUpdateState SW_UPDATE_STATE_SUCCESS =
      SwUpdateState._(13, _omitEnumNames ? '' : 'SW_UPDATE_STATE_SUCCESS');
  static const SwUpdateState SW_UPDATE_STATE_FAILED =
      SwUpdateState._(14, _omitEnumNames ? '' : 'SW_UPDATE_STATE_FAILED');

  static const $core.List<SwUpdateState> values = <SwUpdateState>[
    SW_UPDATE_STATE_NONE,
    SW_UPDATE_STATE_IDLE,
    SW_UPDATE_STATE_UPLOAD_INITIALIZED,
    SW_UPDATE_STATE_UPLOAD_IN_PROGRESS,
    SW_UPDATE_STATE_UPLOAD_SUCCESS,
    SW_UPDATE_STATE_UPLOAD_FAILED,
    SW_UPDATE_STATE_INSTALLING_SYSTEM,
    SW_UPDATE_STATE_INSTALLING_BCM,
    SW_UPDATE_STATE_INSTALLING_BMS,
    SW_UPDATE_STATE_INSTALLING_BLE,
    SW_UPDATE_STATE_INSTALLING_MCU,
    SW_UPDATE_STATE_INSTALLING_AOSP,
    SW_UPDATE_STATE_REBOOTING,
    SW_UPDATE_STATE_SUCCESS,
    SW_UPDATE_STATE_FAILED,
  ];

  static final $core.List<SwUpdateState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 14);
  static SwUpdateState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SwUpdateState._(super.value, super.name);
}

class SwUpdateTrigger extends $pb.ProtobufEnum {
  static const SwUpdateTrigger SW_UPDATE_TRIGGER_NONE =
      SwUpdateTrigger._(0, _omitEnumNames ? '' : 'SW_UPDATE_TRIGGER_NONE');
  static const SwUpdateTrigger SW_UPDATE_TRIGGER_ALL =
      SwUpdateTrigger._(1, _omitEnumNames ? '' : 'SW_UPDATE_TRIGGER_ALL');
  static const SwUpdateTrigger SW_UPDATE_TRIGGER_BCM =
      SwUpdateTrigger._(2, _omitEnumNames ? '' : 'SW_UPDATE_TRIGGER_BCM');
  static const SwUpdateTrigger SW_UPDATE_TRIGGER_BMS =
      SwUpdateTrigger._(3, _omitEnumNames ? '' : 'SW_UPDATE_TRIGGER_BMS');
  static const SwUpdateTrigger SW_UPDATE_TRIGGER_BLE =
      SwUpdateTrigger._(4, _omitEnumNames ? '' : 'SW_UPDATE_TRIGGER_BLE');
  static const SwUpdateTrigger SW_UPDATE_TRIGGER_MCU =
      SwUpdateTrigger._(5, _omitEnumNames ? '' : 'SW_UPDATE_TRIGGER_MCU');
  static const SwUpdateTrigger SW_UPDATE_TRIGGER_AOSP =
      SwUpdateTrigger._(6, _omitEnumNames ? '' : 'SW_UPDATE_TRIGGER_AOSP');
  static const SwUpdateTrigger SW_UPDATE_TRIGGER_HU =
      SwUpdateTrigger._(7, _omitEnumNames ? '' : 'SW_UPDATE_TRIGGER_HU');

  static const $core.List<SwUpdateTrigger> values = <SwUpdateTrigger>[
    SW_UPDATE_TRIGGER_NONE,
    SW_UPDATE_TRIGGER_ALL,
    SW_UPDATE_TRIGGER_BCM,
    SW_UPDATE_TRIGGER_BMS,
    SW_UPDATE_TRIGGER_BLE,
    SW_UPDATE_TRIGGER_MCU,
    SW_UPDATE_TRIGGER_AOSP,
    SW_UPDATE_TRIGGER_HU,
  ];

  static final $core.List<SwUpdateTrigger?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static SwUpdateTrigger? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SwUpdateTrigger._(super.value, super.name);
}

class SystemCmdList extends $pb.ProtobufEnum {
  static const SystemCmdList SYS_CMD_NONE =
      SystemCmdList._(0, _omitEnumNames ? '' : 'SYS_CMD_NONE');
  static const SystemCmdList SYS_CMD_SOM =
      SystemCmdList._(1, _omitEnumNames ? '' : 'SYS_CMD_SOM');

  static const $core.List<SystemCmdList> values = <SystemCmdList>[
    SYS_CMD_NONE,
    SYS_CMD_SOM,
  ];

  static final $core.List<SystemCmdList?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static SystemCmdList? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SystemCmdList._(super.value, super.name);
}

class ConfigUpdateStatus extends $pb.ProtobufEnum {
  static const ConfigUpdateStatus CONFIG_UPDATE_INPROGRESS =
      ConfigUpdateStatus._(0, _omitEnumNames ? '' : 'CONFIG_UPDATE_INPROGRESS');
  static const ConfigUpdateStatus CONFIG_UPDATE_SUCCESS =
      ConfigUpdateStatus._(1, _omitEnumNames ? '' : 'CONFIG_UPDATE_SUCCESS');
  static const ConfigUpdateStatus CONFIG_UPDATE_FAILURE =
      ConfigUpdateStatus._(2, _omitEnumNames ? '' : 'CONFIG_UPDATE_FAILURE');

  static const $core.List<ConfigUpdateStatus> values = <ConfigUpdateStatus>[
    CONFIG_UPDATE_INPROGRESS,
    CONFIG_UPDATE_SUCCESS,
    CONFIG_UPDATE_FAILURE,
  ];

  static final $core.List<ConfigUpdateStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ConfigUpdateStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ConfigUpdateStatus._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
