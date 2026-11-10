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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'wifican.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'wifican.pbenum.dart';

/// Register message with request for subscribing to list of required CAN IDs
class Register extends $pb.GeneratedMessage {
  factory Register({
    $core.Iterable<$core.int>? canIds,
  }) {
    final result = Register._();
    if (canIds != null) result.canIds.addAll(canIds);
    return result;
  }

  Register._();

  factory Register.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Register()..mergeFromBuffer(data, registry);
  factory Register.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Register()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Register',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: Register.$_createMessage)
    ..p<$core.int>(1, _omitFieldNames ? '' : 'canIds', $pb.PbFieldType.KU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Register clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Register copyWith(void Function(Register) updates) =>
      super.copyWith((message) => updates(message as Register)) as Register;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Register() / Register.new instead')
  static Register create() => Register._();
  static $pb.GeneratedMessage $_createMessage() => Register._();
  @$core.override
  Register createEmptyInstance() => Register._();
  @$core.pragma('dart2js:noInline')
  static Register getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Register>(Register.$_createMessage);
  static Register? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.int> get canIds => $_getList(0);
}

/// Generic response message
class Response extends $pb.GeneratedMessage {
  factory Response({
    RespStatus? status,
    $core.String? statusMsg,
  }) {
    final result = Response._();
    if (status != null) result.status = status;
    if (statusMsg != null) result.statusMsg = statusMsg;
    return result;
  }

  Response._();

  factory Response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Response()..mergeFromBuffer(data, registry);
  factory Response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Response()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: Response.$_createMessage)
    ..aE<RespStatus>(1, _omitFieldNames ? '' : 'status',
        enumValues: RespStatus.values)
    ..aOS(2, _omitFieldNames ? '' : 'statusMsg')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Response copyWith(void Function(Response) updates) =>
      super.copyWith((message) => updates(message as Response)) as Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Response() / Response.new instead')
  static Response create() => Response._();
  static $pb.GeneratedMessage $_createMessage() => Response._();
  @$core.override
  Response createEmptyInstance() => Response._();
  @$core.pragma('dart2js:noInline')
  static Response getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Response>(Response.$_createMessage);
  static Response? _defaultInstance;

