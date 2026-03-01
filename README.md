# azure-devops-agent

A Docker image based on **Ubuntu 24.04** for running Azure DevOps agents in Linux environments. This project automates the installation of all required dependencies, configures the agent, and enables seamless integration with Azure DevOps pipelines. It is ideal for running jobs in customized or containerized environments, supporting multiple architectures.

## Installed Tools

| Tool | Version |
|------|---------|
| Azure CLI | latest |
| Java (OpenJDK) | 8, 11, 17 |
| Maven | latest |
| Python | 3.9, 3.10, 3.11, 3.12 (default), 3.13, 3.14 |
| Helm | latest |
| kubectl | latest stable |
| Docker CLI | latest |
| yamale | latest |
| yamllint | latest |

### Python Details

All Python versions include:
- `venv` — virtual environment support
- `dev` — headers for native extensions
- `pip` — package manager (installed via `get-pip.py`)
- `distutils` — build utilities (3.8–3.11 only)

To switch the default Python version:
```bash
sudo update-alternatives --config python3
```

Or call a specific version directly:
```bash
python3.10 --version
python3.11 -m venv myenv
```

### Java Details

To switch the default Java version:
```bash
sudo update-alternatives --config java
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AZP_URL` | ✅ | Azure DevOps organization URL (e.g., `https://dev.azure.com/yourorg/`) |
| `AZP_TOKEN` | ✅ | Personal Access Token with agent registration permissions |
| `AZP_POOL` | ✅ | Name of the agent pool |
| `AZP_AGENT_NAME` | ❌ | Name for the agent instance (auto-generated if not set) |

## Supported Architectures

| Architecture | Tag |
|---|---|
| linux/amd64 | `linux-x64` |
| linux/arm64 | `linux-arm64` |
| linux/arm/v7 | `linux-arm` |

## Build

> **Prerequisite:** Multi-platform builds require the Docker Buildx plugin.
> ```bash
> # Add Docker's official repository first
> sudo apt install ca-certificates curl
> sudo install -m 0755 -d /etc/apt/keyrings
> sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
> sudo chmod a+r /etc/apt/keyrings/docker.asc
> echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
> sudo apt update
> sudo apt install docker-buildx-plugin
> docker buildx create --use --name mybuilder
> ```

To build the Docker image locally (single platform):

```bash
docker build -t azure-devops-agent .
```

To build for a specific platform:

```bash
docker buildx build --platform linux/amd64 -t azure-devops-agent --load .
```

To build multi-platform:

```bash
docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t azure-devops-agent --push .
```

> Note: `--load` loads the image into the local Docker daemon (single platform only).
> `--push` pushes directly to a registry (required for multi-platform).

## Example Usage

```bash
docker run -dit --name azp-agent \
  -e AZP_URL="https://dev.azure.com/yourorg/" \
  -e AZP_TOKEN="yourPAT" \
  -e AZP_POOL="your-pool" \
  -e AZP_AGENT_NAME="your-agent" \
  azure-devops-agent

# Clean
docker stop azp-agent && docker rm azp-agent && docker rmi azure-devops-agent
```

## Image Structure

The Dockerfile is organized in layers ordered by change frequency to maximize Docker cache efficiency:

1. **Base packages** — curl, git, jq, sudo, etc.
2. **Azure CLI** — installed via official Microsoft script
3. **Java** — OpenJDK 8, 11, 17 + Maven
4. **Python** — multiple versions with pip, venv and dev headers
5. **Python tools** — yamale, yamllint
6. **Helm** — via official Helm repository
7. **kubectl** — latest stable binary
8. **Docker CLI** — via official Docker repository
9. **Agent setup** — user, permissions, entrypoint script

> Each layer cleans `apt` cache with `rm -rf /var/lib/apt/lists/*` to minimize final image size.