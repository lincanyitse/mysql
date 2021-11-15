FROM debian as build

ARG MYSQL_VER=5.7.34
ENV MYSQL_MAJOR=5.7 \
    MYSQL_VERSION=${MYSQL_VER} \
    GOSU_VERSION=1.12

COPY --from=gosu/assets /opt/gosu /opt/gosu
COPY install.sh /tmp/
COPY docker-entrypoint.sh /usr/local/bin/

RUN sed -i 's/\w\+.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list && \
    groupadd -r mysql && useradd -r -g mysql mysql && \
    export MYSQL_MAJOR=${MYSQL_VER%.*} && \
    /tmp/install.sh apt_install && \ 
    savedAptMark="$(apt-mark showmanual)"; \
    /tmp/install.sh gosu_install && \ 
    /tmp/install.sh compile_install; \
    apt-mark auto '.*' >/dev/null;\
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark >/dev/null; \
    apt-get purge -qqy --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get install -qqy --no-install-recommends  libatomic1 libssl-dev libaio-dev libncurses5-dev libbison-dev libtirpc-dev && \
    rm -rf /var/lib/apt/lists/* /tmp/* && \
    mkdir /docker-entrypoint-initdb.d && \
    ln -s usr/local/bin/docker-entrypoint.sh /docker-entrypoint.sh # backwards compat

VOLUME /var/lib/mysql
ENTRYPOINT ["docker-entrypoint.sh"]
EXPOSE 3306 33060
CMD ["mysqld"]
