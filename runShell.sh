podman run -it --rm \
       --entrypoint /bin/bash \
       -v ./output/:/output/:Z \
       tex-expression-to-png
