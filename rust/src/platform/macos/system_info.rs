use crate::api::simple::SystemInfo;
use sysctl::Sysctl;
use std::time::{SystemTime, UNIX_EPOCH};

/// macOS implementation: Get system information
pub fn get_system_info_impl() -> SystemInfo {
    let os_name = "macOS".to_string();

    // Get OS version and kernel version
    let os_version = sysctl::Ctl::new("kern.osproductversion")
        .and_then(|c| c.value_string())
        .unwrap_or_else(|_| "Unknown".to_string());
    let kernel_version = sysctl::Ctl::new("kern.osrelease")
        .and_then(|c| c.value_string())
        .unwrap_or_else(|_| "Unknown".to_string());

    // Get hostname
    let hostname = sysctl::Ctl::new("kern.hostname")
        .and_then(|c| c.value_string())
        .unwrap_or_else(|_| "Unknown".to_string());

    // Get CPU info
    let cpu_brand = sysctl::Ctl::new("machdep.cpu.brand_string")
        .and_then(|c| c.value_string())
        .unwrap_or_else(|_| "Unknown CPU".to_string());
    let cpu_cores = sysctl::Ctl::new("hw.ncpu")
        .and_then(|c| c.value())
        .map(|v| v.try_into().unwrap_or(0))
        .unwrap_or(0);

    // Get memory info
    let total_memory = sysctl::Ctl::new("hw.memsize")
        .and_then(|c| c.value())
        .map(|v| v.try_into().unwrap_or(0))
        .unwrap_or(0);

    // Get boot time and uptime
    let boottime_val = sysctl::Ctl::new("kern.boottime")
        .and_then(|c| c.value())
        .unwrap_or(sysctl::CtlValue::Struct(Vec::new()));

    let boot_time = if let sysctl::CtlValue::Struct(val) = boottime_val {
        if val.len() >= 8 {
            // The timeval struct has two i64 fields for seconds and microseconds
            let seconds = i64::from_le_bytes(val[0..8].try_into().unwrap());
            seconds as u64
        } else {
            0
        }
    } else {
        0
    };

    let uptime = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
        .saturating_sub(boot_time);


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
