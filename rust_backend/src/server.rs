use std::sync::Arc;

use anyhow::Result;
use log::{error, info, warn};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
};

use crate::controller::ControllerHandle;
use crate::protocol::{parse_controller_packet, parse_handshake};

// ─────────────────────────────────────────────────────────────────────────────
// Server
// ─────────────────────────────────────────────────────────────────────────────

pub struct Server {
    port:       u16,
    controller: Arc<ControllerHandle>,
}

impl Server {
    pub fn new(port: u16, controller: Arc<ControllerHandle>) -> Self {
        Self { port, controller }
    }

    pub async fn run(&self) -> Result<()> {
        let addr = format!("0.0.0.0:{}", self.port);
        let listener = TcpListener::bind(&addr).await?;

        info!("GamePad Server listening on {}", addr);
        // JSON status events are read by the Flutter Windows host
        println!(r#"{{"event":"server_started","port":{}}}"#, self.port);

        loop {
            match listener.accept().await {
                Ok((socket, addr)) => {
                    info!("Client connected: {}", addr);
                    let ctrl = Arc::clone(&self.controller);
                    tokio::spawn(async move {
                        if let Err(e) = handle_client(socket, ctrl).await {
                            let msg = e.to_string();
                            if !msg.contains("UnexpectedEof")
                                && !msg.contains("Connection reset")
                                && !msg.contains("os error 10054")
                            {
                                error!("Client error: {}", e);
                            }
                        }
                    });
                }
                Err(e) => error!("Accept error: {}", e),
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-client handler
// ─────────────────────────────────────────────────────────────────────────────

/// Wire format (both directions):
///   [length: u32 LE]  — number of bytes that follow (includes the type byte)
///   [type:   u8    ]
///   [payload: ...]
///
/// Client → Server types:
///   0x01  Handshake
///   0x02  ControllerPacket  (sent at ~120 Hz)
///
/// Server → Client types:
///   0x81  ServerAck (response to handshake)
async fn handle_client(
    mut socket: tokio::net::TcpStream,
    controller: Arc<ControllerHandle>,
) -> Result<()> {
    let mut len_buf = [0u8; 4];
    let mut player_id: Option<u32> = None;

    loop {
        // ── read length prefix ────────────────────────────────────────────
        socket.read_exact(&mut len_buf).await?;
        let content_len = u32::from_le_bytes(len_buf) as usize;

        if content_len == 0 || content_len > 4096 {
            warn!("Invalid content length: {}", content_len);
            break;
        }

        // ── read content (type byte + payload) ────────────────────────────
        let mut content = vec![0u8; content_len];
        socket.read_exact(&mut content).await?;

        let packet_type = content[0];
        let payload = &content[1..];

        match packet_type {
            // ── Handshake ─────────────────────────────────────────────────
            0x01 => match parse_handshake(payload) {
                Ok(hs) => {
                    let pid = hs.player_id;
                    info!(
                        "Handshake: player={} device='{}' layout='{}'",
                        pid, hs.device_name, hs.layout
                    );
                    player_id = Some(pid);
                    controller.add(pid);

                    // Send ServerAck: [len=6][0x81][success=1][player_id: 4 bytes]
                    let mut ack = Vec::with_capacity(10);
                    ack.extend_from_slice(&6u32.to_le_bytes()); // content length
                    ack.push(0x81);                              // type: ack
                    ack.push(1);                                 // success = true
                    ack.extend_from_slice(&pid.to_le_bytes());  // assigned player id
                    socket.write_all(&ack).await?;
                }
                Err(e) => warn!("Bad handshake: {}", e),
            },

            // ── ControllerPacket ──────────────────────────────────────────
            0x02 => {
                if let Ok(pkt) = parse_controller_packet(payload) {
                    let pid = player_id.unwrap_or(pkt.player_id);
                    controller.update(crate::controller::ControllerPacket {
                        player_id: pid,
                        ..pkt
                    });
                }
            }

            _ => warn!("Unknown packet type: 0x{:02X}", packet_type),
        }
    }

    // ── Cleanup on disconnect ─────────────────────────────────────────────
    if let Some(pid) = player_id {
        controller.remove(pid);
        info!("Player {} disconnected", pid);
    }

    Ok(())
}
