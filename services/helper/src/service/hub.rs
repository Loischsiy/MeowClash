use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::VecDeque;
use std::fs::File;
use std::io::{BufRead, Error, Read};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::{io, thread};
use warp::{Filter, Reply};

const LISTEN_PORT: u16 = 47890;

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct StartParams {
    pub path: String,
    pub arg: String,
    pub home_dir: Option<String>,
    #[serde(default)]
    pub tun_enabled: bool,
    #[serde(default = "default_tun_device")]
    pub tun_device: String,
}

fn default_tun_device() -> String {
    "MeowClash".to_owned()
}

#[derive(Debug, Deserialize)]
struct TunParams {
    #[serde(default = "default_tun_device")]
    device: String,
}

fn sha256_file(path: &str) -> Result<String, Error> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0; 4096];

    loop {
        let bytes_read = file.read(&mut buffer)?;
        if bytes_read == 0 {
            break;
        }
        hasher.update(&buffer[..bytes_read]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}

static LOGS: Lazy<Arc<Mutex<VecDeque<String>>>> =
    Lazy::new(|| Arc::new(Mutex::new(VecDeque::with_capacity(100))));
static PROCESS: Lazy<Arc<Mutex<Option<std::process::Child>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));
static RECOVERY_BLOCKED: Lazy<std::sync::atomic::AtomicBool> =
    Lazy::new(|| std::sync::atomic::AtomicBool::new(false));

fn start(start_params: StartParams) -> impl Reply {
    let sha256 = sha256_file(start_params.path.as_str()).unwrap_or("".to_string());
    if sha256 != env!("TOKEN") {
        return format!("The SHA256 hash of the program requesting execution is: {}. The helper program only allows execution of applications with the SHA256 hash: {}.", sha256,  env!("TOKEN"),);
    }
    if let Err(error) = stop_core() {
        log_message(format!("stopping previous core reported: {error}"));
        if start_params.tun_enabled {
            return error;
        }
    }
    if start_params.tun_enabled {
        if RECOVERY_BLOCKED.load(std::sync::atomic::Ordering::SeqCst) {
            return "TUN recovery is incomplete; refusing to start TUN".to_owned();
        }
        if let Err(error) = crate::service::netstate::cleanup(
            &start_params.tun_device,
            &log_message,
        ) {
            return error;
        }
        if let Err(error) = crate::service::netstate::prepare(
            &start_params.tun_device,
            false,
            &log_message,
        ) {
            return error;
        }
    }
    let mut process = PROCESS.lock().unwrap();
    let mut command = Command::new(&start_params.path);
    command.stderr(Stdio::piped()).arg(&start_params.arg);
    
    // Set SAFE_PATHS to prevent "path is not subpath of home directory" errors
    // This ensures the core can access provider files before SetHomeDir is called
    if let Some(home_dir) = start_params.home_dir {
        command.env("SAFE_PATHS", home_dir);
    }
    
    match command.spawn() {
        Ok(child) => {
            *process = Some(child);
            if let Some(ref mut child) = *process {
                let stderr = child.stderr.take().unwrap();
                let reader = io::BufReader::new(stderr);
                thread::spawn(move || {
                    for line in reader.lines() {
                        match line {
                            Ok(output) => {
                                log_message(output);
                            }
                            Err(_) => {
                                break;
                            }
                        }
                    }
                });
            }
            "".to_string()
        }
        Err(e) => {
            log_message(e.to_string());
            let _ = crate::service::netstate::finish(&log_message);
            e.to_string()
        }
    }
}

fn stop_core() -> Result<(), String> {
    let mut process = PROCESS.lock().unwrap();
    let had_process = process.is_some();
    if let Some(mut child) = process.take() {
        let _ = child.kill();
        let _ = child.wait();
    }
    *process = None;
    drop(process);
    if had_process {
        crate::service::netstate::finish(&log_message)
    } else {
        match crate::service::netstate::recover(&log_message)? {
            Some(marker) if marker.status != "restored" => Err("network recovery is incomplete".to_owned()),
            _ => Ok(()),
        }
    }
}

fn stop() -> impl Reply {
    stop_core().err().unwrap_or_default()
}

fn prepare_tun(params: TunParams) -> impl Reply {
    if RECOVERY_BLOCKED.load(std::sync::atomic::Ordering::SeqCst) {
        match crate::service::netstate::recover(&log_message) {
            Ok(None) => return "TUN recovery is incomplete; refusing to enable TUN".to_owned(),
            Ok(Some(marker)) if marker.status == "restored" => {
                RECOVERY_BLOCKED.store(false, std::sync::atomic::Ordering::SeqCst)
            }
            _ => return "TUN recovery is incomplete; refusing to enable TUN".to_owned(),
        }
    }
    let allow_active_lock = PROCESS.lock().unwrap().is_some();
    crate::service::netstate::prepare(&params.device, allow_active_lock, &log_message)
        .err()
        .unwrap_or_default()
}

fn finish_tun() -> impl Reply {
    crate::service::netstate::finish(&log_message)
        .err()
        .unwrap_or_default()
}

fn recover_tun() -> impl Reply {
    match crate::service::netstate::recover(&log_message) {
        Ok(None) if RECOVERY_BLOCKED.load(std::sync::atomic::Ordering::SeqCst) => {
            "network recovery remains blocked; no valid backup is available".to_owned()
        }
        Ok(None) => {
            RECOVERY_BLOCKED.store(false, std::sync::atomic::Ordering::SeqCst);
            String::new()
        }
        Ok(Some(marker)) if marker.status == "restored" => {
            RECOVERY_BLOCKED.store(false, std::sync::atomic::Ordering::SeqCst);
            String::new()
        }
        Ok(Some(_)) => "network recovery is incomplete".to_owned(),
        Err(error) => {
            RECOVERY_BLOCKED.store(true, std::sync::atomic::Ordering::SeqCst);
            error
        }
    }
}

