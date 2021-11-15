#!/bin/bash
latest="${MYSQL_VERSION}"
run() {
    name="$1"
    cmd="$2"
    echo "$name runing......"
    sh -c "$cmd" >/tmp/info.log 2>/tmp/error.log
    ret=$?
    if [ $ret -eq 0 ]; then
        echo "${name} run success!"
    else
        echo "${name} run fail!"
        cat /tmp/info.log
        cat /tmp/error.log
    fi
    return $ret
}

apt_install() {
    run 'apt update' 'apt-get update -qq' &&
        run 'apt install' 'apt-get install -qqy build-essential cmake ca-certificates wget gnupg dirmngr libbison-dev libssl-dev libncurses5-dev pkg-config libtirpc-dev git libaio-dev' &&
        latest=$(wget -q -O- "http://dev.mysql.com/downloads/mysql/${MYSQL_MAJOR}.html?tpl=files&os=src&osva=Generic+Linux+(Architecture+Independent)" | grep "${MYSQL_MAJOR}" | grep -oE "(${MYSQL_MAJOR}.[0-9]+)" | head -n 1) &&
        if [ "${latest}" != "" -a "${latest}" != "${MYSQL_VERSION}" ]; then export MYSQL_VERSION="${latest}"; fi
    return $?
}

compile_install() {
    url="http://dev.mysql.com/get/Downloads/MySQL-${MYSQL_MAJOR}/mysql-boost-${MYSQL_VERSION}.tar.gz"
    cd /tmp &&
        run 'msql download' "wget -q -O- ${url} | tar zxv" &&
        cd /tmp/mysql-${MYSQL_VERSION} &&
        run 'cmake' 'cmake . \
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
            -DMYSQL_DATADIR=/var/lib/mysql' &&
        run 'make' 'make -j$(nproc)' &&
        run 'make install' 'make install -j$(nproc)' &&
        mkdir -p /etc/mysql/conf.d/ &&
        echo '[mysqld]\nskip-host-cache\nskip-name-resolve' >/etc/mysql/conf.d/docker.cnf &&
        rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld /var/lib/mysql-files &&
        chown -R mysql:mysql /var/lib/mysql /var/run/mysqld &&
        chmod 1777 /var/run/mysqld /var/lib/mysql
}

gosu_install() {
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"
    run 'gosu download' "wget -O /usr/local/bin/gosu \"https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch\""
    run 'gosu verify download' "wget -O /usr/local/bin/gosu.asc \"https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc\""
    export GNUPGHOME="$(mktemp -d)"
    run 'gpg key' 'gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4'
    run 'gpg verify' 'gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu'
    run 'gpg kill' 'gpgconf --kill all'
    rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc
    run 'apt mark' "apt-mark auto '.*' >/dev/null"
    run 'apt mark manual' "[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark >/dev/null"
    chmod +x /usr/local/bin/gosu
    gosu --version
    gosu nobody true
}

_main() {
    case $1 in
    apt_install)
        apt_install
        ;;
    gosu_install)
        #gosu_install
	    /opt/gosu/gosu.install.sh
        rm -fr /opt/gosu
        if [ ! -e '/usr/local/bin/gosu' ];then
            gosu_install
        fi
        ;;
    compile_install)
        compile_install
        ;;
    *)
        exec "$@"
        ;;
    esac
}

_main "$@"
