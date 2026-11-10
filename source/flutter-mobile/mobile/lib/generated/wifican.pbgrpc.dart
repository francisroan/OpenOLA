// This is a generated file - do not edit.
//
// Generated from wifican.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $1;

import 'wifican.pb.dart' as $0;

export 'wifican.pb.dart';

/// Wican service endpoints
@$pb.GrpcServiceName('wifican.WifiCanRpc')
class WifiCanRpcClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  WifiCanRpcClient(super.channel, {super.options, super.interceptors});

  /// Diagnostic App Enpoints ----- START -----
  /// First call to be made with list of CAN IDs to subscribe to
  $grpc.ResponseFuture<$0.Response> init(
    $0.Register request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$init, request, options: options);
  }

  /// Deinit to be called before disconnecting from the gRPC server for any
  /// clean up calls
  $grpc.ResponseFuture<$0.Response> deinit(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deinit, request, options: options);
  }

  /// Read a CAN Frame to the gRPC server
  $grpc.ResponseFuture<$0.CANPacket> readCanFrame(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$readCanFrame, request, options: options);
  }

  /// Write a CAN Frame to the gRPC server
  $grpc.ResponseFuture<$0.Response> writeCanFrame(
    $0.CANPacket request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$writeCanFrame, request, options: options);
  }

  /// Read a stream of CAN Frames (Filters based on subscribed CAN IDs)
  $grpc.ResponseStream<$0.CANPacket> readCanStream(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$readCanStream, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Write a stream of CAN Frames
  $grpc.ResponseFuture<$0.Response> writeCanStream(
    $async.Stream<$0.CANPacket> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$writeCanStream, request, options: options)
        .single;
  }

  /// Dumps a stream of all CAN packets without any filtering
  $grpc.ResponseStream<$0.CANPacket> canDumpStream(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$canDumpStream, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Vehicle operation mode endpoints ----- START -----
  $grpc.ResponseFuture<$0.VehicleOperationMode> getVehicleOperationMode(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getVehicleOperationMode, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.Response> setVehicleOperationMode(
    $0.VehicleOperationMode request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setVehicleOperationMode, request,
        options: options);
  }

  /// System upgrade endpoints ----- START -----
  $grpc.ResponseFuture<$0.Response> swUpdateFileClearCache(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$swUpdateFileClearCache, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.Response> swUpdateFileTransferMeta(
    $0.SwUpdateFileMetadataReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$swUpdateFileTransferMeta, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.SwUpdateFileMetadataResp> swUpdateFileTransfer(
    $async.Stream<$0.SwUpdateFileChunk> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$swUpdateFileTransfer, request,
            options: options)
        .single;
  }

  $grpc.ResponseFuture<$0.Response> swUpdateTriggerUpgrade(
    $0.SwUpdateTriggerCmd request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$swUpdateTriggerUpgrade, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.SwUpdateStatus> swUpdateCheckStatus(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$swUpdateCheckStatus, request, options: options);
  }

  /// TODO DEPRICATE in production ----- START -----
  $grpc.ResponseFuture<$0.Response> swUpdateTestSetStatus(
    $0.SwUpdateStatus request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$swUpdateTestSetStatus, request, options: options);
  }

  /// Provisioning endpoints ----- START -----
  $grpc.ResponseFuture<$0.Response> getSwVersion(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSwVersion, request, options: options);
  }

  $grpc.ResponseFuture<$0.Response> getAospVersion(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getAospVersion, request, options: options);
  }

  $grpc.ResponseFuture<$0.Response> generateCerts(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$generateCerts, request, options: options);
  }

  $grpc.ResponseFuture<$0.Response> registerInstallCerts(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$registerInstallCerts, request, options: options);
  }

  $grpc.ResponseFuture<$0.Response> validateCerts(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$validateCerts, request, options: options);
  }

  $grpc.ResponseFuture<$0.Response> registerNavigation(
    $0.NavigationConfig request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$registerNavigation, request, options: options);
  }

  $grpc.ResponseFuture<$0.Response> provisionVin(
    $0.Vin request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$provisionVin, request, options: options);
  }

  $grpc.ResponseFuture<$0.VehicleIdentifiers> getVehicleIdentifiers(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getVehicleIdentifiers, request, options: options);
  }

  /// ECOS App Endpoints ----- START -----
  $grpc.ResponseFuture<$0.RmtCmdResp> remoteRunTestCmd(
    $0.RmtCmdReq request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$remoteRunTestCmd, request, options: options);
  }

  $grpc.ResponseFuture<$0.EcosDynoFlags> getEcosDynoFlags(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getEcosDynoFlags, request, options: options);
  }

  $grpc.ResponseFuture<$0.Response> setEcosFlag(
    $0.EcosFlag request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setEcosFlag, request, options: options);
  }

  $grpc.ResponseFuture<$0.Response> setDynoFlag(
    $0.DynoFlag request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setDynoFlag, request, options: options);
  }

  $grpc.ResponseFuture<$0.ConfigUpdateResp> techPackUpdate(
    $0.ConfigType request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$techPackUpdate, request, options: options);
  }

  /// Manufacturing App Endpoints ----- START -----
  /// Command stream for manufacturing app to listen for different commands
  $grpc.ResponseStream<$0.RmtCmdReq> localRunTestStream(
    $async.Stream<$0.RmtCmdResp> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$localRunTestStream, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.RmtCmdReq> localGetTestCmd(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$localGetTestCmd, request, options: options);
  }

  $grpc.ResponseFuture<$0.Response> localSendTestResp(
    $0.RmtCmdResp request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$localSendTestResp, request, options: options);
  }

  /// TODO DEPRICATE in production ----- START -----
  $grpc.ResponseFuture<$0.SystemTestResp> runSystemTestCmd(
    $0.SystemTestCmd request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$runSystemTestCmd, request, options: options);
  }

  /// Runs a shell command on the head unit as root (uid 0); its output comes
  /// back in Response.status_msg. Used to foreground the diagnostic app for
  /// self-tests and to read the on-device diagnostic identity.
  $grpc.ResponseFuture<$0.Response> executeADBCommand(
    $0.Command request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$executeADBCommand, request, options: options);
  }

  // method descriptors

  static final _$init = $grpc.ClientMethod<$0.Register, $0.Response>(
      '/wifican.WifiCanRpc/Init',
      ($0.Register value) => value.writeToBuffer(),
      $0.Response.fromBuffer);
  static final _$deinit = $grpc.ClientMethod<$1.Empty, $0.Response>(
      '/wifican.WifiCanRpc/Deinit',
      ($1.Empty value) => value.writeToBuffer(),
      $0.Response.fromBuffer);
  static final _$readCanFrame = $grpc.ClientMethod<$1.Empty, $0.CANPacket>(
      '/wifican.WifiCanRpc/ReadCanFrame',
      ($1.Empty value) => value.writeToBuffer(),
      $0.CANPacket.fromBuffer);
  static final _$writeCanFrame = $grpc.ClientMethod<$0.CANPacket, $0.Response>(
      '/wifican.WifiCanRpc/WriteCanFrame',
      ($0.CANPacket value) => value.writeToBuffer(),
      $0.Response.fromBuffer);
  static final _$readCanStream = $grpc.ClientMethod<$1.Empty, $0.CANPacket>(
      '/wifican.WifiCanRpc/ReadCanStream',
      ($1.Empty value) => value.writeToBuffer(),
      $0.CANPacket.fromBuffer);
  static final _$writeCanStream = $grpc.ClientMethod<$0.CANPacket, $0.Response>(
      '/wifican.WifiCanRpc/WriteCanStream',
      ($0.CANPacket value) => value.writeToBuffer(),
      $0.Response.fromBuffer);
  static final _$canDumpStream = $grpc.ClientMethod<$1.Empty, $0.CANPacket>(
      '/wifican.WifiCanRpc/CanDumpStream',
      ($1.Empty value) => value.writeToBuffer(),
      $0.CANPacket.fromBuffer);
  static final _$getVehicleOperationMode =
      $grpc.ClientMethod<$1.Empty, $0.VehicleOperationMode>(
          '/wifican.WifiCanRpc/GetVehicleOperationMode',
          ($1.Empty value) => value.writeToBuffer(),
          $0.VehicleOperationMode.fromBuffer);
  static final _$setVehicleOperationMode =
      $grpc.ClientMethod<$0.VehicleOperationMode, $0.Response>(
          '/wifican.WifiCanRpc/SetVehicleOperationMode',
          ($0.VehicleOperationMode value) => value.writeToBuffer(),
          $0.Response.fromBuffer);
  static final _$swUpdateFileClearCache =
      $grpc.ClientMethod<$1.Empty, $0.Response>(
          '/wifican.WifiCanRpc/SwUpdateFileClearCache',
          ($1.Empty value) => value.writeToBuffer(),
          $0.Response.fromBuffer);
  static final _$swUpdateFileTransferMeta =
      $grpc.ClientMethod<$0.SwUpdateFileMetadataReq, $0.Response>(
          '/wifican.WifiCanRpc/SwUpdateFileTransferMeta',
          ($0.SwUpdateFileMetadataReq value) => value.writeToBuffer(),
          $0.Response.fromBuffer);
  static final _$swUpdateFileTransfer =
      $grpc.ClientMethod<$0.SwUpdateFileChunk, $0.SwUpdateFileMetadataResp>(
          '/wifican.WifiCanRpc/SwUpdateFileTransfer',
          ($0.SwUpdateFileChunk value) => value.writeToBuffer(),
          $0.SwUpdateFileMetadataResp.fromBuffer);
  static final _$swUpdateTriggerUpgrade =
      $grpc.ClientMethod<$0.SwUpdateTriggerCmd, $0.Response>(
          '/wifican.WifiCanRpc/SwUpdateTriggerUpgrade',
          ($0.SwUpdateTriggerCmd value) => value.writeToBuffer(),
          $0.Response.fromBuffer);
  static final _$swUpdateCheckStatus =
      $grpc.ClientMethod<$1.Empty, $0.SwUpdateStatus>(
          '/wifican.WifiCanRpc/SwUpdateCheckStatus',
          ($1.Empty value) => value.writeToBuffer(),
          $0.SwUpdateStatus.fromBuffer);
  static final _$swUpdateTestSetStatus =
      $grpc.ClientMethod<$0.SwUpdateStatus, $0.Response>(
          '/wifican.WifiCanRpc/SwUpdateTestSetStatus',
          ($0.SwUpdateStatus value) => value.writeToBuffer(),
          $0.Response.fromBuffer);
  static final _$getSwVersion = $grpc.ClientMethod<$1.Empty, $0.Response>(
      '/wifican.WifiCanRpc/GetSwVersion',
      ($1.Empty value) => value.writeToBuffer(),
      $0.Response.fromBuffer);
  static final _$getAospVersion = $grpc.ClientMethod<$1.Empty, $0.Response>(
      '/wifican.WifiCanRpc/GetAospVersion',
      ($1.Empty value) => value.writeToBuffer(),
      $0.Response.fromBuffer);
  static final _$generateCerts = $grpc.ClientMethod<$1.Empty, $0.Response>(
      '/wifican.WifiCanRpc/GenerateCerts',
      ($1.Empty value) => value.writeToBuffer(),
      $0.Response.fromBuffer);
  static final _$registerInstallCerts =
      $grpc.ClientMethod<$1.Empty, $0.Response>(
          '/wifican.WifiCanRpc/RegisterInstallCerts',
          ($1.Empty value) => value.writeToBuffer(),
          $0.Response.fromBuffer);
  static final _$validateCerts = $grpc.ClientMethod<$1.Empty, $0.Response>(
      '/wifican.WifiCanRpc/ValidateCerts',
      ($1.Empty value) => value.writeToBuffer(),
      $0.Response.fromBuffer);
  static final _$registerNavigation =
      $grpc.ClientMethod<$0.NavigationConfig, $0.Response>(
          '/wifican.WifiCanRpc/RegisterNavigation',
          ($0.NavigationConfig value) => value.writeToBuffer(),
          $0.Response.fromBuffer);
  static final _$provisionVin = $grpc.ClientMethod<$0.Vin, $0.Response>(
      '/wifican.WifiCanRpc/ProvisionVin',
      ($0.Vin value) => value.writeToBuffer(),
      $0.Response.fromBuffer);
  static final _$getVehicleIdentifiers =
      $grpc.ClientMethod<$1.Empty, $0.VehicleIdentifiers>(
          '/wifican.WifiCanRpc/GetVehicleIdentifiers',
          ($1.Empty value) => value.writeToBuffer(),
          $0.VehicleIdentifiers.fromBuffer);
  static final _$remoteRunTestCmd =
      $grpc.ClientMethod<$0.RmtCmdReq, $0.RmtCmdResp>(
          '/wifican.WifiCanRpc/RemoteRunTestCmd',
          ($0.RmtCmdReq value) => value.writeToBuffer(),
          $0.RmtCmdResp.fromBuffer);
  static final _$getEcosDynoFlags =
      $grpc.ClientMethod<$1.Empty, $0.EcosDynoFlags>(
          '/wifican.WifiCanRpc/GetEcosDynoFlags',
          ($1.Empty value) => value.writeToBuffer(),
          $0.EcosDynoFlags.fromBuffer);
  static final _$setEcosFlag = $grpc.ClientMethod<$0.EcosFlag, $0.Response>(
      '/wifican.WifiCanRpc/SetEcosFlag',
      ($0.EcosFlag value) => value.writeToBuffer(),
      $0.Response.fromBuffer);
  static final _$setDynoFlag = $grpc.ClientMethod<$0.DynoFlag, $0.Response>(
      '/wifican.WifiCanRpc/SetDynoFlag',
      ($0.DynoFlag value) => value.writeToBuffer(),
      $0.Response.fromBuffer);
  static final _$techPackUpdate =
      $grpc.ClientMethod<$0.ConfigType, $0.ConfigUpdateResp>(
          '/wifican.WifiCanRpc/TechPackUpdate',
          ($0.ConfigType value) => value.writeToBuffer(),
          $0.ConfigUpdateResp.fromBuffer);
  static final _$localRunTestStream =
      $grpc.ClientMethod<$0.RmtCmdResp, $0.RmtCmdReq>(
          '/wifican.WifiCanRpc/LocalRunTestStream',
          ($0.RmtCmdResp value) => value.writeToBuffer(),
          $0.RmtCmdReq.fromBuffer);
  static final _$localGetTestCmd = $grpc.ClientMethod<$1.Empty, $0.RmtCmdReq>(
      '/wifican.WifiCanRpc/LocalGetTestCmd',
      ($1.Empty value) => value.writeToBuffer(),
      $0.RmtCmdReq.fromBuffer);
  static final _$localSendTestResp =
      $grpc.ClientMethod<$0.RmtCmdResp, $0.Response>(
          '/wifican.WifiCanRpc/LocalSendTestResp',
          ($0.RmtCmdResp value) => value.writeToBuffer(),
          $0.Response.fromBuffer);
  static final _$runSystemTestCmd =
      $grpc.ClientMethod<$0.SystemTestCmd, $0.SystemTestResp>(
          '/wifican.WifiCanRpc/RunSystemTestCmd',
          ($0.SystemTestCmd value) => value.writeToBuffer(),
          $0.SystemTestResp.fromBuffer);
  static final _$executeADBCommand =
      $grpc.ClientMethod<$0.Command, $0.Response>(
          '/wifican.WifiCanRpc/ExecuteADBCommand',
          ($0.Command value) => value.writeToBuffer(),
          $0.Response.fromBuffer);
}

