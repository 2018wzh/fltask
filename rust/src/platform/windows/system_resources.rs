use crate::api::simple::{DiskInfo, NetworkInfo, SystemResourceInfo};
use std::mem;
use std::ptr;

use windows::core::PCWSTR;
use windows::Win32::Storage::FileSystem::*;
use windows::Win32::System::SystemInformation::*;
use windows::Win32::NetworkManagement::IpHelper::*;
use windows::Win32::Foundation::*;

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
    unsafe {
        let mut network_info = NetworkInfo {
            bytes_sent: 0,
            bytes_received: 0,
            packets_sent: 0,
            packets_received: 0,
        };

        // 获取网络接口表
        let mut table: *mut MIB_IFTABLE = ptr::null_mut();
        let mut size = 0u32;

        // 第一次调用获取需要的缓冲区大小
        let result = GetIfTable(
            Some(table),
            &mut size,
            false,
        );

        if result == ERROR_INSUFFICIENT_BUFFER.0 {
            // 分配缓冲区
            let layout = std::alloc::Layout::from_size_align(size as usize, std::mem::align_of::<MIB_IFTABLE>()).unwrap();
            table = std::alloc::alloc(layout) as *mut MIB_IFTABLE;

            // 第二次调用获取实际数据
            if GetIfTable(Some(table), &mut size, false) == NO_ERROR.0 {
                let if_table = &*table;
                let num_entries = if_table.dwNumEntries as usize;

                // 遍历所有网络接口
                for i in 0..num_entries {
                    let row = if_table.table.get_unchecked(i);

                    // 只统计活动的网络接口 (Up状态)
                    if row.dwOperStatus == INTERNAL_IF_OPER_STATUS(1) { // IF_OPER_STATUS_UP
                        network_info.bytes_sent += row.dwOutOctets as u64;
                        network_info.bytes_received += row.dwInOctets as u64;
                        network_info.packets_sent += row.dwOutUcastPkts as u64 + row.dwOutNUcastPkts as u64;
                        network_info.packets_received += row.dwInUcastPkts as u64 + row.dwInNUcastPkts as u64;
                    }
                }
            }

            // 释放缓冲区
            if !table.is_null() {
                std::alloc::dealloc(table as *mut u8, layout);
            }
        }

        network_info
    }
}
