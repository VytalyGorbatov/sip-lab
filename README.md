# SIP Lab Environment

This repository provides a Docker-based environment for simulating and testing Session Initiation Protocol (SIP) traffic. It utilizes Asterisk as a PBX server and SIPp for traffic generation, orchestrated to run synchronized caller and callee scenarios. It also integrates `SIPTorch` for fuzzing capabilities.

## Architecture

The environment consists of three main services defined in `docker-compose.yml`:

- **server**: An Asterisk PBX server (based on `andrius/asterisk`). It handles SIP registration and call routing.
  - Configuration files: `server/configs/pjsip.conf`, `server/configs/extensions.conf`.
- **sip_callee**: The receiving end of the calls (User Agent Server). It runs a Python control script (`server.py`) that manages the execution of SIPp scenarios.
- **sip_caller**: The initiating end of the calls (User Agent Client). It runs a Python control script (`client.py`) that coordinates with the callee to start scenarios synchronously.

The `shared/` directory contains resources shared between the host and the containers, including the `SIPTorch` library.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Configuration

### 1. Fix Docker Volume Path

**Important:** Before running, you must update the absolute path in `docker-compose.yml` to match your local machine's directory structure.

Open `docker-compose.yml` and locate the `volumes` section at the bottom:

```yaml
volumes:
  shared-data:
    driver: local
    driver_opts:
      o: bind
      type: none
      # UPDATE THIS PATH TO YOUR LOCAL REPOSITORY PATH
      device: /absolute/path/to/your/sip-lab-repo/shared
```

### 2. Network Settings

The control scripts currently use hardcoded IP addresses. Ensure your Docker network assigns IPs as expected or update the following files:

- **user/client.py**: Update `SERVER_HOST` (default `172.18.0.3`) to match the IP of the `sip_callee` container.

## Usage

1. **Build and Start the Containers:**

   ```bash
   docker-compose up --build
   ```

   This command will:
   - Build the `server` and `user` images.
   - Start the Asterisk server.
   - Start the Callee and Caller containers.

2. **Simulation Flow:**

   - The **Callee** container starts listening for a coordination signal.
   - The **Caller** container sends a `RESTART` signal to the Callee.
   - The **Callee** resets its scenario script (`run_callee_commands.sh`) and signals back `START`.
   - The **Caller** begins its scenario script (`run_caller_commands.sh`).

3. **Modifying Scenarios:**

   - **Caller Logic**: Edit `user/run_caller_commands.sh` to change how traffic is generated.
   - **Callee Logic**: Edit `user/run_callee_commands.sh` to change how calls are received.
   - **SIPp Scenarios**: XML scenario files and PCAP files are located in `user/sipp-scenarios/`.

## Directory Structure

```
.
├── docker-compose.yml       # Service definitions
├── server/                  # Asterisk server setup
│   ├── Dockerfile
│   └── configs/             # Asterisk configuration files
├── shared/                  # Shared resources
│   └── SIPTorch/            # SIP fuzzing library
├── user/                    # Client/Server simulation scripts
│   ├── Dockerfile           # Environment for caller/callee
│   ├── client.py            # Caller orchestration script
│   ├── server.py            # Callee orchestration script
│   ├── run_caller_commands.sh
│   ├── run_callee_commands.sh
│   └── sipp-scenarios/      # SIPp scenario files
```

## SIPTorch

The repository includes `SIPTorch` in the `shared/` directory. This is a framework for SIP fuzzing and testing. See `shared/SIPTorch/README.md` for specific documentation on using that tool.
