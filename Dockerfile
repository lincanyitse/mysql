FROM debian:bullseye-slim
ENV GOSU_VERSION 1.16 
ENV MYSQL_MAJOR=5.7 
RUN set -eux; \
    groupadd -r mysql -g 999 && useradd -u 999 -r -g mysql mysql

RUN set -eux; \
    # sed -i 's/\w\+.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list && \
    apt-get update -qq && \
    apt-get install -qqy curl vim gnupg && \
    rm -rf /tmp/* /var/lib/apt/lists/*; \
    # add gosu for easy step-down from root
    # https://github.com/tianon/gosu/releases
    # TODO find a better userspace architecture detection method than querying the kernel
    arch="$(uname -m)"; \
    case "$arch" in \
    aarch64) gosuArch='arm64' ;; \
    armv7l) gosuArch='armhf' ;; \
    x86_64) gosuArch='amd64' ;; \
    *) echo >&2 "error: unsupported architecture: '$arch'"; exit 1 ;; \
    esac; \
    curl -fL -o /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$gosuArch.asc"; \
    curl -fSL -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$gosuArch"; \
    export GNUPGHOME="$(mktemp -d)" &&  \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu &&  \
    rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc &&  \
    chmod 755 /usr/local/bin/gosu; \
    gosu --version; \
    gosu nobody true

RUN set -eux; \    
    savedAptMark="$(apt-mark showmanual)"; \
    apt-mark auto '.*' >/dev/null;\
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark >/dev/null; \
    apt-get update -qq && \
    apt-get install -qqy build-essential cmake ca-certificates wget gnupg dirmngr libbison-dev libssl-dev libncurses5-dev pkg-config libtirpc-dev git libaio-dev && \
    latest=$(curl -fsSL "http://dev.mysql.com/downloads/mysql/${MYSQL_MAJOR}.html?tpl=files&os=src&osva=Generic+Linux+(Architecture+Independent)" | grep "${MYSQL_MAJOR}" | grep -oE "(${MYSQL_MAJOR}.[0-9]+)" | head -n 1) && \
    MYSQL_VERSION="${latest}" && \
    url="http://dev.mysql.com/get/Downloads/MySQL-${MYSQL_MAJOR}/mysql-boost-${MYSQL_VERSION}.tar.gz"; \
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
    make -j$(nproc) && \
    make install -j$(nproc) && \
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