import 'dart:typed_data';

/// Encodes gamepad packets into the custom binary wire format.
///
/// Wire frame (both directions):
///   [content_len : u32 LE]   — bytes that follow (type + payload)
///   [type        : u8]
///   [payload     : ...]
///
/// Packet types sent by Android:
///   0x01  Handshake
///   0x02  ControllerPacket  (~120 Hz)
///
/// Must stay in sync with rust_backend/src/protocol.rs
class PacketEncoder {
  // ── Packet type IDs ──────────────────────────────────────────────────────
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

  // ── Handshake ─────────────────────────────────────────────────────────────
  //
  // content = [0x01][player_id:4][name_len:1][name:N][layout_len:1][layout:M]
  static Uint8List encodeHandshake({
    required int    playerId,
    required String deviceName,
    required String layout,
  }) {
    final nameB   = _utf8(deviceName);
    final layoutB = _utf8(layout);
    // content length: type(1) + pid(4) + namelen(1) + name + layoutlen(1) + layout
    final contentLen = 1 + 4 + 1 + nameB.length + 1 + layoutB.length;
    final buf = ByteData(4 + contentLen);
    int o = 0;

    buf.setUint32(o, contentLen, Endian.little); o += 4;
    buf.setUint8(o++, typeHandshake);
    buf.setUint32(o, playerId, Endian.little);   o += 4;
    buf.setUint8(o++, nameB.length);
    for (final b in nameB) buf.setUint8(o++, b);
    buf.setUint8(o++, layoutB.length);
    for (final b in layoutB) buf.setUint8(o++, b);

    return buf.buffer.asUint8List();
  }

  // ── ControllerPacket ──────────────────────────────────────────────────────
  //
  // content = [0x02][68-byte payload]  → content_len = 69
  //
  // Payload layout (LE):
  //   player_id    : u32  (4)
  //   sequence     : u32  (4)
  //   timestamp    : u64  (8)   µs since epoch
  //   left_x       : f32  (4)
  //   left_y       : f32  (4)
  //   right_x      : f32  (4)
  //   right_y      : f32  (4)
  //   left_trigger : f32  (4)
  //   right_trigger: f32  (4)
  //   buttons      : u32  (4)
  //   gyro_x/y/z   : f32  (12)
  //   accel_x/y/z  : f32  (12)
  //   Total: 4+4+8+13*4 = 68 bytes
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
  }) {
    const payloadLen = 68;
    const contentLen = 1 + payloadLen; // type byte + payload
    final buf = ByteData(4 + contentLen);
    int o = 0;

    buf.setUint32(o, contentLen, Endian.little); o += 4;
    buf.setUint8(o++, typeController);

    buf.setUint32(o, playerId, Endian.little);  o += 4;
    buf.setUint32(o, sequence, Endian.little);  o += 4;

    final ts = DateTime.now().microsecondsSinceEpoch;
    buf.setUint64(o, ts, Endian.little);        o += 8;

    buf.setFloat32(o, leftX.clamp(-1.0, 1.0),           Endian.little); o += 4;
    buf.setFloat32(o, leftY.clamp(-1.0, 1.0),           Endian.little); o += 4;
    buf.setFloat32(o, rightX.clamp(-1.0, 1.0),          Endian.little); o += 4;
    buf.setFloat32(o, rightY.clamp(-1.0, 1.0),          Endian.little); o += 4;
    buf.setFloat32(o, leftTrigger.clamp(0.0, 1.0),      Endian.little); o += 4;
    buf.setFloat32(o, rightTrigger.clamp(0.0, 1.0),     Endian.little); o += 4;
    buf.setUint32(o, buttons, Endian.little);            o += 4;
    buf.setFloat32(o, gyroX,  Endian.little);            o += 4;
    buf.setFloat32(o, gyroY,  Endian.little);            o += 4;
    buf.setFloat32(o, gyroZ,  Endian.little);            o += 4;
    buf.setFloat32(o, accelX, Endian.little);            o += 4;
    buf.setFloat32(o, accelY, Endian.little);            o += 4;
    buf.setFloat32(o, accelZ, Endian.little);

    return buf.buffer.asUint8List();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<int> _utf8(String s) => s.codeUnits; // ASCII-safe for now
}
