use crate::api::simple::{DiskInfo, NetworkInfo, SystemResourceInfo};
use procfs::{
    diskstats,
    net::{dev_status, Tcp, Udp},
    CpuInfo, Meminfo,
};

/// Linux implementation: Get system resource information
pub fn get_system_resources_impl() -> SystemResourceInfo {
    // Get memory info
    let mem_info = Meminfo::new().unwrap();
    let memory_total = mem_info.mem_total;
    let memory_available = mem_info.mem_available.unwrap_or(0);
    let memory_used = memory_total - memory_available;

    // Get CPU usage (simplified)
    let cpu_usage = get_cpu_usage();

    // Get disk info
    let disk_usage = get_disk_info();

    // Get network info
    let network_usage = get_network_info();

    SystemResourceInfo {
        cpu_usage,
        memory_total,
        memory_used,
        memory_available,
        disk_usage,
        network_usage,
    }
}

/// Get CPU usage (simplified)
fn get_cpu_usage() -> f64 {
    // This is a simplified implementation. For accurate CPU usage,
    // you would need to compare CPU times over an interval.
    if let Ok(stat) = procfs::Stat::new() {
        let total_time: u64 = stat.cpu_time.iter().sum();
        let idle_time = stat.cpu_time[3]; // idle
        if total_time > 0 {
            100.0 - (idle_time as f64 / total_time as f64 * 100.0)
        } else {
            0.0
        }
    } else {
        0.0
    }
}

/// Get disk information
fn get_disk_info() -> Vec<DiskInfo> {
    let mut disks = Vec::new();
    if let Ok(all_mounts) = procfs::process::mountinfo() {
        for mount in all_mounts {
            if mount.mount_point.starts_with("/dev") {
                if let Ok(stat) = nix::sys::statvfs::statvfs(mount.mount_point.as_str()) {
                    let total_space = stat.blocks() * stat.fragment_size();
                    let available_space = stat.blocks_available() * stat.fragment_size();
                    let used_space = total_space - available_space;
                    disks.push(DiskInfo {
                        name: mount.mount_source.unwrap_or_default(),
                        mount_point: mount.mount_point,
                        total_space,
                        used_space,
                        available_space,
                    });
                }
            }
        }
    }
    disks
}

/// Get network information
fn get_network_info() -> NetworkInfo {
    let mut network_info = NetworkInfo {
        bytes_sent: 0,
        bytes_received: 0,
        packets_sent: 0,
        packets_received: 0,
    };

    if let Ok(dev) = dev_status() {
        for (iface, stats) in dev {
            network_info.bytes_received += stats.recv_bytes as u64;
            network_info.bytes_sent += stats.sent_bytes as u64;
            network_info.packets_received += stats.recv_packets as u64;
            network_info.packets_sent += stats.sent_packets as u64;
        }
    }

    network_info
}
