FROM nybase/nybase AS builder

ENV BUILD_DIR="/build" 

COPY *.sh ${BUILD_DIR}/

RUN bash ${BUILD_DIR}/install.sh

FROM nybase/nybase 
COPY --from=builder /app  /app/

EXPOSE 80/tcp 443/tcp
