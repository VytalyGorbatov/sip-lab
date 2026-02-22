#!/usr/bin/env python3
"""UDP control client that requests restarts and runs a bash command."""

import socket
import subprocess
import sys
from typing import Tuple

SERVER_HOST = "172.18.0.3"
SERVER_PORT = 5005
CLIENT_COMMAND = "./run_caller_commands.sh"  # Populate with the bash command to run.
RESTART_PAYLOAD = b"RESTART"
START_PAYLOAD = b"START"

def run_command() -> None:
    """Execute the configured bash command and wait for it to finish."""
    if not CLIENT_COMMAND:
        raise RuntimeError("CLIENT_COMMAND is empty; set a bash command to run.")
    proc = subprocess.Popen(["/bin/bash", "-c", CLIENT_COMMAND])
    proc.wait()

def await_start(sock: socket.socket, server: Tuple[str, int]) -> None:
    """Send the restart request and block until the server replies."""
    sock.sendto(RESTART_PAYLOAD, server)
    print("Sent RESTART to server, waiting for START...")
    while True:
        data, _ = sock.recvfrom(4096)
        if data.strip().upper() == START_PAYLOAD:
            print("Received START from server.")
            return

def main() -> None:
    server = (SERVER_HOST, SERVER_PORT)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        try:
            while True:
                await_start(sock, server)
                run_command()
        except KeyboardInterrupt:
            pass

if __name__ == "__main__":
    try:
        main()
    except RuntimeError as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)
