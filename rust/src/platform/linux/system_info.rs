use crate::api::simple::SystemInfo;
use std::time::{SystemTime, UNIX_EPOCH};

pub fn get_system_info_impl() -> SystemInfo {
    let os_name = "Linux".to_string();
    // OS version from /etc/os-release
    let os_version = std::fs::read_to_string("/etc/os-release").ok().and_then(|data| {
        let mut name = None; let mut version = None;
        for line in data.lines() {
            if line.starts_with("NAME=") { name = Some(line.trim_start_matches("NAME=").trim_matches('"').to_string()); }
            if line.starts_with("VERSION=") { version = Some(line.trim_start_matches("VERSION=").trim_matches('"').to_string()); }
        }
        match (name, version) { (Some(n), Some(v)) => Some(format!("{} {}", n, v)), (Some(n), None) => Some(n), _ => None }
    }).unwrap_or_else(|| "Unknown".to_string());

    let kernel_version = unsafe {
        let mut uts: libc::utsname = std::mem::zeroed();
        if libc::uname(&mut uts) == 0 {
            let c_str = std::ffi::CStr::from_ptr(uts.release.as_ptr());
            c_str.to_string_lossy().into_owned()
        } else { "Unknown".to_string() }
    };

    let hostname = unsafe {
        let mut uts: libc::utsname = std::mem::zeroed();
        if libc::uname(&mut uts) == 0 {
            let c_str = std::ffi::CStr::from_ptr(uts.nodename.as_ptr());
            c_str.to_string_lossy().into_owned()
        } else { "Unknown".to_string() }
    };

    let cpu_brand = std::fs::read_to_string("/proc/cpuinfo").ok().and_then(|d| {
        d.lines().find(|l| l.starts_with("model name"))
            .and_then(|l| l.split(':').nth(1))
            .map(|s| s.trim().to_string())
    }).unwrap_or_else(|| "Unknown CPU".to_string());

    let cpu_cores = num_cpus::get() as u32;

    let total_memory = std::fs::read_to_string("/proc/meminfo").ok().and_then(|meminfo| {
        for line in meminfo.lines() {
            if line.starts_with("MemTotal:") {
                if let Some(kb) = line.split_whitespace().nth(1) { return Some(kb.parse::<u64>().unwrap_or(0) * 1024); }
            }
        }
        None
    }).unwrap_or(0);

    let boot_time = std::fs::read_to_string("/proc/stat").ok().and_then(|d| {
        d.lines().find(|l| l.starts_with("btime "))
            .and_then(|l| l.split_whitespace().nth(1))
            .and_then(|s| s.parse::<u64>().ok())
    }).unwrap_or(0);

    let uptime = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs().saturating_sub(boot_time);

    SystemInfo { os_name, os_version, kernel_version, hostname, cpu_brand, cpu_cores, total_memory, boot_time, uptime }
}
