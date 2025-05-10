#!/bin/bash

set -e # stop on error

# ==== LOAD CONFIGURATION ====
source .config.env

# ==== SET COLOR ====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# ==== GET OUTPUTS ====
echo -e "${YELLOW}Fetching CloudFormation stack outputs...${NC}"
OUTPUTS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs" --output json)

get_output() {
    echo $OUTPUTS | jq -r ".[] | select(.OutputKey==\"$1\") | .OutputValue"
}

VPC_ID=$(get_output VPCId)
PUBLIC_SUBNET1_ID=$(get_output PublicSubnet1Id)
PUBLIC_SUBNET2_ID=$(get_output PublicSubnet2Id)
PRIVATE_SUBNET1_ID=$(get_output PrivateSubnet1Id)
PRIVATE_SUBNET2_ID=$(get_output PrivateSubnet2Id)
IGW_ID=$(get_output InternetGatewayId)
NATGW_ID=$(get_output NATGatewayId)
PUBLIC_IP=$(get_output PublicEC2IP)
PRIVATE_IP=$(get_output PrivateEC2IP)
PUBLIC_EC2_ID=$(get_output PublicEC2InstanceId)
PRIVATE_EC2_ID=$(get_output PrivateEC2InstanceId)

# ==== CHECK VPC ====
echo -e "${YELLOW}Checking VPC...${NC}"
aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $REGION --query "Vpcs[0].[VpcId,State,CidrBlock]" --output table

# ==== CHECK SUBNETS ====

echo -e "${YELLOW}Checking Public Subnet...${NC}"
echo -e "${YELLOW}Public Subnet 1:${NC}"
aws ec2 describe-subnets --subnet-ids $PUBLIC_SUBNET1_ID --region $REGION --query "Subnets[0].[SubnetId,State,CidrBlock,MapPublicIpOnLaunch]" --output table

echo -e "${YELLOW}Public Subnet 2:${NC}"
aws ec2 describe-subnets --subnet-ids $PUBLIC_SUBNET2_ID --region $REGION --query "Subnets[0].[SubnetId,State,CidrBlock,MapPublicIpOnLaunch]" --output table

echo -e "${YELLOW}Private Subnet 1:${NC}"
aws ec2 describe-subnets --subnet-ids $PRIVATE_SUBNET1_ID --region $REGION --query "Subnets[0].[SubnetId,State,CidrBlock,MapPublicIpOnLaunch]" --output table

echo -e "${YELLOW}Private Subnet 2:${NC}"
aws ec2 describe-subnets --subnet-ids $PRIVATE_SUBNET2_ID --region $REGION --query "Subnets[0].[SubnetId,State,CidrBlock,MapPublicIpOnLaunch]" --output table

# ==== CHECK IGW & NATGW ====
echo -e "${YELLOW}Checking Internet Gateway...${NC}"
aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID --region $REGION --query "InternetGateways[0].[InternetGatewayId,Attachments[0].VpcId]" --output table

echo -e "${YELLOW}Checking NAT Gateway...${NC}"
aws ec2 describe-nat-gateways --nat-gateway-ids $NATGW_ID --region $REGION --query "NatGateways[0].[NatGatewayId,State,SubnetId]" --output table

# ==== CHECK ROUTE TABLES ====
echo -e "${YELLOW}Checking Route Tables...${NC}"
echo -e "${YELLOW}Public Route Table:${NC}"
aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=*public* --region $REGION --query "RouteTables[0].[RouteTableId,Routes[0].GatewayId]" --output table

echo -e "${YELLOW}Private Route Table:${NC}"
aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=*private* --region $REGION --query "RouteTables[0].[RouteTableId,Routes[0].NatGatewayId]" --output table

# ==== CHECK EC2 INSTANCES ====
echo -e "${YELLOW}Checking Public EC2 Instance...${NC}"
aws ec2 describe-instances --instance-ids $PUBLIC_EC2_ID --region $REGION --query "Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress,SubnetId]" --output table

echo -e "${YELLOW}Checking Private EC2 Instance...${NC}"
aws ec2 describe-instances --instance-ids $PRIVATE_EC2_ID --region $REGION --query "Reservations[0].Instances[0].[InstanceId,State.Name,PrivateIpAddress,SubnetId]" --output table

# ==== CHECK SSH PORT 22 ====
echo -e "\n${YELLOW}Checking SSH (port 22) on Public EC2 Instance...${NC}"
timeout 5 bash -c "</dev/tcp/$PUBLIC_IP/22" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SSH port 22 is open on $PUBLIC_IP${NC}"
else
    echo -e "${RED}SSH port 22 is NOT open on $PUBLIC_IP${NC}"
fi

# ==== PRINT SSH INSTRUCTIONS ====
echo -e "${GREEN}To connect to the public instance:${NC}"
echo "ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"
echo -e "${GREEN}Then, to connect to the private instance from the public instance:${NC}"
echo "ssh ec2-user@$PRIVATE_IP"

echo -e "${GREEN}AWS infrastructure test completed!${NC}"
