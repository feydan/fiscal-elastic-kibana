FROM centos:7

RUN yum -y install java

RUN adduser elastic

USER elastic

WORKDIR /home/elastic

RUN curl -L -O https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.2.4.tar.gz
RUN tar -xvf elasticsearch-6.2.4.tar.gz

WORKDIR elasticsearch-6.2.4

COPY elasticsearch.yml config/elasticsearch.yml

CMD ["sh", "-c", "ES_JAVA_OPTS='-Xms500m -Xmx500m' bin/elasticsearch"]