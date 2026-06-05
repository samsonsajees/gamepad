import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/packet_encoder.dart';
import '../../core/tcp_client.dart';
import '../../core/udp_client.dart';
import 'connection_mode.dart';

// ── Transport clients ─────────────────────────────────────────────────────────

final tcpClientProvider = Provider<TcpClient>((ref) {
  final c = TcpClient();
  ref.onDispose(c.dispose);
  return c;
});

final udpClientProvider = Provider<UdpClient>((ref) {
  final c = UdpClient();
  ref.onDispose(c.dispose);
  return c;
});

// ── Active mode ───────────────────────────────────────────────────────────────

final connectionModeProvider =
    StateProvider<ConnectionMode>((ref) => ConnectionMode.usb);

// ── Status stream (whichever client is active) ────────────────────────────────

final connectionStatusStreamProvider = StreamProvider<ConnectionStatus>((ref) {
  final mode = ref.watch(connectionModeProvider);
  return mode == ConnectionMode.usb
      ? ref.watch(tcpClientProvider).statusStream
      : ref.watch(udpClientProvider).statusStream;
});

// ── Unified notifier ──────────────────────────────────────────────────────────

class ConnectionNotifier extends AsyncNotifier<ConnectionStatus> {
  @override
  Future<ConnectionStatus> build() async => ConnectionStatus.disconnected;

  // ── USB / TCP ──────────────────────────────────────────────────────────────

  Future<bool> connectUsb(String host, int port) async {
    state = const AsyncValue.loading();
    final client = ref.read(tcpClientProvider);
    final ok = await client.connect(host, port, autoReconnect: true);

    if (ok) {
      ref.read(connectionModeProvider.notifier).state = ConnectionMode.usb;
      client.send(PacketEncoder.encodeHandshake(
        playerId:   AppConstants.defaultPlayerId,
        deviceName: 'Android Gamepad',
        layout:     AppConstants.layoutRacing,
      ));
      state = const AsyncValue.data(ConnectionStatus.connected);
    } else {
      state = const AsyncValue.data(ConnectionStatus.error);
    }
    return ok;
  }

  // ── WiFi / UDP ─────────────────────────────────────────────────────────────

  Future<bool> connectWifi(String host, int port, int token) async {
    state = const AsyncValue.loading();
    final udp = ref.read(udpClientProvider);
    final ok  = await udp.connect(host, port, token);

    if (ok) {
      ref.read(connectionModeProvider.notifier).state = ConnectionMode.wifi;
      // Send handshake so the server registers this player slot
      udp.send(PacketEncoder.encodeUdpHandshake(
        playerId:   AppConstants.defaultPlayerId,
        deviceName: 'Android Gamepad',
        layout:     AppConstants.layoutRacing,
      ));
      state = const AsyncValue.data(ConnectionStatus.connected);
    } else {
      state = const AsyncValue.data(ConnectionStatus.error);
    }
    return ok;
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    final mode = ref.read(connectionModeProvider);
    if (mode == ConnectionMode.usb) {
      await ref.read(tcpClientProvider).disconnect();
    } else {
      await ref.read(udpClientProvider).disconnect();
    }
    state = const AsyncValue.data(ConnectionStatus.disconnected);
  }
}

final connectionNotifierProvider =
    AsyncNotifierProvider<ConnectionNotifier, ConnectionStatus>(
  ConnectionNotifier.new,
);
