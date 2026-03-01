#!/bin/bash
set -e

if [ -f /etc/environment ]; then
  set -a
  . /etc/environment
  set +a
fi

# Auto-detect TARGETARCH if not set
if [ -z "${TARGETARCH}" ]; then
  case "$(uname -m)" in
    "x86_64")  TARGETARCH="linux-x64" ;;
    "aarch64") TARGETARCH="linux-arm64" ;;
    "armv7l")  TARGETARCH="linux-arm" ;;
    *)         TARGETARCH="linux-x64" ;;
  esac
  echo "TARGETARCH not set, auto-detected: ${TARGETARCH}"
fi

if [ -z "${AZP_URL}" ]; then
  echo 1>&2 "error: missing AZP_URL environment variable"
  exit 1
fi

if [ -n "$AZP_CLIENTID" ]; then
  echo "Using service principal credentials to get token"
  az login --allow-no-subscriptions --service-principal --username "$AZP_CLIENTID" --password "$AZP_CLIENTSECRET" --tenant "$AZP_TENANTID"
  # adapted from https://learn.microsoft.com/en-us/azure/databricks/dev-tools/user-aad-token
  AZP_TOKEN=$(az account get-access-token --query accessToken --output tsv)
  echo "Token retrieved"
fi

if [ -z "${AZP_TOKEN_FILE}" ]; then
  if [ -z "${AZP_TOKEN}" ]; then
    echo 1>&2 "error: missing AZP_TOKEN environment variable"
    exit 1
  fi

  AZP_TOKEN_FILE="/azp/.token"
  echo -n "${AZP_TOKEN}" > "${AZP_TOKEN_FILE}"
fi

unset AZP_CLIENTSECRET
unset AZP_TOKEN

if [ -n "${AZP_WORK}" ]; then
  mkdir -p "${AZP_WORK}"
fi

cleanup() {
  trap "" EXIT

  if [ -e ./config.sh ]; then
    print_header "Cleanup. Removing Azure Pipelines agent..."

    while true; do
      # Use the same auth method used during config
      ./config.sh remove --unattended --auth "PAT" --token "$(cat "${AZP_TOKEN_FILE}")" && break

      echo "Retrying in 30 seconds..."
      sleep 30
    done
  fi
}

print_header() {
  lightcyan="\033[1;36m"
  nocolor="\033[0m"
  echo -e "\n${lightcyan}$1${nocolor}\n"
}

# Let the agent ignore the token env variables
export VSO_AGENT_IGNORE="AZP_TOKEN,AZP_TOKEN_FILE"

print_header "1. Determining matching Azure Pipelines agent..."

AZP_AGENT_PACKAGES=$(curl -LsS \
    -u user:$(cat "${AZP_TOKEN_FILE}") \
    -H "Accept:application/json" \
    "${AZP_URL}/_apis/distributedtask/packages/agent?platform=${TARGETARCH}&top=1")

# Debug: log the response to help diagnose issues
echo "Agent packages response: ${AZP_AGENT_PACKAGES}" | head -c 500

AZP_AGENT_PACKAGE_LATEST_URL=$(echo "${AZP_AGENT_PACKAGES}" | jq -r ".value[0].downloadUrl")

if [ -z "${AZP_AGENT_PACKAGE_LATEST_URL}" -o "${AZP_AGENT_PACKAGE_LATEST_URL}" == "null" ]; then
  echo 1>&2 "error: could not determine a matching Azure Pipelines agent"
  echo 1>&2 "Platform requested: ${TARGETARCH}"
  echo 1>&2 "AZP_URL: ${AZP_URL}"
  echo 1>&2 "Raw response: ${AZP_AGENT_PACKAGES}"
  exit 1
fi

# Após obter AZP_AGENT_PACKAGE_LATEST_URL, verificar se é versão 3.x
AGENT_VERSION=$(echo "${AZP_AGENT_PACKAGES}" | jq -r ".value[0].version.major")
if [ "${AGENT_VERSION}" -lt 3 ]; then
  echo 1>&2 "error: Agent version ${AGENT_VERSION}.x is not supported on Ubuntu 24.04. Requires 3.x+"
  exit 1
fi

print_header "2. Downloading and extracting Azure Pipelines agent..."

# Removed background+wait pattern to properly catch extraction errors
curl -LsS "${AZP_AGENT_PACKAGE_LATEST_URL}" | tar -xz

if [ ! -f ./env.sh ]; then
  echo 1>&2 "error: env.sh not found after extraction - download may have failed"
  exit 1
fi

source ./env.sh

trap "cleanup; exit 0" EXIT
trap "cleanup; exit 130" INT
trap "cleanup; exit 143" TERM

print_header "3. Configuring Azure Pipelines agent..."

./config.sh --unattended \
  --agent "${AZP_AGENT_NAME:-$(hostname)}" \
  --url "${AZP_URL}" \
  --auth "PAT" \
  --token "$(cat "${AZP_TOKEN_FILE}")" \
  --pool "${AZP_POOL:-Default}" \
  --work "${AZP_WORK:-_work}" \
  --replace \
  --acceptTeeEula & wait $!

print_header "4. Running Azure Pipelines agent..."

chmod +x ./run.sh

# To be aware of TERM and INT signals call ./run.sh
# Running it with the --once flag at the end will shut down the agent after the build is executed
./run.sh "$@" & wait $!