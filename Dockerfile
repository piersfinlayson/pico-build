FROM ubuntu:22.04
LABEL maintainer="piers@piersandkatie.com"
LABEL description="Container for building all things related to the Raspberry Pi Pico"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        apt-transport-https \
        bash \
        bash-completion \
        build-essential \
        ca-certificates \
        cmake \
        coreutils \
        curl \
        git \
        libusb-1.0-0-dev \
        nano \
        pkg-config \
        python3 \
        sed \
        sudo \
        vim \
        wget \ 
        xz-utils && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*

COPY sudoers /etc/sudoers.d/nopasswd
RUN useradd -ms /bin/bash build && \
    usermod -a -G dialout build && \
    usermod -a -G sudo build && \
    cp /etc/skel/.bashrc /etc/skel/.profile /etc/skel/.bash_logout /home/build/ && \
    sed -i -- 's/#force_color_prompt=yes/force_color_prompt=yes/g' /home/build/.bashrc

USER build
COPY .vimrc /home/build/
COPY install-pico-build.sh /tmp/
RUN /tmp/install-pico-build.sh /home/build/builds && \
    sudo apt-get clean && \
    sudo rm -fr /var/lib/apt/lists/*

WORKDIR /home/build
ENV PICO_SDK_PATH /home/build/builds/pico-sdk
ENV PICO_TOOLCHAIN_PATH /home/build/builds/arm-gnu-toolchain
CMD ["/bin/bash", "-l"]
