FROM sipp_box

USER root

COPY run_legit.sh /opt/run_legit.sh
RUN mkdir -p /opt/shared
RUN mkdir -p /opt/sipp-scenarios
WORKDIR /opt

ENTRYPOINT ["/bin/bash"]
