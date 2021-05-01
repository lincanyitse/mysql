FROM debian

RUN set -x &&\
    sed -i 's/\w\+.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list && \
    groupadd -r mysql && useradd -r -g mysql mysql && \
    apt-get update -qq && apt-get install -qqy --no-install-recommends gnupg dirmngr && \
    rm -rf /var/lib/apt/lists/*

ENV GOSU_VERSION 1.12
RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update -qq; \
    apt-get install -qqy --no-install-recommends ca-certificates wget; \
    rm -rf /var/lib/apt/lists/*; \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
    wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
    apt-mark auto '.*' > /dev/null; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
    apt-get purge -qqy --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    chmod +x /usr/local/bin/gosu; \
    gosu --version; \
    gosu nobody true

ARG MYSQL_VER=5.7.34
ENV MYSQL_MAJOR=5.7
ENV MYSQL_VERSION=${MYSQL_VER}
RUN set -x && \
    export MYSQL_MAJOR=${MYSQL_VER%.*} && \
    apt-get update -qq && \
    apt-get install -qqy build-essential cmake curl ca-certificates wget libbison-dev libssl-dev libncurses5-dev pkg-config libtirpc-dev git libaio-dev >/dev/null && \
    cd /tmp && \
    version=$(curl -fsSL "http://dev.mysql.com/downloads/mysql/${MYSQL_MAJOR}.html?tpl=files&os=src&osva=Generic+Linux+(Architecture+Independent)"|grep "${MYSQL_MAJOR}"|grep -oE "(${MYSQL_MAJOR}.[0-9]+)"|head -n 1) || \
    if [ "$version" == "" ]; then version=$(wget -q -O- "http://dev.mysql.com/downloads/mysql/${MYSQL_MAJOR}.html?tpl=files&os=src&osva=Generic+Linux+(Architecture+Independent)"|grep "${MYSQL_MAJOR}"|grep -oE "(${MYSQL_MAJOR}.[0-9]+)"|head -n 1);fi && \
    if [ "$MYSQL_VERSION" != "$version" -a "$version" != "" ]; then export MYSQL_VERSION="$version";fi && \
    curl -fsSL "http://dev.mysql.com/get/Downloads/MySQL-${MYSQL_MAJOR}/mysql-boost-${MYSQL_VERSION}.tar.gz" | tar -zxv || \
    wget -q -O - "http://dev.mysql.com/get/Downloads/MySQL-${MYSQL_MAJOR}/mysql-boost-${MYSQL_VERSION}.tar.gz" | tar -zxv && \
    cd /tmp/mysql-${MYSQL_VERSION} && \
    cmake \
    -DBUILD_CONFIG=mysql_release \
    -DINSTALL_LAYOUT=RPM \
    -DWITH_BOOST=boost \
    -DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
    -DDEFAULT_CHARSET=utf8mb4 \
    -DDEFAULT_COLLATION=utf8mb4_general_ci \
    -DWITH_EXTRA_CHARSETS:STRING=utf8mb4,gbk \
    -DWITH_MYISAM_STORAGE_ENGINE=1 \
    -DWITH_INNOBASE_STORAGE_ENGINE=1 \
    -DENABLED_LOCAL_INFILE=1 \
    # -DWITH_MEMORY_STORAGE_ENGINE=1 \
    # -DWITH_READLINE=1 \
    # -DMYSQL_USER=mysql \
    -DINSTALL_MYSQLTESTDIR= \
    -DINSTALL_SECURE_FILE_PRIV_EMBEDDEDDIR= \
    -DWITH_EMBEDDED_SERVER=false \
    -DMYSQL_DATADIR=/var/mysql/data && \
    make -j$(nproc) && make install -j$(nproc) && \
    apt-get purge -qqy --auto-remove build-essential cmake git wget; \
    mkdir -p /etc/mysql/conf.d/ &&\
    echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf && \
    rm -rf /var/lib/apt/lists/* /tmp/* && \
    rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld && \
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld &&\
    chmod 1777 /var/run/mysqld /var/lib/mysql

VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /usr/local/bin/
RUN mkdir /docker-entrypoint-initdb.d && \
    mkdir -p /var/lib/mysql-files && \
    ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 3306 33060
CMD ["mysqld"]