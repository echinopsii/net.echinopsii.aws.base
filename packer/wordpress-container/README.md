#### Build a packer image with consul installed

1. Launch packer

```
packer build wordpress.json && docker push echinopsii/wordpress:4.6.1 
```

1. Current limitation :

docker-push directive return following error: 

```
==> docker: Running post-processor: docker-push
    docker (docker-push): Pushing: sha256:5363ca73b52fbf0cd30c8a4fb4788f09ea251e6c007bb32b4fbcf2c3074e5bcc
    docker (docker-push): An image does not exist locally with the tag: sha256
    docker (docker-push): The push refers to a repository [docker.io/library/sha256]
Build 'docker' errored: 1 error(s) occurred:
```

