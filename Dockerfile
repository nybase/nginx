FROM nybase/nybase AS builder

ENV BUILD_DIR="/build" 

COPY *.sh ${BUILD_DIR}/

RUN bash ${BUILD_DIR}/install.sh

FROM nybase/nybase 

COPY --from=builder /app  /app/

RUN apt-get update ; apt-get install -y libjemalloc-dev ; \
    mkdir -p /etc/service/nginx ; \
    bash -c 'echo -e "#!/bin/bash\nexec /app/nginx/sbin/nginx -g \"daemon off;\"" > /etc/service/nginx/run' ; \
    chmod 755 /etc/service/nginx/run

EXPOSE 80/tcp 443/tcp

CMD ["runsvdir", "/etc/service"]
