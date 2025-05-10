# AWS Infrastructure Deployment with CloudFormation

## Objective
Automatically deploy a complete AWS infrastructure (VPC, Subnets, IGW, NAT Gateway, Security Groups, EC2) using CloudFormation.

---

## Directory Structure
```
├── main.template.yaml
├── README.md
├── deploy.sh
├── test.sh
├── clean.sh
├── .config.env
└── modules/
    ├── 1-vpc-subnet.yaml
    ├── 2-igw-public-route.yaml
    ├── 3-natgw-private-route.yaml
    ├── 4-security-groups.yaml
    └── 5-ec2.yaml
```

---

## Prerequisites
1. **Install AWS CLI**: [Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
2. **Configure AWS CLI**:
   ```bash
   aws configure
   ```
3. **Create an EC2 KeyPair** (if you don't have one):
   ```bash
   aws ec2 create-key-pair --key-name your_key_name --query 'KeyMaterial' --output text > your_key_name.pem
   chmod 400 your_key_name.pem
   ```
4. **Get your public IP address** (to SSH into the Public EC2):
   - Visit https://ifconfig.me or https://ipinfo.io

---

## How to Run (with Scripts)

### **1. Configure environment variables**
Create a file named `.config.env` in the project root with the following content:
```bash
BUCKET_NAME=your-bucket-name
REGION=your-region
STACK_NAME=your-stack-name
KEY_NAME=your-keypair-name
MY_IP=your-public-ip/32
ENVIRONMENT=your-environment (dev, prod, etc.)
```
- Replace the values as appropriate for your environment.

### **2. Make scripts executable**
```bash
chmod +x deploy.sh test.sh clean.sh
```

### **3. Deploy the infrastructure**
```bash
./deploy.sh
```
- This script will:
  - Create the S3 bucket if it does not exist
  - Upload all modules and main.yaml to S3
  - Deploy the CloudFormation stack with all parameters

### **4. Test the deployed resources**
```bash
./test.sh
```
- This script will:
  - Print CloudFormation stack outputs
  - List all EC2, NAT Gateway, EIP, ENI, Security Groups, Subnets, and Route Tables in your VPC

### **5. Clean up resources**
```bash
./clean.sh
```
- This script will:
  - Delete the CloudFormation stack
  - Remove all files from the S3 bucket and delete the bucket

---

## How to Run (manual)

### **1. Upload files to S3**
Create a bucket if you don't have one (bucket name must be globally unique):
```bash
aws s3 mb s3://YOUR_BUCKET_NAME
```
Upload main.template.yaml and modules folder to S3:
```bash
aws s3 cp modules/ s3://YOUR_BUCKET_NAME/modules/ --recursive
aws s3 cp main.template.yaml s3://YOUR_BUCKET_NAME/main.template.yaml
```

### **2. Deploy the CloudFormation stack**
```bash
aws cloudformation create-stack \
  --stack-name YOUR_STACK_NAME \
  --template-url https://YOUR_BUCKET_NAME.s3.YOUR_REGION.amazonaws.com/main.yaml \
  --parameters ParameterKey=Environment,ParameterValue=dev ParameterKey=MyIp,ParameterValue=YOUR_IP/32 ParameterKey=KeyName,ParameterValue=YOUR_KEY_NAME ParameterKey=BucketName,ParameterValue=YOUR_BUCKET_NAME ParameterKey=Region,ParameterValue=YOUR_REGION
```
- Replace `YOUR_IP`, `YOUR_KEY_NAME`, `YOUR_BUCKET_NAME`, and `YOUR_REGION` as appropriate

### **3. Check the results**
- Go to AWS Console > CloudFormation to monitor stack creation.
- When complete, check Outputs for the Instance IDs of the Public and Private EC2.
- Go to EC2 Console to get the Public IP of the Public EC2, then SSH into it:
  ```bash
  ssh -i YOUR_KEY_NAME.pem ec2-user@<PublicIP>
  ```
- From the Public EC2, SSH into the Private EC2 using its Private IP.
    ```bash
    ssh -i ec2-user@<PrivateIP>
    ```
### **4. Clean up resources**
After finishing the lab, delete the stack to avoid incurring charges:
```bash
aws cloudformation delete-stack --stack-name YOUR_STACK_NAME
```
And remove files/bucket from S3 if needed:
```bash
aws s3 rm s3://YOUR_BUCKET_NAME/modules/ --recursive
aws s3 rm s3://YOUR_BUCKET_NAME/main.yaml
aws s3 rb s3://YOUR_BUCKET_NAME
```
---

## Contact
If you have questions, contact me via email at giangttc203@gmail.com.

---