@$pb.GrpcServiceName('wifican.WifiCanRpc')
abstract class WifiCanRpcServiceBase extends $grpc.Service {
  $core.String get $name => 'wifican.WifiCanRpc';

  WifiCanRpcServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Register, $0.Response>(
        'Init',
        init_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Register.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.Response>(
        'Deinit',
        deinit_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.CANPacket>(
        'ReadCanFrame',
        readCanFrame_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.CANPacket value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CANPacket, $0.Response>(
        'WriteCanFrame',
        writeCanFrame_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CANPacket.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.CANPacket>(
        'ReadCanStream',
        readCanStream_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.CANPacket value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CANPacket, $0.Response>(
        'WriteCanStream',
        writeCanStream,
        true,
        false,
        ($core.List<$core.int> value) => $0.CANPacket.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.CANPacket>(
        'CanDumpStream',
        canDumpStream_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.CANPacket value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.VehicleOperationMode>(
        'GetVehicleOperationMode',
        getVehicleOperationMode_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.VehicleOperationMode value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.VehicleOperationMode, $0.Response>(
        'SetVehicleOperationMode',
        setVehicleOperationMode_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.VehicleOperationMode.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.Response>(
        'SwUpdateFileClearCache',
        swUpdateFileClearCache_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SwUpdateFileMetadataReq, $0.Response>(
        'SwUpdateFileTransferMeta',
        swUpdateFileTransferMeta_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SwUpdateFileMetadataReq.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SwUpdateFileChunk, $0.SwUpdateFileMetadataResp>(
            'SwUpdateFileTransfer',
            swUpdateFileTransfer,
            true,
            false,
            ($core.List<$core.int> value) =>
                $0.SwUpdateFileChunk.fromBuffer(value),
            ($0.SwUpdateFileMetadataResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SwUpdateTriggerCmd, $0.Response>(
        'SwUpdateTriggerUpgrade',
        swUpdateTriggerUpgrade_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SwUpdateTriggerCmd.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.SwUpdateStatus>(
        'SwUpdateCheckStatus',
        swUpdateCheckStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.SwUpdateStatus value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SwUpdateStatus, $0.Response>(
        'SwUpdateTestSetStatus',
        swUpdateTestSetStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SwUpdateStatus.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.Response>(
        'GetSwVersion',
        getSwVersion_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.Response>(
        'GetAospVersion',
        getAospVersion_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.Response>(
        'GenerateCerts',
        generateCerts_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.Response>(
        'RegisterInstallCerts',
        registerInstallCerts_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.Response>(
        'ValidateCerts',
        validateCerts_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.NavigationConfig, $0.Response>(
        'RegisterNavigation',
        registerNavigation_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.NavigationConfig.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Vin, $0.Response>(
        'ProvisionVin',
        provisionVin_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Vin.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.VehicleIdentifiers>(
        'GetVehicleIdentifiers',
        getVehicleIdentifiers_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.VehicleIdentifiers value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RmtCmdReq, $0.RmtCmdResp>(
        'RemoteRunTestCmd',
        remoteRunTestCmd_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RmtCmdReq.fromBuffer(value),
        ($0.RmtCmdResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.EcosDynoFlags>(
        'GetEcosDynoFlags',
        getEcosDynoFlags_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.EcosDynoFlags value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.EcosFlag, $0.Response>(
        'SetEcosFlag',
        setEcosFlag_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.EcosFlag.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DynoFlag, $0.Response>(
        'SetDynoFlag',
        setDynoFlag_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DynoFlag.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ConfigType, $0.ConfigUpdateResp>(
        'TechPackUpdate',
        techPackUpdate_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ConfigType.fromBuffer(value),
        ($0.ConfigUpdateResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RmtCmdResp, $0.RmtCmdReq>(
        'LocalRunTestStream',
        localRunTestStream,
        true,
        true,
        ($core.List<$core.int> value) => $0.RmtCmdResp.fromBuffer(value),
        ($0.RmtCmdReq value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.RmtCmdReq>(
        'LocalGetTestCmd',
        localGetTestCmd_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.RmtCmdReq value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RmtCmdResp, $0.Response>(
        'LocalSendTestResp',
        localSendTestResp_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RmtCmdResp.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SystemTestCmd, $0.SystemTestResp>(
        'RunSystemTestCmd',
        runSystemTestCmd_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SystemTestCmd.fromBuffer(value),
        ($0.SystemTestResp value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Command, $0.Response>(
        'ExecuteADBCommand',
        executeADBCommand_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Command.fromBuffer(value),
        ($0.Response value) => value.writeToBuffer()));
  }

  $async.Future<$0.Response> init_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Register> $request) async {
    return init($call, await $request);
  }

  $async.Future<$0.Response> init($grpc.ServiceCall call, $0.Register request);

  $async.Future<$0.Response> deinit_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return deinit($call, await $request);
  }

  $async.Future<$0.Response> deinit($grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.CANPacket> readCanFrame_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return readCanFrame($call, await $request);
  }

  $async.Future<$0.CANPacket> readCanFrame(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Response> writeCanFrame_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.CANPacket> $request) async {
    return writeCanFrame($call, await $request);
  }

  $async.Future<$0.Response> writeCanFrame(
      $grpc.ServiceCall call, $0.CANPacket request);

  $async.Stream<$0.CANPacket> readCanStream_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async* {
    yield* readCanStream($call, await $request);
  }

  $async.Stream<$0.CANPacket> readCanStream(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Response> writeCanStream(
      $grpc.ServiceCall call, $async.Stream<$0.CANPacket> request);

  $async.Stream<$0.CANPacket> canDumpStream_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async* {
    yield* canDumpStream($call, await $request);
  }

  $async.Stream<$0.CANPacket> canDumpStream(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.VehicleOperationMode> getVehicleOperationMode_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getVehicleOperationMode($call, await $request);
  }

  $async.Future<$0.VehicleOperationMode> getVehicleOperationMode(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Response> setVehicleOperationMode_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.VehicleOperationMode> $request) async {
    return setVehicleOperationMode($call, await $request);
  }

  $async.Future<$0.Response> setVehicleOperationMode(
      $grpc.ServiceCall call, $0.VehicleOperationMode request);

  $async.Future<$0.Response> swUpdateFileClearCache_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return swUpdateFileClearCache($call, await $request);
  }

  $async.Future<$0.Response> swUpdateFileClearCache(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Response> swUpdateFileTransferMeta_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SwUpdateFileMetadataReq> $request) async {
    return swUpdateFileTransferMeta($call, await $request);
  }

  $async.Future<$0.Response> swUpdateFileTransferMeta(
      $grpc.ServiceCall call, $0.SwUpdateFileMetadataReq request);

  $async.Future<$0.SwUpdateFileMetadataResp> swUpdateFileTransfer(
      $grpc.ServiceCall call, $async.Stream<$0.SwUpdateFileChunk> request);

  $async.Future<$0.Response> swUpdateTriggerUpgrade_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SwUpdateTriggerCmd> $request) async {
    return swUpdateTriggerUpgrade($call, await $request);
  }

  $async.Future<$0.Response> swUpdateTriggerUpgrade(
      $grpc.ServiceCall call, $0.SwUpdateTriggerCmd request);

  $async.Future<$0.SwUpdateStatus> swUpdateCheckStatus_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return swUpdateCheckStatus($call, await $request);
  }

  $async.Future<$0.SwUpdateStatus> swUpdateCheckStatus(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Response> swUpdateTestSetStatus_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SwUpdateStatus> $request) async {
    return swUpdateTestSetStatus($call, await $request);
  }

  $async.Future<$0.Response> swUpdateTestSetStatus(
      $grpc.ServiceCall call, $0.SwUpdateStatus request);

  $async.Future<$0.Response> getSwVersion_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getSwVersion($call, await $request);
  }

  $async.Future<$0.Response> getSwVersion(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Response> getAospVersion_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getAospVersion($call, await $request);
  }

  $async.Future<$0.Response> getAospVersion(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Response> generateCerts_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return generateCerts($call, await $request);
  }

  $async.Future<$0.Response> generateCerts(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Response> registerInstallCerts_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return registerInstallCerts($call, await $request);
  }

  $async.Future<$0.Response> registerInstallCerts(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Response> validateCerts_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return validateCerts($call, await $request);
  }

  $async.Future<$0.Response> validateCerts(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Response> registerNavigation_Pre($grpc.ServiceCall $call,
      $async.Future<$0.NavigationConfig> $request) async {
    return registerNavigation($call, await $request);
  }

  $async.Future<$0.Response> registerNavigation(
      $grpc.ServiceCall call, $0.NavigationConfig request);

  $async.Future<$0.Response> provisionVin_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Vin> $request) async {
    return provisionVin($call, await $request);
  }

  $async.Future<$0.Response> provisionVin(
      $grpc.ServiceCall call, $0.Vin request);

  $async.Future<$0.VehicleIdentifiers> getVehicleIdentifiers_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getVehicleIdentifiers($call, await $request);
  }

  $async.Future<$0.VehicleIdentifiers> getVehicleIdentifiers(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.RmtCmdResp> remoteRunTestCmd_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.RmtCmdReq> $request) async {
    return remoteRunTestCmd($call, await $request);
  }

  $async.Future<$0.RmtCmdResp> remoteRunTestCmd(
      $grpc.ServiceCall call, $0.RmtCmdReq request);

  $async.Future<$0.EcosDynoFlags> getEcosDynoFlags_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getEcosDynoFlags($call, await $request);
  }

  $async.Future<$0.EcosDynoFlags> getEcosDynoFlags(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Response> setEcosFlag_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.EcosFlag> $request) async {
    return setEcosFlag($call, await $request);
  }

  $async.Future<$0.Response> setEcosFlag(
      $grpc.ServiceCall call, $0.EcosFlag request);

  $async.Future<$0.Response> setDynoFlag_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.DynoFlag> $request) async {
    return setDynoFlag($call, await $request);
  }

  $async.Future<$0.Response> setDynoFlag(
      $grpc.ServiceCall call, $0.DynoFlag request);

  $async.Future<$0.ConfigUpdateResp> techPackUpdate_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ConfigType> $request) async {
    return techPackUpdate($call, await $request);
  }

  $async.Future<$0.ConfigUpdateResp> techPackUpdate(
      $grpc.ServiceCall call, $0.ConfigType request);

  $async.Stream<$0.RmtCmdReq> localRunTestStream(
      $grpc.ServiceCall call, $async.Stream<$0.RmtCmdResp> request);

  $async.Future<$0.RmtCmdReq> localGetTestCmd_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return localGetTestCmd($call, await $request);
  }

  $async.Future<$0.RmtCmdReq> localGetTestCmd(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.Response> localSendTestResp_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.RmtCmdResp> $request) async {
    return localSendTestResp($call, await $request);
  }

  $async.Future<$0.Response> localSendTestResp(
      $grpc.ServiceCall call, $0.RmtCmdResp request);

  $async.Future<$0.SystemTestResp> runSystemTestCmd_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.SystemTestCmd> $request) async {
    return runSystemTestCmd($call, await $request);
  }

  $async.Future<$0.SystemTestResp> runSystemTestCmd(
      $grpc.ServiceCall call, $0.SystemTestCmd request);

  $async.Future<$0.Response> executeADBCommand_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Command> $request) async {
    return executeADBCommand($call, await $request);
  }

  $async.Future<$0.Response> executeADBCommand(
      $grpc.ServiceCall call, $0.Command request);
}
