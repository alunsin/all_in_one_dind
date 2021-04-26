ARG GOLANG_VERSION=1.15.2
ARG BAZEL_VERSION=2.2.0
ARG IBM_CLOUD_VERSION=1.2.1
FROM golang:$GOLANG_VERSION AS builder

ARG TF_VERSION
ENV TF_VERSION ${TF_VERSION:-v0.12.29}

RUN go get rsc.io/goversion \
    && GO111MODULE=on go get github.com/hashicorp/terraform@$TF_VERSION

FROM debian:buster

ARG GOLANG_VERSION
ENV GOLANG_VERSION ${GOLANG_VERSION:-1.15.2}

ARG BAZEL_VERSION
ENV BAZEL_VERSION ${BAZEL_VERSION:-2.2.0}

ARG IBM_CLOUD_VERSION
ENV IBM_CLOUD_VERSION ${IBM_CLOUD_VERSION:-1.2.1}

WORKDIR /workspace
RUN mkdir -p /workspace
ENV WORKSPACE=/workspace \
    TERM=xterm
ENV PATH /usr/local/go/bin:$PATH

COPY --from=builder /go/bin/* /usr/local/bin/

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common \
    lsb-release && \
    rm -rf /var/lib/apt/lists/*

RUN add-apt-repository "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367 \
    && apt-get update && apt-get install -y --no-install-recommends \
    ansible \
    build-essential \
    ca-certificates \
    curl \
    default-jdk \
    file \
    git \
    gcc \
    jq \
    make \
    mercurial \
    openssh-client \
    pkg-config \
    procps \
    python \
    python-dev \
    python-gflags \
    python-openssl \
    python-pip \
    python-yaml \
    python3 \
    python3-distutils \
    python3-gflags \
    python3-pip \
    python3-yaml \
    rsync \
    unzip \
    wget \
    xz-utils \
    zip \
    zlib1g-dev \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "${dpkgArch##*-}" in \
        'amd64') \
            url="https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-amd64.tar.gz"; \
            ibm_cloud_url="https://clis.ng.bluemix.net/download/bluemix-cli/${IBM_CLOUD_VERSION}/linux64"; \
            curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg; \
            mv bazel.gpg /etc/apt/trusted.gpg.d/; \
            echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list; \
            apt update && apt install -y bazel=$BAZEL_VERSION; \
            ;; \
        'ppc64el') \
            url="https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-ppc64le.tar.gz"; \
            ibm_cloud_url="https://clis.ng.bluemix.net/download/bluemix-cli/${IBM_CLOUD_VERSION}/ppc64le"; \
            wget -O /usr/local/bin/bazel "https://oplab9.parqtec.unicamp.br/pub/ppc64el/bazel/ubuntu_18.04/bazel_bin_ppc64le_$BAZEL_VERSION" --progress=dot:giga; \
            chmod +x /usr/local/bin/bazel; \
            ;; \
        's390x') \
            url="https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-s390x.tar.gzr"; \
            ;; \
    esac; \
    \
    wget -O go.tgz "$url" --progress=dot:giga; \
    tar -C /usr/local -xzf go.tgz; \
    rm go.tgz; \
    go version; \
    wget -O ibm_cloud.tgz "$ibm_cloud_url" --progress=dot:giga; \
    tar -xf ibm_cloud.tgz; \
    ./Bluemix_CLI/install; \
    ibmcloud plugin install power-iaas; \
    ibmcloud plugin install cloud-object-storage; \
    rm -rf ./Bluemix_CLI; \
    rm ibm_cloud.tgz; \
    rm -rf /var/lib/apt/lists/*

ENV GOPATH /go
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

##
#Docker in Docker inspired from
#  https://github.com/docker-library/docker/tree/master/20.10/dind
# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
##
RUN set -eux; \
	addgroup --system dockremap; \
	adduser --system --ingroup dockremap dockremap; \
	echo 'dockremap:165536:65536' >> /etc/subuid; \
	echo 'dockremap:165536:65536' >> /etc/subgid

# https://github.com/docker/docker/tree/master/hack/dind
ENV DIND_COMMIT ed89041433a031cafc0a0f19cfe573c31688d377

RUN set -eux; \
	wget -O /usr/local/bin/dind "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind"; \
	chmod +x /usr/local/bin/dind;

#COPY dockerd-entrypoint.sh /usr/local/bin/
RUN set -eux; \
    wget https://raw.githubusercontent.com/docker-library/docker/094faa88f437cafef7aeb0cc36e75b59046cc4b9/20.10/dind/dockerd-entrypoint.sh;\
    chmod +x dockerd-entrypoint.sh;\
    mv dockerd-entrypoint.sh /usr/local/bin

VOLUME /var/lib/docker
EXPOSE 2375 2376

ENTRYPOINT ["dockerd-entrypoint.sh"]
CMD []