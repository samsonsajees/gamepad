use anyhow::{anyhow, Result};

use crate::controller::ControllerPacket;

// ─────────────────────────────────────────────────────────────────────────────
// Binary protocol layout (all values little-endian)
// ─────────────────────────────────────────────────────────────────────────────
//
// HANDSHAKE payload  (variable):
//   player_id  : u32   (4 bytes)
//   name_len   : u8    (1 byte)
//   name       : utf-8 (name_len bytes)
//   layout_len : u8    (1 byte)
//   layout     : utf-8 (layout_len bytes)
//
// CONTROLLER PACKET payload  (68 bytes, fixed):
//   player_id    : u32  (4)
//   sequence     : u32  (4)
//   timestamp    : u64  (8)   microseconds since epoch
//   left_x       : f32  (4)   [-1, 1]
//   left_y       : f32  (4)   [-1, 1]
//   right_x      : f32  (4)   [-1, 1]
//   right_y      : f32  (4)   [-1, 1]
//   left_trigger : f32  (4)   [0, 1]
//   right_trigger: f32  (4)   [0, 1]
//   buttons      : u32  (4)   bitmask
//   gyro_x       : f32  (4)
//   gyro_y       : f32  (4)
//   gyro_z       : f32  (4)
//   accel_x      : f32  (4)
//   accel_y      : f32  (4)
//   accel_z      : f32  (4)
//   Total: 4+4+8+13*4 = 68 bytes
// ─────────────────────────────────────────────────────────────────────────────

// ── Handshake ─────────────────────────────────────────────────────────────────

pub struct HandshakeData {
    pub player_id:   u32,
    pub device_name: String,
    pub layout:      String,
}

pub fn parse_handshake(data: &[u8]) -> Result<HandshakeData> {
    if data.len() < 6 {
        return Err(anyhow!("Handshake payload too short ({} bytes)", data.len()));
    }

    let mut off = 0usize;
    let player_id = read_u32(data, &mut off)?;
    let name_len  = read_u8(data, &mut off)? as usize;

    if data.len() < off + name_len + 1 {
        return Err(anyhow!("Handshake truncated at device name"));
    }
    let device_name = String::from_utf8(data[off..off + name_len].to_vec())?;
    off += name_len;

    let layout_len = read_u8(data, &mut off)? as usize;
    let layout = if data.len() >= off + layout_len {
        String::from_utf8(data[off..off + layout_len].to_vec())?
    } else {
        "unknown".into()
    };

    Ok(HandshakeData { player_id, device_name, layout })
}

// ── ControllerPacket ──────────────────────────────────────────────────────────

pub fn parse_controller_packet(data: &[u8]) -> Result<ControllerPacket> {
    const EXPECTED: usize = 68;
    if data.len() < EXPECTED {
        return Err(anyhow!(
            "ControllerPacket payload too short: got {} expected {}",
            data.len(),
            EXPECTED
        ));
    }

    let mut off = 0usize;

    Ok(ControllerPacket {
        player_id:     read_u32(data, &mut off)?,
        sequence:      read_u32(data, &mut off)?,
        timestamp:     read_u64(data, &mut off)?,
        left_x:        read_f32(data, &mut off)?,
        left_y:        read_f32(data, &mut off)?,
        right_x:       read_f32(data, &mut off)?,
        right_y:       read_f32(data, &mut off)?,
        left_trigger:  read_f32(data, &mut off)?,
        right_trigger: read_f32(data, &mut off)?,
        buttons:       read_u32(data, &mut off)?,
        gyro_x:        read_f32(data, &mut off)?,
        gyro_y:        read_f32(data, &mut off)?,
        gyro_z:        read_f32(data, &mut off)?,
        accel_x:       read_f32(data, &mut off)?,
        accel_y:       read_f32(data, &mut off)?,
        accel_z:       read_f32(data, &mut off)?,
    })
}

// ── Helpers ───────────────────────────────────────────────────────────────────

fn read_u8(data: &[u8], off: &mut usize) -> Result<u8> {
    if *off >= data.len() { return Err(anyhow!("read_u8: out of bounds")); }
    let v = data[*off]; *off += 1; Ok(v)
}

fn read_u32(data: &[u8], off: &mut usize) -> Result<u32> {
    let end = *off + 4;
    if end > data.len() { return Err(anyhow!("read_u32: out of bounds")); }
    let v = u32::from_le_bytes(data[*off..end].try_into()?);
    *off = end; Ok(v)
}

fn read_u64(data: &[u8], off: &mut usize) -> Result<u64> {
    let end = *off + 8;
    if end > data.len() { return Err(anyhow!("read_u64: out of bounds")); }
    let v = u64::from_le_bytes(data[*off..end].try_into()?);
    *off = end; Ok(v)
}

fn read_f32(data: &[u8], off: &mut usize) -> Result<f32> {
    let end = *off + 4;
    if end > data.len() { return Err(anyhow!("read_f32: out of bounds")); }
    let v = f32::from_le_bytes(data[*off..end].try_into()?);
    *off = end; Ok(v)
}

// ── Button bitmask constants ──────────────────────────────────────────────────
// Must match PacketEncoder constants in Flutter

#[allow(dead_code)]
pub mod buttons {
    pub const A:          u32 = 1 << 0;
    pub const B:          u32 = 1 << 1;
    pub const X:          u32 = 1 << 2;
    pub const Y:          u32 = 1 << 3;
    pub const LB:         u32 = 1 << 4;
    pub const RB:         u32 = 1 << 5;
    pub const START:      u32 = 1 << 6;
    pub const BACK:       u32 = 1 << 7;
    pub const L_THUMB:    u32 = 1 << 8;
    pub const R_THUMB:    u32 = 1 << 9;
    pub const DPAD_UP:    u32 = 1 << 10;
    pub const DPAD_DOWN:  u32 = 1 << 11;
    pub const DPAD_LEFT:  u32 = 1 << 12;
    pub const DPAD_RIGHT: u32 = 1 << 13;
}
