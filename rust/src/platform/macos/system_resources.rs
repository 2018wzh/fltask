use crate::api::simple::{DiskInfo, NetworkInfo, SystemResourceInfo};
use sysctl::{Sysctl, CtlValue};
use std::path::Path;
use nix::sys::statvfs;
use libproc::libproc::net_info;

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

    SystemResourceInfo { cpu_usage, memory_total: total_memory, memory_used: used_memory, memory_available: free_memory, swap_total, swap_used, swap_free, disk_usage, network_usage }
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
        let total_space = stat.blocks() * stat.fragment_size();
        let available_space = stat.blocks_available() * stat.fragment_size();
        let used_space = total_space - available_space;
        disks.push(DiskInfo { name: "/".to_string(), mount_point: "/".to_string(), total_space, used_space, available_space });
    }
    disks
}

fn get_network_info() -> NetworkInfo {
    let mut network_info = NetworkInfo { bytes_sent: 0, bytes_received: 0, packets_sent: 0, packets_received: 0 };
    if let Ok(info) = net_info::get_net_info() {
        for if_info in info.interfaces {
            network_info.bytes_received += if_info.ifi_ibytes;
            network_info.bytes_sent += if_info.ifi_obytes;
            network_info.packets_received += if_info.ifi_ipackets;
            network_info.packets_sent += if_info.ifi_opackets;
        }
    }
    network_info
}
