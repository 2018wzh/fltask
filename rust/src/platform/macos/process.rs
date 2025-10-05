use crate::api::simple::ProcessInfo;
use libproc::libproc::{proc_pid, task_info};
use libproc::processes;

pub fn get_processes_impl() -> Vec<ProcessInfo> {
    let mut processes = Vec::new();
    if let Ok(pids) = processes::pids_by_type(processes::ProcFilter::All) {
        for pid in pids {
            // pidinfo requires (pid: i32, arg: u64). For TaskAllInfo the arg is 0.
            if let Ok(task_info) = proc_pid::pidinfo::<task_info::TaskAllInfo>(pid as i32, 0) {
                let raw = &task_info.pbsd.pbi_name;
                let nul_pos = raw.iter().position(|c| *c == 0).unwrap_or(raw.len());
                let name = String::from_utf8_lossy(&raw[..nul_pos]).to_string();
                let memory_usage = task_info.ptinfo.pti_resident_size as u64;
                processes.push(ProcessInfo {
                    pid: pid as u32,
                    name: name.clone(),
                    cpu_usage: 0.0, // TODO: collect per‑process CPU usage (requires task threads info / sampling)
                    memory_usage,
                    parent_pid: Some(task_info.pbsd.pbi_ppid as u32),
                    status: String::new(),
                    command: name,
                    start_time: 0,
                });
            }
        }
    }
    processes
}

pub fn kill_process_impl(pid: u32) -> bool {
    unsafe { libc::kill(pid as i32, libc::SIGKILL) == 0 }
}
