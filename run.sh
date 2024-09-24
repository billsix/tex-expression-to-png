#!/bin/env bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <math_formula> <image_size> <output_filename>"
    echo "Example: $0 \"E = 5 + m*c^2\" 800 output.png"
    exit 1
fi


podman run -it --rm \
       -v ./output/:/output/:Z \
       tex-expression-to-png "$@"
