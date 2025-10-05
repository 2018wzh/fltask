// 导入平台特定实现
#[cfg(target_os = "windows")]
use crate::platform::windows::{
    get_processes_impl, get_system_resources_impl, get_system_info_impl, kill_process_impl
};

#[cfg(target_os = "linux")]
use crate::platform::linux::{
    get_processes_impl, get_system_resources_impl, get_system_info_impl, kill_process_impl
};

#[cfg(target_os = "macos")]
use crate::platform::macos::{
    get_processes_impl, get_system_resources_impl, get_system_info_impl, kill_process_impl
};

#[cfg(not(any(target_os = "windows", target_os = "linux", target_os = "macos")))]
use crate::platform::default::{
    get_processes_impl, get_system_resources_impl, get_system_info_impl, kill_process_impl
};

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

// Process information structure
#[derive(Debug, Clone)]
pub struct ProcessInfo {
    pub pid: u32,
    pub name: String,
    pub cpu_usage: f64,
    pub memory_usage: u64, // in bytes
    pub parent_pid: Option<u32>,
    pub status: String,
    pub command: String,
    pub start_time: u64, // timestamp
}

// System resource information
#[derive(Debug, Clone)]
pub struct SystemResourceInfo {
    pub cpu_usage: f64,
    pub memory_total: u64,
    pub memory_used: u64,
    pub memory_available: u64,
    pub disk_usage: Vec<DiskInfo>,
    pub network_usage: NetworkInfo,
}

#[derive(Debug, Clone)]
pub struct DiskInfo {
    pub name: String,
    pub mount_point: String,
    pub total_space: u64,
    pub used_space: u64,
    pub available_space: u64,
}

#[derive(Debug, Clone)]
pub struct NetworkInfo {
    pub bytes_sent: u64,
    pub bytes_received: u64,
    pub packets_sent: u64,
    pub packets_received: u64,
}

// System information structure
#[derive(Debug, Clone)]
pub struct SystemInfo {
    pub os_name: String,
    pub os_version: String,
    pub kernel_version: String,
    pub hostname: String,
    pub cpu_brand: String,
    pub cpu_cores: u32,
    pub total_memory: u64,
    pub boot_time: u64,
    pub uptime: u64,
}

// API functions for Flutter to call

/// Get list of all processes
#[flutter_rust_bridge::frb(sync)]
pub fn get_processes() -> Vec<ProcessInfo> {
    get_processes_impl()
}

/// Get system resource usage
#[flutter_rust_bridge::frb(sync)]
pub fn get_system_resources() -> SystemResourceInfo {
    get_system_resources_impl()
}

/// Get system information
#[flutter_rust_bridge::frb(sync)]
pub fn get_system_info() -> SystemInfo {
    get_system_info_impl()
}

/// Kill a process by PID
#[flutter_rust_bridge::frb(sync)]
pub fn kill_process(pid: u32) -> bool {
    kill_process_impl(pid)
}
