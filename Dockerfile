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
    echo "meson compile -C builddir" >> ~/.bash_history

# Build the CLI as an image-build stage so the image ships a ready-to-run binary
# — all building happens here, not at `make example`/run time. Placed after the
# toolchain install so meson/clang/glib are available. buildDebug.sh runs
# meson setup + compile + install (to /usr/local/bin) and symlinks
# compile_commands.json for clangd.
COPY meson.build /root/texExpToPng/meson.build
COPY src /root/texExpToPng/src
RUN /usr/local/bin/buildDebug.sh


ENTRYPOINT ["/entrypoint.sh"]
