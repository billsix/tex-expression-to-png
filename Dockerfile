# Use the Red Hat Universal Base Image 8
FROM docker.io/debian

RUN apt update && \
    apt install -y texlive dvipng texlive-latex-extra

COPY entrypoint/entrypoint.sh  /entrypoint.sh
COPY src/texExpToPng.py  /texExpToPng.py

ENTRYPOINT ["/entrypoint.sh"]
