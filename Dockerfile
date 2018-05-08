FROM alpine
ENV VERSION_BACKUPPC=4.2.1 VERSION_BACKUPPC_XS=0.57 VERSION_RSYNC_BPC=3.0.9.12

USER 0

EXPOSE 80 8080

ADD root /

VOLUME ["/etc/backuppc", "/var/lib/backuppc", "/var/log/backuppc"]

RUN apk add --no-cache tini iputils bash curl \
        openssh-client rsync tar bzip2 samba-client \
        supervisor \
        apache2 \
        rrdtool ttf-dejavu \
        perl perl-archive-zip perl-file-listing perl-xml-rss perl-io-socket-inet6 perl-cgi perl-cgi-session && \
    apk add --no-cache --virtual build-dependencies \
        make g++ git gcc zlib-dev perl-dev && \
    sed -i 's|apache:/var/www:|apache:/var/lib/backuppc:|' /etc/passwd && \
    cd /tmp/ && \
    git clone -b ${VERSION_BACKUPPC} https://github.com/backuppc/backuppc.git && \
    git clone -b ${VERSION_RSYNC_BPC} https://github.com/backuppc/rsync-bpc.git && \
    git clone -b ${VERSION_BACKUPPC_XS} https://github.com/backuppc/backuppc-xs.git && \
    cd /tmp/backuppc-xs && perl Makefile.PL && make && make test && make install && cd .. && \
    cd /tmp/rsync-bpc && ./configure && make && make install && cd .. && \
    cd /tmp/backuppc && \
    ./makeDist --nosyntaxCheck --releasedate "`date -u "+%d %b %Y"`" --version ${VERSION_BACKUPPC} && \
    tar -zxf dist/BackupPC-${VERSION_BACKUPPC}.tar.gz && \
    cd BackupPC-${VERSION_BACKUPPC} && \
    ./configure.pl --hostname=backuppc \
        --batch \
        --backuppc-user=apache \
        --scgi-port=-1 \
        --cgi-dir /var/www/localhost/cgi-bin/backuppc \
        --data-dir /var/lib/backuppc \
        --html-dir /var/www/localhost/htdocs/backuppc/images \
        --html-dir-url /backuppc/images \
        --install-dir /usr/local/share/backuppc \
        --config-dir /etc/backuppc \
        --log-dir /var/log/backuppc && \
    chown apache:apache /etc/backuppc /var/lib/backuppc && \
    mkdir /run/apache2 && chown apache:apache /run/apache2 && \
    mkdir /etc/apache2/conf.local.d && chown 0:0 /etc/apache2/conf.local.d && chmod 755 /etc/apache2/conf.local.d && \
    sed -i 's/Listen .*/Listen 8080/' /etc/apache2/httpd.conf && \
    sed -i 's/#LoadModule cgi/LoadModule cgi/' /etc/apache2/httpd.conf && \
    sed -ri \
    		-e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
    		-e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' /etc/apache2/httpd.conf && \
    echo 'RedirectMatch permanent "^/$" "/BackupPC_Admin"' >> /etc/apache2/httpd.conf && \
    echo 'IncludeOptional /etc/apache2/conf.local.d/*.conf' >> /etc/apache2/httpd.conf && \
    echo 'Alias /backuppc/images /var/www/localhost/htdocs/backuppc/images' >> /etc/apache2/conf.d/backuppc.conf && \
    echo 'ScriptAlias /BackupPC_Admin /var/www/localhost/cgi-bin/backuppc/BackupPC_Admin' >> /etc/apache2/conf.d/backuppc.conf && \
    sed -i "s/\$Conf{CgiAdminUsers}.*/\$Conf{CgiAdminUsers} = '*';/" /etc/backuppc/config.pl && \
    sed -i 's@files = .*@files = /etc/supervisor.d/*.ini /etc/supervisor.local.d/*.ini@' /etc/supervisord.conf && \
    cp -a /etc/backuppc/ /etc/backuppc.org/ && \
    chmod +x /usr/local/bin/run && \
    apk del --no-cache build-dependencies && \
    rm -rf /tmp/{backuppc,backuppc-xs,rsync-bpc}

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/run"]
