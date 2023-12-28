FROM debian:12-slim
ENV GOSU_VERSION 1.16 
ENV MYSQL_MAJOR=5.7
ENV MYSQL_VERSION=5.7.44
RUN set -eux; \
    groupadd -r mysql -g 999 && useradd -u 999 -r -g mysql mysql \
    && apt-get update && apt-get install -y \
    curl  \
    vim \
    && latest=$(curl -fsSL "http://dev.mysql.com/downloads/mysql/${MYSQL_MAJOR}.html?tpl=files&os=src&osva=Generic+Linux+(Architecture+Independent)" | grep "${MYSQL_MAJOR}" | grep -oE "(${MYSQL_MAJOR}.[0-9]+)" | head -n 1) \
    && export MYSQL_VERSION="${latest}" \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-mark auto '.*' >/dev/null;\
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark >/dev/null; \
    apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    bison \
    openssl \
    libssl-dev \
    pkg-config \
    libtirpc-dev \
    git \
    libaio-dev \
    libncurses5-dev \
    gnupg \
    ca-certificates \
    && url="http://dev.mysql.com/get/Downloads/MySQL-${MYSQL_MAJOR}/mysql-boost-${MYSQL_VERSION}.tar.gz"; \
    cd /tmp && \
    curl -fsSL "${url}" | tar zxv; \
    cd /tmp/mysql-${MYSQL_VERSION} && \
    cmake . \
    -DBUILD_CONFIG=mysql_release \
    -DINSTALL_LAYOUT=STANDALONE \
    -DCPACK_MONOLITHIC_INSTALL=0 \
    -DWITH_BOOST=boost \
    -DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
    -DDEFAULT_CHARSET=utf8mb4 \
    -DDEFAULT_COLLATION=utf8mb4_general_ci \
    -DWITH_EXTRA_CHARSETS:STRING=utf8mb4,gbk \
    -DWITH_MYISAM_STORAGE_ENGINE=1 \
    -DWITH_INNOBASE_STORAGE_ENGINE=1 \
    -DENABLED_LOCAL_INFILE=1 \
    -DCMAKE_INSTALL_PREFIX=/usr/share/mysql \
    -DINSTALL_BINDIR=/usr/bin \
    -DINSTALL_SBINDIR=/usr/sbin \
    -DINSTALL_LIBDIR=/usr/lib/mysql \
    -DINSTALL_INCLUDEDIR=/usr/include/mysql \
    -DINSTALL_DOCDIR=/usr/share/doc/packages \
    -DSYSCONFDIR=/etc/mysql/ \
    -DINSTALL_MYSQLTESTDIR= \
    -DINSTALL_SECURE_FILE_PRIV_EMBEDDEDDIR= \
    -DWITH_EMBEDDED_SERVER=0 \
    -DWITH_EMBEDDED_SHARED_LIBRARY=0 \
    -DENABLE_DOWNLOADS=0 \
    -DWITH_DEBUG=0 \
    -DWITH_UNIT_TESTS=OFF \
    -DMYSQL_DATADIR=/var/lib/mysql && \
    make -j1 && \
    make install -j1 && \
    mkdir -p /etc/mysql/conf.d/ && \
    echo '[mysqld]\nskip-host-cache\nskip-name-resolve' >/etc/mysql/conf.d/docker.cnf && \
    rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld /var/lib/mysql-files && \
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld && \
    chmod 1777 /var/run/mysqld /var/lib/mysql && \
    mkdir /docker-entrypoint-initdb.d && \
    apt-get purge -qqy --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get install -qqy --no-install-recommends  libatomic1 libssl-dev libaio-dev libncurses5-dev libbison-dev libtirpc-dev && \
    rm -rf /tmp/* /var/lib/apt/lists/*

VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 3306 33060
CMD ["mysqld"]