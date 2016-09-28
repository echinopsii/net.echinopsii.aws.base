#### Build a packer image with ansible installed

1. Copy myvars.sample-json to myvars.json (ignored file on this git repo) and fill with your environment values
```
cp test/myvars.sample-json test/myvars.json
vim test/myvars.json
```

1. Launch packer

```
packer build -var-file test/myvars.json ansible.json
```

