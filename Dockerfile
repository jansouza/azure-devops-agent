FROM ubuntu:22.04
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

RUN echo "TARGETPLATFORM: $TARGETPLATFORM"
RUN echo "TARGETOS: $TARGETOS"
RUN echo "TARGETARCH: $TARGETARCH"
RUN echo "TARGETVARIANT: $TARGETVARIANT"

RUN case "$TARGETPLATFORM" in \
  "linux/amd64") TARGETARCH="linux-x64" ;; \
  "linux/arm64") TARGETARCH="linux-arm64" ;; \
  "linux/arm/v7") TARGETARCH="linux-arm" ;; \
  *) TARGETARCH="unknown" ;; \
  esac && \
  echo "Set TARGETARCH to $TARGETARCH" && \
  echo "TARGETARCH=$TARGETARCH" >> /etc/environment

#ENV TARGETARCH="linux-x64"
# Also can be "linux-arm", "linux-arm64".

RUN apt update && \
  apt upgrade -y && \
  apt install -y curl gpg apt-transport-https git jq libicu70 unzip

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Java Development Kits
RUN apt install -y openjdk-8-jdk openjdk-11-jdk openjdk-17-jdk

# Install Maven
RUN apt install -y maven

# Install Helm
RUN curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list && \
    apt-get update && \
    apt-get install -y helm

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Install Docker CLI
RUN apt-get update && \
    apt-get install -y ca-certificates gnupg lsb-release && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli

WORKDIR /azp/

COPY assets/azp-start.sh ./
RUN chmod +x ./azp-start.sh

# Create agent user and set up home directory
RUN useradd -m -d /home/agent agent
RUN chown -R agent:agent /azp /home/agent

USER agent
# Another option is to run the agent as root.
# ENV AGENT_ALLOW_RUNASROOT="true"

ENTRYPOINT [ "./azp-start.sh" ]