#!/bin/bash

# ==== COLOR DEFINITIONS ====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ==== FUNCTIONS FOR COLORED OUTPUT ====
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    echo -e "\n${PURPLE}==== $1 ====${NC}\n"
}

# ==== LOAD CONFIGURATION ====
header "LOADING CONFIGURATION"
source .config.env
success "Configuration loaded successfully"

# ==== DELETE S3 BUCKET ====
header "DELETING S3 BUCKET"
info "Removing objects from S3 bucket..."
aws s3 rm s3://$BUCKET_NAME/modules/ --recursive --region $REGION
aws s3 rm s3://$BUCKET_NAME/main.yaml --region $REGION
aws s3 rb s3://$BUCKET_NAME --region $REGION
success "S3 bucket $BUCKET_NAME deletion command sent. Check S3 Console for progress."

# ==== DELETE CLOUDFORMATION STACK ====
header "DELETING CLOUDFORMATION STACK"
info "Deleting CloudFormation stack: $STACK_NAME"
aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
info "Waiting for stack to be deleted..."
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
success "Stack $STACK_NAME deleted successfully"

# ==== DELETE KEY PAIR ====
header "DELETING KEY PAIR"
info "Deleting key pair: $KEY_NAME"
aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION
success "Key pair $KEY_NAME deleted successfully"
