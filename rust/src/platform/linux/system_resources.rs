use crate::api::simple::{DiskInfo, NetworkInfo, SystemResourceInfo};
use std::path::Path;
use nix::sys::statvfs;
use std::fs;

pub fn get_system_resources_impl() -> SystemResourceInfo {
    let total_memory = fs::read_to_string("/proc/meminfo").ok().and_then(|meminfo| {
        for line in meminfo.lines() {
            if line.starts_with("MemTotal:") {
                if let Some(kb) = line.split_whitespace().nth(1) { return Some(kb.parse::<u64>().unwrap_or(0) * 1024); }
            }
        }
        None
    }).unwrap_or(0);
    let free_memory = 0; // Placeholder; Linux free memory semantics are nuanced.
    let used_memory = total_memory - free_memory;

    let cpu_usage = 0.0; // TODO: implement sampling based load
    let disk_usage = get_disk_info();
    let network_usage = get_network_info();

    SystemResourceInfo { cpu_usage, memory_total: total_memory, memory_used: used_memory, memory_available: free_memory, disk_usage, network_usage }
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
    let mut net = NetworkInfo { bytes_sent: 0, bytes_received: 0, packets_sent: 0, packets_received: 0 };
    if let Ok(content) = fs::read_to_string("/proc/net/dev") {
        for line in content.lines().skip(2) {
            if let Some((_iface, data)) = line.split_once(':') {
                let parts: Vec<&str> = data.split_whitespace().collect();
                if parts.len() >= 16 {
                    let rx_bytes = parts[0].parse::<u64>().unwrap_or(0);
                    let rx_packets = parts[1].parse::<u64>().unwrap_or(0);
                    let tx_bytes = parts[8].parse::<u64>().unwrap_or(0);
                    let tx_packets = parts[9].parse::<u64>().unwrap_or(0);
                    net.bytes_received += rx_bytes;
                    net.packets_received += rx_packets;
                    net.bytes_sent += tx_bytes;
                    net.packets_sent += tx_packets;
                }
            }
        }
    }
    net
}
