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

// 获取每核心使用率 (瞬时快照 busy/(busy+idle))
fn get_per_core_load() -> Vec<f64> {
    use libc::{c_int, c_uint, c_void, mach_port_t, natural_t, kern_return_t};
    const KERN_SUCCESS: kern_return_t = 0;
    #[repr(C)]
    struct ProcessorCpuLoadInfo { user: u32, system: u32, idle: u32, nice: u32 }
    extern "C" {
        fn mach_host_self() -> mach_port_t;
        fn host_processor_info(host: mach_port_t, flavor: c_int, out_cpu_count: *mut c_uint, out_cpu_info: *mut *mut natural_t, out_cpu_info_count: *mut c_uint) -> kern_return_t;
        fn vm_deallocate(target_task: mach_port_t, address: usize, size: usize) -> kern_return_t;
    }
    const PROCESSOR_CPU_LOAD_INFO: c_int = 2;

    unsafe {
        let host = mach_host_self();
        let mut cpu_count: c_uint = 0;
        let mut cpu_info: *mut natural_t = std::ptr::null_mut();
        let mut info_count: c_uint = 0;
        if host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &mut cpu_count, &mut cpu_info, &mut info_count) != KERN_SUCCESS { return Vec::new(); }
        if cpu_info.is_null() || cpu_count == 0 { return Vec::new(); }
        let stride = std::mem::size_of::<ProcessorCpuLoadInfo>() / std::mem::size_of::<natural_t>();
        let slice = std::slice::from_raw_parts(cpu_info, info_count as usize);
        let mut loads = Vec::with_capacity(cpu_count as usize);
        for i in 0..cpu_count as usize {
            let base = i * stride;
            if base + 3 < slice.len() {
                let user = slice[base] as u64;
                let system = slice[base + 1] as u64;
                let idle = slice[base + 2] as u64;
                let nice = slice[base + 3] as u64;
                let busy = user + system + nice;
                let total = busy + idle;
                if total > 0 { loads.push((busy as f64 / total as f64) * 100.0); }
            }
        }
        // 释放分配的内存
        let _ = vm_deallocate(mach_host_self(), cpu_info as usize, (info_count as usize * std::mem::size_of::<natural_t>()) as usize);
        loads
    }
}
