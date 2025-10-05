use std::mem;
use std::ffi::OsString;
use std::os::windows::ffi::OsStringExt;
use crate::api::simple::ProcessInfo;

use windows::{
    Win32::Foundation::*,
    Win32::System::Threading::*,
    Win32::System::Diagnostics::ToolHelp::*,
    Win32::System::ProcessStatus::*,
};

/// Windows实现：获取进程列表
pub fn get_processes_impl() -> Vec<ProcessInfo> {
    let mut processes = Vec::new();
    
    unsafe {
        // 创建进程快照
        let snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        let snapshot = match snapshot {
            Ok(snapshot) => snapshot,
            Err(_) => return processes,
        };
        if snapshot == INVALID_HANDLE_VALUE {
            return processes;
        }
        
        let mut process_entry = PROCESSENTRY32W {
            dwSize: mem::size_of::<PROCESSENTRY32W>() as u32,
            ..Default::default()
        };
        
        // 遍历进程
        if Process32FirstW(snapshot, &mut process_entry).is_ok() {
            loop {
                let name = OsString::from_wide(&process_entry.szExeFile[..])
                    .to_string_lossy()
                    .trim_end_matches('\0')
                    .to_string();
                
                // 获取进程内存和CPU使用率
                let (memory_usage, cpu_usage) = get_process_info(process_entry.th32ProcessID);
                
                processes.push(ProcessInfo {
                    pid: process_entry.th32ProcessID,
                    name,
                    cpu_usage,
                    memory_usage,
                    parent_pid: if process_entry.th32ParentProcessID == 0 { 
                        None 
                    } else { 
                        Some(process_entry.th32ParentProcessID) 
                    },
                    status: "Running".to_string(),
                    command: String::new(), // 可以通过QueryFullProcessImageNameW获取
                    start_time: 0, // 可以通过GetProcessTimes获取
                });
                
                if Process32NextW(snapshot, &mut process_entry).is_err() {
                    break;
                }
            }
        }
        
        let _ = CloseHandle(snapshot);
    }
    
    processes
}

/// 获取单个进程的内存和CPU使用信息
fn get_process_info(pid: u32) -> (u64, f64) {
    unsafe {
        let handle = match OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, false, pid) {
            Ok(h) => h,
            Err(_) => return (0, 0.0),
        };
        
        // 获取内存使用情况
        let mut pmc = PROCESS_MEMORY_COUNTERS::default();
        let memory_usage = if GetProcessMemoryInfo(handle, &mut pmc, mem::size_of::<PROCESS_MEMORY_COUNTERS>() as u32).is_ok() {
            pmc.WorkingSetSize as u64
        } else {
            0
        };
        
        // CPU使用率计算
        let cpu_usage = calculate_cpu_usage(handle);
        
        let _ = CloseHandle(handle);
        (memory_usage, cpu_usage)
    }
}

// 计算CPU使用率
unsafe fn calculate_cpu_usage(process_handle: HANDLE) -> f64 {
    let mut creation_time = FILETIME::default();
    let mut exit_time = FILETIME::default();
    let mut kernel_time = FILETIME::default();
    let mut user_time = FILETIME::default();

    if GetProcessTimes(
        process_handle,
        &mut creation_time,
        &mut exit_time,
        &mut kernel_time,
        &mut user_time,
    )
    .is_ok()
    {
        let kernel_time = filetime_to_u64(kernel_time);
        let user_time = filetime_to_u64(user_time);

        let system_time = get_system_time();

        let cpu_usage = if system_time != 0 {
            ((kernel_time + user_time) as f64 / system_time as f64) * 100.0
        } else {
            0.0
        };

        cpu_usage
    } else {
        0.0
    }
}

// FILETIME转换为u64
fn filetime_to_u64(filetime: FILETIME) -> u64 {
    (filetime.dwHighDateTime as u64) << 32 | (filetime.dwLowDateTime as u64)
}

// 获取系统时间
fn get_system_time() -> u64 {
    unsafe {
        let mut system_idle_time = FILETIME::default();
        let mut kernel_time = FILETIME::default();
        let mut user_time = FILETIME::default();

        if GetSystemTimes(Some(&mut system_idle_time), Some(&mut kernel_time), Some(&mut user_time)).is_ok() {
            filetime_to_u64(kernel_time) + filetime_to_u64(user_time)
        } else {
            0
        }
    }
}

/// Windows实现：结束进程
pub fn kill_process_impl(pid: u32) -> bool {
    unsafe {
        let handle = match OpenProcess(PROCESS_TERMINATE, TRUE, pid) {
            Ok(h) => h,
            Err(_) => return false,
        };
        
        let result = TerminateProcess(handle, 1).is_ok();
        let _ = CloseHandle(handle);
        result
    }
}