#!/bin/bash

podman run -it --rm \
       -v ./output/:/output/ \
       tex-expression-to-png "$@"
