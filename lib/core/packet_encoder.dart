import 'dart:typed_data';

/// Encodes gamepad packets into the custom binary wire format.
///
/// Internally builds [type:1][payload:N] "content" blocks.
/// TCP wraps them in a [length:4] frame.
/// UDP prepends a [token:4] — done by UdpClient.send().
///
/// Must stay in sync with rust_backend/src/protocol.rs
class PacketEncoder {
  // ── Type IDs ─────────────────────────────────────────────────────────────
  static const int typeHandshake  = 0x01;
  static const int typeController = 0x02;

  // ── Button bitmasks (must match protocol.rs buttons module) ──────────────
  static const int btnA          = 1 << 0;
  static const int btnB          = 1 << 1;
  static const int btnX          = 1 << 2;
  static const int btnY          = 1 << 3;
  static const int btnLB         = 1 << 4;
  static const int btnRB         = 1 << 5;
  static const int btnStart      = 1 << 6;
  static const int btnBack       = 1 << 7;
  static const int btnLThumb     = 1 << 8;
  static const int btnRThumb     = 1 << 9;
  static const int btnDpadUp     = 1 << 10;
  static const int btnDpadDown   = 1 << 11;
  static const int btnDpadLeft   = 1 << 12;
  static const int btnDpadRight  = 1 << 13;

  // ═════════════════════════════════════════════════════════════════════════
  // Internal content builders — return [type:1][payload:N]
  // ═════════════════════════════════════════════════════════════════════════

  static Uint8List _handshakeContent({
    required int    playerId,
    required String deviceName,
    required String layout,
  }) {
    final nameB   = _utf8(deviceName);
    final layoutB = _utf8(layout);
    final len = 1 + 4 + 1 + nameB.length + 1 + layoutB.length;
    final buf = ByteData(len);
    int o = 0;
    buf.setUint8(o++, typeHandshake);
    buf.setUint32(o, playerId, Endian.little); o += 4;
    buf.setUint8(o++, nameB.length);
    for (final b in nameB) buf.setUint8(o++, b);
    buf.setUint8(o++, layoutB.length);
    for (final b in layoutB) buf.setUint8(o++, b);
    return buf.buffer.asUint8List();
  }

  // Controller payload is always 68 bytes → content = 1 + 68 = 69 bytes
  static Uint8List _controllerContent({
    required int    playerId,
    required int    sequence,
    required double leftX,
    required double leftY,
    required double rightX,
    required double rightY,
    required double leftTrigger,
    required double rightTrigger,
    required int    buttons,
    required double gyroX,
    required double gyroY,
    required double gyroZ,
    required double accelX,
    required double accelY,
    required double accelZ,
  }) {
    const len = 69; // type(1) + payload(68)
    final buf = ByteData(len);
    int o = 0;

    buf.setUint8(o++, typeController);
    buf.setUint32(o, playerId, Endian.little);              o += 4;
    buf.setUint32(o, sequence, Endian.little);              o += 4;
    buf.setUint64(o, DateTime.now().microsecondsSinceEpoch,
                  Endian.little);                           o += 8;
    buf.setFloat32(o, leftX.clamp(-1.0, 1.0),        Endian.little); o += 4;
    buf.setFloat32(o, leftY.clamp(-1.0, 1.0),        Endian.little); o += 4;
    buf.setFloat32(o, rightX.clamp(-1.0, 1.0),       Endian.little); o += 4;
    buf.setFloat32(o, rightY.clamp(-1.0, 1.0),       Endian.little); o += 4;
    buf.setFloat32(o, leftTrigger.clamp(0.0, 1.0),   Endian.little); o += 4;
    buf.setFloat32(o, rightTrigger.clamp(0.0, 1.0),  Endian.little); o += 4;
    buf.setUint32(o, buttons,                         Endian.little); o += 4;
    buf.setFloat32(o, gyroX,  Endian.little);                         o += 4;
    buf.setFloat32(o, gyroY,  Endian.little);                         o += 4;
    buf.setFloat32(o, gyroZ,  Endian.little);                         o += 4;
    buf.setFloat32(o, accelX, Endian.little);                         o += 4;
    buf.setFloat32(o, accelY, Endian.little);                         o += 4;
    buf.setFloat32(o, accelZ, Endian.little);

    return buf.buffer.asUint8List();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TCP — [length:4][content]
  // ═════════════════════════════════════════════════════════════════════════

  static Uint8List _tcpFrame(Uint8List content) {
    final frame = Uint8List(4 + content.length);
    ByteData.sublistView(frame)
        .setUint32(0, content.length, Endian.little);
    frame.setRange(4, frame.length, content);
    return frame;
  }

  static Uint8List encodeHandshake({
    required int    playerId,
    required String deviceName,
    required String layout,
  }) =>
      _tcpFrame(_handshakeContent(
        playerId: playerId, deviceName: deviceName, layout: layout,
      ));

  static Uint8List encodeControllerPacket({
    required int    playerId,
    required int    sequence,
    required double leftX,
    required double leftY,
    required double rightX,
    required double rightY,
    required double leftTrigger,
    required double rightTrigger,
    required int    buttons,
    required double gyroX,
    required double gyroY,
    required double gyroZ,
    required double accelX,
    required double accelY,
    required double accelZ,
  }) =>
      _tcpFrame(_controllerContent(
        playerId: playerId, sequence: sequence,
        leftX: leftX, leftY: leftY, rightX: rightX, rightY: rightY,
        leftTrigger: leftTrigger, rightTrigger: rightTrigger,
        buttons: buttons,
        gyroX: gyroX, gyroY: gyroY, gyroZ: gyroZ,
        accelX: accelX, accelY: accelY, accelZ: accelZ,
      ));

  // ═════════════════════════════════════════════════════════════════════════
  // UDP — content only; UdpClient.send() prepends the 4-byte token
  // ═════════════════════════════════════════════════════════════════════════

  static Uint8List encodeUdpHandshake({
    required int    playerId,
    required String deviceName,
    required String layout,
  }) =>
      _handshakeContent(
        playerId: playerId, deviceName: deviceName, layout: layout,
      );

  static Uint8List encodeUdpControllerPacket({
    required int    playerId,
    required int    sequence,
    required double leftX,
    required double leftY,
    required double rightX,
    required double rightY,
    required double leftTrigger,
    required double rightTrigger,
    required int    buttons,
    required double gyroX,
    required double gyroY,
    required double gyroZ,
    required double accelX,
    required double accelY,
    required double accelZ,
  }) =>
      _controllerContent(
        playerId: playerId, sequence: sequence,
        leftX: leftX, leftY: leftY, rightX: rightX, rightY: rightY,
        leftTrigger: leftTrigger, rightTrigger: rightTrigger,
        buttons: buttons,
        gyroX: gyroX, gyroY: gyroY, gyroZ: gyroZ,
        accelX: accelX, accelY: accelY, accelZ: accelZ,
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<int> _utf8(String s) => s.codeUnits;
}
