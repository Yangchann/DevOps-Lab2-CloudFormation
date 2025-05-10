#!/bin/bash

set -e # stop on error

# ==== LOAD CONFIGURATION ====
source .config.env

# ==== GENERATE main.yaml FROM main.template.yaml ====
echo "Generating main.yaml from main.template.yaml..."
python - <<END
import os
config = {}
with open('.config.env') as f:
    for line in f:
        if '=' in line:
            k, v = line.strip().split('=', 1)
            config[k.strip()] = v.strip()
with open('main.template.yaml', 'r') as f:
    content = f.read()
content = content.replace('{{BUCKET_NAME}}', config['BUCKET_NAME'])
content = content.replace('{{REGION}}', config['REGION'])
with open('main.yaml', 'w') as f:
    f.write(content)
print("main.yaml generated successfully!")
END

# ==== CREATE KEYPAIR IF NEEDED ====
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" &>/dev/null; then
    echo "Key pair $KEY_NAME does not exist. Creating..."
    aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text --region "$REGION" > "$KEY_NAME.pem"
    chmod 400 "$KEY_NAME.pem"
    echo "Key pair created and saved to $KEY_NAME.pem"
else
    echo "Key pair $KEY_NAME already exists. Skipping creation."
fi

# ==== CREATE BUCKET IF NOT EXISTS ====
if ! aws s3 ls "s3://$BUCKET_NAME" --region $REGION 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Bucket $BUCKET_NAME already exists. Skipping creation."
else
    echo "Creating bucket $BUCKET_NAME..."
    aws s3 mb s3://$BUCKET_NAME --region $REGION
fi

# ==== UPLOAD FILES TO S3 ====
echo "Uploading modules/ to S3..."
aws s3 cp modules/ s3://$BUCKET_NAME/modules/ --recursive --region $REGION

echo "Uploading main.yaml to S3..."
aws s3 cp main.yaml s3://$BUCKET_NAME/main.yaml --region $REGION

# ==== DEPLOY CLOUDFORMATION STACK ====
echo "Deploying CloudFormation stack..."
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &>/dev/null; then
    echo "Stack $STACK_NAME already exists. Updating stack..."
    aws cloudformation update-stack \
        --stack-name $STACK_NAME \
        --region $REGION \
        --template-url https://$BUCKET_NAME.s3.$REGION.amazonaws.com/main.yaml \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=MyIp,ParameterValue=$MY_IP \
            ParameterKey=KeyName,ParameterValue=$KEY_NAME \
            ParameterKey=BucketName,ParameterValue=$BUCKET_NAME \
            ParameterKey=Region,ParameterValue=$REGION || true
    echo "Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $REGION
else
    echo "Creating new stack $STACK_NAME..."
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --region $REGION \
        --template-url https://$BUCKET_NAME.s3.$REGION.amazonaws.com/main.yaml \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=MyIp,ParameterValue=$MY_IP \
            ParameterKey=KeyName,ParameterValue=$KEY_NAME \
            ParameterKey=BucketName,ParameterValue=$BUCKET_NAME \
            ParameterKey=Region,ParameterValue=$REGION
    echo "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
fi

echo "Stack $STACK_NAME deployed successfully!"

# ==== GET OUTPUTS ====
echo "Fetching stack outputs..."
OUTPUTS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs" --output json)
PUBLIC_IP=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="PublicEC2IP") | .OutputValue')
PRIVATE_IP=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="PrivateEC2IP") | .OutputValue')

echo ""
echo "===================="
echo "Stack Outputs:"
echo "$OUTPUTS" | jq
echo "===================="
echo ""

if [ -z "$PUBLIC_IP" ] || [ -z "$PRIVATE_IP" ]; then
    echo "Could not find PublicEC2IP or PrivateEC2IP in stack outputs. Please check your CloudFormation outputs."
    exit 1
fi

echo "To connect to the public instance:"
echo "ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"
echo ""
echo "Then, to connect to the private instance from the public instance:"
echo "ssh ec2-user@$PRIVATE_IP"
echo ""
echo "Deployment completed!"
