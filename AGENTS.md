# Gamepad Claude Project Instructions

This project aims to turn an Android phone into an Xbox-compatible racing controller for Windows games using a USB cable.

## Technologies Used
- **Flutter**: For both Android and Windows applications.
- **Rust**: For the gamepad server on Windows.
- **ViGEmBus**: A virtual gamepad bus driver for Windows.
- **Android Platform Tools (ADB)**: For USB communication with Android devices.

## Project Structure
- `flutter_app/`: Contains the Flutter application for both Android and Windows.
    - `lib/core/`: Shared constants, binary encoding, TCP client.
    - `lib/features/`: Connection management, racing game logic, Windows host screen.
    - `lib/shared/`: Theming.
- `rust_backend/`: Contains the Rust server application.
    - `src/main.rs`: Entry point.
    - `src/server.rs`: TCP listener and client handler.
    - `src/protocol.rs`: Binary packet parsing and button constants.
    - `src/controller.rs`: ViGEmBus worker thread and XInput mapping.
- `setup_usb.ps1`: PowerShell script for setting up the USB tunnel.

## Quick Start / Build Commands

### 1. Build the Rust server (Windows)
```powershell
cd rust_backend
cargo build --release
```

### 2. Build & run the Windows Flutter host
```powershell
cd flutter_app
flutter run -d windows
```
**Note**: Copy `rust_backend\target\release\gamepad_server.exe` to the same folder as the Flutter Windows app before running.

### 3. Set up USB tunnel
```powershell
.\setup_usb.ps1
# Or manually:
adb reverse tcp:5000 tcp:5000
```

### 4. Run the Android app
```powershell
cd flutter_app
flutter run -d <your-android-device>
```

## Android Permissions
Ensure the following permissions are added to `flutter_app/android/app/src/main/AndroidManifest.xml` (inside `<manifest>` tag, before `<application>`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

## Further Documentation
- **Wire Protocol**: See `rust_backend/src/protocol.rs` and `flutter_app/lib/core/packet_encoder.dart`.
- **Roadmap**: Refer to the `Roadmap` section in `README.md` for future features.
