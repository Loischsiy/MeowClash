use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct AdapterBackup {
    pub name: String,
    pub guid: String,
    pub dhcp: bool,
    #[serde(default)]
    pub dns_servers: Vec<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct TunLock {
    pub schema_version: u32,
    pub created_at: String,
    pub os: String,
    #[serde(default)]
    pub tun_device: String,
    #[serde(default)]
    pub adapters: Vec<AdapterBackup>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct RecoveryMarker {
    pub timestamp: String,
    pub status: String,
    pub restored: Vec<String>,
    pub errors: Vec<String>,
}

pub fn supported_schema(version: Option<u64>) -> bool {
    version == Some(1)
}

#[cfg(target_os = "windows")]
mod windows {
    use super::{AdapterBackup, RecoveryMarker, TunLock};
    use std::env;
    use std::fs::{self, File, OpenOptions};
    use std::io::Write;
    use std::path::{Path, PathBuf};
    use std::process::Command;
    use std::time::{SystemTime, UNIX_EPOCH};

    const APP_DEVICE: &str = "MeowClash";

    fn root() -> PathBuf {
        env::var_os("PROGRAMDATA")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                env::var_os("LOCALAPPDATA")
                    .map(PathBuf::from)
                    .unwrap_or_else(|| PathBuf::from(r"C:\ProgramData"))
            })
            .join(APP_DEVICE)
    }

    fn lock_path() -> PathBuf {
        root().join("tun.lock")
    }

    fn lock_backup_path() -> PathBuf {
        root().join("tun.lock.bak")
    }

    fn has_lock() -> bool {
        lock_path().exists() || lock_backup_path().exists()
    }

    fn marker_path() -> PathBuf {
        root().join("recovery.json")
    }

    fn log_line(log: &dyn Fn(String), message: impl AsRef<str>) {
        log(format!("[netstate] {}", message.as_ref()));
    }

    fn powershell(script: &str, envs: &[(&str, &str)]) -> Result<String, String> {
        let mut command = Command::new("powershell.exe");
        command.args(["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script]);
        for (key, value) in envs {
            command.env(key, value);
        }
        let output = command.output().map_err(|error| error.to_string())?;
        if !output.status.success() {
            return Err(format!(
                "PowerShell exited with {}: {}",
                output.status,
                String::from_utf8_lossy(&output.stderr).trim()
            ));
        }
        String::from_utf8(output.stdout).map_err(|error| error.to_string())
    }

    fn atomic_write(path: &Path, bytes: &[u8], replace: bool) -> Result<(), String> {
        let parent = path.parent().ok_or("missing parent directory")?;
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
        let suffix = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let temporary = parent.join(format!(".tun-{}-{suffix}.tmp", std::process::id()));
        let result = (|| {
            let mut file = OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&temporary)
                .map_err(|error| error.to_string())?;
            file.write_all(bytes).map_err(|error| error.to_string())?;
            file.sync_all().map_err(|error| error.to_string())?;
            if replace && path.exists() {
                fs::remove_file(path).map_err(|error| error.to_string())?;
            }
            fs::rename(&temporary, path).map_err(|error| error.to_string())?;
            if let Ok(directory) = File::open(parent) {
                let _ = directory.sync_all();
            }
            Ok(())
        })();
        if result.is_err() {
            let _ = fs::remove_file(temporary);
        }
        result
    }

    fn capture(device: &str) -> Result<TunLock, String> {
        const SCRIPT: &str = r#"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$ErrorActionPreference = 'Stop'
$physical = @(Get-NetAdapter -Physical -ErrorAction Stop | ForEach-Object { $_.ifIndex })
$adapters = @(
  Get-NetIPInterface -AddressFamily IPv4 |
    Group-Object InterfaceIndex |
    ForEach-Object {
      $ip = $_.Group[0]
      if ($ip.InterfaceIndex -notin $physical) { return }
      $adapter = Get-NetAdapter -InterfaceIndex $ip.InterfaceIndex -ErrorAction SilentlyContinue
      if ($null -eq $adapter) { return }
      $dns = @(Get-DnsClientServerAddress -InterfaceIndex $ip.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { $_.ServerAddresses })
      $registryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{' + $adapter.InterfaceGuid.ToString() + '}'
      $registry = Get-ItemProperty -LiteralPath $registryPath -ErrorAction SilentlyContinue
      [pscustomobject]@{
        name = $adapter.Name
        guid = $adapter.InterfaceGuid.ToString()
        dhcp = [string]::IsNullOrEmpty([string]$registry.NameServer)
        dns_servers = $dns
      }
    }
[pscustomobject]@{
  schema_version = 1
  created_at = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
  os = 'windows'
  tun_device = $env:MEOWCLASH_TUN_DEVICE
  adapters = $adapters
} | ConvertTo-Json -Depth 6 -Compress
"#;
        let output = powershell(SCRIPT, &[("MEOWCLASH_TUN_DEVICE", device)])?;
        let lock: TunLock = serde_json::from_str(output.trim()).map_err(|error| error.to_string())?;
        if lock.adapters.is_empty() {
            return Err("no network adapters were captured; refusing to enable TUN".to_owned());
        }
        Ok(lock)
    }

    fn parse_lock(bytes: &[u8]) -> Result<TunLock, String> {
        let value: serde_json::Value = serde_json::from_slice(&bytes)
            .map_err(|error| format!("invalid lock JSON: {error}"))?;
        let schema = value.get("schema_version").and_then(serde_json::Value::as_u64);
        let adapters = value
            .get("adapters")
            .cloned()
            .unwrap_or_else(|| serde_json::Value::Array(Vec::new()));
        let lock = TunLock {
            schema_version: schema.unwrap_or_default().min(u32::MAX as u64) as u32,
            created_at: value
                .get("created_at")
                .and_then(serde_json::Value::as_str)
                .unwrap_or_default()
                .to_owned(),
            os: value
                .get("os")
                .and_then(serde_json::Value::as_str)
                .unwrap_or_default()
                .to_owned(),
            tun_device: value
                .get("tun_device")
                .and_then(serde_json::Value::as_str)
                .unwrap_or(APP_DEVICE)
                .to_owned(),
            adapters: serde_json::from_value(adapters)
                .map_err(|error| format!("invalid adapter backup: {error}"))?,
        };
        Ok(lock)
    }

    fn read_lock() -> Result<Option<TunLock>, String> {
        let primary = lock_path();
        let backup = lock_backup_path();
        if primary.exists() {
            let bytes = fs::read(&primary).map_err(|error| error.to_string())?;
            return match parse_lock(&bytes) {
                Ok(lock) => Ok(Some(lock)),
                Err(primary_error) if backup.exists() => {
                    let backup_bytes = fs::read(backup).map_err(|error| error.to_string())?;
                    parse_lock(&backup_bytes)
                        .map(Some)
                        .map_err(|backup_error| format!("{primary_error}; backup: {backup_error}"))
                }
                Err(error) => Err(error),
            };
        }
        if backup.exists() {
            return fs::read(backup)
                .map_err(|error| error.to_string())
                .and_then(|bytes| parse_lock(&bytes).map(Some));
        }
        Ok(None)
    }

    fn restore_adapter(adapter: &AdapterBackup, dhcp_only: bool) -> Result<(), String> {
        if adapter.guid.is_empty() {
            return Err(format!("{} has no adapter GUID", adapter.name));
        }
        const SCRIPT: &str = r#"
$ErrorActionPreference = 'Stop'
$guid = '{' + $env:MEOWCLASH_ADAPTER_GUID.Trim('{}') + '}'
$adapter = Get-NetAdapter | Where-Object { $_.InterfaceGuid.ToString() -ieq $guid.Trim('{}') } | Select-Object -First 1
if ($null -eq $adapter) { throw "Adapter $guid is not present" }
$servers = @(ConvertFrom-Json -InputObject $env:MEOWCLASH_DNS_SERVERS)
$registryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\' + $guid
$useDhcp = $env:MEOWCLASH_DHCP -eq 'true' -or $servers.Count -eq 0
if ($useDhcp) {
  Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses -ErrorAction Stop
  $registry = Get-ItemProperty -LiteralPath $registryPath -ErrorAction SilentlyContinue
  if (-not [string]::IsNullOrEmpty([string]$registry.NameServer)) { throw "Adapter $guid DNS is still statically configured" }
} else {
  Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses @($servers) -ErrorAction Stop
  $actual = @(Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object { $_.ServerAddresses })
  if (Compare-Object @($servers | Sort-Object) @($actual | Sort-Object)) { throw "Adapter $guid DNS servers did not match the backup" }
}
"#;
        let dns = serde_json::to_string(&adapter.dns_servers).map_err(|error| error.to_string())?;
        powershell(
            SCRIPT,
            &[
                ("MEOWCLASH_ADAPTER_GUID", adapter.guid.as_str()),
                ("MEOWCLASH_DHCP", if dhcp_only || adapter.dhcp { "true" } else { "false" }),
                ("MEOWCLASH_DNS_SERVERS", if dhcp_only { "[]" } else { dns.as_str() }),
            ],
        )?;
        Ok(())
    }

    fn core_process_running() -> bool {
        match Command::new("tasklist")
            .args(["/FI", "IMAGENAME eq MeowClashCore.exe", "/FO", "CSV", "/NH"])
            .output()
        {
            Ok(output) => String::from_utf8_lossy(&output.stdout).contains("MeowClashCore.exe"),
            Err(_) => true,
        }
    }

    fn cleanup_leftovers(device: &str, log: &dyn Fn(String)) -> Vec<String> {
        if core_process_running() {
            log_line(log, "skipped TUN route/device cleanup because a core process is running");
            return Vec::new();
        }
        const SCRIPT: &str = r#"
$ErrorActionPreference = 'Stop'
$name = $env:MEOWCLASH_TUN_DEVICE
$adapter = Get-NetAdapter | Where-Object { $_.Name -ceq $name } | Select-Object -First 1
if ($null -ne $adapter -and $adapter.Status -ne 'Up') {
  Get-NetRoute -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue |
    Where-Object { $_.DestinationPrefix -in @('0.0.0.0/0', '198.18.0.0/16') } |
    Remove-NetRoute -Confirm:$false -ErrorAction Continue
  Get-PnpDevice -Class Net -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -ceq $name } |
    ForEach-Object { & pnputil.exe /remove-device $_.InstanceId | Out-Null }
}
"#;
        match powershell(SCRIPT, &[("MEOWCLASH_TUN_DEVICE", device)]) {
            Ok(_) => {
                log_line(log, format!("checked stale routes and adapter named '{device}'"));
                Vec::new()
            }
            Err(error) => {
                log_line(log, format!("leftover route/device cleanup failed: {error}"));
                vec![format!("TUN cleanup: {error}")]
            }
        }
    }

    fn flush_dns(log: &dyn Fn(String)) -> Result<(), String> {
        let result = Command::new("ipconfig")
            .arg("/flushdns")
            .output()
            .map_err(|error| error.to_string())?;
        if result.status.success() {
            log_line(log, "flushed DNS cache");
            Ok(())
        } else {
            Err(format!(
                "ipconfig /flushdns failed: {}",
                String::from_utf8_lossy(&result.stderr).trim()
            ))
        }
    }

    fn save_marker(marker: &RecoveryMarker) -> Result<(), String> {
        let data = serde_json::to_vec_pretty(marker).map_err(|error| error.to_string())?;
        atomic_write(&marker_path(), &data, true)
    }

    fn marker(status: &str, restored: Vec<String>, errors: Vec<String>) -> RecoveryMarker {
        let timestamp = powershell(
            "[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')",
            &[],
        )
        .map(|value| value.trim().to_owned())
        .unwrap_or_else(|_| {
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map(|duration| duration.as_secs().to_string())
                .unwrap_or_default()
        });
        RecoveryMarker {
            timestamp,
            status: status.to_owned(),
            restored,
            errors,
        }
    }

    pub fn prepare(device: &str, allow_active_lock: bool, log: &dyn Fn(String)) -> Result<(), String> {
        if let Some(lock) = read_lock()? {
            if allow_active_lock
                && super::supported_schema(Some(lock.schema_version as u64))
                && lock.tun_device == device
            {
                log_line(log, "existing write-ahead lock retained for the active TUN session");
                return Ok(());
            }
            return Err("an unsupported TUN lock must be recovered before enabling TUN".to_owned());
        }
        let lock = capture(device)?;
        let bytes = serde_json::to_vec_pretty(&lock).map_err(|error| error.to_string())?;
        atomic_write(&lock_path(), &bytes, false)?;
        if let Err(error) = atomic_write(&lock_backup_path(), &bytes, true) {
            let _ = fs::remove_file(lock_path());
            return Err(error);
        }
        log_line(log, format!("durable TUN backup saved for {} adapters", lock.adapters.len()));
        Ok(())
    }

    pub fn recover(log: &dyn Fn(String)) -> Result<Option<RecoveryMarker>, String> {
        if !has_lock() {
            return Ok(None);
        }
        log_line(log, "write-ahead lock found; restoring the previous network state");
        let lock = match read_lock() {
            Ok(Some(lock)) => lock,
            Ok(None) => return Ok(None),
            Err(error) => {
                let report = marker("failed", Vec::new(), vec![error.clone()]);
                let _ = save_marker(&report);
                log_line(log, format!("invalid lock removed without touching unlisted adapters: {error}"));
                if lock_path().exists() {
                    fs::remove_file(lock_path()).map_err(|remove_error| remove_error.to_string())?;
                }
                if lock_backup_path().exists() {
                    fs::remove_file(lock_backup_path())
                        .map_err(|remove_error| remove_error.to_string())?;
                }
                return Ok(Some(report));
            }
        };

        let supported = super::supported_schema(Some(lock.schema_version as u64)) && lock.os == "windows";
        if !supported {
            log_line(log, format!("unsupported lock schema {}; resetting listed adapters to DHCP", lock.schema_version));
        }
        let mut restored = Vec::new();
        let mut errors = Vec::new();
        if lock.adapters.is_empty() {
            errors.push("lock contains no adapters; no network interfaces were changed".to_owned());
        }
        for adapter in &lock.adapters {
            let dhcp_only = !supported;
            match restore_adapter(adapter, dhcp_only) {
                Ok(()) => {
                    let action = if dhcp_only || adapter.dhcp || adapter.dns_servers.is_empty() {
                        "DNS reset to DHCP"
                    } else {
                        "static DNS restored"
                    };
                    restored.push(format!("{}: {action}", adapter.name));
                    log_line(log, format!("{} — {action}", adapter.name));
                }
                Err(error) => {
                    errors.push(format!("{}: {error}", adapter.name));
                    log_line(log, format!("{} — restore failed: {error}", adapter.name));
                }
            }
        }
        if let Err(error) = flush_dns(log) {
            errors.push(error);
        }
        if supported {
            errors.extend(cleanup_leftovers(&lock.tun_device, log));
        }
        let report = marker(if errors.is_empty() { "restored" } else { "partial" }, restored, errors);
        save_marker(&report)?;
        if report.status == "restored" {
            if lock_path().exists() {
                fs::remove_file(lock_path()).map_err(|error| error.to_string())?;
            }
            if lock_backup_path().exists() {
                fs::remove_file(lock_backup_path()).map_err(|error| error.to_string())?;
            }
            log_line(log, "recovery completed; write-ahead lock deleted");
        } else {
            log_line(log, "recovery was partial; keeping the lock for the next boot retry");
        }
        Ok(Some(report))
    }

    pub fn finish(log: &dyn Fn(String)) -> Result<(), String> {
        let Some(lock) = read_lock()? else { return Ok(()) };
        if !super::supported_schema(Some(lock.schema_version as u64)) || lock.os != "windows" {
            return Err("unsupported TUN lock; use boot recovery before finishing the session".to_owned());
        }
        let mut errors = Vec::new();
        for adapter in &lock.adapters {
            if let Err(error) = restore_adapter(adapter, false) {
                errors.push(format!("{}: {error}", adapter.name));
            }
        }
        if let Err(error) = flush_dns(log) {
            errors.push(error);
        }
        if errors.is_empty() {
            if lock_path().exists() {
                fs::remove_file(lock_path()).map_err(|error| error.to_string())?;
            }
            if lock_backup_path().exists() {
                fs::remove_file(lock_backup_path()).map_err(|error| error.to_string())?;
            }
            log_line(log, "TUN stopped; backed-up DNS verified by successful restore and lock deleted");
            Ok(())
        } else {
            log_line(log, format!("TUN restore incomplete; keeping lock: {}", errors.join("; ")));
            Err(errors.join("; "))
        }
    }

    pub fn cleanup(device: &str, log: &dyn Fn(String)) -> Result<(), String> {
        if has_lock() {
            return Err("cannot clean the TUN adapter while a recovery lock exists".to_owned());
        }
        let errors = cleanup_leftovers(device, log);
        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors.join("; "))
        }
    }

    pub fn health(device: &str) -> Result<bool, String> {
        const SCRIPT: &str = r#"
$ErrorActionPreference = 'Stop'
$adapter = Get-NetAdapter | Where-Object { $_.Name -ceq $env:MEOWCLASH_TUN_DEVICE } | Select-Object -First 1
$route = $false
if ($null -ne $adapter) {
  $route = $null -ne (Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 1)
}
[pscustomobject]@{ adapter = ($null -ne $adapter); default_route = $route } | ConvertTo-Json -Compress
"#;
        let output = powershell(SCRIPT, &[("MEOWCLASH_TUN_DEVICE", device)])?;
        let value: serde_json::Value = serde_json::from_str(output.trim()).map_err(|error| error.to_string())?;
        Ok(value["adapter"].as_bool() == Some(true)
            && value["default_route"].as_bool() == Some(true))
    }

    pub fn read_marker() -> Result<Option<String>, String> {
        let path = marker_path();
        if !path.exists() {
            return Ok(None);
        }
        let value = fs::read_to_string(&path).map_err(|error| error.to_string())?;
        fs::remove_file(path).map_err(|error| error.to_string())?;
        Ok(Some(value))
    }
}

