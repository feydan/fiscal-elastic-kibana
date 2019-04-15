FROM centos:7

RUN yum -y install java

RUN adduser kibana

USER kibana

WORKDIR /home/kibana

ENV KIBANA_VERSION=7.0.0
ENV KIBANA_DIR="kibana-${KIBANA_VERSION}-linux-x86_64"

RUN curl -L https://artifacts.elastic.co/downloads/kibana/${KIBANA_DIR}.tar.gz | tar -xz

WORKDIR ${KIBANA_DIR}

COPY kibana.yml config/kibana.yml

EXPOSE 5601

CMD ["bin/kibana"]