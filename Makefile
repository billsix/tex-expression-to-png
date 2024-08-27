all: clean image

image:
	podman build -t tex-expression-to-png .

clean:
	rm -rf output/*

shell:
	podman run -it --rm \
		--entrypoint /bin/bash \
		-v ./output/:/output/:Z \
		tex-expression-to-png
