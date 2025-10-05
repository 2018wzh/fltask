use crate::api::simple::SystemInfo;
use procfs::{CpuInfo, Meminfo, Uptime, Version};
use std::fs;
use std::time::{SystemTime, UNIX_EPOCH};

/// Linux implementation: Get system information
pub fn get_system_info_impl() -> SystemInfo {
    let os_name = "Linux".to_string();

    // Get OS version and kernel version
    let (os_version, kernel_version) = get_linux_version();

    // Get hostname
    let hostname = fs::read_to_string("/proc/sys/kernel/hostname")
        .unwrap_or_else(|_| "Unknown".to_string())
        .trim()
        .to_string();

    // Get CPU info
    let cpu_info = CpuInfo::new().unwrap();
    let cpu_brand = cpu_info.model_name(0).unwrap_or("Unknown CPU").to_string();
    let cpu_cores = cpu_info.num_cores() as u32;

    // Get memory info
    let mem_info = Meminfo::new().unwrap();
    let total_memory = mem_info.mem_total;

    // Get uptime and boot time
    let uptime = Uptime::new().unwrap().uptime_f64() as u64;
    let current_time = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let boot_time = current_time.saturating_sub(uptime);

    SystemInfo {
        os_name,
        os_version,
        kernel_version,
        hostname,
        cpu_brand,
        cpu_cores,
        total_memory,
        boot_time,
        uptime,
    }
}

/// Get Linux version information
fn get_linux_version() -> (String, String) {
    let version = Version::new().unwrap();
    let os_release = version.osrelease;
    let kernel_version = version.version;
    (os_release, kernel_version)
}
