mod controller;
mod protocol;
mod server;

use anyhow::Result;
use std::sync::Arc;

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::Builder::from_env(
        env_logger::Env::default().default_filter_or("info"),
    )
    .init();

    let port: u16 = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(5000);

    // Controller manager runs on its own dedicated thread
    // (ViGEmBus COM calls need thread affinity)
    let ctrl_handle = Arc::new(controller::ControllerHandle::new()?);

    let srv = server::Server::new(port, Arc::clone(&ctrl_handle));
    srv.run().await
}
