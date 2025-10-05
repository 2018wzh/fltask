use crate::api::simple::SystemInfo;
use std::ffi::OsString;
use std::mem;
use std::os::windows::ffi::OsStringExt;

use std::time::{SystemTime, UNIX_EPOCH};

use winapi::um::winbase::GetComputerNameW;
use windows::{core::PCWSTR, Win32::System::{Registry::*, SystemInformation::*}};

/// Windows实现：获取系统信息
pub fn get_system_info_impl() -> SystemInfo {
    unsafe {
        // 获取计算机名
        let mut hostname_len = 256u32;
        let mut hostname_buf = vec![0u16; 256];
        let hostname = if GetComputerNameW(hostname_buf.as_mut_ptr(), &mut hostname_len) == 1 {
            OsString::from_wide(&hostname_buf[..hostname_len as usize])
                .to_string_lossy()
                .into_owned()
        } else {
            "Unknown".to_string()
        };

        // 获取系统信息
        let mut sys_info = SYSTEM_INFO::default();
        GetSystemInfo(&mut sys_info);

        // 获取版本信息
        let (os_version, kernel_version) = get_windows_version();

        // 获取内存信息
        let mut mem_status = MEMORYSTATUSEX {
            dwLength: mem::size_of::<MEMORYSTATUSEX>() as u32,
            ..Default::default()
        };
        let _ = GlobalMemoryStatusEx(&mut mem_status);

        // 获取CPU信息
        let cpu_brand = get_cpu_brand();
        
        // 获取运行时间和启动时间
        let uptime = get_system_uptime();
        let current_time = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        let boot_time = current_time.saturating_sub(uptime);

        SystemInfo {
            os_name: "Windows".to_string(),
            os_version,
            kernel_version,
            hostname,
            cpu_brand,
            cpu_cores: sys_info.dwNumberOfProcessors,
            total_memory: mem_status.ullTotalPhys,
            boot_time,
            uptime,
        }
    }
}

/// 获取Windows版本信息
fn get_windows_version() -> (String, String) {
    // 简化实现，实际可以通过RtlGetVersion或注册表获取
    ("11".to_string(), "10.0.22621".to_string())
}

/// 获取CPU品牌信息
fn get_cpu_brand() -> String {
    unsafe {
        // 通过注册表获取CPU信息
        let mut key = HKEY::default();
        let subkey = "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0\0"
            .encode_utf16()
            .collect::<Vec<_>>();

        if RegOpenKeyExW(
            HKEY_LOCAL_MACHINE,
            PCWSTR(subkey.as_ptr()),
            0,
            KEY_READ,
            &mut key,
        )
        .is_ok()
        {
            let mut buffer = vec![0u8; 256];
            let mut buffer_size = buffer.len() as u32;
            let value_name = "ProcessorNameString\0".encode_utf16().collect::<Vec<_>>();

            if RegQueryValueExW(
                key,
                PCWSTR(value_name.as_ptr()),
                None,
                None,
                Some(buffer.as_mut_ptr()),
                Some(&mut buffer_size),
            )
            .is_ok()
            {
                let cpu_name_wide: &[u16] = std::slice::from_raw_parts(
                    buffer.as_ptr() as *const u16,
                    (buffer_size as usize) / 2,
                );
                let cpu_name = OsString::from_wide(cpu_name_wide)
                    .to_string_lossy()
                    .trim_end_matches('\0')
                    .trim()
                    .to_string();

                let _ = RegCloseKey(key);
                return cpu_name;
            }
            let _ = RegCloseKey(key);
        }
    }

    "Unknown CPU".to_string()
}

/// 获取系统运行时间
fn get_system_uptime() -> u64 {
    unsafe {
        GetTickCount64() / 1000 // 转换为秒
    }
}
