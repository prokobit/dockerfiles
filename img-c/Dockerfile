FROM rockylinux/rockylinux:10-minimal

ARG VERSION
LABEL org.opencontainers.image.version="${VERSION}"

WORKDIR /app

COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

ENTRYPOINT ["/app/run.sh"]
