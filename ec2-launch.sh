#!/bin/bash

if [ -z "$1"  ]; then
    echo -e "\e[1;31mInput is missing\e[0m"
    exit 1
fi
COMPONENT=$1



TEMP_ID="ami-0fc800a3140d9997d"
TEMP_VER=5
ZONE_ID=Z078908237A6SF5H7OAQ8

CREATE_INSTANCE(){
# check if instance is already there
aws ec2 describe-instances --filters "Name=tag:Name,Values=${COMPONENT}" | jq .Reservations[].Instances[].State.Name | sed 's/"//g' | grep -E 'running|stopped' &>/dev/null
if [ $? -eq 0 ]; then
  echo -e "\e[1;33mInstance is already there\e[0m"
 else

#create spot instance from launch template

aws ec2 run-instances --launch-template LaunchTemplateId=${TEMP_ID},Version=${TEMP_VER}  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${COMPONENT}}]" "ResourceType=spot-instances-request,Tags=[{Key=Name,Value=${COMPONENT}}]" | jq
fi

sleep 10

# get private ipaddress of instance
IPADDRESS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${COMPONENT}" | jq .Reservations[].Instances[].PrivateIpAddress | sed 's/"//g' | grep -v null)



# update the DNS record
sed -e "s/IPADDRESS/${IPADDRESS}/" -e "s/COMPONENT/${COMPONENT}/" record.json >/tmp/record.json

aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file:///tmp/record.json | jq

}
if [ $COMPONENT == "all" ]; then
  for comp in frontend mongodb mysql ; do
    COMPONENT=$comp
    CREATE_INSTANCE
  done
  else
    CREATE_INSTANCE
fi

