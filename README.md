# Mobile Gamepad — Racing Edition

Turn your Android phone into an Xbox-compatible racing controller for Windows games using a USB cable.

```
Android Flutter App  →  USB (ADB tunnel)  →  Windows Flutter Host
                                                      ↓
                                              Rust gamepad_server
                                                      ↓
                                            ViGEmBus  XInput Controller
                                                      ↓
                                               Windows Game
```

---

## Quick Start

### Prerequisites

| Tool | Link |
|------|------|
| Flutter 3.16+ | https://docs.flutter.dev/get-started/install |
| Rust toolchain | https://rustup.rs |
| ViGEmBus driver | https://github.com/nefarius/ViGEmBus/releases |
| Android Platform Tools (ADB) | https://developer.android.com/studio/releases/platform-tools |

---

### 1 — Build the Rust server (Windows)

```powershell
cd rust_backend
cargo build --release
# Output: target\release\gamepad_server.exe
```

### 2 — Build & run the Windows Flutter host

```powershell
cd flutter_app
flutter run -d windows
```

Copy `rust_backend\target\release\gamepad_server.exe` to the same folder as
the Flutter Windows app, then click **START SERVER** inside the app.

### 3 — Set up USB tunnel

```powershell
# Run once after plugging in the USB cable:
.\setup_usb.ps1

# Or manually:
adb reverse tcp:5000 tcp:5000
```

### 4 — Run the Android app

```powershell
cd flutter_app
flutter run -d <your-android-device>
```

Tap **CONNECT** (host = `127.0.0.1`, port = `5000`).

---

## Android Permissions

Add to `flutter_app/android/app/src/main/AndroidManifest.xml`
(inside the `<manifest>` tag, before `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

---

## Racing Controls

| Control | Action |
|---------|--------|
| **Tilt phone left/right** | Steer |
| **Left slider (drag up)** | Brake |
| **Right slider (drag up)** | Throttle |
| **HAND BRAKE button** | A button (handbrake) |
| **START / BACK** | Menu navigation |
| **D-Pad** | Menu navigation |

Steering sensitivity is set by `AppConstants.steeringGRange` (default 6.5 m/s² = full lock).

---

## Wire Protocol

Custom binary over TCP (no protoc needed).

```
Frame:  [content_len: u32 LE] [type: u8] [payload: ...]

0x01  Handshake   → server
0x02  ControllerPacket (68-byte payload, ~120 Hz) → server
0x81  ServerAck   ← server
```

See `rust_backend/src/protocol.rs` and `flutter_app/lib/core/packet_encoder.dart`.

---

## Architecture

```
flutter_app/lib/
├── core/
│   ├── constants.dart          shared constants
│   ├── packet_encoder.dart     binary encoding (matches protocol.rs)
│   └── tcp_client.dart         socket wrapper
├── features/
│   ├── connection/
│   │   ├── connection_provider.dart   Riverpod: connect / disconnect
│   │   └── connection_screen.dart     Android: USB setup + connect UI
│   ├── racing/
│   │   ├── racing_providers.dart      controller state + sensor pipeline
│   │   ├── packet_sender.dart         120 Hz dispatch loop
│   │   ├── racing_screen.dart         main gamepad layout
│   │   └── widgets/
│   │       ├── trigger_slider.dart    vertical drag trigger
│   │       ├── steering_indicator.dart tilt needle bar
│   │       └── gamepad_button.dart    animated press button
│   └── host/
│       └── host_screen.dart           Windows: server launcher + monitor
└── shared/
    └── theme.dart                     dark racing palette

rust_backend/src/
├── main.rs         entry point, tokio runtime
├── server.rs       TCP listener, per-client async handler
├── protocol.rs     binary packet parsing, button constants
└── controller.rs   ViGEmBus worker thread, XInput mapping
```

---

## Latency Budget (USB)

| Stage | Target |
|-------|--------|
| Sensor sampling | 8 ms (120 Hz) |
| Flutter UI frame | 1–2 ms |
| ADB USB tunnel | < 1 ms |
| Rust processing | < 1 ms |
| Game poll (XInput) | 4–8 ms |
| **Total** | **~15 ms** |

---

## Roadmap

- [ ] WiFi UDP mode (QR pairing)
- [ ] Force-feedback (HapticCmd 0x82)
- [ ] FPS layout (dual joystick + gyro aiming)
- [ ] Layout editor (drag & drop)
- [ ] Multi-controller (4-player)
- [ ] Auto ADB tunnel on USB connect
