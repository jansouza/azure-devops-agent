# azure-devops-agent

A Docker image based on Ubuntu for running Azure DevOps agents in Linux environments. This project automates the installation of all required dependencies, configures the agent, and enables seamless integration with Azure DevOps pipelines. It is ideal for running jobs in customized or containerized environments, supporting multiple architectures.

## Environment Variables

- `AZP_URL` (required): Azure DevOps organization URL (e.g., https://dev.azure.com/yourorg/)
- `AZP_TOKEN` (required): Personal Access Token with agent registration permissions
- `AZP_POOL` (required): Name of the agent pool
- `AZP_AGENT_NAME` (optional): Name for the agent instance

## Supported Architectures
- linux/amd64
- linux/arm64
- linux/arm/v7

## Build

To build the Docker image locally, run:

```
docker build -t azure-devops-agent .
```

## Example Usage

```
docker run -dit --name azp-agent \
  -e AZP_URL="https://dev.azure.com/yourorg/" \
  -e AZP_TOKEN="yourPAT" \
  -e AZP_POOL="your-pool" \
  -e AZP_AGENT_NAME="your-agent" \
  jansouza/azp-agent
```