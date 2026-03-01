FROM ubuntu:24.04
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

RUN echo "TARGETPLATFORM: $TARGETPLATFORM" && \
    echo "TARGETOS: $TARGETOS" && \
    echo "TARGETARCH: $TARGETARCH" && \
    echo "TARGETVARIANT: $TARGETVARIANT"

RUN PLATFORM="${TARGETPLATFORM:-$(dpkg --print-architecture)}" && \
  case "$PLATFORM" in \
  "linux/amd64"|"amd64") TARGETARCH="linux-x64" ;; \
  "linux/arm64"|"arm64") TARGETARCH="linux-arm64" ;; \
  "linux/arm/v7"|"armhf") TARGETARCH="linux-arm" ;; \
  *) TARGETARCH="linux-x64" ;; \
  esac && \
  echo "Set TARGETARCH to $TARGETARCH (from platform: $PLATFORM)" && \
  echo "TARGETARCH=$TARGETARCH" >> /etc/environment

# Layer 1: Base system packages (rarely changes)
RUN apt update && \
    apt upgrade -y && \
    apt install -y \
      curl gpg apt-transport-https git jq libicu74 unzip sudo \
      ca-certificates gnupg lsb-release software-properties-common \
      libssl3 libstdc++6 zlib1g liblttng-ust1 libkrb5-3 libgssapi-krb5-2 && \
    rm -rf /var/lib/apt/lists/*

# Layer 2: Azure CLI (changes independently)
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
    rm -rf /var/lib/apt/lists/*

# Layer 3: Java (changes independently)
RUN apt update && \
    apt install -y openjdk-8-jdk openjdk-11-jdk openjdk-17-jdk maven && \
    rm -rf /var/lib/apt/lists/*

# Layer 4: Python (changes independently)
RUN add-apt-repository ppa:deadsnakes/ppa && apt update && \
    apt install -y \
      python3.9 python3.9-venv python3.9-dev python3.9-distutils \
      python3.10 python3.10-venv python3.10-dev python3.10-distutils \
      python3.11 python3.11-venv python3.11-dev python3.11-distutils \
      python3.12 python3.12-venv python3.12-dev \
      python3.13 python3.13-venv python3.13-dev \
      python3.14 python3.14-venv python3.14-dev \
      python3-pip python3-setuptools python3-wheel && \
    rm -rf /var/lib/apt/lists/* && \
    curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
    python3.9 /tmp/get-pip.py --break-system-packages --ignore-installed && \
    python3.10 /tmp/get-pip.py --break-system-packages --ignore-installed && \
    python3.11 /tmp/get-pip.py --break-system-packages --ignore-installed && \
    python3.12 /tmp/get-pip.py --break-system-packages --ignore-installed && \
    python3.13 /tmp/get-pip.py --break-system-packages --ignore-installed && \
    python3.14 /tmp/get-pip.py --break-system-packages --ignore-installed && \
    rm /tmp/get-pip.py && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 2 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 3 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 4 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 5 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 6 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.14 7 && \
    update-alternatives --set python3 /usr/bin/python3.12

# Layer 5: Python tools (changes independently)
RUN pip3 install --break-system-packages yamale yamllint && \
    ln -sf /usr/local/bin/yamale /usr/bin/yamale && \
    ln -sf /usr/local/bin/yamllint /usr/bin/yamllint

# Layer 6: Helm (changes independently)
RUN curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list && \
    apt-get update && \
    apt-get install -y helm && \
    rm -rf /var/lib/apt/lists/*

# Layer 7: kubectl (changes independently) - fixed for multi-arch
RUN PLATFORM="${TARGETPLATFORM:-$(dpkg --print-architecture)}" && \
    KUBECTL_ARCH=$(case "$PLATFORM" in \
      "linux/amd64"|"amd64") echo "amd64" ;; \
      "linux/arm64"|"arm64") echo "arm64" ;; \
      "linux/arm/v7"|"armhf") echo "arm" ;; \
      *) echo "amd64" ;; \
    esac) && \
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/${KUBECTL_ARCH}/kubectl" && \
    install -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Layer 8: Docker CLI (changes independently)
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Layer 9: Agent setup (changes most frequently)
WORKDIR /azp
COPY assets/azp-start.sh ./
RUN chmod +x ./azp-start.sh && \
    useradd -m -d /home/agent agent && \
    usermod -aG sudo agent && \
    echo "agent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    chown -R agent:agent /azp /home/agent && \
    chmod -R 775 /azp

USER agent

ENTRYPOINT [ "./azp-start.sh" ]