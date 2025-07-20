FROM ubuntu:22.04
ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN echo "TARGETPLATFORM: $TARGETPLATFORM"
RUN echo "BUILDPLATFORM: $BUILDPLATFORM"

# Set TARGETARCH based on TARGETPLATFORM
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
      echo "TARGETARCH=linux-x64" >> /etc/environment; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      echo "TARGETARCH=linux-arm64" >> /etc/environment; \
    elif [ "$TARGETPLATFORM" = "linux/arm/v7" ]; then \
      echo "TARGETARCH=linux-arm" >> /etc/environment; \
    fi
RUN . /etc/environment && echo "TARGETARCH: $TARGETARCH"

#ENV TARGETARCH="linux-x64"
# Also can be "linux-arm", "linux-arm64".

RUN apt update && \
  apt upgrade -y && \
  apt install -y curl git jq libicu70

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