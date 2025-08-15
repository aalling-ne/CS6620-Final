# NYC Vacant Properties Map

This project retrieves vacant storefront data from the NYC Open Data API, processes it via an AWS Lambda Function run periodically by Cloudwatch, stores the processed data in S3, and serves it via a static Leaflet.js web application.  

The cloud infrastructure is fully provisioned with Terraform and is run entirely locally using LocalStack.

### CS6620 - Final Project - Summer 2025
Alexander Alling

## How to Run

### 1. Prerequisites

Make sure you have the following installed:
- Docker
- Docker Compose
- Terraform

Optional for manual testing:
- AWS CLI via awscli-local

### 2. Download the repo
```
git clone https://github.com/aalling-ne/CS6620-Final
```  
then, navigate to the repository location.

### 3. Start LocalStack
```
docker-compose up
```

### OPTIONAL - Manually Recreate Lambda Function ZIP
The repository includes the Lambda Function script in a zip file with it's dependcies included.  
To recreate this file locally, run:

```
chmod +x build_lambda.sh
./build_lambda.sh
```
This will replace the existing zip file at `/terraform/etl_package.zip`

### 4. Deploy via Terraform

```
cd terraform
terraform init
terraform apply
yes
```

### 5. View the Website

In your browser, go to:  
http://vacant-properties-web.s3-website.localhost.localstack.cloud:4566

### OPTIONAL - Test the ETL Script Manually

With awslocal installed, you can invoke the Lambda Function manually, instead of waiting for the daily EventBridge Trigger.
```
awslocal lambda invoke --function-name vacant-properties-etl output.json
```  
You can confirm the script ran succesfully by viewing the resulting file with `cat output.json`  

## Infrastructure

- LocalStack emulates AWS services in Docker container.
- Terraform provisions all AWS resources inside LocalStack.
- ETL Lambda runs daily via a CloudWatch rule and:
  - Fetches data from NYC Open Data via Socrata API.
  - Filters out properties with missing lat/lon.
  - Extracts unique primary_business_activity values.
  - Uploads results to S3 as JSON files.
- S3 Bucket hosts HTML/CSS/JS frontend that loads data directly from S3.  

![architecture-diagram](https://github.com/aalling-ne/CS6620-Final/blob/main/architecture-diagram.png?raw=true)

## Repository Files

`terraform/main.tf` - Terraform config file to provision AWS resources in LocalStack.  
`terraform/etl_package.zip` - File containing Lambda Function Script bundled with its dependancies.  
`web/` - Folder containing HTML/CSS/JS and /data folder for Frontend.  
`build_lambda.sh` - Shell script that creats etl_package.zip.  
`docker-compose.yml` - Compose file that starts up LocalStack.  
`etl_script.py` - Python script that is used as a Lambda Function for Extracting, Transforming, Loading the Vacant Property data.  
`architecture-diagram.png` - The nice diagram above.  

## Limitations and Next Steps

#### If this project were to be expanded upon for a real client, the resulting web application would be more useful if it could be used to filter for attributes such as:
- Leasing Status (For Lease / For Sale / etc.)
- Desired Rent
- Zoning Code

Unfortunatly, this is not the exact purpose of the NYC Open Data dataset being utilized, so that information is not availible.  

#### The Frontend Web Application is fairly plain looking.  
My next development goal, if I were continuing this project, would be to use a library such as React to make a more pleasant and uniform set of filter buttons.  
I'm a novice with Javascript, and creating an actually functional cloud infrastructure got in the way of going back to make something that looked nicer, unfortunatly.

## Resources Used
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission  
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment  
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule  

https://docs.localstack.cloud/aws/tutorials/s3-static-website-terraform/
https://docs.localstack.cloud/aws/integrations/aws-native-tools/aws-cli/#aws-cli
https://docs.localstack.cloud/aws/capabilities/config/configuration/
https://discuss.localstack.cloud/t/lambda-s3-nosuchbucket-error/725.html

https://docs.aws.amazon.com/lambda/latest/dg/python-package.html
https://docs.aws.amazon.com/AmazonS3/latest/userguide/olap-writing-lambda.html