  @$pb.TagNumber(1)
  RespStatus get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(RespStatus value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get statusMsg => $_getSZ(1);
  @$pb.TagNumber(2)
  set statusMsg($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatusMsg() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatusMsg() => $_clearField(2);
}

/// CAN packet with raw CAN frame data
class CANPacket extends $pb.GeneratedMessage {
  factory CANPacket({
    $core.List<$core.int>? canFrame,
  }) {
    final result = CANPacket._();
    if (canFrame != null) result.canFrame = canFrame;
    return result;
  }

  CANPacket._();

  factory CANPacket.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CANPacket()..mergeFromBuffer(data, registry);
  factory CANPacket.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CANPacket()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CANPacket',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: CANPacket.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'canFrame', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CANPacket clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CANPacket copyWith(void Function(CANPacket) updates) =>
      super.copyWith((message) => updates(message as CANPacket)) as CANPacket;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CANPacket() / CANPacket.new instead')
  static CANPacket create() => CANPacket._();
  static $pb.GeneratedMessage $_createMessage() => CANPacket._();
  @$core.override
  CANPacket createEmptyInstance() => CANPacket._();
  @$core.pragma('dart2js:noInline')
  static CANPacket getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CANPacket>(CANPacket.$_createMessage);
  static CANPacket? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get canFrame => $_getN(0);
  @$pb.TagNumber(1)
  set canFrame($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCanFrame() => $_has(0);
  @$pb.TagNumber(1)
  void clearCanFrame() => $_clearField(1);
}

/// Request message from remote client to local client
class RmtCmdReq extends $pb.GeneratedMessage {
  factory RmtCmdReq({
    RmtCmdList? cmdId,
    RmtSubCmdLcd? subCmdLcd,
    RmtSubCmdGps? subCmdGps,
    RmtSubCmdBt? subCmdBt,
    RmtSubCmdBle? subCmdBle,
    RmtSubCmdWifi? subCmdWifi,
    RmtSubCmdSpkr? subCmdSpkr,
    RmtSubCmdMic? subCmdMic,
    RmtSubCmdMcuCal? subCmdMcuCal,
    RmtSubCmdVin? subCmdVin,
    RmtSubCmdProv? subCmdProv,
    RmtSubCmdSwUpdate? subCmdSwUpdate,
    $core.String? cmdInputStr,
    $core.List<$core.int>? cmdInputBytes,
    RmtSubCmdEsim? subCmdEsim,
  }) {
    final result = RmtCmdReq._();
    if (cmdId != null) result.cmdId = cmdId;
    if (subCmdLcd != null) result.subCmdLcd = subCmdLcd;
    if (subCmdGps != null) result.subCmdGps = subCmdGps;
    if (subCmdBt != null) result.subCmdBt = subCmdBt;
    if (subCmdBle != null) result.subCmdBle = subCmdBle;
    if (subCmdWifi != null) result.subCmdWifi = subCmdWifi;
    if (subCmdSpkr != null) result.subCmdSpkr = subCmdSpkr;
    if (subCmdMic != null) result.subCmdMic = subCmdMic;
    if (subCmdMcuCal != null) result.subCmdMcuCal = subCmdMcuCal;
    if (subCmdVin != null) result.subCmdVin = subCmdVin;
    if (subCmdProv != null) result.subCmdProv = subCmdProv;
    if (subCmdSwUpdate != null) result.subCmdSwUpdate = subCmdSwUpdate;
    if (cmdInputStr != null) result.cmdInputStr = cmdInputStr;
    if (cmdInputBytes != null) result.cmdInputBytes = cmdInputBytes;
    if (subCmdEsim != null) result.subCmdEsim = subCmdEsim;
    return result;
  }

  RmtCmdReq._();

  factory RmtCmdReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RmtCmdReq()..mergeFromBuffer(data, registry);
  factory RmtCmdReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RmtCmdReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RmtCmdReq',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: RmtCmdReq.$_createMessage)
    ..aE<RmtCmdList>(1, _omitFieldNames ? '' : 'cmdId',
        enumValues: RmtCmdList.values)
    ..aE<RmtSubCmdLcd>(2, _omitFieldNames ? '' : 'subCmdLcd',
        enumValues: RmtSubCmdLcd.values)
    ..aE<RmtSubCmdGps>(3, _omitFieldNames ? '' : 'subCmdGps',
        enumValues: RmtSubCmdGps.values)
    ..aE<RmtSubCmdBt>(4, _omitFieldNames ? '' : 'subCmdBt',
        enumValues: RmtSubCmdBt.values)
    ..aE<RmtSubCmdBle>(5, _omitFieldNames ? '' : 'subCmdBle',
        enumValues: RmtSubCmdBle.values)
    ..aE<RmtSubCmdWifi>(6, _omitFieldNames ? '' : 'subCmdWifi',
        enumValues: RmtSubCmdWifi.values)
    ..aE<RmtSubCmdSpkr>(7, _omitFieldNames ? '' : 'subCmdSpkr',
        enumValues: RmtSubCmdSpkr.values)
    ..aE<RmtSubCmdMic>(8, _omitFieldNames ? '' : 'subCmdMic',
        enumValues: RmtSubCmdMic.values)
    ..aE<RmtSubCmdMcuCal>(9, _omitFieldNames ? '' : 'subCmdMcuCal',
        enumValues: RmtSubCmdMcuCal.values)
    ..aE<RmtSubCmdVin>(10, _omitFieldNames ? '' : 'subCmdVin',
        enumValues: RmtSubCmdVin.values)
    ..aE<RmtSubCmdProv>(11, _omitFieldNames ? '' : 'subCmdProv',
        enumValues: RmtSubCmdProv.values)
    ..aE<RmtSubCmdSwUpdate>(12, _omitFieldNames ? '' : 'subCmdSwUpdate',
        enumValues: RmtSubCmdSwUpdate.values)
    ..aOS(13, _omitFieldNames ? '' : 'cmdInputStr')
    ..a<$core.List<$core.int>>(
        14, _omitFieldNames ? '' : 'cmdInputBytes', $pb.PbFieldType.OY)
    ..aE<RmtSubCmdEsim>(15, _omitFieldNames ? '' : 'subCmdEsim',
        enumValues: RmtSubCmdEsim.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RmtCmdReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RmtCmdReq copyWith(void Function(RmtCmdReq) updates) =>
      super.copyWith((message) => updates(message as RmtCmdReq)) as RmtCmdReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RmtCmdReq() / RmtCmdReq.new instead')
  static RmtCmdReq create() => RmtCmdReq._();
  static $pb.GeneratedMessage $_createMessage() => RmtCmdReq._();
  @$core.override
  RmtCmdReq createEmptyInstance() => RmtCmdReq._();
  @$core.pragma('dart2js:noInline')
  static RmtCmdReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RmtCmdReq>(RmtCmdReq.$_createMessage);
  static RmtCmdReq? _defaultInstance;

  @$pb.TagNumber(1)
  RmtCmdList get cmdId => $_getN(0);
  @$pb.TagNumber(1)
  set cmdId(RmtCmdList value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);

  @$pb.TagNumber(2)
  RmtSubCmdLcd get subCmdLcd => $_getN(1);
  @$pb.TagNumber(2)
  set subCmdLcd(RmtSubCmdLcd value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSubCmdLcd() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubCmdLcd() => $_clearField(2);

  @$pb.TagNumber(3)
  RmtSubCmdGps get subCmdGps => $_getN(2);
  @$pb.TagNumber(3)
  set subCmdGps(RmtSubCmdGps value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSubCmdGps() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubCmdGps() => $_clearField(3);

  @$pb.TagNumber(4)
  RmtSubCmdBt get subCmdBt => $_getN(3);
  @$pb.TagNumber(4)
  set subCmdBt(RmtSubCmdBt value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasSubCmdBt() => $_has(3);
  @$pb.TagNumber(4)
  void clearSubCmdBt() => $_clearField(4);

  @$pb.TagNumber(5)
  RmtSubCmdBle get subCmdBle => $_getN(4);
  @$pb.TagNumber(5)
  set subCmdBle(RmtSubCmdBle value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasSubCmdBle() => $_has(4);
  @$pb.TagNumber(5)
  void clearSubCmdBle() => $_clearField(5);

  @$pb.TagNumber(6)
  RmtSubCmdWifi get subCmdWifi => $_getN(5);
  @$pb.TagNumber(6)
  set subCmdWifi(RmtSubCmdWifi value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasSubCmdWifi() => $_has(5);
  @$pb.TagNumber(6)
  void clearSubCmdWifi() => $_clearField(6);

  @$pb.TagNumber(7)
  RmtSubCmdSpkr get subCmdSpkr => $_getN(6);
  @$pb.TagNumber(7)
  set subCmdSpkr(RmtSubCmdSpkr value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSubCmdSpkr() => $_has(6);
  @$pb.TagNumber(7)
  void clearSubCmdSpkr() => $_clearField(7);

  @$pb.TagNumber(8)
  RmtSubCmdMic get subCmdMic => $_getN(7);
  @$pb.TagNumber(8)
  set subCmdMic(RmtSubCmdMic value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasSubCmdMic() => $_has(7);
  @$pb.TagNumber(8)
  void clearSubCmdMic() => $_clearField(8);

  @$pb.TagNumber(9)
  RmtSubCmdMcuCal get subCmdMcuCal => $_getN(8);
  @$pb.TagNumber(9)
  set subCmdMcuCal(RmtSubCmdMcuCal value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSubCmdMcuCal() => $_has(8);
  @$pb.TagNumber(9)
  void clearSubCmdMcuCal() => $_clearField(9);

  @$pb.TagNumber(10)
  RmtSubCmdVin get subCmdVin => $_getN(9);
  @$pb.TagNumber(10)
  set subCmdVin(RmtSubCmdVin value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasSubCmdVin() => $_has(9);
  @$pb.TagNumber(10)
  void clearSubCmdVin() => $_clearField(10);

  @$pb.TagNumber(11)
  RmtSubCmdProv get subCmdProv => $_getN(10);
  @$pb.TagNumber(11)
  set subCmdProv(RmtSubCmdProv value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasSubCmdProv() => $_has(10);
  @$pb.TagNumber(11)
  void clearSubCmdProv() => $_clearField(11);

  @$pb.TagNumber(12)
  RmtSubCmdSwUpdate get subCmdSwUpdate => $_getN(11);
  @$pb.TagNumber(12)
  set subCmdSwUpdate(RmtSubCmdSwUpdate value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasSubCmdSwUpdate() => $_has(11);
  @$pb.TagNumber(12)
  void clearSubCmdSwUpdate() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get cmdInputStr => $_getSZ(12);
  @$pb.TagNumber(13)
  set cmdInputStr($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCmdInputStr() => $_has(12);
  @$pb.TagNumber(13)
  void clearCmdInputStr() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.List<$core.int> get cmdInputBytes => $_getN(13);
  @$pb.TagNumber(14)
  set cmdInputBytes($core.List<$core.int> value) => $_setBytes(13, value);
  @$pb.TagNumber(14)
  $core.bool hasCmdInputBytes() => $_has(13);
  @$pb.TagNumber(14)
  void clearCmdInputBytes() => $_clearField(14);

  @$pb.TagNumber(15)
  RmtSubCmdEsim get subCmdEsim => $_getN(14);
  @$pb.TagNumber(15)
  set subCmdEsim(RmtSubCmdEsim value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasSubCmdEsim() => $_has(14);
  @$pb.TagNumber(15)
  void clearSubCmdEsim() => $_clearField(15);
}

/// Respsonse message from local client to remote client
class RmtCmdResp extends $pb.GeneratedMessage {
  factory RmtCmdResp({
    RmtCmdList? cmdId,
    RmtCmdRespStatus? respStatus,
    $core.String? respStr,
    $core.List<$core.int>? respBytes,
  }) {
    final result = RmtCmdResp._();
    if (cmdId != null) result.cmdId = cmdId;
    if (respStatus != null) result.respStatus = respStatus;
    if (respStr != null) result.respStr = respStr;
    if (respBytes != null) result.respBytes = respBytes;
    return result;
  }

  RmtCmdResp._();

  factory RmtCmdResp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RmtCmdResp()..mergeFromBuffer(data, registry);
  factory RmtCmdResp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RmtCmdResp()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RmtCmdResp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: RmtCmdResp.$_createMessage)
    ..aE<RmtCmdList>(1, _omitFieldNames ? '' : 'cmdId',
        enumValues: RmtCmdList.values)
    ..aE<RmtCmdRespStatus>(2, _omitFieldNames ? '' : 'respStatus',
        enumValues: RmtCmdRespStatus.values)
    ..aOS(3, _omitFieldNames ? '' : 'respStr')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'respBytes', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RmtCmdResp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RmtCmdResp copyWith(void Function(RmtCmdResp) updates) =>
      super.copyWith((message) => updates(message as RmtCmdResp)) as RmtCmdResp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RmtCmdResp() / RmtCmdResp.new instead')
  static RmtCmdResp create() => RmtCmdResp._();
  static $pb.GeneratedMessage $_createMessage() => RmtCmdResp._();
  @$core.override
  RmtCmdResp createEmptyInstance() => RmtCmdResp._();
  @$core.pragma('dart2js:noInline')
  static RmtCmdResp getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RmtCmdResp>(RmtCmdResp.$_createMessage);
  static RmtCmdResp? _defaultInstance;

  @$pb.TagNumber(1)
  RmtCmdList get cmdId => $_getN(0);
  @$pb.TagNumber(1)
  set cmdId(RmtCmdList value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);

  @$pb.TagNumber(2)
  RmtCmdRespStatus get respStatus => $_getN(1);
  @$pb.TagNumber(2)
  set respStatus(RmtCmdRespStatus value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRespStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearRespStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get respStr => $_getSZ(2);
  @$pb.TagNumber(3)
  set respStr($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRespStr() => $_has(2);
  @$pb.TagNumber(3)
  void clearRespStr() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get respBytes => $_getN(3);
  @$pb.TagNumber(4)
  set respBytes($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRespBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearRespBytes() => $_clearField(4);
}

class NavigationConfig extends $pb.GeneratedMessage {
  factory NavigationConfig({
    $core.String? vinNumber,
  }) {
    final result = NavigationConfig._();
    if (vinNumber != null) result.vinNumber = vinNumber;
    return result;
  }

  NavigationConfig._();

  factory NavigationConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NavigationConfig()..mergeFromBuffer(data, registry);
  factory NavigationConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NavigationConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NavigationConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: NavigationConfig.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'VinNumber', protoName: 'VinNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NavigationConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NavigationConfig copyWith(void Function(NavigationConfig) updates) =>
      super.copyWith((message) => updates(message as NavigationConfig))
          as NavigationConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use NavigationConfig() / NavigationConfig.new instead')
  static NavigationConfig create() => NavigationConfig._();
  static $pb.GeneratedMessage $_createMessage() => NavigationConfig._();
  @$core.override
  NavigationConfig createEmptyInstance() => NavigationConfig._();
  @$core.pragma('dart2js:noInline')
  static NavigationConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NavigationConfig>(
          NavigationConfig.$_createMessage);
  static NavigationConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get vinNumber => $_getSZ(0);
  @$pb.TagNumber(1)
  set vinNumber($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVinNumber() => $_has(0);
  @$pb.TagNumber(1)
  void clearVinNumber() => $_clearField(1);
}

class Vin extends $pb.GeneratedMessage {
  factory Vin({
    $core.String? vinNumber,
  }) {
    final result = Vin._();
    if (vinNumber != null) result.vinNumber = vinNumber;
    return result;
  }

  Vin._();

  factory Vin.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Vin()..mergeFromBuffer(data, registry);
  factory Vin.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Vin()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Vin',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: Vin.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'VinNumber', protoName: 'VinNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Vin clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Vin copyWith(void Function(Vin) updates) =>
      super.copyWith((message) => updates(message as Vin)) as Vin;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Vin() / Vin.new instead')
  static Vin create() => Vin._();
  static $pb.GeneratedMessage $_createMessage() => Vin._();
  @$core.override
  Vin createEmptyInstance() => Vin._();
  @$core.pragma('dart2js:noInline')
  static Vin getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Vin>(Vin.$_createMessage);
  static Vin? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get vinNumber => $_getSZ(0);
  @$pb.TagNumber(1)
  set vinNumber($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVinNumber() => $_has(0);
  @$pb.TagNumber(1)
  void clearVinNumber() => $_clearField(1);
}

class VehicleIdentifiers extends $pb.GeneratedMessage {
  factory VehicleIdentifiers({
    $core.String? manifestJson,
  }) {
    final result = VehicleIdentifiers._();
    if (manifestJson != null) result.manifestJson = manifestJson;
    return result;
  }

  VehicleIdentifiers._();

  factory VehicleIdentifiers.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VehicleIdentifiers()..mergeFromBuffer(data, registry);
  factory VehicleIdentifiers.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VehicleIdentifiers()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VehicleIdentifiers',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: VehicleIdentifiers.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'manifestJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VehicleIdentifiers clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VehicleIdentifiers copyWith(void Function(VehicleIdentifiers) updates) =>
      super.copyWith((message) => updates(message as VehicleIdentifiers))
          as VehicleIdentifiers;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use VehicleIdentifiers() / VehicleIdentifiers.new instead')
  static VehicleIdentifiers create() => VehicleIdentifiers._();
  static $pb.GeneratedMessage $_createMessage() => VehicleIdentifiers._();
  @$core.override
  VehicleIdentifiers createEmptyInstance() => VehicleIdentifiers._();
  @$core.pragma('dart2js:noInline')
  static VehicleIdentifiers getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VehicleIdentifiers>(
          VehicleIdentifiers.$_createMessage);
  static VehicleIdentifiers? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get manifestJson => $_getSZ(0);
  @$pb.TagNumber(1)
  set manifestJson($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasManifestJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearManifestJson() => $_clearField(1);
}

class VehicleOperationMode extends $pb.GeneratedMessage {
  factory VehicleOperationMode({
    VehicleOperationState? curMode,
    $fixnum.Int64? modifiedTs,
    $core.String? modifiedTsStr,
    $core.String? modifiedBy,
  }) {
    final result = VehicleOperationMode._();
    if (curMode != null) result.curMode = curMode;
    if (modifiedTs != null) result.modifiedTs = modifiedTs;
    if (modifiedTsStr != null) result.modifiedTsStr = modifiedTsStr;
    if (modifiedBy != null) result.modifiedBy = modifiedBy;
    return result;
  }

  VehicleOperationMode._();

  factory VehicleOperationMode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VehicleOperationMode()..mergeFromBuffer(data, registry);
  factory VehicleOperationMode.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VehicleOperationMode()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VehicleOperationMode',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: VehicleOperationMode.$_createMessage)
    ..aE<VehicleOperationState>(1, _omitFieldNames ? '' : 'curMode',
        enumValues: VehicleOperationState.values)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'modifiedTs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(3, _omitFieldNames ? '' : 'modifiedTsStr')
    ..aOS(4, _omitFieldNames ? '' : 'modifiedBy')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VehicleOperationMode clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VehicleOperationMode copyWith(void Function(VehicleOperationMode) updates) =>
      super.copyWith((message) => updates(message as VehicleOperationMode))
          as VehicleOperationMode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use VehicleOperationMode() / VehicleOperationMode.new instead')
  static VehicleOperationMode create() => VehicleOperationMode._();
  static $pb.GeneratedMessage $_createMessage() => VehicleOperationMode._();
  @$core.override
  VehicleOperationMode createEmptyInstance() => VehicleOperationMode._();
  @$core.pragma('dart2js:noInline')
  static VehicleOperationMode getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VehicleOperationMode>(
          VehicleOperationMode.$_createMessage);
  static VehicleOperationMode? _defaultInstance;

  @$pb.TagNumber(1)
  VehicleOperationState get curMode => $_getN(0);
  @$pb.TagNumber(1)
  set curMode(VehicleOperationState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCurMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCurMode() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get modifiedTs => $_getI64(1);
  @$pb.TagNumber(2)
  set modifiedTs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModifiedTs() => $_has(1);
  @$pb.TagNumber(2)
  void clearModifiedTs() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get modifiedTsStr => $_getSZ(2);
  @$pb.TagNumber(3)
  set modifiedTsStr($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasModifiedTsStr() => $_has(2);
  @$pb.TagNumber(3)
  void clearModifiedTsStr() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get modifiedBy => $_getSZ(3);
  @$pb.TagNumber(4)
  set modifiedBy($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasModifiedBy() => $_has(3);
  @$pb.TagNumber(4)
  void clearModifiedBy() => $_clearField(4);
}

class SwUpdateStatus extends $pb.GeneratedMessage {
  factory SwUpdateStatus({
    SwUpdateState? status,
    $core.String? statusMsg,
  }) {
    final result = SwUpdateStatus._();
    if (status != null) result.status = status;
    if (statusMsg != null) result.statusMsg = statusMsg;
    return result;
  }

  SwUpdateStatus._();

  factory SwUpdateStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SwUpdateStatus()..mergeFromBuffer(data, registry);
  factory SwUpdateStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SwUpdateStatus()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SwUpdateStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: SwUpdateStatus.$_createMessage)
    ..aE<SwUpdateState>(1, _omitFieldNames ? '' : 'status',
        enumValues: SwUpdateState.values)
    ..aOS(2, _omitFieldNames ? '' : 'statusMsg')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SwUpdateStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SwUpdateStatus copyWith(void Function(SwUpdateStatus) updates) =>
      super.copyWith((message) => updates(message as SwUpdateStatus))
          as SwUpdateStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SwUpdateStatus() / SwUpdateStatus.new instead')
  static SwUpdateStatus create() => SwUpdateStatus._();
  static $pb.GeneratedMessage $_createMessage() => SwUpdateStatus._();
  @$core.override
  SwUpdateStatus createEmptyInstance() => SwUpdateStatus._();
  @$core.pragma('dart2js:noInline')
  static SwUpdateStatus getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SwUpdateStatus>(
          SwUpdateStatus.$_createMessage);
  static SwUpdateStatus? _defaultInstance;

  @$pb.TagNumber(1)
  SwUpdateState get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(SwUpdateState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get statusMsg => $_getSZ(1);
  @$pb.TagNumber(2)
  set statusMsg($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatusMsg() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatusMsg() => $_clearField(2);
}

class SwUpdateFileMetadataReq extends $pb.GeneratedMessage {
  factory SwUpdateFileMetadataReq({
    $core.String? name,
    $core.int? size,
    $core.String? csum,
  }) {
    final result = SwUpdateFileMetadataReq._();
    if (name != null) result.name = name;
    if (size != null) result.size = size;
    if (csum != null) result.csum = csum;
    return result;
  }

  SwUpdateFileMetadataReq._();

  factory SwUpdateFileMetadataReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SwUpdateFileMetadataReq()..mergeFromBuffer(data, registry);
  factory SwUpdateFileMetadataReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SwUpdateFileMetadataReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SwUpdateFileMetadataReq',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: SwUpdateFileMetadataReq.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aI(2, _omitFieldNames ? '' : 'size', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'csum')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SwUpdateFileMetadataReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SwUpdateFileMetadataReq copyWith(
          void Function(SwUpdateFileMetadataReq) updates) =>
      super.copyWith((message) => updates(message as SwUpdateFileMetadataReq))
          as SwUpdateFileMetadataReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SwUpdateFileMetadataReq() / SwUpdateFileMetadataReq.new instead')
  static SwUpdateFileMetadataReq create() => SwUpdateFileMetadataReq._();
  static $pb.GeneratedMessage $_createMessage() => SwUpdateFileMetadataReq._();
  @$core.override
  SwUpdateFileMetadataReq createEmptyInstance() => SwUpdateFileMetadataReq._();
  @$core.pragma('dart2js:noInline')
  static SwUpdateFileMetadataReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SwUpdateFileMetadataReq>(
          SwUpdateFileMetadataReq.$_createMessage);
  static SwUpdateFileMetadataReq? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get size => $_getIZ(1);
  @$pb.TagNumber(2)
  set size($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearSize() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get csum => $_getSZ(2);
  @$pb.TagNumber(3)
  set csum($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCsum() => $_has(2);
  @$pb.TagNumber(3)
  void clearCsum() => $_clearField(3);
}

class SwUpdateFileMetadataResp extends $pb.GeneratedMessage {
  factory SwUpdateFileMetadataResp({
    $core.String? name,
    $core.int? size,
    $core.String? csum,
    $core.String? transferStatus,
  }) {
    final result = SwUpdateFileMetadataResp._();
    if (name != null) result.name = name;
    if (size != null) result.size = size;
    if (csum != null) result.csum = csum;
    if (transferStatus != null) result.transferStatus = transferStatus;
    return result;
  }

  SwUpdateFileMetadataResp._();

  factory SwUpdateFileMetadataResp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SwUpdateFileMetadataResp()..mergeFromBuffer(data, registry);
  factory SwUpdateFileMetadataResp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SwUpdateFileMetadataResp()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SwUpdateFileMetadataResp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: SwUpdateFileMetadataResp.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aI(2, _omitFieldNames ? '' : 'size', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'csum')
    ..aOS(4, _omitFieldNames ? '' : 'transferStatus')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SwUpdateFileMetadataResp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SwUpdateFileMetadataResp copyWith(
          void Function(SwUpdateFileMetadataResp) updates) =>
      super.copyWith((message) => updates(message as SwUpdateFileMetadataResp))
          as SwUpdateFileMetadataResp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SwUpdateFileMetadataResp() / SwUpdateFileMetadataResp.new instead')
  static SwUpdateFileMetadataResp create() => SwUpdateFileMetadataResp._();
  static $pb.GeneratedMessage $_createMessage() => SwUpdateFileMetadataResp._();
  @$core.override
  SwUpdateFileMetadataResp createEmptyInstance() =>
      SwUpdateFileMetadataResp._();
  @$core.pragma('dart2js:noInline')
  static SwUpdateFileMetadataResp getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SwUpdateFileMetadataResp>(
          SwUpdateFileMetadataResp.$_createMessage);
  static SwUpdateFileMetadataResp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get size => $_getIZ(1);
  @$pb.TagNumber(2)
  set size($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearSize() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get csum => $_getSZ(2);
  @$pb.TagNumber(3)
  set csum($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCsum() => $_has(2);
  @$pb.TagNumber(3)
  void clearCsum() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get transferStatus => $_getSZ(3);
  @$pb.TagNumber(4)
  set transferStatus($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTransferStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearTransferStatus() => $_clearField(4);
}

class SwUpdateFileChunk extends $pb.GeneratedMessage {
  factory SwUpdateFileChunk({
    $core.List<$core.int>? chunk,
  }) {
    final result = SwUpdateFileChunk._();
    if (chunk != null) result.chunk = chunk;
    return result;
  }

  SwUpdateFileChunk._();

  factory SwUpdateFileChunk.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SwUpdateFileChunk()..mergeFromBuffer(data, registry);
  factory SwUpdateFileChunk.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SwUpdateFileChunk()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SwUpdateFileChunk',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: SwUpdateFileChunk.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'chunk', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SwUpdateFileChunk clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SwUpdateFileChunk copyWith(void Function(SwUpdateFileChunk) updates) =>
      super.copyWith((message) => updates(message as SwUpdateFileChunk))
          as SwUpdateFileChunk;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SwUpdateFileChunk() / SwUpdateFileChunk.new instead')
  static SwUpdateFileChunk create() => SwUpdateFileChunk._();
  static $pb.GeneratedMessage $_createMessage() => SwUpdateFileChunk._();
  @$core.override
  SwUpdateFileChunk createEmptyInstance() => SwUpdateFileChunk._();
  @$core.pragma('dart2js:noInline')
  static SwUpdateFileChunk getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SwUpdateFileChunk>(
          SwUpdateFileChunk.$_createMessage);
  static SwUpdateFileChunk? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get chunk => $_getN(0);
  @$pb.TagNumber(1)
  set chunk($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChunk() => $_has(0);
  @$pb.TagNumber(1)
  void clearChunk() => $_clearField(1);
}

class SwUpdateTriggerCmd extends $pb.GeneratedMessage {
  factory SwUpdateTriggerCmd({
    SwUpdateTrigger? trigger,
  }) {
    final result = SwUpdateTriggerCmd._();
    if (trigger != null) result.trigger = trigger;
    return result;
  }

  SwUpdateTriggerCmd._();

  factory SwUpdateTriggerCmd.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SwUpdateTriggerCmd()..mergeFromBuffer(data, registry);
  factory SwUpdateTriggerCmd.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SwUpdateTriggerCmd()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SwUpdateTriggerCmd',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: SwUpdateTriggerCmd.$_createMessage)
    ..aE<SwUpdateTrigger>(1, _omitFieldNames ? '' : 'trigger',
        enumValues: SwUpdateTrigger.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SwUpdateTriggerCmd clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SwUpdateTriggerCmd copyWith(void Function(SwUpdateTriggerCmd) updates) =>
      super.copyWith((message) => updates(message as SwUpdateTriggerCmd))
          as SwUpdateTriggerCmd;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SwUpdateTriggerCmd() / SwUpdateTriggerCmd.new instead')
  static SwUpdateTriggerCmd create() => SwUpdateTriggerCmd._();
  static $pb.GeneratedMessage $_createMessage() => SwUpdateTriggerCmd._();
  @$core.override
  SwUpdateTriggerCmd createEmptyInstance() => SwUpdateTriggerCmd._();
  @$core.pragma('dart2js:noInline')
  static SwUpdateTriggerCmd getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SwUpdateTriggerCmd>(
          SwUpdateTriggerCmd.$_createMessage);
  static SwUpdateTriggerCmd? _defaultInstance;

  @$pb.TagNumber(1)
  SwUpdateTrigger get trigger => $_getN(0);
  @$pb.TagNumber(1)
  set trigger(SwUpdateTrigger value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTrigger() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrigger() => $_clearField(1);
}

class SystemTestCmd extends $pb.GeneratedMessage {
  factory SystemTestCmd({
    SystemCmdList? cmdId,
    $core.String? respStr,
    $core.List<$core.int>? respBytes,
  }) {
    final result = SystemTestCmd._();
    if (cmdId != null) result.cmdId = cmdId;
    if (respStr != null) result.respStr = respStr;
    if (respBytes != null) result.respBytes = respBytes;
    return result;
  }

  SystemTestCmd._();

  factory SystemTestCmd.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SystemTestCmd()..mergeFromBuffer(data, registry);
  factory SystemTestCmd.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SystemTestCmd()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SystemTestCmd',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: SystemTestCmd.$_createMessage)
    ..aE<SystemCmdList>(1, _omitFieldNames ? '' : 'cmdId',
        enumValues: SystemCmdList.values)
    ..aOS(2, _omitFieldNames ? '' : 'respStr')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'respBytes', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SystemTestCmd clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SystemTestCmd copyWith(void Function(SystemTestCmd) updates) =>
      super.copyWith((message) => updates(message as SystemTestCmd))
          as SystemTestCmd;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SystemTestCmd() / SystemTestCmd.new instead')
  static SystemTestCmd create() => SystemTestCmd._();
  static $pb.GeneratedMessage $_createMessage() => SystemTestCmd._();
  @$core.override
  SystemTestCmd createEmptyInstance() => SystemTestCmd._();
  @$core.pragma('dart2js:noInline')
  static SystemTestCmd getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SystemTestCmd>(
          SystemTestCmd.$_createMessage);
  static SystemTestCmd? _defaultInstance;

  @$pb.TagNumber(1)
  SystemCmdList get cmdId => $_getN(0);
  @$pb.TagNumber(1)
  set cmdId(SystemCmdList value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get respStr => $_getSZ(1);
  @$pb.TagNumber(2)
  set respStr($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRespStr() => $_has(1);
  @$pb.TagNumber(2)
  void clearRespStr() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get respBytes => $_getN(2);
  @$pb.TagNumber(3)
  set respBytes($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRespBytes() => $_has(2);
  @$pb.TagNumber(3)
  void clearRespBytes() => $_clearField(3);
}

class SystemTestResp extends $pb.GeneratedMessage {
  factory SystemTestResp({
    SystemCmdList? cmdId,
    RmtCmdRespStatus? respStatus,
    $core.String? respStr,
    $core.List<$core.int>? respBytes,
  }) {
    final result = SystemTestResp._();
    if (cmdId != null) result.cmdId = cmdId;
    if (respStatus != null) result.respStatus = respStatus;
    if (respStr != null) result.respStr = respStr;
    if (respBytes != null) result.respBytes = respBytes;
    return result;
  }

  SystemTestResp._();

  factory SystemTestResp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SystemTestResp()..mergeFromBuffer(data, registry);
  factory SystemTestResp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SystemTestResp()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SystemTestResp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: SystemTestResp.$_createMessage)
    ..aE<SystemCmdList>(1, _omitFieldNames ? '' : 'cmdId',
        enumValues: SystemCmdList.values)
    ..aE<RmtCmdRespStatus>(2, _omitFieldNames ? '' : 'respStatus',
        enumValues: RmtCmdRespStatus.values)
    ..aOS(3, _omitFieldNames ? '' : 'respStr')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'respBytes', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SystemTestResp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SystemTestResp copyWith(void Function(SystemTestResp) updates) =>
      super.copyWith((message) => updates(message as SystemTestResp))
          as SystemTestResp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SystemTestResp() / SystemTestResp.new instead')
  static SystemTestResp create() => SystemTestResp._();
  static $pb.GeneratedMessage $_createMessage() => SystemTestResp._();
  @$core.override
  SystemTestResp createEmptyInstance() => SystemTestResp._();
  @$core.pragma('dart2js:noInline')
  static SystemTestResp getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SystemTestResp>(
          SystemTestResp.$_createMessage);
  static SystemTestResp? _defaultInstance;

  @$pb.TagNumber(1)
  SystemCmdList get cmdId => $_getN(0);
  @$pb.TagNumber(1)
  set cmdId(SystemCmdList value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdId() => $_clearField(1);

  @$pb.TagNumber(2)
  RmtCmdRespStatus get respStatus => $_getN(1);
  @$pb.TagNumber(2)
  set respStatus(RmtCmdRespStatus value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRespStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearRespStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get respStr => $_getSZ(2);
  @$pb.TagNumber(3)
  set respStr($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRespStr() => $_has(2);
  @$pb.TagNumber(3)
  void clearRespStr() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get respBytes => $_getN(3);
  @$pb.TagNumber(4)
  set respBytes($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRespBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearRespBytes() => $_clearField(4);
}

class Command extends $pb.GeneratedMessage {
  factory Command({
    $core.String? cmdMsg,
  }) {
    final result = Command._();
    if (cmdMsg != null) result.cmdMsg = cmdMsg;
    return result;
  }

  Command._();

  factory Command.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Command()..mergeFromBuffer(data, registry);
  factory Command.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Command()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Command',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: Command.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'cmdMsg')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Command clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Command copyWith(void Function(Command) updates) =>
      super.copyWith((message) => updates(message as Command)) as Command;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Command() / Command.new instead')
  static Command create() => Command._();
  static $pb.GeneratedMessage $_createMessage() => Command._();
  @$core.override
  Command createEmptyInstance() => Command._();
  @$core.pragma('dart2js:noInline')
  static Command getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Command>(Command.$_createMessage);
  static Command? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cmdMsg => $_getSZ(0);
  @$pb.TagNumber(1)
  set cmdMsg($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdMsg() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdMsg() => $_clearField(1);
}

class EcosDynoFlags extends $pb.GeneratedMessage {
  factory EcosDynoFlags({
    RespStatus? status,
    $core.String? ecos1,
    $core.String? ecos2,
    $core.String? dyno,
  }) {
    final result = EcosDynoFlags._();
    if (status != null) result.status = status;
    if (ecos1 != null) result.ecos1 = ecos1;
    if (ecos2 != null) result.ecos2 = ecos2;
    if (dyno != null) result.dyno = dyno;
    return result;
  }

  EcosDynoFlags._();
  factory EcosDynoFlags.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EcosDynoFlags()..mergeFromBuffer(data, registry);
  factory EcosDynoFlags.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EcosDynoFlags()..mergeFromJson(json, registry);
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EcosDynoFlags',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: EcosDynoFlags.$_createMessage)
    ..aE<RespStatus>(1, _omitFieldNames ? '' : 'status', enumValues: RespStatus.values)
    ..aOS(2, _omitFieldNames ? '' : 'ecos1')
    ..aOS(3, _omitFieldNames ? '' : 'ecos2')
    ..aOS(4, _omitFieldNames ? '' : 'dyno')
    ..hasRequiredFields = false;
  EcosDynoFlags clone() => deepCopy();
  EcosDynoFlags copyWith(void Function(EcosDynoFlags) updates) =>
      super.copyWith((message) => updates(message as EcosDynoFlags)) as EcosDynoFlags;
  @$core.override $pb.BuilderInfo get info_ => _i;
  static EcosDynoFlags create() => EcosDynoFlags._();
  static $pb.GeneratedMessage $_createMessage() => EcosDynoFlags._();
  @$core.override EcosDynoFlags createEmptyInstance() => EcosDynoFlags._();
  static EcosDynoFlags? _defaultInstance;
  static EcosDynoFlags getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EcosDynoFlags>(EcosDynoFlags.$_createMessage);
  @$pb.TagNumber(1) RespStatus get status => $_getN(0);
  @$pb.TagNumber(1) set status(RespStatus value) => $_setField(1, value);
  @$pb.TagNumber(2) $core.String get ecos1 => $_getSZ(1);
  @$pb.TagNumber(2) set ecos1($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3) $core.String get ecos2 => $_getSZ(2);
  @$pb.TagNumber(3) set ecos2($core.String value) => $_setString(2, value);
  @$pb.TagNumber(4) $core.String get dyno => $_getSZ(3);
  @$pb.TagNumber(4) set dyno($core.String value) => $_setString(3, value);
}

class EcosFlag extends $pb.GeneratedMessage {
  factory EcosFlag({$core.int? ecosType, $core.String? flag}) {
    final result = EcosFlag._();
    if (ecosType != null) result.ecosType = ecosType;
    if (flag != null) result.flag = flag;
    return result;
  }
  EcosFlag._();
  factory EcosFlag.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EcosFlag()..mergeFromBuffer(data, registry);
  factory EcosFlag.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EcosFlag()..mergeFromJson(json, registry);
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EcosFlag',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: EcosFlag.$_createMessage)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'ecosType', $pb.PbFieldType.O3)
    ..aOS(2, _omitFieldNames ? '' : 'flag')
    ..hasRequiredFields = false;
  EcosFlag clone() => deepCopy();
  EcosFlag copyWith(void Function(EcosFlag) updates) =>
      super.copyWith((message) => updates(message as EcosFlag)) as EcosFlag;
  @$core.override $pb.BuilderInfo get info_ => _i;
  static EcosFlag create() => EcosFlag._();
  static $pb.GeneratedMessage $_createMessage() => EcosFlag._();
  @$core.override EcosFlag createEmptyInstance() => EcosFlag._();
  static EcosFlag? _defaultInstance;
  static EcosFlag getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EcosFlag>(EcosFlag.$_createMessage);
  @$pb.TagNumber(1) $core.int get ecosType => $_getIZ(0);
  @$pb.TagNumber(1) set ecosType($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(2) $core.String get flag => $_getSZ(1);
  @$pb.TagNumber(2) set flag($core.String value) => $_setString(1, value);
}

class DynoFlag extends $pb.GeneratedMessage {
  factory DynoFlag({$core.String? flag}) {
    final result = DynoFlag._();
    if (flag != null) result.flag = flag;
    return result;
  }
  DynoFlag._();
  factory DynoFlag.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DynoFlag()..mergeFromBuffer(data, registry);
  factory DynoFlag.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DynoFlag()..mergeFromJson(json, registry);
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DynoFlag',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: DynoFlag.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'flag')
    ..hasRequiredFields = false;
  DynoFlag clone() => deepCopy();
  DynoFlag copyWith(void Function(DynoFlag) updates) =>
      super.copyWith((message) => updates(message as DynoFlag)) as DynoFlag;
  @$core.override $pb.BuilderInfo get info_ => _i;
  static DynoFlag create() => DynoFlag._();
  static $pb.GeneratedMessage $_createMessage() => DynoFlag._();
  @$core.override DynoFlag createEmptyInstance() => DynoFlag._();
  static DynoFlag? _defaultInstance;
  static DynoFlag getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DynoFlag>(DynoFlag.$_createMessage);
  @$pb.TagNumber(1) $core.String get flag => $_getSZ(0);
  @$pb.TagNumber(1) set flag($core.String value) => $_setString(0, value);
}

class ConfigType extends $pb.GeneratedMessage {
  factory ConfigType({$core.String? type}) {
    final result = ConfigType._();
    if (type != null) result.type = type;
    return result;
  }
  ConfigType._();
  factory ConfigType.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfigType()..mergeFromBuffer(data, registry);
  factory ConfigType.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfigType()..mergeFromJson(json, registry);
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConfigType',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: ConfigType.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'type')
    ..hasRequiredFields = false;
  ConfigType clone() => deepCopy();
  ConfigType copyWith(void Function(ConfigType) updates) =>
      super.copyWith((message) => updates(message as ConfigType)) as ConfigType;
  @$core.override $pb.BuilderInfo get info_ => _i;
  static ConfigType create() => ConfigType._();
  static $pb.GeneratedMessage $_createMessage() => ConfigType._();
  @$core.override ConfigType createEmptyInstance() => ConfigType._();
  static ConfigType? _defaultInstance;
  static ConfigType getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConfigType>(ConfigType.$_createMessage);
  @$pb.TagNumber(1) $core.String get type => $_getSZ(0);
  @$pb.TagNumber(1) set type($core.String value) => $_setString(0, value);
}

class ConfigUpdateResp extends $pb.GeneratedMessage {
  factory ConfigUpdateResp({ConfigUpdateStatus? status, $core.String? statusMsg}) {
    final result = ConfigUpdateResp._();
    if (status != null) result.status = status;
    if (statusMsg != null) result.statusMsg = statusMsg;
    return result;
  }
  ConfigUpdateResp._();
  factory ConfigUpdateResp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfigUpdateResp()..mergeFromBuffer(data, registry);
  factory ConfigUpdateResp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfigUpdateResp()..mergeFromJson(json, registry);
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConfigUpdateResp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wifican'),
      createEmptyInstance: ConfigUpdateResp.$_createMessage)
    ..aE<ConfigUpdateStatus>(1, _omitFieldNames ? '' : 'status', enumValues: ConfigUpdateStatus.values)
    ..aOS(2, _omitFieldNames ? '' : 'statusMsg')
    ..hasRequiredFields = false;
  ConfigUpdateResp clone() => deepCopy();
  ConfigUpdateResp copyWith(void Function(ConfigUpdateResp) updates) =>
      super.copyWith((message) => updates(message as ConfigUpdateResp)) as ConfigUpdateResp;
  @$core.override $pb.BuilderInfo get info_ => _i;
  static ConfigUpdateResp create() => ConfigUpdateResp._();
  static $pb.GeneratedMessage $_createMessage() => ConfigUpdateResp._();
  @$core.override ConfigUpdateResp createEmptyInstance() => ConfigUpdateResp._();
  static ConfigUpdateResp? _defaultInstance;
  static ConfigUpdateResp getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConfigUpdateResp>(ConfigUpdateResp.$_createMessage);
  @$pb.TagNumber(1) ConfigUpdateStatus get status => $_getN(0);
  @$pb.TagNumber(1) set status(ConfigUpdateStatus value) => $_setField(1, value);
  @$pb.TagNumber(2) $core.String get statusMsg => $_getSZ(1);
  @$pb.TagNumber(2) set statusMsg($core.String value) => $_setString(1, value);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
