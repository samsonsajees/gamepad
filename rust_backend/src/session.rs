/// Lightweight session token used to authenticate WiFi UDP packets.
///
/// Generated once at server startup from system time + a mixing constant.
/// Displayed as a QR code by the Windows Flutter host so the Android app
/// can include it in every UDP packet.
#[derive(Clone, Copy, Debug)]
pub struct SessionToken {
    pub value: u32,
}

impl SessionToken {
    /// Derive a pseudo-random token from the current nanosecond clock.
    /// Good enough for LAN authentication — not cryptographic.
    pub fn generate() -> Self {
        use std::time::{SystemTime, UNIX_EPOCH};
        let ns = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .subsec_nanos();
        // Mix with a constant to avoid obvious values
        Self { value: ns ^ 0xA5_F3_C7_91 }
    }

    pub fn validate(&self, candidate: u32) -> bool {
        candidate == self.value
    }
}

impl std::fmt::Display for SessionToken {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.value)
    }
}
