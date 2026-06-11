mod controller;
mod protocol;
mod server;
mod session;
mod udp_server;

use std::sync::Arc;

use anyhow::Result;

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::Builder::from_env(
        env_logger::Env::default().default_filter_or("info"),
    )
    .init();

    let tcp_port: u16 = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(5000);

    let udp_port: u16 = tcp_port + 1; // 5001 by default

    // Session token — printed as JSON for the Flutter Windows host to display
    let token = session::SessionToken::generate();

    let ctrl = Arc::new(controller::ControllerHandle::new()?);

    // Emit one JSON line with all connection params; Flutter host reads stdout
    println!(
        r#"{{"event":"session_info","tcp_port":{},"udp_port":{},"token":{}}}"#,
        tcp_port, udp_port, token
    );

    let tcp_srv = server::Server::new(tcp_port, Arc::clone(&ctrl));
    let udp_srv = udp_server::UdpServer::new(udp_port, Arc::clone(&ctrl), token);

    // Watch stdin: if the parent Flutter process dies, the stdin pipe breaks.
    // This guarantees the server won't become an orphaned background process!
    tokio::spawn(async {
        use tokio::io::AsyncReadExt;
        let mut stdin = tokio::io::stdin();
        let mut buf = [0u8; 1];
        let _ = stdin.read(&mut buf).await;
        log::info!("Stdin closed/broken. Parent died. Exiting.");
        std::process::exit(0);
    });

    // Run both servers; if either fails the whole process exits
    tokio::try_join!(tcp_srv.run(), udp_srv.run())?;

    Ok(())
}
