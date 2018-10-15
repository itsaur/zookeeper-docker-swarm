FROM zookeeper:3.5

ARG version

RUN apk --no-cache add \
bash \
bind-tools \
coreutils \
curl \
jq \
nano \
openjdk8 \
procps \
su-exec

ARG DIR=/usr/local/bin
COPY crontab.txt \
docker-healthcheck \
docker-swarm-entrypoint.sh \
trigger.sh \
zookeeper-cleanup.sh \
$DIR/

RUN chgrp 0 $DIR/docker-healthcheck && \
chmod +x $DIR/docker-healthcheck \
$DIR/docker-swarm-entrypoint.sh \
$DIR/trigger.sh \
$DIR/zookeeper-cleanup.sh && \
echo 0 | tee $DIR/HEALTHY $DIR/INITIALIZED 1>/dev/null

ENV ZOO_TICK_TIME 2000
ENV ZOO_INIT_LIMIT 5
ENV ZOO_SYNC_LIMIT 2
ENV ZOO_RECONFIG_ENABLED true
ENV ZOO_SKIP_ACL yes
ENV ZOO_DYNAMIC_CONFIG_FILE $ZOO_CONF_DIR/zoo.cfg.dynamic

ENV image_version $version

HEALTHCHECK --interval=10s --timeout=5s CMD ["docker-healthcheck"]

ENTRYPOINT ["docker-swarm-entrypoint.sh"]
CMD ["zkServer.sh", "start-foreground"]
