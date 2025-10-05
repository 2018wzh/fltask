use crate::api::simple::ProcessInfo;
use std::{fs, path::Path};
use std::io::Read;

pub fn get_processes_impl() -> Vec<ProcessInfo> {
    let mut out = Vec::new();
    let proc_dir = Path::new("/proc");
    if let Ok(entries) = fs::read_dir(proc_dir) {
        for entry in entries.flatten() {
            let file_name = entry.file_name();
            let file_str = match file_name.to_str() { Some(s) => s, None => continue };
            if !file_str.chars().all(|c| c.is_ascii_digit()) { continue; }
            let pid: u32 = match file_str.parse() { Ok(p) => p, Err(_) => continue };

            let name = fs::read_to_string(format!("/proc/{}/comm", pid))
                .map(|s| s.trim_end().to_string())
                .unwrap_or_else(|_| String::from("?"));

            let command = fs::read_to_string(format!("/proc/{}/cmdline", pid))
                .map(|s| s.split('\0').filter(|p| !p.is_empty()).collect::<Vec<_>>().join(" "))
                .unwrap_or_else(|_| name.clone());

            let mut parent_pid: Option<u32> = None;
            let mut memory_usage: u64 = 0;
            if let Ok(mut f) = fs::File::open(format!("/proc/{}/status", pid)) {
                let mut buf = String::new();
                if f.read_to_string(&mut buf).is_ok() {
                    for line in buf.lines() {
                        if line.starts_with("PPid:") {
                            if let Some(val) = line.split_whitespace().nth(1) { parent_pid = val.parse().ok(); }
                        } else if line.starts_with("VmRSS:") {
                            if let Some(val) = line.split_whitespace().nth(1) { memory_usage = val.parse::<u64>().unwrap_or(0) * 1024; }
                        }
                    }
                }
            }

            out.push(ProcessInfo {
                pid,
                name: name.clone(),
                cpu_usage: 0.0,
                memory_usage,
                parent_pid,
                status: String::new(),
                command,
                start_time: 0,
            });
        }
    }
    out
}

pub fn kill_process_impl(pid: u32) -> bool {
    unsafe { libc::kill(pid as i32, libc::SIGKILL) == 0 }
}
