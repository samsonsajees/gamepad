use std::sync::Arc;

use anyhow::Result;
use log::{info, warn};
use tokio::net::UdpSocket;

use crate::controller::{ControllerHandle, ControllerPacket};
use crate::protocol::parse_controller_packet;
use crate::session::SessionToken;

// ─────────────────────────────────────────────────────────────────────────────
// UdpServer
// ─────────────────────────────────────────────────────────────────────────────
//
// UDP packet format (Android → Windows):
//
//   [token    : u32 LE]   4 bytes  — session authentication
//   [type     : u8    ]   1 byte
//   [payload  : ...   ]   N bytes
//
// Types (same numeric values as TCP):
//   0x01  Handshake  (player_id:4, name_len:1, name:N, layout_len:1, layout:M)
//   0x02  ControllerPacket  (68-byte fixed payload)
//
// No length prefix — UDP packets carry their own length.
// ─────────────────────────────────────────────────────────────────────────────

pub struct UdpServer {
    socket:  tokio::net::UdpSocket,
    ctrl:    Arc<ControllerHandle>,
    token:   SessionToken,
}

impl UdpServer {
    pub fn new(socket: tokio::net::UdpSocket, ctrl: Arc<ControllerHandle>, token: SessionToken) -> Self {
        Self { socket, ctrl, token }
    }

    pub async fn run(self) -> Result<()> {
        let addr = self.socket.local_addr()?;

        info!("UDP server listening on {}", addr);
        println!(
            r#"{{"event":"udp_started","port":{}}}"#,
            addr.port()
        );

        let mut buf = vec![0u8; 512];

        loop {
            let (len, src) = match self.socket.recv_from(&mut buf).await {
                Ok(v)  => v,
                Err(e) => { warn!("UDP recv error: {}", e); continue; }
            };

            let data = &buf[..len];

            // Minimum: token(4) + type(1) = 5 bytes
            if data.len() < 5 {
                continue;
            }

            // ── Token check ───────────────────────────────────────────────
            let recv_token = u32::from_le_bytes(
                data[0..4].try_into().unwrap_or_default(),
            );
            if !self.token.validate(recv_token) {
                warn!("Bad token from {} — expected {} got {}", src, self.token, recv_token);
                continue;
            }

            let packet_type = data[4];
            let payload     = &data[5..];

            match packet_type {
                // ── Handshake ─────────────────────────────────────────────
                0x01 => {
                    if payload.len() < 4 { continue; }
                    let player_id = u32::from_le_bytes(
                        payload[0..4].try_into().unwrap_or_default(),
                    );
                    self.ctrl.add(player_id);
                    info!("WiFi handshake from P{} at {}", player_id, src);
                }

                // ── ControllerPacket ──────────────────────────────────────
                0x02 => {
                    if let Ok(pkt) = parse_controller_packet(payload) {
                        self.ctrl.update(pkt);
                    }
                }

                _ => warn!("Unknown UDP type 0x{:02X} from {}", packet_type, src),
            }
        }
    }
}
