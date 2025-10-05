use crate::api::simple::ProcessInfo;
use procfs::process::{all_processes, Process};

/// Linux implementation: Get process list
pub fn get_processes_impl() -> Vec<ProcessInfo> {
    let mut processes = Vec::new();

    if let Ok(all_procs) = all_processes() {
        for p in all_procs {
            if let Ok(proc) = p {
                let stat = proc.stat();
                if let Ok(stat) = stat {
                    let memory_usage = stat.rss_bytes().unwrap_or(0);

                    processes.push(ProcessInfo {
                        pid: stat.pid as u32,
                        name: stat.comm.clone(),
                        cpu_usage: 0.0, // Calculating CPU usage on Linux is more complex
                        memory_usage,
                        parent_pid: Some(stat.ppid as u32),
                        status: stat.state.to_string(),
                        command: stat.comm.clone(),
                        start_time: stat.starttime,
                    });
                }
            }
        }
    }

    processes
}

/// Linux implementation: Kill a process
pub fn kill_process_impl(pid: u32) -> bool {
    unsafe {
        libc::kill(pid as i32, libc::SIGKILL) == 0
    }
}
