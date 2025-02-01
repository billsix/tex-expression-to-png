FROM docker.io/debian:trixie


RUN apt update && apt upgrade -y && \
    apt install -y texlive  \
                   dvipng  \
                   texlive-latex-extra \
                   cargo


COPY entrypoint/entrypoint.sh  /entrypoint.sh
COPY src/  /src/src
COPY Cargo.lock Cargo.toml /src/

RUN cd /src && cargo build --release && cargo build && \
    install -Dm755 target/release/tex_exp_to_png /usr/local/bin/


ENTRYPOINT ["/entrypoint.sh"]
