FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    tzdata \
    bash \
    awscli

# Install MongoDB Database Tools (mongodump)
RUN curl -fsSL https://pgp.mongodb.com/server-6.0.asc | \
    gpg --dearmor -o /usr/share/keyrings/mongodb.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/mongodb.gpg] \
    https://repo.mongodb.org/apt/ubuntu \
    $(lsb_release -cs)/mongodb-org/6.0 multiverse" \
    > /etc/apt/sources.list.d/mongodb.list

RUN apt-get update && apt-get install -y \
    mongodb-database-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
