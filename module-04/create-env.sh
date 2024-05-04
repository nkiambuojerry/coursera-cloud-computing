#!/bin/bash
##############################################################################
# Module-04
# This assignment requires you to modify your previous scripts and use the 
# Launch Template and Autoscaling group commands for creating EC2 instances
# You will need an additional script to generate a JSON file with parameters
# for your launch template
# 
# You will need to define these variables in a txt file named: arguments.txt
# 1 image-id
# 2 instance-type
# 3 key-name
# 4 security-group-ids
# 5 count
# 6 user-data file name
# 7 Tag (use the module name - later we can use the tags to query/filter
# 8 Target Group (use your initials)
# 9 elb-name (use your initials)
# 10 Availability Zone 1
# 11 Availablitty Zone 2
# 12 Launch Template Name
# 13 ASG name
# 14 ASG min
# 15 ASG max
# 16 ASG desired
# 17 AWS Region for LaunchTemplate (use your default region)
##############################################################################

ltconfigfile="./config.json"

if [ $# = 0 ]
then
  echo 'You do not have enough variable in your arugments.txt, perhaps you forgot to run: bash ./create-env.sh $(< ~/arguments.txt)'
  exit 1 
elif ! [[ -a $ltconfigfile ]]
  then
   echo 'The launch template configuration JSON file does not exist - make sure you run/ran the command: bash ./create-lt-json.sh $(< ~/arguments.txt) command before running the create-env.sh $(< ~/arguments.txt)'
   echo "Now exiting the program..."
   exit 1
# else run the creation logic
else
if [ -a $ltconfigfile ]
    then
    echo "Launch template data file: $ltconfigfile exists..." 
fi
echo "Finding and storing default VPCID value..."
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/describe-vpcs.html
VPCID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[*].VpcId" --output=text)
echo $VPCID

echo "Finding and storing the subnet IDs for defined in arguments.txt Availability Zone 1 and 2..."
SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${10}")
SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${11}")
echo $SUBNET2A
echo $SUBNET2B

# Create AWS EC2 Launch Template
# https://awscli.amazonaws.com/v2/documentation/api/2.0.33/reference/ec2/create-launch-template.html
echo "Creating the AutoScalingGroup Launch Template..."
aws ec2 create-launch-template \
    --launch-template-name $12 \
    --version-description AutoScalingVersion1 \
    --launch-template-data '{ "NetworkInterfaces": [ { "DeviceIndex": 0, "AssociatePublicIpAddress": true, "Groups": [ "sg-0cde1af268aac1d1f" ], "SubnetId": "subnet-0842e5e649ea7b4ae", "DeleteOnTermination": true } ], "ImageId": "ami-04b70fa74e45c3917", "InstanceType": "t2.micro", "KeyName": "coursera-key", "UserData": "IyEvYmluL2Jhc2gNCg0KIyBTYW1wbGUgY29kZSB0byBpbnN0YWxsIE5naW54IHdlYnNlcnZlcg0KDQpzdWRvIGFwdCB1cGRhdGUNCnN1ZG8gYXB0IGluc3RhbGwgLXkgbmdpbngNCg0Kc3VkbyBzeXN0ZW1jdGwgZW5hYmxlIC0tbm93IG5naW54DQo=", "Placement": { "AvailabilityZone": "us-east-1a" },"TagSpecifications":[{"ResourceType":"instance","Tags":[{"Key":"module","Value": "module04-tag" }]}] }' --region us-east-1
echo "Launch Template created..."

# Retreive the Launch Template ID using a --query
LAUNCHTEMPLATEID=lt-0cccf5ac62d2c0cc8

echo 'Creating the TARGET GROUP and storing the ARN in $TARGETARN'
# https://awscli.amazonaws.com/v2/documentation/api/2.0.34/reference/elbv2/create-target-group.html
TARGETARN=arn:aws:elasticloadbalancing:us-east-1:813820435365:targetgroup/tg-njm/e35d4fc7c22dc4b3
echo $TARGETARN

echo "Creating ELBv2 Elastic Load Balancer..."
#https://awscli.amazonaws.com/v2/documentation/api/2.0.34/reference/elbv2/create-load-balancer.html
ELBARN=arn:aws:elasticloadbalancing:us-east-1:813820435365:loadbalancer/app/njm-elb/acabc84867f6add2
echo $ELBARN

# Decrease the deregistration timeout (deregisters faster than the default 300 second timeout per instance)
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/elbv2/modify-target-group-attributes.html
aws elbv2 modify-target-group-attributes --target-group-arn $TARGETARN --attributes Key=deregistration_delay.timeout_seconds,Value=30

# AWS elbv2 wait for load-balancer available
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/elbv2/wait/load-balancer-available.html
echo "Waiting for load balancer to be available..."
aws elbv2 wait load-balancer-available \
    --load-balancer-arns arn:aws:elasticloadbalancing:us-east-1:813820435365:loadbalancer/app/njm-elb/acabc84867f6add2
echo "Load balancer available..."
# create AWS elbv2 listener for HTTP on port 80
#https://awscli.amazonaws.com/v2/documentation/api/latest/reference/elbv2/create-listener.html
aws elbv2 create-listener \
    --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:813820435365:loadbalancer/app/njm-elb/acabc84867f6add2 \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:813820435365:targetgroup/tg-njm/e35d4fc7c22dc4b3 

echo 'Creating Auto Scaling Group...'
# Create Autoscaling group ASG - needs to come after Target Group is created
# Create autoscaling group
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/autoscaling/create-auto-scaling-group.html
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name asg-njm \
    --launch-template LaunchTemplateId=lt-0cccf5ac62d2c0cc8 \
    --min-size 2 \
    --max-size 5 \
    --vpc-zone-identifier "subnet-0842e5e649ea7b4ae,subnet-09644c14dda43bc8d,subnet-09a1af5df2c78d767" 

echo 'Waiting for Auto Scaling Group to spin up EC2 instances and attach them to the TargetARN...'
# Create waiter for registering targets
# https://docs.aws.amazon.com/cli/latest/reference/elbv2/wait/target-in-service.html
aws elbv2 wait target-in-service
--target-group-arn arn:aws:elasticloadbalancing:us-east-1:813820435365:targetgroup/tg-njm/e35d4fc7c22dc4b3
echo "Targets attached to Auto Scaling Group..."

# Collect Instance IDs
# https://stackoverflow.com/questions/31744316/aws-cli-filter-or-logic
INSTANCEIDS=$(aws ec2 describe-instances --output=text --query 'Reservations[*].Instances[*].InstanceId' --filter "Name=instance-state-name,Values=running,pending")

if [ "$INSTANCEIDS" != "" ]
  then
    aws ec2 wait instance-running --instance-ids $INSTANCEIDS
    echo "Finished launching instances..."
  else
    echo 'There are no running or pending values in $INSTANCEIDS to wait for...'
fi 


# Retreive ELBv2 URL via aws elbv2 describe-load-balancers --query and print it to the screen
#https://awscli.amazonaws.com/v2/documentation/api/latest/reference/elbv2/describe-load-balancers.html
URL=$(aws elbv2 describe-load-balancers --load-balancer-arns arn:aws:elasticloadbalancing:us-east-1:813820435365:loadbalancer/app/njm-elb/acabc84867f6add2) 
echo $URL

# end of outer fi - based on arguments.txt content
fi
