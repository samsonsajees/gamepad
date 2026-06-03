use std::{collections::HashMap, sync::mpsc, thread};

use anyhow::Result;
use log::{error, info};
use vigem_client::{Client, TargetId, Xbox360Wired, XGamepad, XButtons};

use crate::protocol::buttons;

// ─────────────────────────────────────────────────────────────────────────────
// Public types
// ─────────────────────────────────────────────────────────────────────────────

/// Full controller state received from the Android app.
#[derive(Clone, Debug, Default)]
pub struct ControllerPacket {
    pub player_id:     u32,
    pub sequence:      u32,
    pub timestamp:     u64,
    pub left_x:        f32,
    pub left_y:        f32,
    pub right_x:       f32,
    pub right_y:       f32,
    pub left_trigger:  f32,
    pub right_trigger: f32,
    pub buttons:       u32,
    pub gyro_x:        f32,
    pub gyro_y:        f32,
    pub gyro_z:        f32,
    pub accel_x:       f32,
    pub accel_y:       f32,
    pub accel_z:       f32,
}

/// Commands sent to the dedicated ViGEmBus thread.
enum Cmd {
    Add(u32),
    Update(u32, Box<ControllerPacket>),
    Remove(u32),
}

// ─────────────────────────────────────────────────────────────────────────────
// ControllerHandle  –  cheap Clone, send commands from async context
// ─────────────────────────────────────────────────────────────────────────────

pub struct ControllerHandle {
    tx: mpsc::SyncSender<Cmd>,
}

impl ControllerHandle {
    /// Spawns the dedicated ViGEm worker thread and returns a handle.
    pub fn new() -> Result<Self> {
        let (tx, rx) = mpsc::sync_channel::<Cmd>(512);

        thread::Builder::new()
            .name("vigem-worker".into())
            .spawn(move || vigem_thread(rx))?;

        Ok(Self { tx })
    }

    pub fn add(&self, player_id: u32) {
        let _ = self.tx.send(Cmd::Add(player_id));
    }

    pub fn update(&self, packet: ControllerPacket) {
        let pid = packet.player_id;
        let _ = self.tx.send(Cmd::Update(pid, Box::new(packet)));
    }

    pub fn remove(&self, player_id: u32) {
        let _ = self.tx.send(Cmd::Remove(player_id));
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// ViGEm worker thread
// ─────────────────────────────────────────────────────────────────────────────
//
// All ViGEmBus COM calls happen here – they must stay on a single thread.
// Each player slot gets its own Client connection so the Xbox360Wired target
// can hold an owned Client value (vigem-client 0.1 API).

fn vigem_thread(rx: mpsc::Receiver<Cmd>) {
    // Slot: Xbox360Wired owns its Client
    let mut slots: HashMap<u32, Xbox360Wired<Client>> = HashMap::new();

    info!("ViGEm worker thread started");

    while let Ok(cmd) = rx.recv() {
        match cmd {
            Cmd::Add(pid) => {
                if slots.contains_key(&pid) {
                    continue;
                }
                match Client::connect() {
                    Ok(client) => {
                        let mut target =
                            Xbox360Wired::new(client, TargetId::XBOX360_WIRED);
                        match target.plugin() {
                            Ok(_) => {}
                            Err(e) => {
                                error!("Failed to plugin controller P{}: {}", pid, e);
                                continue;
                            }
                        }
                        if let Err(e) = target.wait_ready() {
                            error!("Controller P{} not ready: {}", pid, e);
                            continue;
                        }
                        slots.insert(pid, target);
                        info!("Virtual Xbox 360 controller created for P{}", pid);
                        // JSON event read by Flutter Windows host
                        println!(
                            r#"{{"event":"player_connected","player_id":{}}}"#,
                            pid
                        );
                    }
                    Err(e) => {
                        error!("ViGEmBus connect failed for P{}: {}", pid, e);
                        eprintln!(
                            "ERROR: Cannot connect to ViGEmBus. \
                             Install the driver from https://github.com/nefarius/ViGEmBus/releases"
                        );
                    }
                }
            }

            Cmd::Update(pid, pkt) => {
                if let Some(target) = slots.get_mut(&pid) {
                    let report = map_to_xinput(&pkt);
                    if let Err(e) = target.update(&report) {
                        error!("Controller P{} update failed: {}", pid, e);
                    }
                }
            }

            Cmd::Remove(pid) => {
                if let Some(mut target) = slots.remove(&pid) {
                    let _ = target.unplug();
                    println!(
                        r#"{{"event":"player_disconnected","player_id":{}}}"#,
                        pid
                    );
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Packet → XInput mapping
// ─────────────────────────────────────────────────────────────────────────────

fn map_to_xinput(p: &ControllerPacket) -> XGamepad {
    // XInput button bitmasks (XUSB_GAMEPAD_*)
    const DPAD_UP:    u16 = 0x0001;
    const DPAD_DOWN:  u16 = 0x0002;
    const DPAD_LEFT:  u16 = 0x0004;
    const DPAD_RIGHT: u16 = 0x0008;
    const START:      u16 = 0x0010;
    const BACK:       u16 = 0x0020;
    const L_THUMB:    u16 = 0x0040;
    const R_THUMB:    u16 = 0x0080;
    const LB:         u16 = 0x0100;
    const RB:         u16 = 0x0200;
    const BTN_A:      u16 = 0x1000;
    const BTN_B:      u16 = 0x2000;
    const BTN_X:      u16 = 0x4000;
    const BTN_Y:      u16 = 0x8000;

    let b = p.buttons;
    let mut w: u16 = 0;
    if b & buttons::A         != 0 { w |= BTN_A; }
    if b & buttons::B         != 0 { w |= BTN_B; }
    if b & buttons::X         != 0 { w |= BTN_X; }
    if b & buttons::Y         != 0 { w |= BTN_Y; }
    if b & buttons::LB        != 0 { w |= LB; }
    if b & buttons::RB        != 0 { w |= RB; }
    if b & buttons::START     != 0 { w |= START; }
    if b & buttons::BACK      != 0 { w |= BACK; }
    if b & buttons::L_THUMB   != 0 { w |= L_THUMB; }
    if b & buttons::R_THUMB   != 0 { w |= R_THUMB; }
    if b & buttons::DPAD_UP   != 0 { w |= DPAD_UP; }
    if b & buttons::DPAD_DOWN != 0 { w |= DPAD_DOWN; }
    if b & buttons::DPAD_LEFT != 0 { w |= DPAD_LEFT; }
    if b & buttons::DPAD_RIGHT!= 0 { w |= DPAD_RIGHT; }

    XGamepad {
        buttons: XButtons::from(w),
        left_trigger: (p.left_trigger.clamp(0.0, 1.0) * 255.0) as u8,
        right_trigger: (p.right_trigger.clamp(0.0, 1.0) * 255.0) as u8,
        thumb_lx: (p.left_x.clamp(-1.0, 1.0) * 32767.0) as i16,
        thumb_ly: (p.left_y.clamp(-1.0, 1.0) * 32767.0) as i16,
        thumb_rx: (p.right_x.clamp(-1.0, 1.0) * 32767.0) as i16,
        thumb_ry: (p.right_y.clamp(-1.0, 1.0) * 32767.0) as i16,
    }
}
