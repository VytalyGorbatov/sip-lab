FROM andrius/asterisk:latest

RUN apt-get -y update

RUN apt-get -y install \
    git \
    build-essential \
    libpcap-dev \
    libssl-dev \
    libxml2-dev \
    libpcre3-dev \
    bash \
    vim \
    tcpdump \
    && rm -rf /var/lib/apt/lists/*

USER root

COPY configs/pjsip.conf /etc/asterisk/pjsip.conf
COPY configs/extensions.conf /etc/asterisk/extensions.conf
RUN mkdir -p /opt/shared

EXPOSE 5060/udp 5060/tcp

# RUN asterisk -rx "pjsip reload"
# RUN asterisk -rx "dialplan reload"
