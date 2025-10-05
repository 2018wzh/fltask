use crate::api::simple::ProcessInfo;
use libproc::libproc::proc_pid;

/// macOS implementation: Get process list
pub fn get_processes_impl() -> Vec<ProcessInfo> {
    let mut processes = Vec::new();

    if let Ok(pids) = proc_pid::listpids(proc_pid::ProcType::ProcAllPIDS) {
        for pid in pids {
            if let Ok(task_info) = proc_pid::pidinfo::<proc_pid::TaskAllInfo>(pid as i32, 0) {
                if let Ok(path) = proc_pid::pidpath(pid as i32) {
                    let name = std::path::Path::new(&path)
                        .file_name()
                        .and_then(|s| s.to_str())
                        .unwrap_or(&path)
                        .to_string();

                    let memory_usage = task_info.ptinfo.pti_resident_size;
                    
                    // CPU usage is complex to calculate accurately on macOS without historical data
                    let cpu_usage = 0.0; 

                    processes.push(ProcessInfo {
                        pid: pid as u32,
                        name,
                        cpu_usage,
                        memory_usage,
                        parent_pid: Some(task_info.pbsd.pbi_ppid as u32),
                        status: "Running".to_string(), // Simplified status
                        command: path,
                        start_time: task_info.pbsd.pbi_start_tvsec,
                    });
                }
            }
        }
    }

    processes
}

/// macOS implementation: Kill a process
pub fn kill_process_impl(pid: u32) -> bool {
    unsafe {
        libc::kill(pid as i32, libc::SIGKILL) == 0
    }
}
