FROM zookeeper:3.5

ARG version

RUN apk add --update bind-tools curl jq

COPY docker-healthcheck docker-swarm-entrypoint.sh /usr/local/bin/

RUN chgrp 0 /usr/local/bin/docker-healthcheck && \
chmod +x /usr/local/bin/docker-healthcheck && \
chmod 777 /usr/local/bin/docker-swarm-entrypoint.sh

ENV ZOO_TICK_TIME 2000
ENV ZOO_INIT_LIMIT 5
ENV ZOO_SYNC_LIMIT 2
ENV ZOO_STANDALONE_ENABLED true
ENV ZOO_RECONFIG_ENABLED true
ENV ZOO_SKIP_ACL yes
ENV ZOO_DYNAMIC_CONFIG_FILE $ZOO_CONF_DIR/zoo.cfg.dynamic

RUN echo 0 | tee /usr/local/bin/INITIALIZED >> /dev/null && \
echo 0 | tee /usr/local/bin/HEALTHY >> /dev/null

ENV image_version $version

HEALTHCHECK --interval=10s --timeout=5s CMD ["docker-healthcheck"]

ENTRYPOINT ["docker-swarm-entrypoint.sh"]
CMD ["zkServer.sh", "start-foreground"]
