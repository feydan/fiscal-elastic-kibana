FROM centos:7

RUN yum -y install java

RUN adduser kibana

USER kibana

WORKDIR /home/kibana

RUN curl -L -O https://artifacts.elastic.co/downloads/kibana/kibana-6.2.4-linux-x86_64.tar.gz
RUN tar -xvf kibana-6.2.4-linux-x86_64.tar.gz

WORKDIR kibana-6.2.4-linux-x86_64

COPY kibana.yml config/kibana.yml

EXPOSE 5601

CMD ["bin/kibana"]