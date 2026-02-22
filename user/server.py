#!/usr/bin/env python3
"""UDP control server that manages a background bash command."""

import signal
import socket
import subprocess
import sys
from typing import Optional

SERVER_HOST = "0.0.0.0"
SERVER_PORT = 5005
SERVER_COMMAND = "./run_callee_commands.sh"  # Populate with the bash command to run.

def launch_command() -> subprocess.Popen:
    """Start the configured bash command as a child process."""
    if not SERVER_COMMAND:
        raise RuntimeError("SERVER_COMMAND is empty; set a bash command to run.")
    return subprocess.Popen(["/bin/bash", "-c", SERVER_COMMAND])

def stop_command(proc: Optional[subprocess.Popen]) -> None:
    """Terminate the running process if it exists."""
    if proc is None:
        return
    if proc.poll() is not None:
        print("Process already terminated.")
        return
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()

def restart_command(proc: Optional[subprocess.Popen]) -> subprocess.Popen:
    """Replace the current process with a fresh one."""
    stop_command(proc)
    return launch_command()

def main() -> None:
    current_proc: Optional[subprocess.Popen] = None
    try:
        current_proc = launch_command()
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind((SERVER_HOST, SERVER_PORT))
            while True:
                print("Waiting for RESTART command from client...")
                data, addr = sock.recvfrom(4096)
                if data.strip().upper() != b"RESTART":
                    continue
                print("Received RESTART command, restarting process...")
                current_proc = restart_command(current_proc)
                sock.sendto(b"START", addr)
    except KeyboardInterrupt:
        pass
    finally:
        stop_command(current_proc)

if __name__ == "__main__":
    # Ensure child processes die when the server exits.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    main()
