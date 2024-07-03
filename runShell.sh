podman run -it --rm \
       --entrypoint /bin/bash \
       -v ./output/:/output/ \
       tex-expression-to-png
