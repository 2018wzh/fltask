use crate::api::simple::{DiskInfo, NetworkInfo, SystemResourceInfo};
use sysctl::{Sysctl, CtlValue};
use std::path::Path;
use nix::sys::statvfs;

pub fn get_system_resources_impl() -> SystemResourceInfo {
    let total_memory = sysctl::Ctl::new("hw.memsize").and_then(|c| c.value()).ok().and_then(|v| match v { CtlValue::Int(i) => Some(i as u64), CtlValue::Uint(i) => Some(i as u64), CtlValue::S64(i) => Some(i as u64), CtlValue::U64(i) => Some(i as u64), _ => None }).unwrap_or(0);
    let free_memory = 0; // placeholder (could parse vm_stat output)
    let used_memory = total_memory - free_memory;

    // Swap stats - using sysctl vm.swapusage (requires privilege). We'll attempt and fallback.
    let mut swap_total: u64 = 0;
    let mut swap_used: u64 = 0;
    let mut swap_free: u64 = 0;
    if let Ok(swap_ctl) = sysctl::Ctl::new("vm.swapusage") {
        if let Ok(CtlValue::Struct(bytes)) = swap_ctl.value() {
            // struct xsw_usage { u64 xsu_total; u64 xsu_avail; u64 xsu_used; ... }
            if bytes.len() >= 24 {
                let total = u64::from_ne_bytes(bytes[0..8].try_into().unwrap());
                let avail = u64::from_ne_bytes(bytes[8..16].try_into().unwrap());
                let used = u64::from_ne_bytes(bytes[16..24].try_into().unwrap());
                swap_total = total;
                swap_used = used;
                swap_free = if total > used { total - used } else { avail };
            }
        }
    }

    let cpu_usage = get_cpu_usage();
    let disk_usage = get_disk_info();
    let network_usage = get_network_info();

    let cpu_per_core = get_per_core_load();
    SystemResourceInfo { cpu_usage, cpu_per_core, memory_total: total_memory, memory_used: used_memory, memory_available: free_memory, swap_total, swap_used, swap_free, disk_usage, network_usage }
}

fn get_cpu_usage() -> f64 {
    if let Ok(load) = sysctl::Ctl::new("vm.loadavg") {
        if let Ok(sysctl::CtlValue::Struct(vals)) = load.value() {
            if !vals.is_empty() {
                let load_avg_int = u32::from_le_bytes(vals[0..4].try_into().unwrap());
                return (load_avg_int as f64 / 65536.0) * 100.0;
            }
        }
    }
    0.0
}

fn get_disk_info() -> Vec<DiskInfo> {
    let mut disks = Vec::new();
    if let Ok(stat) = statvfs::statvfs(Path::new("/")) {
        let total_space = (stat.blocks() as u64).saturating_mul(stat.fragment_size() as u64);
        let available_space = (stat.blocks_available() as u64).saturating_mul(stat.fragment_size() as u64);
        let used_space = total_space.saturating_sub(available_space);
        disks.push(DiskInfo { name: "/".into(), mount_point: "/".into(), total_space, used_space, available_space });
    }
    disks
}

fn get_network_info() -> NetworkInfo {
    // Placeholder implementation: returns zeros. For macOS, a proper implementation
    // could use getifaddrs + if_data to sum counters per interface.
    NetworkInfo { bytes_sent: 0, bytes_received: 0, packets_sent: 0, packets_received: 0 }
}

// 获取每核心使用率 (瞬时快照 busy/(busy+idle))
fn get_per_core_load() -> Vec<f64> {
    // Placeholder: proper macOS per-core sampling requires Mach APIs which are
    // not available on non-mac targets. Return empty list for now.
    Vec::new()
}