fn cleanup_tun(params: TunParams) -> impl Reply {
    crate::service::netstate::cleanup(&params.device, &log_message)
        .err()
        .unwrap_or_default()
}

fn tun_health(params: TunParams) -> impl Reply {
    match crate::service::netstate::health(&params.device) {
        Ok(healthy) => healthy.to_string(),
        Err(error) => {
            log_message(format!("TUN health check failed: {error}"));
            "false".to_owned()
        }
    }
}

fn recovery_marker() -> impl Reply {
    match crate::service::netstate::read_marker() {
        Ok(Some(marker)) => warp::reply::with_header(marker, "Content-Type", "application/json"),
        Ok(None) => warp::reply::with_header(String::new(), "Content-Type", "application/json"),
        Err(error) => {
            log_message(format!("could not read recovery marker: {error}"));
            warp::reply::with_header(String::new(), "Content-Type", "application/json")
        }
    }
}

fn core_session() -> impl Reply {
    let mut process = PROCESS.lock().unwrap();
    let status = match process.as_mut() {
        Some(child) => child.try_wait(),
        None => return "false".to_owned(),
    };
    match status {
        Ok(None) | Err(_) => "true".to_owned(),
        Ok(Some(_)) => {
            *process = None;
            "false".to_owned()
        }
    }
}

fn shutdown_service() -> impl Reply {
    // Do not allow shutting down the Windows service via HTTP in production
    log_message("Received shutdown request - ignored".to_string());
    "Shutdown endpoint is disabled".to_string()
}

fn log_message(message: String) {
    let mut log_buffer = LOGS.lock().unwrap();
    if log_buffer.len() == 100 {
        log_buffer.pop_front();
    }
    log_buffer.push_back(format!("{}\n", message));
}

fn get_logs() -> impl Reply {
    let log_buffer = LOGS.lock().unwrap();
    let value = log_buffer
        .iter()
        .cloned()
        .collect::<Vec<String>>()
        .join("\n");
    warp::reply::with_header(value, "Content-Type", "text/plain")
}

pub async fn run_service() -> anyhow::Result<()> {
    match crate::service::netstate::recover(&log_message) {
        Ok(Some(marker)) if marker.status != "restored" => {
            RECOVERY_BLOCKED.store(true, std::sync::atomic::Ordering::SeqCst);
            log_message("boot-time network recovery was partial".to_owned());
        }
        Ok(_) => {}
        Err(error) => {
            RECOVERY_BLOCKED.store(true, std::sync::atomic::Ordering::SeqCst);
            log_message(format!("boot-time network recovery failed: {error}"));
        }
    }
    if RECOVERY_BLOCKED.load(std::sync::atomic::Ordering::SeqCst) {
        tokio::spawn(async {
            for attempt in 1..=20 {
                tokio::time::sleep(std::time::Duration::from_secs(3)).await;
                match crate::service::netstate::recover(&log_message) {
                    Ok(Some(marker)) if marker.status == "restored" => {
                        RECOVERY_BLOCKED.store(false, std::sync::atomic::Ordering::SeqCst);
                        log_message(format!("boot-time network recovery completed on retry {attempt}"));
                        break;
                    }
                    Ok(None) if !RECOVERY_BLOCKED.load(std::sync::atomic::Ordering::SeqCst) => break,
                    Ok(_) => {}
                    Err(error) => log_message(format!("network recovery retry {attempt} failed: {error}")),
                }
            }
        });
    }
    let api_ping = warp::get().and(warp::path("ping")).map(|| env!("TOKEN"));

    let api_start = warp::post()
        .and(warp::path("start"))
        .and(warp::body::json())
        .map(|start_params: StartParams| start(start_params));

    let api_stop = warp::post().and(warp::path("stop")).map(|| stop());

    let api_logs = warp::get().and(warp::path("logs")).map(|| get_logs());
    let api_tun_prepare = warp::post()
        .and(warp::path("tun"))
        .and(warp::path("prepare"))
        .and(warp::body::json())
        .map(prepare_tun);
    let api_tun_finish = warp::post()
        .and(warp::path("tun"))
        .and(warp::path("finish"))
        .map(finish_tun);
    let api_tun_recover = warp::post()
        .and(warp::path("tun"))
        .and(warp::path("recover"))
        .map(recover_tun);
    let api_tun_cleanup = warp::post()
        .and(warp::path("tuncleanup"))
        .and(warp::body::json())
        .map(cleanup_tun);
    let api_tun_health = warp::post()
        .and(warp::path("tun"))
        .and(warp::path("health"))
        .and(warp::body::json())
        .map(tun_health);
    let api_recovery = warp::get()
        .and(warp::path("recovery"))
        .map(recovery_marker);
    let api_session = warp::get()
        .and(warp::path("session"))
        .map(core_session);

    warp::serve(
        api_ping
            .or(api_start)
            .or(api_stop)
            .or(api_logs)
            .or(api_tun_prepare)
            .or(api_tun_finish)
            .or(api_tun_recover)
            .or(api_tun_cleanup)
            .or(api_tun_health)
            .or(api_recovery)
            .or(api_session),
    )
        .run(([127, 0, 0, 1], LISTEN_PORT))
        .await;

    Ok(())
}

pub fn stop_for_service() {
    if let Err(error) = stop_core() {
        log_message(format!("service shutdown network restore failed: {error}"));
    }
}
