use crate::api::simple::{DiskInfo, NetworkInfo, SystemResourceInfo};
use std::mem;
use std::time::{Duration, Instant};
use std::sync::Mutex;

use winapi::um::psapi::{GetPerformanceInfo, PERFORMANCE_INFORMATION};
use windows::core::PCWSTR;
use windows::Win32::NetworkManagement::IpHelper::{FreeMibTable, GetIfTable2, MIB_IF_TABLE2};
use windows::Win32::NetworkManagement::Ndis::IF_OPER_STATUS;
use windows::Win32::Storage::FileSystem::*;
use windows::Win32::System::SystemInformation::MEMORYSTATUSEX;
use windows::Win32::System::SystemInformation::*;

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

        // 更精确的 Windows 下 swap(page file) 计算：
        // 使用 GetPerformanceInfo 得到：
        //   CommitLimit  = 物理内存页数 + PageFile 可承载的页数 (可能略小于简单相加)
        //   CommitTotal  = 当前已提交(保证可驻留)的页数 (包含仍在物理内存中的页)
        // PageFile(可用/总) 近似 = (CommitLimit - PhysicalTotal) * PageSize
        // PageFile(已用)     近似 = max(CommitTotal - PhysicalTotal, 0) * PageSize
        // 这样不会把物理内存重复计入 swap。
        let mut swap_total: u64 = 0;
        let mut swap_used: u64 = 0;
        let swap_free: u64; // 推迟赋值，避免未使用初值警告

        let mut perf_info: PERFORMANCE_INFORMATION = std::mem::zeroed();
        perf_info.cb = mem::size_of::<PERFORMANCE_INFORMATION>() as u32;
        // GetPerformanceInfo 返回 BOOL(!=0 成功)
        if GetPerformanceInfo(&mut perf_info, perf_info.cb) != 0 {
            let page_size = perf_info.PageSize;
            let commit_limit = perf_info.CommitLimit as u64; // pages
            let commit_total = perf_info.CommitTotal as u64; // pages
            let phys_total = perf_info.PhysicalTotal as u64; // pages

            // 计算 pagefile 容量 (去除物理内存页)
            if commit_limit > phys_total {
                swap_total = (commit_limit - phys_total) * page_size as u64;
            }
            // 已用的 pagefile (提交的超出物理内存部分)
            if commit_total > phys_total {
                swap_used = (commit_total - phys_total) * page_size as u64;
            }
            swap_free = swap_total.saturating_sub(swap_used);
        } else {
            // 回退方案：沿用 MEMORYSTATUSEX 粗略估计
            // ullTotalPageFile 包含物理内存，因此减去物理得到估计的 pagefile 总量
            if mem_status.ullTotalPageFile > mem_status.ullTotalPhys {
                swap_total = mem_status.ullTotalPageFile - mem_status.ullTotalPhys;
            }
            // 已用 = (TotalCommit - AvailCommit) 超出物理部分
            if mem_status.ullTotalPageFile > mem_status.ullAvailPageFile {
                let commit_used = mem_status.ullTotalPageFile - mem_status.ullAvailPageFile; // 含物理
                if commit_used > mem_status.ullTotalPhys {
                    swap_used = commit_used - mem_status.ullTotalPhys;
                }
            }
            swap_free = swap_total.saturating_sub(swap_used);
        }

        let cpu_per_core = get_per_core_usage();
        SystemResourceInfo {
            cpu_usage,
            cpu_per_core,
            memory_total: mem_status.ullTotalPhys,
            memory_used: mem_status.ullTotalPhys - mem_status.ullAvailPhys,
            memory_available: mem_status.ullAvailPhys,
            swap_total,
            swap_used,
            swap_free,
            disk_usage,
            network_usage,
        }
    }
}

/// 获取CPU使用率
// ===== CPU 采集实现 (NtQuerySystemInformation) =====
// 参考 SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION:
// https://learn.microsoft.com/windows/win32/api/winternl/ns-winternl-system_processor_performance_information
// winapi 已提供 winnt 中的结构，但未直接导出此结构，我们手动定义匹配布局。

#[repr(C)]
#[derive(Clone, Copy, Default, Debug)]
struct SystemProcessorPerformanceInformation {
    idle_time: i64,
    kernel_time: i64,
    user_time: i64,
    dpc_time: i64,
    interrupt_time: i64,
    interrupts: u32,
}

#[allow(non_camel_case_types)]
type NTSTATUS = i32;

// SystemInformationClass 常量 (摘取需要的)
const SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION_CLASS: u32 = 8; // SYSTEM_INFORMATION_CLASS::SystemProcessorPerformanceInformation

extern "system" {
    fn NtQuerySystemInformation(
        system_information_class: u32,
        system_information: *mut std::ffi::c_void,
        system_information_length: u32,
        return_length: *mut u32,
    ) -> NTSTATUS;
}

