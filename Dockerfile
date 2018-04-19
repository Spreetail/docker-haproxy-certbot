# haproxy1.6.9 with certbot
FROM haproxy:1.8-alpine

RUN mkdir -p /config

RUN apk update

# Install Supervisor, cron, libnl-utils, net-tools, iptables
RUN apk add --no-cache --virtual .build-deps supervisor dcron libnl-dev net-tools iptables rsyslog

# ADD rsyslog.conf /etc/rsyslog.conf
# RUN mkdir -p /etc/rsyslog.d

# Setup Supervisor
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Install Certbot
RUN apk add --virtual --no-cache certbot

RUN rm -rf /var/cache/apk/*


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
ENTRYPOINT ["/start.sh"]
