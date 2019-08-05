FROM vault:1.2.0
RUN apk add --no-cache curl
# COPY vault /bin/vault