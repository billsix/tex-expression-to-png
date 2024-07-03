#!/bin/bash

podman run -it --rm \
       -v ./output/:/output/ \
       my-debian "$@"
