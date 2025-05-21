g5k-setup-docker -t
docker build --pull --rm -f 'Dockerfile' -t 'experiment-01:latest' '.'
docker save experiment-01:latest -o image.tar
singularity build image.sif docker-archive://image.tar
rm image.tar
