FROM debian

ARG MYSQL_VER=5.7.39
ENV MYSQL_MAJOR=5.7 \
    MYSQL_VERSION=${MYSQL_VER} \
    GOSU_VERSION=1.14
# 创建用户及用户组
RUN groupadd -r mysql && \
    useradd -r -g mysql -m mysql
# 安装默认工具
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends gnupg dirmngr >/dev/null && \
    rm -rf /var/lib/apt/lists/*
# 安装 gosu
RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends curl ca-certificates >/dev/null; \
    rm -rf /var/lib/apt/lists/*; \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{print $NF}')"; \
    curl -fsSLo /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
    curl -fsSLo /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
    apt-mark auto '.*' >/dev/null; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark >/dev/null; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false >/dev/null; \
    chmod +x /usr/local/bin/gosu; \
    gosu --version && gosu nobody true

COPY install.sh /tmp
COPY docker-entrypoint.sh /usr/local/bin/
RUN set -eux;\
    chmod 755 /tmp/install.sh && \
    /tmp/install.sh apt_install && \ 
    /tmp/install.sh compile_install; \
    ln -s /usr/local/bin/docker-entrypoint.sh /entrypoint.sh && \
    apt-get purge -qqy --auto-remove -o APT::AutoRemove::RecommendsImportant=false >/dev/null; \
    apt-get install -qqy --no-install-recommends  bzip2 openssl perl xz-utils zstd libssl-dev libaio-dev libncurses5-dev libbison-dev libtirpc-dev && \
    rm -rf /var/lib/apt/lists/* /tmp/* 


VOLUME /var/lib/mysql
EXPOSE 3306 33060

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["mysqld"]
