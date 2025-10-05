use crate::api::simple::{DiskInfo, NetworkInfo, SystemResourceInfo};
use std::mem;

use windows::core::PCWSTR;
use windows::Win32::Storage::FileSystem::*;
use windows::Win32::System::SystemInformation::*;
use windows::Win32::NetworkManagement::IpHelper::{FreeMibTable, GetIfTable2, MIB_IF_TABLE2};
use windows::Win32::NetworkManagement::Ndis::IF_OPER_STATUS;

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
    let mut network_info = NetworkInfo {
        bytes_sent: 0,
        bytes_received: 0,
        packets_sent: 0,
        packets_received: 0,
    };

    unsafe {
        let mut table: *mut MIB_IF_TABLE2 = std::ptr::null_mut();
        if GetIfTable2(&mut table).is_ok() {
            let num_entries = (*table).NumEntries;
            let entries = std::slice::from_raw_parts((*table).Table.as_ptr(), num_entries as usize);

            for entry in entries {
                if entry.OperStatus == IF_OPER_STATUS(1) { // IfOperStatusUp
                    network_info.bytes_received += entry.InOctets;
                    network_info.bytes_sent += entry.OutOctets;
                    network_info.packets_received += entry.InUcastPkts + entry.InNUcastPkts;
                    network_info.packets_sent += entry.OutUcastPkts + entry.OutNUcastPkts;
                }
            }
            FreeMibTable(table as *const _);
        }
    }

    network_info
}
