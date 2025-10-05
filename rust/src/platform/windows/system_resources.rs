use crate::api::simple::{DiskInfo, NetworkInfo, SystemResourceInfo};
use std::mem;

use windows::core::PCWSTR;
use windows::{Win32::Storage::FileSystem::*, Win32::System::SystemInformation::*};

/// Windows实现：获取系统资源信息
pub fn get_system_resources_impl() -> SystemResourceInfo {
    unsafe {
        // 获取内存信息
        let mut mem_status = MEMORYSTATUSEX {
            dwLength: mem::size_of::<MEMORYSTATUSEX>() as u32,
            ..Default::default()
        };
        let _ = GlobalMemoryStatusEx(&mut mem_status);

        // 获取CPU使用率（简化实现）
        let cpu_usage = get_cpu_usage();

        // 获取磁盘信息
        let disk_usage = get_disk_info();

        // 获取网络信息
        let network_usage = get_network_info();

        SystemResourceInfo {
            cpu_usage,
            memory_total: mem_status.ullTotalPhys,
            memory_used: mem_status.ullTotalPhys - mem_status.ullAvailPhys,
            memory_available: mem_status.ullAvailPhys,
            disk_usage,
            network_usage,
        }
    }
}

/// 获取CPU使用率
fn get_cpu_usage() -> f64 {
    // 简化实现，实际需要使用PDH计数器或NT系统调用
    // 这里返回一个模拟值
    25.0
}

/// 获取磁盘信息
fn get_disk_info() -> Vec<DiskInfo> {
    let mut disks = Vec::new();

    unsafe {
        // 获取所有驱动器
        let drives = GetLogicalDrives();
        for i in 0..26 {
            if (drives & (1 << i)) != 0 {
                let drive_letter = format!("{}:", (b'A' + i) as char);
                let drive_path = format!("{}\\", drive_letter);

                let mut total_bytes = 0u64;
                let mut free_bytes = 0u64;

                let drive_path_wide: Vec<u16> = drive_path
                    .encode_utf16()
                    .chain(std::iter::once(0))
                    .collect();

                if GetDiskFreeSpaceExW(
                    PCWSTR(drive_path_wide.as_ptr()),
                    Some(&mut free_bytes),
                    Some(&mut total_bytes),
                    None,
                )
                .is_ok()
                {
                    disks.push(DiskInfo {
                        name: drive_letter.clone(),
                        mount_point: drive_path,
                        total_space: total_bytes,
                        used_space: total_bytes - free_bytes,
                        available_space: free_bytes,
                    });
                }
            }
        }
    }

    disks
}

/// 获取网络信息
fn get_network_info() -> NetworkInfo {
    // 简化实现，实际需要使用GetIfTable等API
    NetworkInfo {
        bytes_sent: 1024 * 1024 * 100,     // 100MB
        bytes_received: 1024 * 1024 * 500, // 500MB
        packets_sent: 50000,
        packets_received: 250000,
    }
}
