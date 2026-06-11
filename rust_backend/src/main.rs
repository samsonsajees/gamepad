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
        .unwrap_or(0);

    let mut tcp_listener = None;
    let mut udp_socket = None;

    if tcp_port == 0 {
        // Find dynamic sequential ports
        for _ in 0..100 {
            if let Ok(listener) = tokio::net::TcpListener::bind("0.0.0.0:0").await {
                let actual_tcp_port = listener.local_addr().unwrap().port();
                if let Ok(socket) = tokio::net::UdpSocket::bind(format!("0.0.0.0:{}", actual_tcp_port + 1)).await {
                    tcp_listener = Some(listener);
                    udp_socket = Some(socket);
                    break;
                }
            }
        }
    } else {
        let udp_port = if std::env::args().len() > 2 {
            std::env::args().nth(2).and_then(|s| s.parse().ok()).unwrap_or(tcp_port + 1)
        } else {
            tcp_port + 1
        };
        tcp_listener = Some(tokio::net::TcpListener::bind(format!("0.0.0.0:{}", tcp_port)).await?);
        udp_socket = Some(tokio::net::UdpSocket::bind(format!("0.0.0.0:{}", udp_port)).await?);
    }

    let tcp_listener = tcp_listener.expect("Failed to find free sequential ports");
    let udp_socket = udp_socket.expect("Failed to bind UDP socket");

    let actual_tcp_port = tcp_listener.local_addr()?.port();
    let actual_udp_port = udp_socket.local_addr()?.port();

    // Session token — printed as JSON for the Flutter Windows host to display
    let token = session::SessionToken::generate();

    let ctrl = Arc::new(controller::ControllerHandle::new()?);

    // Emit one JSON line with all connection params; Flutter host reads stdout
    println!(
        r#"{{"event":"session_info","tcp_port":{},"udp_port":{},"token":{}}}"#,
        actual_tcp_port, actual_udp_port, token
    );

    let tcp_srv = server::Server::new(tcp_listener, Arc::clone(&ctrl));
    let udp_srv = udp_server::UdpServer::new(udp_socket, Arc::clone(&ctrl), token);

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
