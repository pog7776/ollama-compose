#!/bin/sh

exec sudo docker exec -it ollama ollama "$@"
