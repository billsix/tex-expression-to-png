FROM registry.fedoraproject.org/fedora:45

ARG USE_EMACS=0


COPY entrypoint/dotfiles/.lldbinit /root/.lldbinit
COPY entrypoint/dotfiles/.emacs.d/install-melpa-packages.el /root/.emacs.d/install-melpa-packages.el
COPY .clang-format /root
COPY entrypoint/01-install-base.sh /usr/local/bin
COPY entrypoint/02-install-emacs.sh /usr/local/bin
COPY entrypoint/buildDebug.sh /usr/local/bin
COPY entrypoint/format.sh /usr/local/bin
COPY entrypoint/lint.sh /usr/local/bin
COPY entrypoint/shell.sh /usr/local/bin
COPY entrypoint/entrypoint.sh /


# System-package installation lives in per-group scripts (entrypoint/0N-install-*.sh),
# host-runnable with no container runtime; the scripts take no options -- WHICH optional
# groups run is decided here by the ARG `if` block. The dnf cache mount, the tsflags
# `sed`, and keepcache stay in the Dockerfile (build plumbing). 01-install-base.sh does
# `dnf upgrade` + the base (toolchain + TeX Live) install; the emacs MELPA bootstrap and
# the ls alias are config, so they stay here under the USE_EMACS check.
RUN  --mount=type=cache,target=/var/cache/libdnf5 \
     --mount=type=cache,target=/var/lib/dnf \
     sed -i -e "s@tsflags=nodocs@#tsflags=nodocs@g" /etc/dnf/dnf.conf && \
     echo "keepcache=True" >> /etc/dnf/dnf.conf && \
     /usr/local/bin/01-install-base.sh && \
     if [ "$USE_EMACS" = "1" ]; then \
       /usr/local/bin/02-install-emacs.sh && \
       emacs --batch --load /root/.emacs.d/install-melpa-packages.el && \
       echo "alias ls='ls --color=auto'" >> ~/.bashrc ;\
     fi ; \
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
COPY tests /root/texExpToPng/tests
RUN /usr/local/bin/buildDebug.sh

# Gate the normal build on the test suite (smoke render + TeX-free usage error).
# These are the meson test() targets the sanitizer gate below re-runs under
# ASan/UBSan; a red test here fails the image.
RUN meson test -C /root/texExpToPng/builddir --print-errorlogs

# Sanitizer gate (opt-in via RUN_SANITIZERS=1; `make image` sets it). Build
# texExpToPng a second/third time — under UBSan(trap) and ASan — in separate
# meson setup dirs (the normal install build above is untouched) and run the
# test suite under each. A surviving UB traps (SIGILL); a memory error aborts;
# either fails the image the same way the plain `meson test` step does. Trap
# mode links no runtime (low friction) and is the reliable gate — diagnostic
# UBSan under-reports. ASan leak detection is defaulted off in
# tex_exp_to_png.c (__asan_default_options): the gate is for corruption, not
# the intentional exit-time leaks on fatal_error() paths. clang/meson/ninja and
# the ASan runtime already ship in the image, so no new packages.
ARG RUN_SANITIZERS=0
RUN if [ "$RUN_SANITIZERS" = "1" ]; then \
      set -e; \
      echo '== UBSan (trap) gate =='; \
      CC=clang meson setup /tmp/san-ubsan /root/texExpToPng --buildtype=debug \
          -Dwarning_level=3 \
          -Dc_args='-fsanitize=undefined -fsanitize-trap=undefined' \
          -Dc_link_args='-fsanitize=undefined -fsanitize-trap=undefined'; \
      meson compile -C /tmp/san-ubsan; \
      meson test -C /tmp/san-ubsan --no-rebuild --print-errorlogs; \
      echo '== ASan gate =='; \
      CC=clang meson setup /tmp/san-asan /root/texExpToPng --buildtype=debug \
          -Dwarning_level=3 -Db_sanitize=address; \
      meson compile -C /tmp/san-asan; \
      meson test -C /tmp/san-asan --no-rebuild --print-errorlogs; \
      rm -rf /tmp/san-ubsan /tmp/san-asan; \
    fi


ENTRYPOINT ["/entrypoint.sh"]
