FROM centos:7

RUN yum -y install java

RUN adduser elastic

USER elastic

WORKDIR /home/elastic

ENV ELASTICSEARCH_VERSION=6.6.0
ENV ELASTICSEARCH_DIR="elasticsearch-${ELASTICSEARCH_VERSION}"

RUN curl -L "https://artifacts.elastic.co/downloads/elasticsearch/${ELASTICSEARCH_DIR}.tar.gz" | tar -xz

WORKDIR ${ELASTICSEARCH_DIR}

COPY elasticsearch.yml config/elasticsearch.yml

CMD ["sh", "-c", "ES_JAVA_OPTS='-Xms500m -Xmx500m' bin/elasticsearch"]