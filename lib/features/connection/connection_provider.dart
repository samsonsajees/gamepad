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

final connectionModeProvider = StateProvider<ConnectionMode>(
  (ref) => ConnectionMode.usb,
);

// ── Status stream (whichever client is active) ────────────────────────────────

final connectionStatusStreamProvider = StreamProvider<ConnectionStatus>((ref) {
  // Always use TCP client for connection lifecycle (USB and WiFi both use TCP for status)
  return ref.watch(tcpClientProvider).statusStream;
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
      client.send(
        PacketEncoder.encodeHandshake(
          playerId: AppConstants.defaultPlayerId,
          deviceName: 'Android Gamepad',
          layout: AppConstants.layoutRacing,
        ),
      );
      state = const AsyncValue.data(ConnectionStatus.connected);
    } else {
      state = const AsyncValue.data(ConnectionStatus.error);
    }
    return ok;
  }

  // ── WiFi / UDP ─────────────────────────────────────────────────────────────

  Future<bool> connectWifi(String host, int udpPort, int token) async {
    state = const AsyncValue.loading();
    // The UI passes the UDP port. The TCP port is always UDP port - 1.
    final tcpPort = udpPort - 1;

    final tcp = ref.read(tcpClientProvider);
    final tcpOk = await tcp.connect(host, tcpPort, autoReconnect: false);

    if (tcpOk) {
      final udp = ref.read(udpClientProvider);
      final udpOk = await udp.connect(host, udpPort, token);

      if (udpOk) {
        ref.read(connectionModeProvider.notifier).state = ConnectionMode.wifi;

        // Send TCP handshake to register player slot on server
        tcp.send(
          PacketEncoder.encodeHandshake(
            playerId: AppConstants.defaultPlayerId,
            deviceName: 'Android Gamepad',
            layout: AppConstants.layoutRacing,
          ),
        );

        state = const AsyncValue.data(ConnectionStatus.connected);
        return true;
      } else {
        await tcp.disconnect();
      }
    }

    state = const AsyncValue.data(ConnectionStatus.error);
    return false;
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    final mode = ref.read(connectionModeProvider);
    await ref.read(tcpClientProvider).disconnect();
    if (mode == ConnectionMode.wifi) {
      await ref.read(udpClientProvider).disconnect();
    }
    state = const AsyncValue.data(ConnectionStatus.disconnected);
  }
}

final connectionNotifierProvider =
    AsyncNotifierProvider<ConnectionNotifier, ConnectionStatus>(
      ConnectionNotifier.new,
    );
