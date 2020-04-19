#!/bin/bash

set -x

temp_dir=`pwd`"/tmp"

if [ $# -lt 1 ]; then
   echo "MUST specify project name." 1>&2
   exit 1
fi

proj_name=$1

#echo -n "Create Stay home system" $proj_name "? [Y/n]: "
#read ANS

case $ANS in
  "" | [Yy]* )
    ;;
  * )
    echo "Canceled."
    exit
    ;;
esac

if [ ! -e $temp_dir ]; then
    mkdir $temp_dir
fi  

# Set project name
sed -e "s/{PROJECT_NAME}/"$proj_name"/g" cfn_base_step1.yaml > $temp_dir/cfn_base_step1.yaml
sed -e "s/{PROJECT_NAME}/"$proj_name"/g" cfn_base_step2.yaml > $temp_dir/cfn_base_step2.yaml
sed -e "s/{PROJECT_NAME}/"$proj_name"/g" cfn_base_step3.yaml > $temp_dir/cfn_base_step3.yaml

create_stack() {
    file=$1
    name=$2

    echo "Crearing stack " $name.

    aws cloudformation create-stack \
        --template-body file:///$file --stack-name $name --capabilities CAPABILITY_NAMED_IAM
    if [ $? -ne 0 ]; then
        echo "Failed to run create-stack command."    
        exit 1
    fi
    aws cloudformation wait stack-create-complete --stack-name $name
    if [ $? -ne 0 ]; then
        echo "Failed to run stack-create-complete command."    
        exit 1
    fi

    result=$(aws cloudformation describe-stacks --stack-name $name \
            --query 'Stacks[].StackStatus' --output text)
    if [ ${result} != "CREATE_COMPLETE" ]; then  
        echo "FAILED to create stack " $name.
        return 1
    fi

    echo "Stack " $name " Successfully created".
    return 0
}

# ---------------------------------------------------------------------
#    Step 1 : VPC/Internet Gateway/Route Table/Subnet/Security Group
#    Step 2 : S3/SFTP Server/CodeCommit (git)/VPC Endpoint
#    Step 3 : IAM Role/Group/User
# ---------------------------------------------------------------------
result_create_stack=
create_stack $temp_dir/cfn_base_step1.yaml stayhome-base-step1 &&
create_stack $temp_dir/cfn_base_step2.yaml stayhome-base-step2 &&
create_stack $temp_dir/cfn_base_step3.yaml stayhome-base-step3 &&
result_create_stack="y"

if [ -z ${result_create_stack} ];then
    exit 1
fi

# --------------------------------------------
#    Get Endpoint URLs
# --------------------------------------------
vpce_sftp_id=$(aws cloudformation list-exports \
    --query "Exports[?Name=='VPCEndpoint-SFTP-$proj_name'].Value" --output text)
vpce_codecommit_id=$(aws cloudformation list-exports \
    --query "Exports[?Name=='VPCEndpoint-CodeCommit-$proj_name'].Value" --output text)
if [ -z ${vpce_sftp_id} -o -z ${vpce_codecommit_id} ]; then
    echo "Cound not get VPC Endpoint id".
    exit 1
fi

dns_codecommit=$(aws ec2 describe-vpc-endpoints \
    --query "VpcEndpoints[?VpcEndpointId=='$vpce_codecommit_id'].DnsEntries[0].DnsName" \
    --output text)
dns_sftp=$(aws ec2 describe-vpc-endpoints \
    --query "VpcEndpoints[?VpcEndpointId=='$vpce_sftp_id'].DnsEntries[0].DnsName" \
    --output text)

# Create key
key_name="ssh_in_vpc"
rm -rf $temp_dir/$key_name*
ssh-keygen -t rsa -f $temp_dir/$key_name -q -N ""
ssh_public_key=$(cat $temp_dir/$key_name.pub)

# --------------------------------------------
#    SFTP User
# --------------------------------------------
# Role 
role_name=$(aws iam get-role --role-name $proj_name-SFTP-Role \
    --query 'Role.Arn' --output text)
if [ -z ${role_name} ]; then
    echo "Cound not get role named "$proj_name"-SFTP-Role."
    exit 1
fi

# Server ip
sftp_server_id=$(aws cloudformation list-exports \
    --query "Exports[?Name=='SFTPServer-$proj_name'].Value" --output text)
if [ -z ${role_name} ]; then
    echo "Cound not get SFTP server id".
    exit 1
fi

# Create SFTP User
aws transfer create-user --home-directory "/$proj_name" \
    --role "arn:aws:iam::363930575156:role/$proj_name-SFTP-Role" \
    --server-id $sftp_server_id --user-name $proj_name \
    --ssh-public-key-body "$ssh_public_key"

# --------------------------------------------
#    Access key (for Codecommit)
# --------------------------------------------
ssh_access_key=$(aws iam upload-ssh-public-key --user-name $proj_name-User \
    --ssh-public-key-body file:///$temp_dir/ssh_in_vpc.pub \
    --query 'SSHPublicKey.SSHPublicKeyId' --output text)

# --------------------------------------------
#    Export information to file
# --------------------------------------------

base_dir=`pwd`"/base"

if [ ! -e $base_dir ]; then
    mkdir $base_dir
fi

mv $temp_dir/ssh_in_vpc $base_dir
rm -rf $base_dir/info.txt

info_file=$base_dir/info.txt
rm -rf $info_file

echo "## Endpoint URL"                  >> $info_file
echo "+ SFTP server"                    >> $info_file
echo $proj_name"@"$dns_sftp             >> $info_file
echo ""                                 >> $info_file
echo "+ GIT server"                     >> $info_file
echo $ssh_access_key"@"$dns_codecommit  >> $info_file
echo ""                                 >> $info_file
echo "## Commands"                      >> $info_file
echo "$ sftp "$proj_name"@"$dns_sftp    >> $info_file
echo "$ git clone ssh://"$ssh_access_key"@"$dns_codecommit"/v1/repos/test-repo"  >> $info_file
echo ""                                  >> $info_file
echo "## ~/.ssh/config"                  >> $info_file
echo "Host  "$dns_sftp                      >> $info_file
echo "  User    "$proj_name                 >> $info_file
echo "  IdentityFile    ~/.ssh/ssh_in_vpc" >> $info_file
echo "Host  "$dns_codecommit                >> $info_file
echo "  User    "$ssh_access_key            >> $info_file
echo "  IdentityFile    ~/.ssh/ssh_in_vpc" >> $info_file

exit 0
   