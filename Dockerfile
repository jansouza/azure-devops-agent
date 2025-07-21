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
  apt install -y curl git jq libicu70

# Install Java Development Kits
# This installs OpenJDK 8, 11, and 17.
RUN apt install -y openjdk-8-jdk openjdk-11-jdk openjdk-17-jdk

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

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