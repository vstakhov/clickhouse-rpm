# Build clickhouse image

FROM centos:7
MAINTAINER Rob Vega <rvega@mimecast.com>

VOLUME ["vol1"]
WORKDIR /root
RUN sh build_packages.sh



