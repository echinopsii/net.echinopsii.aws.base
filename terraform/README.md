Configure terraform

1. Export environment variables for credentials
```
export AWS_PROFILE=<Your AWS profile>
export AWS_DEFAULT_REGION=<Your AWS region>
```
1. Create bucket to store states
```
aws s3 mb s3://<your s3 terraform state bucket>
```