// 缓存上一次采样数据
struct CpuSampleCache {
    last_instant: Instant,
    last_per_core: Vec<SystemProcessorPerformanceInformation>,
    last_total_pct: f64,
    last_per_core_pct: Vec<f64>,
}

lazy_static::lazy_static! {
    static ref CPU_CACHE: Mutex<Option<CpuSampleCache>> = Mutex::new(None);
}

fn query_per_core_raw() -> Option<Vec<SystemProcessorPerformanceInformation>> {
    unsafe {
        // 先获取处理器数量 (GetActiveProcessorCount Win32) 也可以；这里用两步法：尝试递增缓冲，或先猜测 256 核上限。
        let mut count_guess = 64usize; // 初始猜测
        for _ in 0..3 {
            let mut buffer: Vec<SystemProcessorPerformanceInformation> = Vec::with_capacity(count_guess);
            let size_bytes = (buffer.capacity() * std::mem::size_of::<SystemProcessorPerformanceInformation>()) as u32;
            let mut return_len: u32 = 0;
            let status = NtQuerySystemInformation(
                SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION_CLASS,
                buffer.as_mut_ptr() as *mut _ ,
                size_bytes,
                &mut return_len as *mut u32,
            );
            // STATUS_SUCCESS = 0
            if status == 0 {
                let actual_count = (return_len as usize) / std::mem::size_of::<SystemProcessorPerformanceInformation>();
                buffer.set_len(actual_count);
                return Some(buffer);
            } else {
                // 如果缓冲不够 (STATUS_INFO_LENGTH_MISMATCH = 0xC0000004) 扩容
                if status == -1073741820 { // 0xC0000004 as i32
                    // 根据返回长度扩展
                    if return_len as usize > count_guess * std::mem::size_of::<SystemProcessorPerformanceInformation>() {
                        count_guess = (return_len as usize / std::mem::size_of::<SystemProcessorPerformanceInformation>()) + 4;
                    } else {
                        count_guess *= 2;
                    }
                    continue;
                } else {
                    return None;
                }
            }
        }
        None
    }
}

fn get_cpu_usage() -> f64 {
    let (total, _) = sample_cpu_usage();
    total
}

fn get_per_core_usage() -> Vec<f64> {
    let (_, per_core) = sample_cpu_usage();
    per_core
}

fn sample_cpu_usage() -> (f64, Vec<f64>) {
    const MIN_INTERVAL: Duration = Duration::from_millis(400); // 避免过于频繁
    let mut cache = CPU_CACHE.lock().unwrap();
    let now = Instant::now();

    if let Some(ref existing) = *cache {
        if now.duration_since(existing.last_instant) < MIN_INTERVAL {
            return (existing.last_total_pct, existing.last_per_core_pct.clone());
        }
    }

    let cur_raw = match query_per_core_raw() {
        Some(v) => v,
        None => return (0.0, Vec::new()),
    };

    if let Some(prev_cache) = cache.as_ref() {
        let prev_raw = &prev_cache.last_per_core;
        let len = cur_raw.len().min(prev_raw.len());
        if len == 0 { return (0.0, Vec::new()); }
        let mut per_core = Vec::with_capacity(len);
        let mut active_sum = 0.0;
        let mut total_sum = 0.0;
        for i in 0..len {
            let prev = &prev_raw[i];
            let cur = &cur_raw[i];
            let idle_delta = (cur.idle_time - prev.idle_time) as f64;
            let kernel_delta = (cur.kernel_time - prev.kernel_time) as f64;
            let user_delta = (cur.user_time - prev.user_time) as f64;
            if idle_delta < 0.0 || kernel_delta < 0.0 || user_delta < 0.0 {
                per_core.push(0.0);
                continue;
            }
            let active = (kernel_delta - idle_delta).max(0.0) + user_delta;
            let total = active + idle_delta;
            if total > 0.0 {
                let pct = (active / total * 100.0).clamp(0.0, 100.0);
                per_core.push(pct);
                active_sum += active;
                total_sum += total;
            } else {
                per_core.push(0.0);
            }
        }
        let total_pct = if total_sum > 0.0 { (active_sum / total_sum * 100.0).clamp(0.0, 100.0) } else { 0.0 };
        // 更新缓存
        *cache = Some(CpuSampleCache { last_instant: now, last_per_core: cur_raw, last_total_pct: total_pct, last_per_core_pct: per_core.clone() });
        (total_pct, per_core)
    } else {
        // 首次采样，无法计算 delta，存缓存返回 0
        *cache = Some(CpuSampleCache { last_instant: now, last_per_core: cur_raw, last_total_pct: 0.0, last_per_core_pct: Vec::new() });
        (0.0, Vec::new())
    }
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
                if entry.OperStatus == IF_OPER_STATUS(1) {
                    // IfOperStatusUp
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

// ===== 结束 CPU 采集实现 =====
