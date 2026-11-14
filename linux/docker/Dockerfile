# Ambiente reprodutível de build do .deb — DeepSeek Harness Linux
#
#   docker build -f linux/docker/Dockerfile -t dsh-linux-build .
#   docker run --rm -v "$PWD:/src" -w /src dsh-linux-build bash linux/scripts/build-deb.sh
#
# Ubuntu 24.04 para coincidir com o sistema-alvo. Node 24 vem do tarball oficial porque
# o 24.04 não o traz nos repositórios.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=24.9.0
ENV PNPM_HOME=/usr/local/pnpm
ENV PATH=${PNPM_HOME}:${PATH}

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl xz-utils git python3 python3-venv \
      build-essential pkg-config dpkg-dev fakeroot file \
      libgtk-3-0t64 libnss3 libasound2t64 libgbm1 libxss1 libxtst6 \
      libfuse2t64 \
    && rm -rf /var/lib/apt/lists/*

# Node 24 a partir do tarball oficial (verificado por versão, não por checksum publicado aqui).
RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
      -o /tmp/node.tar.xz \
    && mkdir -p /usr/local/lib/nodejs \
    && tar -xJf /tmp/node.tar.xz -C /usr/local/lib/nodejs \
    && ln -s "/usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-x64/bin/node" /usr/local/bin/node \
    && ln -s "/usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-x64/bin/npm" /usr/local/bin/npm \
    && ln -s "/usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-x64/bin/npx" /usr/local/bin/npx \
    && rm /tmp/node.tar.xz \
    && node --version

# pnpm via corepack, na versão fixada pelo package.json da raiz.
RUN corepack enable && corepack prepare pnpm@latest --activate && pnpm --version

WORKDIR /src

# O código é montado em tempo de execução para que o build use a árvore do repositório.
CMD ["bash", "linux/scripts/build-deb.sh"]
