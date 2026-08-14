#!/bin/env bash

[ -d /root/texExpToPng ] && cd /root/texExpToPng

run-clang-tidy . -fix
