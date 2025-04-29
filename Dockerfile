FROM node:23.3.0-slim


# Install pnpm globally and install necessary build tools
RUN npm install -g pnpm@9.15.1 && \
apt-get update && \
apt-get install -y jq sudo curl && \
apt-get clean && \
apt-get install -y git curl procps python3 make g++ && \
apt-get clean && \
rm -rf /var/lib/apt/lists/*

RUN curl -L https://ollama.com/download/ollama-linux-amd64.tgz -o ollama-linux-amd64.tgz && \
    tar -C /usr -xzf ollama-linux-amd64.tgz && \
    rm ollama-linux-amd64.tgz

WORKDIR /app
# Set Python 3 as the default python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Copy package.json and other configuration files
COPY package.json ./
COPY pnpm-lock.yaml ./
COPY tsconfig.json ./
COPY .env.template ./

# Copy the rest of the application code
COPY ./src ./src
RUN cp .env.template .env
RUN mkdir /app/characters/

# Install dependencies and build the project
RUN pnpm install 
RUN pnpm build 


COPY ./.env.template /app/.env
COPY ./entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh
 
ENV DAEMON_PROCESS=true

ENTRYPOINT ["/bin/bash", "entrypoint.sh"]
