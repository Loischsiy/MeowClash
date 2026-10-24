#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
use tokio::runtime::Runtime;
#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
use crate::service::hub::run_service;

mod service;

#[cfg(all(feature = "windows-service", target_os = "windows"))]
pub fn main() -> windows_service::Result<()> {
    if std::env::args().any(|argument| argument == "--recover-tun") {
        return match service::netstate::recover(&|line| eprintln!("{line}")) {
            Ok(_) => Ok(()),
            Err(error) => {
                eprintln!("TUN recovery failed: {error}");
                std::process::exit(1);
            }
        };
    }
    service::windows::main()
}

#[cfg(not(all(feature = "windows-service", target_os = "windows")))]
fn main() {
    if let Ok(rt) = Runtime::new() {
        rt.block_on(async {
            let _ = run_service().await;
        });
    }
}
