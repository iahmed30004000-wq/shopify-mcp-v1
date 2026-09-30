/// The Google Nearby Connections calls the nearby transport makes, behind an
/// interface: [PluginNearbyApi] over the `nearby_connections` plugin, and a
/// fake two-phone "air" in the tests.
library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart' as nc;

import '../frame_chunks.dart';

/// Something the radios reported.
sealed class NearbyEvent {
  const NearbyEvent(this.endpointId);

  final String endpointId;
}

/// Discovery found a phone advertising [serviceId].
final class NearbyEndpointFound extends NearbyEvent {
  const NearbyEndpointFound(super.endpointId, {required this.name, required this.serviceId});

  /// The endpoint name it advertises (its player's display name).
  final String name;
  final String serviceId;
}

final class NearbyEndpointLost extends NearbyEvent {
  const NearbyEndpointLost(super.endpointId);
}

/// A connection is being set up (requested by us, or by the peer when
/// [incoming]); both sides see the same [token] and must accept.
final class NearbyConnectionInitiated extends NearbyEvent {
  const NearbyConnectionInitiated(super.endpointId, {required this.name, required this.token, required this.incoming});

  final String name;
  final String token;
  final bool incoming;
}

enum NearbyConnectionStatus { connected, rejected, error }

final class NearbyConnectionResult extends NearbyEvent {
  const NearbyConnectionResult(super.endpointId, this.status);

  final NearbyConnectionStatus status;
}

final class NearbyDisconnected extends NearbyEvent {
  const NearbyDisconnected(super.endpointId);
}

enum NearbyPayloadKind { bytes, file, stream, other }

final class NearbyPayloadReceived extends NearbyEvent {
  const NearbyPayloadReceived(super.endpointId, {required this.payloadId, required this.kind, this.bytes});

  final int payloadId;
  final NearbyPayloadKind kind;

  /// The payload for [NearbyPayloadKind.bytes].
  final Uint8List? bytes;
}

/// Why a Nearby call failed.
enum NearbyErrorKind {
  /// A runtime permission is missing (revoked meanwhile).
  permission,

  /// Bluetooth / Wi-Fi off, busy or failing.
  radio,

  /// Already advertising / discovering (harmless).
  alreadyActive,

  /// Already connected to that endpoint (harmless).
  alreadyConnected,

  unknown,
}

final class NearbyApiException implements Exception {
  const NearbyApiException(this.kind, [this.message]);

  /// Classifies a plugin failure – its message carries the Nearby status,
  /// e.g. `8007: STATUS_RADIO_ERROR` or `MISSING_PERMISSION_BLUETOOTH_SCAN`.
  factory NearbyApiException.from(Object error) {
    final message = switch (error) {
      PlatformException(:final message, :final code) => '${message ?? ''} $code',
      NearbyApiException(:final kind, :final message) => '${kind.name} ${message ?? ''}',
      _ => '$error',
    };
    final m = message.toUpperCase();
    final kind = switch (m) {
      _ when m.contains('MISSING_PERMISSION') || m.contains('SECURITYEXCEPTION') => NearbyErrorKind.permission,
      _
          when m.contains('ALREADY_ADVERTISING') ||
              m.contains('ALREADY_DISCOVERING') ||
              m.contains('8001') ||
              m.contains('8002') =>
        NearbyErrorKind.alreadyActive,
      _ when m.contains('ALREADY_CONNECTED') || m.contains('8003') => NearbyErrorKind.alreadyConnected,
      _ when m.contains('RADIO') || m.contains('BLUETOOTH') || m.contains('WIFI') || m.contains('8007') =>
        NearbyErrorKind.radio,
      _ => NearbyErrorKind.unknown,
    };
    return NearbyApiException(kind, message.trim());
  }

  final NearbyErrorKind kind;
  final String? message;

  @override
  String toString() => 'NearbyApiException(${kind.name}${message == null ? '' : ': $message'})';
}

/// One phone's Nearby Connections client. Advertising and discovery both
/// use the point-to-point strategy (one partner, the highest bandwidth, with
/// the upgrade to Wi-Fi Direct / hotspot); [events] reports everything the
/// radios do.
abstract class NearbyApi {
  Stream<NearbyEvent> get events;

  /// The largest BYTES payload.
  int get maxPayloadBytes;

  Future<void> startAdvertising({required String name, required String serviceId});

  Future<void> startDiscovery({required String name, required String serviceId});

  Future<void> stopAdvertising();

  Future<void> stopDiscovery();

  Future<void> requestConnection({required String name, required String endpointId});

  Future<void> acceptConnection(String endpointId);

  Future<void> rejectConnection(String endpointId);

  Future<void> sendBytes(String endpointId, Uint8List bytes);

