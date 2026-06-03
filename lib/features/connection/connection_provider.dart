import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/packet_encoder.dart';
import '../../core/tcp_client.dart';

// ── Singleton TCP client ───────────────────────────────────────────────────

final tcpClientProvider = Provider<TcpClient>((ref) {
  final client = TcpClient();
  ref.onDispose(client.dispose);
  return client;
});

// ── Connection status stream ───────────────────────────────────────────────

final connectionStatusStreamProvider = StreamProvider<ConnectionStatus>((ref) {
  return ref.watch(tcpClientProvider).statusStream;
});

// ── Notifier that drives connect / disconnect actions ─────────────────────

class ConnectionNotifier extends AsyncNotifier<ConnectionStatus> {
  @override
  Future<ConnectionStatus> build() async => ConnectionStatus.disconnected;

  Future<bool> connect(String host, int port) async {
    state = const AsyncValue.loading();
    final client = ref.read(tcpClientProvider);
    final ok = await client.connect(host, port);

    if (ok) {
      // Send handshake immediately after TCP is open
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

  Future<void> disconnect() async {
    final client = ref.read(tcpClientProvider);
    await client.disconnect();
    state = const AsyncValue.data(ConnectionStatus.disconnected);
  }
}

final connectionNotifierProvider =
    AsyncNotifierProvider<ConnectionNotifier, ConnectionStatus>(
  ConnectionNotifier.new,
);
