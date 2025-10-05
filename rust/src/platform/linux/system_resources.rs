use crate::api::simple::{DiskInfo, NetworkInfo, SystemResourceInfo};
use std::path::Path;
use nix::sys::statvfs;
use std::fs;

pub fn get_system_resources_impl() -> SystemResourceInfo {
    let mut mem_total: u64 = 0;
    let mut mem_available: u64 = 0;
    let mut swap_total: u64 = 0;
    let mut swap_free: u64 = 0;
    if let Ok(meminfo) = fs::read_to_string("/proc/meminfo") {
        for line in meminfo.lines() {
            if line.starts_with("MemTotal:") {
                if let Some(kb) = line.split_whitespace().nth(1) { mem_total = kb.parse::<u64>().unwrap_or(0) * 1024; }
            } else if line.starts_with("MemAvailable:") {
                if let Some(kb) = line.split_whitespace().nth(1) { mem_available = kb.parse::<u64>().unwrap_or(0) * 1024; }
            } else if line.starts_with("SwapTotal:") {
                if let Some(kb) = line.split_whitespace().nth(1) { swap_total = kb.parse::<u64>().unwrap_or(0) * 1024; }
            } else if line.starts_with("SwapFree:") {
                if let Some(kb) = line.split_whitespace().nth(1) { swap_free = kb.parse::<u64>().unwrap_or(0) * 1024; }
            }
        }
    }
    let mem_used = if mem_total > mem_available { mem_total - mem_available } else { 0 };
    let swap_used = if swap_total > swap_free { swap_total - swap_free } else { 0 };

    let (cpu_usage, cpu_per_core) = read_cpu_usage();
    let disk_usage = get_disk_info();
    let network_usage = get_network_info();

    SystemResourceInfo {
        cpu_usage,
        cpu_per_core,
        memory_total: mem_total,
        memory_used: mem_used,
        memory_available: mem_available,
        swap_total,
        swap_used,
        swap_free,
        disk_usage,
        network_usage,
    }
}

fn read_cpu_usage() -> (f64, Vec<f64>) {
    // Note: True CPU percentage needs delta over time. Here we parse current jiffies and return ratios of busy/total.
    if let Ok(stat) = fs::read_to_string("/proc/stat") {
        let mut per_core = Vec::new();
        let mut total_busy: u64 = 0;
        let mut total_all: u64 = 0;
        for line in stat.lines() {
            if line.starts_with("cpu") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts[0] == "cpu" { // aggregate
                    if parts.len() >= 8 {
                        let user: u64 = parts[1].parse().unwrap_or(0);
                        let nice: u64 = parts[2].parse().unwrap_or(0);
                        let system: u64 = parts[3].parse().unwrap_or(0);
                        let idle: u64 = parts[4].parse().unwrap_or(0);
                        let iowait: u64 = parts[5].parse().unwrap_or(0);
                        let irq: u64 = parts[6].parse().unwrap_or(0);
                        let softirq: u64 = parts[7].parse().unwrap_or(0);
                        let busy = user + nice + system + irq + softirq;
                        total_busy = busy;
                        total_all = busy + idle + iowait;
                    }
                } else { // per core
                    if parts.len() >= 8 {
                        let user: u64 = parts[1].parse().unwrap_or(0);
                        let nice: u64 = parts[2].parse().unwrap_or(0);
                        let system: u64 = parts[3].parse().unwrap_or(0);
                        let idle: u64 = parts[4].parse().unwrap_or(0);
                        let iowait: u64 = parts[5].parse().unwrap_or(0);
                        let irq: u64 = parts[6].parse().unwrap_or(0);
                        let softirq: u64 = parts[7].parse().unwrap_or(0);
                        let busy = user + nice + system + irq + softirq;
                        let all = busy + idle + iowait;
                        if all > 0 { per_core.push((busy as f64 / all as f64) * 100.0); }
                    }
                }
            }
        }
        if total_all > 0 { return ((total_busy as f64 / total_all as f64) * 100.0, per_core); }
    }
    (0.0, Vec::new())
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
