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
    // Placeholder implementation - replace with actual system calls
    vec![
        ProcessInfo {
            pid: 1,
            name: "System".to_string(),
            cpu_usage: 0.1,
            memory_usage: 1024 * 1024, // 1MB
            parent_pid: None,
            status: "Running".to_string(),
            command: "System".to_string(),
            start_time: 0,
        },
        ProcessInfo {
            pid: 2,
            name: "Chrome".to_string(),
            cpu_usage: 15.2,
            memory_usage: 512 * 1024 * 1024, // 512MB
            parent_pid: Some(1),
            status: "Running".to_string(),
            command: "chrome.exe".to_string(),
            start_time: 1000,
        },
        ProcessInfo {
            pid: 3,
            name: "Firefox".to_string(),
            cpu_usage: 8.5,
            memory_usage: 256 * 1024 * 1024, // 256MB
            parent_pid: Some(1),
            status: "Running".to_string(),
            command: "firefox.exe".to_string(),
            start_time: 2000,
        },
    ]
}

/// Get system resource usage
#[flutter_rust_bridge::frb(sync)]
pub fn get_system_resources() -> SystemResourceInfo {
    // Placeholder implementation
    SystemResourceInfo {
        cpu_usage: 25.6,
        memory_total: 16 * 1024 * 1024 * 1024, // 16GB
        memory_used: 8 * 1024 * 1024 * 1024,   // 8GB
        memory_available: 8 * 1024 * 1024 * 1024, // 8GB
        disk_usage: vec![
            DiskInfo {
                name: "C:".to_string(),
                mount_point: "C:\\".to_string(),
                total_space: 500 * 1024 * 1024 * 1024, // 500GB
                used_space: 300 * 1024 * 1024 * 1024,  // 300GB
                available_space: 200 * 1024 * 1024 * 1024, // 200GB
            }
        ],
        network_usage: NetworkInfo {
            bytes_sent: 1024 * 1024 * 100,     // 100MB
            bytes_received: 1024 * 1024 * 500, // 500MB
            packets_sent: 50000,
            packets_received: 250000,
        },
    }
}

/// Get system information
#[flutter_rust_bridge::frb(sync)]
pub fn get_system_info() -> SystemInfo {
    // Placeholder implementation
    SystemInfo {
        os_name: "Windows".to_string(),
        os_version: "11".to_string(),
        kernel_version: "10.0.22621".to_string(),
        hostname: "DESKTOP-PC".to_string(),
        cpu_brand: "Intel Core i7-12700K".to_string(),
        cpu_cores: 12,
        total_memory: 16 * 1024 * 1024 * 1024, // 16GB
        boot_time: 0,
        uptime: 86400, // 1 day in seconds
    }
}

/// Kill a process by PID
#[flutter_rust_bridge::frb(sync)]
pub fn kill_process(pid: u32) -> bool {
    // Placeholder implementation
    println!("Attempting to kill process with PID: {}", pid);
    true // Return success for demo
}
