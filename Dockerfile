# Use the Red Hat Universal Base Image 8
FROM docker.io/debian

COPY entrypoint/entrypoint.sh  /entrypoint.sh
COPY src/texExpToPng.sh  /texExpToPng.sh

RUN apt update && \
    apt install -y texlive dvipng texlive-latex-extra


ENTRYPOINT ["/entrypoint.sh"]
