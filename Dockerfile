# haproxy1.6.9 with certbot
FROM debian:stretch

RUN apt-get update && apt-get install -y libssl1.0.2 libpcre3 liblua5.3 --no-install-recommends && rm -rf /var/lib/apt/lists/*

# Setup HAProxy
ENV HAPROXY_MAJOR 1.8
ENV HAPROXY_VERSION 1.8.7
ENV HAPROXY_MD5=c60f99a989366d14bc370dc7b3b2ff87
ENV OPENSSL_VERSION=1.0.2o
ENV OPENSSL_SHA256=ec3f5c9714ba0fd45cb4e087301eb1336c317e0d20b575a125050470e8089e4d
ENV WORK_DIR=/tmp/build
ENV STATICLIBSSL=$WORK_DIR/staticlibssl

RUN mkdir -p $WORK_DIR; cd $WORK_DIR; buildDeps='curl gcc libc6-dev libpcre3-dev zlib1g-dev perl-modules make ca-certificates' \
  && set -x \
  && apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
  && curl -O https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz \
  && echo "${OPENSSL_SHA256} openssl-$OPENSSL_VERSION.tar.gz" | sha256sum -c \
  && tar -zxf openssl-$OPENSSL_VERSION.tar.gz \
  && cd openssl-* \
  && ./config --prefix=$STATICLIBSSL --openssldir=/etc/ssl --libdir=lib no-shared zlib-dynamic \
  && make && make install_sw \
  && curl -SL "http://www.haproxy.org/download/${HAPROXY_MAJOR}/src/haproxy-${HAPROXY_VERSION}.tar.gz" -o haproxy.tar.gz \
  && echo "${HAPROXY_MD5} *haproxy.tar.gz" | md5sum -c \
  && mkdir -p $WORK_DIR/haproxy \
  && tar -xzf haproxy.tar.gz -C $WORK_DIR/haproxy --strip-components=1 \
  && rm haproxy.tar.gz \
  && make -C $WORK_DIR/haproxy \
    TARGET=linux2628 \
    USE_PCRE=1 USE_STATIC_PCRE=1 USE_PCRE_JIT=1 \
    USE_OPENSSL=1 SSL_INC=$STATICLIBSSL/include SSL_LIB=$STATICLIBSSL/lib \
    USE_ZLIB=1 ADDLIB=-ldl\
    all \
    install-bin \
  && mkdir -p /config \
  && mkdir -p /usr/local/etc/haproxy \
  && cp -R $WORK_DIR/haproxy/examples/errorfiles /usr/local/etc/haproxy/errors \
  && rm -rf $WORK_DIR/haproxy \
  && apt-get purge -y --auto-remove $buildDeps

# Install Supervisor, cron, libnl-utils, net-tools, iptables
RUN apt-get update && apt-get install -y supervisor cron libnl-utils net-tools iptables && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Setup Supervisor
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Install Certbot
RUN apt-get update && apt-get install -y certbot && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Setup Certbot
RUN mkdir -p /usr/local/etc/haproxy/certs.d
RUN mkdir -p /usr/local/etc/letsencrypt
COPY certbot.cron /etc/cron.d/certbot
COPY cli.ini /usr/local/etc/letsencrypt/cli.ini
COPY haproxy-refresh.sh /usr/bin/haproxy-refresh
COPY haproxy-restart.sh /usr/bin/haproxy-restart
COPY certbot-certonly.sh /usr/bin/certbot-certonly
COPY certbot-renew.sh /usr/bin/certbot-renew
RUN chmod +x /usr/bin/haproxy-refresh /usr/bin/haproxy-restart /usr/bin/certbot-certonly /usr/bin/certbot-renew

# Add startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Start
CMD ["/start.sh"]
