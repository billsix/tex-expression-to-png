FROM registry.fedoraproject.org/fedora:44

ARG USE_EMACS=0


COPY entrypoint/dotfiles/.lldbinit /root/.lldbinit
COPY entrypoint/dotfiles/.emacs.d/install-melpa-packages.el /root/.emacs.d/install-melpa-packages.el
COPY .clang-format /root
COPY entrypoint/buildDebug.sh /usr/local/bin
COPY entrypoint/format.sh /usr/local/bin
COPY entrypoint/lint.sh /usr/local/bin
COPY entrypoint/shell.sh /usr/local/bin
COPY entrypoint/entrypoint.sh /


RUN  --mount=type=cache,target=/var/cache/libdnf5 \
     --mount=type=cache,target=/var/lib/dnf \
     sed -i -e "s@tsflags=nodocs@#tsflags=nodocs@g" /etc/dnf/dnf.conf && \
     echo "keepcache=True" >> /etc/dnf/dnf.conf && \
     dnf upgrade -y && \
     if [ "$USE_EMACS" = "1" ]; then \
       dnf install -y \
                   emacs && \
       emacs --batch --load /root/.emacs.d/install-melpa-packages.el && \
       echo "alias ls='ls --color=auto'" >> ~/.bashrc ;\
     fi ; \
    dnf install -y clang \
                   clang-tools-extra \
                   gcc \
                   gdb \
                   git \
                   glib \
                   glib2-devel \
                   lldb \
                   meson \
                   ninja \
                   texlive \
                   texlive-anyfontsize \
                   texlive-dvipng \
                   texlive-dvisvgm \
                   texlive-standalone \
                   tmux \
                   which && \
    echo "exit() {" >> ~/.bashrc && \
    echo "    echo "Formatting on shell exit"" >> ~/.bashrc && \
    echo "    format.sh" >> ~/.bashrc && \
    echo "    lint.sh" >> ~/.bashrc && \
    echo "    builtin exit "$@"" >> ~/.bashrc && \
    echo "}" >> ~/.bashrc && \
    echo "PS1='\[\e[36m\]┌─(\t) \[\e[32m\]\u@\h:\w\n\[\e[36m\]└─λ \[\e[0m\]'" >> ~/.bashrc && \
    echo "/usr/local/bin/buildDebug.sh" >> ~/.bash_history




ENTRYPOINT ["/entrypoint.sh"]