  /// Cancels an incoming payload (files and streams are never accepted).
  Future<void> cancelPayload(int payloadId);

  Future<void> disconnect(String endpointId);

  Future<void> stopAllEndpoints();
}

/// [NearbyApi] over the `nearby_connections` plugin (a process-wide
/// singleton with one set of callbacks – one transport at a time).
class PluginNearbyApi implements NearbyApi {
  PluginNearbyApi({this.strategy = nc.Strategy.P2P_POINT_TO_POINT});

  /// P2P_POINT_TO_POINT: exactly one partner and the fastest medium.
  /// P2P_STAR is a drop-in alternative if a device family misbehaves.
  final nc.Strategy strategy;

  final StreamController<NearbyEvent> _events = StreamController<NearbyEvent>.broadcast();

  // Created on first use: the plugin subscribes to its event channel in its
  // constructor.
  nc.Nearby get _nearby => nc.Nearby();

  @override
  Stream<NearbyEvent> get events => _events.stream;

  @override
  int get maxPayloadBytes => FrameChunks.nearbyMaxPayload;

  void _emit(NearbyEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _initiated(String id, nc.ConnectionInfo info) => _emit(
    NearbyConnectionInitiated(
      id,
      name: info.endpointName,
      token: info.authenticationToken,
      incoming: info.isIncomingConnection,
    ),
  );

  void _result(String id, nc.Status status) => _emit(
    NearbyConnectionResult(id, switch (status) {
      nc.Status.CONNECTED => NearbyConnectionStatus.connected,
      nc.Status.REJECTED => NearbyConnectionStatus.rejected,
      nc.Status.ERROR => NearbyConnectionStatus.error,
    }),
  );

  void _disconnected(String id) => _emit(NearbyDisconnected(id));

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on NearbyApiException {
      rethrow;
    } catch (e) {
      throw NearbyApiException.from(e);
    }
  }

  @override
  Future<void> startAdvertising({required String name, required String serviceId}) => _guard(() async {
    final ok = await _nearby.startAdvertising(
      name,
      strategy,
      serviceId: serviceId,
      onConnectionInitiated: _initiated,
      onConnectionResult: _result,
      onDisconnected: _disconnected,
    );
    if (!ok) throw const NearbyApiException(NearbyErrorKind.radio, 'startAdvertising returned false');
  });

  @override
  Future<void> startDiscovery({required String name, required String serviceId}) => _guard(() async {
    final ok = await _nearby.startDiscovery(
      name,
      strategy,
      serviceId: serviceId,
      onEndpointFound: (id, endpointName, service) =>
          _emit(NearbyEndpointFound(id, name: endpointName, serviceId: service)),
      onEndpointLost: (id) {
        if (id != null) _emit(NearbyEndpointLost(id));
      },
    );
    if (!ok) throw const NearbyApiException(NearbyErrorKind.radio, 'startDiscovery returned false');
  });

  @override
  Future<void> stopAdvertising() => _guard(_nearby.stopAdvertising);

  @override
  Future<void> stopDiscovery() => _guard(_nearby.stopDiscovery);

  @override
  Future<void> requestConnection({required String name, required String endpointId}) => _guard(() async {
    await _nearby.requestConnection(
      name,
      endpointId,
      onConnectionInitiated: _initiated,
      onConnectionResult: _result,
      onDisconnected: _disconnected,
    );
  });

  @override
  Future<void> acceptConnection(String endpointId) => _guard(() async {
    await _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (id, payload) => _emit(
        NearbyPayloadReceived(
          id,
          payloadId: payload.id,
          kind: switch (payload.type) {
            nc.PayloadType.BYTES => NearbyPayloadKind.bytes,
            nc.PayloadType.FILE => NearbyPayloadKind.file,
            nc.PayloadType.STREAM => NearbyPayloadKind.stream,
            nc.PayloadType.NONE => NearbyPayloadKind.other,
          },
          bytes: payload.type == nc.PayloadType.BYTES ? payload.bytes : null,
        ),
      ),
    );
  });

  @override
  Future<void> rejectConnection(String endpointId) => _guard(() => _nearby.rejectConnection(endpointId));

  @override
  Future<void> sendBytes(String endpointId, Uint8List bytes) =>
      _guard(() => _nearby.sendBytesPayload(endpointId, bytes));

  @override
  Future<void> cancelPayload(int payloadId) => _guard(() => _nearby.cancelPayload(payloadId));

  @override
  Future<void> disconnect(String endpointId) => _guard(() => _nearby.disconnectFromEndpoint(endpointId));

  @override
  Future<void> stopAllEndpoints() => _guard(_nearby.stopAllEndpoints);
}
