# syntax=docker/dockerfile:1

ARG SAGEMATH_IMAGE=docker.io/sagemath/sagemath@sha256:e068670ae5863b54b2550e72437ec637b0283acb0dc712c8584c124dbf44e667
FROM ${SAGEMATH_IMAGE}

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG SAGECELL_GIT_REF=281fc2356c52929fb08f4cd4cbfd8655e4ddd236

ENV DEBIAN_FRONTEND=noninteractive \
    SAGECELL_HOME=/opt/sagecell \
    SAGECELL_PORT=8888 \
    SAGECELL_GIT_REF=${SAGECELL_GIT_REF} \
    SAGECELL_WORKDIR=/tmp/sagecell \
    SAGECELL_DB=/var/lib/sagecell/sqlite.db \
    SAGECELL_MAX_KERNELS=4 \
    SAGECELL_MAX_PREFORKED=1 \
    SAGECELL_RLIMIT_CPU=30 \
    PYTHONUNBUFFERED=1

COPY packages-known-good.txt /tmp/packages-known-good.txt

RUN apt-get update \
    && grep -vE '^[[:space:]]*(#|$)' /tmp/packages-known-good.txt \
       | xargs apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "$SAGECELL_WORKDIR" /var/lib/sagecell

WORKDIR /opt

RUN git clone https://github.com/sagemath/sagecell.git "${SAGECELL_HOME}" \
    && git -C "${SAGECELL_HOME}" checkout --detach "${SAGECELL_GIT_REF}" \
    && test "$(git -C "${SAGECELL_HOME}" rev-parse HEAD)" = "${SAGECELL_GIT_REF}"

WORKDIR ${SAGECELL_HOME}

COPY requirements-known-good.txt /tmp/requirements-known-good.txt

RUN sage -pip install --no-cache-dir \
        --constraint /tmp/requirements-known-good.txt \
        lockfile==0.12.2 \
        paramiko==5.0.0 \
        psutil==7.2.2 \
        sockjs-tornado==1.0.7 \
        SQLAlchemy==2.0.51

COPY patch_sagecell.py /tmp/patch_sagecell.py
RUN python3 /tmp/patch_sagecell.py

COPY sagecell_config.py /opt/sagecell/config.py
COPY sagecell_log.py /opt/sagecell/log.py

# Service-only build:
# We intentionally do NOT run "sage -sh -c make" here, because that full
# static/frontend build is the fragile JSmol/Jupyter/webpack/browser UI part.
# Xronos only needs the /service execution endpoint for now.
RUN mkdir -p static build

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

EXPOSE 8888
VOLUME ["/var/lib/sagecell"]

HEALTHCHECK --interval=30s --timeout=45s --start-period=240s --retries=5 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["sagecell"]
