FROM registry.fedoraproject.org/fedora:43

COPY entrypoint/dotfiles/ /root/
COPY .clang-format /root
COPY entrypoint/buildDebug.sh /usr/local/bin
COPY entrypoint/format.sh /usr/local/bin
COPY entrypoint/lint.sh /usr/local/bin
COPY entrypoint/shell.sh /usr/local/bin
COPY entrypoint/entrypoint.sh /



RUN sed -i -e "s@tsflags=nodocs@#tsflags=nodocs@g" /etc/dnf/dnf.conf && \
    echo "keepcache=True" >> /etc/dnf/dnf.conf && \
    dnf upgrade -y && \
    dnf install -y clang \
                   clang-tools-extra \
                   emacs \
                   gcc \
                   gdb \
                   git \
                   lldb \
                   meson \
                   ninja \
                   texlive \
                   texlive-anyfontsize \
                   texlive-dvipng \
                   texlive-dvisvgm \
                   texlive-standalone \
                   which && \
    emacs --batch --load /root/.emacs.d/install-melpa-packages.el

COPY . /root/texExpToPng/

# build from source
RUN cd /root/texExpToPng/ && \
    CC=clang CXX=clang++ meson setup builddir --buildtype=debug -Dwarning_level=3 && \
    meson configure builddir -Dcpp_args="-Wall" && \
    meson compile -C builddir  && \
    meson install -C builddir && \
    ln -s builddir/compile_commands.json


RUN echo "exit() {" >> ~/.bashrc && \
    echo "    echo "Formatting on shell exit"" >> ~/.bashrc && \
    echo "    format.sh" >> ~/.bashrc && \
    echo "    lint.sh" >> ~/.bashrc && \
    echo "    builtin exit "$@"" >> ~/.bashrc && \
    echo "}" >> ~/.bashrc && \
    echo "PS1='\[\e[36m\]┌─(\t) \[\e[32m\]\u@\h:\w\n\[\e[36m\]└─λ \[\e[0m\]'" >> ~/.bashrc



ENTRYPOINT ["/entrypoint.sh"]
