#!/bin/sh
docker run --rm -it --mount type=bind,source=$PWD,target=/app -w /app -p 5000:5000 rummy $*
