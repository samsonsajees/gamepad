/// Which transport the Android controller uses.
///
/// USB   → TCP over ADB reverse tunnel (127.0.0.1:5000)
/// WiFi  → UDP over LAN             (PC_IP:5001, token-authenticated)
enum ConnectionMode { usb, wifi }