#[cfg(target_os = "windows")]
pub use windows::{cleanup, finish, health, prepare, read_marker, recover};

#[cfg(not(target_os = "windows"))]
pub fn recover(_log: &dyn Fn(String)) -> Result<Option<RecoveryMarker>, String> {
    Ok(None)
}

#[cfg(not(target_os = "windows"))]
pub fn prepare(_device: &str, _allow_active_lock: bool, _log: &dyn Fn(String)) -> Result<(), String> {
    Ok(())
}

#[cfg(not(target_os = "windows"))]
pub fn finish(_log: &dyn Fn(String)) -> Result<(), String> {
    Ok(())
}

#[cfg(not(target_os = "windows"))]
pub fn cleanup(_device: &str, _log: &dyn Fn(String)) -> Result<(), String> {
    Ok(())
}

#[cfg(not(target_os = "windows"))]
pub fn health(_device: &str) -> Result<bool, String> {
    Ok(true)
}

#[cfg(not(target_os = "windows"))]
pub fn read_marker() -> Result<Option<String>, String> {
    Ok(None)
}

#[cfg(test)]
mod tests {
    use super::{supported_schema, AdapterBackup, TunLock};

    #[test]
    fn lock_schema_round_trips() {
        let lock = TunLock {
            schema_version: 1,
            created_at: "2026-10-23T12:00:00Z".to_owned(),
            os: "windows".to_owned(),
            tun_device: "MeowClash".to_owned(),
            adapters: vec![AdapterBackup {
                name: "Wi-Fi".to_owned(),
                guid: "{1234}".to_owned(),
                dhcp: false,
                dns_servers: vec!["192.168.1.1".to_owned()],
            }],
        };
        let encoded = serde_json::to_vec(&lock).unwrap();
        let decoded: TunLock = serde_json::from_slice(&encoded).unwrap();
        assert_eq!(decoded.schema_version, 1);
        assert_eq!(decoded.adapters[0].dns_servers[0], "192.168.1.1");
        assert!(!decoded.adapters[0].dhcp);
    }

    #[test]
    fn recovery_uses_dhcp_fallback_for_unknown_schema() {
        assert!(supported_schema(Some(1)));
        assert!(!supported_schema(Some(2)));
        assert!(!supported_schema(None));
        assert!(serde_json::from_str::<TunLock>("not json").is_err());
    }
}
