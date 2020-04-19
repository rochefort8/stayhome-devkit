#!/bin/bash

set -x

temp_dir=`pwd`"/tmp"
user_rootdir=`pwd`"/user"

if [ $# -lt 2 ]; then
   echo "MUST specify project name and user name" 1>&2
   exit 1
fi

proj_name=$1
user_name=$2

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

if [ ! -e $user_rootdir ]; then
    mkdir $user_rootdir
fi  

user_dir=$user_rootdir/$user_name

rm -rf $user_dir
mkdir $user_dir

info_file=$user_dir/info.txt
rm -rf $info_file

# -------
# Keypair for EC2 instance
# -------
aws ec2 create-key-pair --key-name ${user_name} --query 'KeyMaterial' --output text \
    > ${user_dir}/${user_name}.pem
if [ $? -ne 0 ]; then
    echo "Could not create key pair" ${instance_name}"."
    exit 1
fi

# Set project name and user name
sed -e "s/{PROJECT_NAME}/"$proj_name"/g" cfn_user.yaml > $temp_dir/tmp.yaml
sed -e "s/{USER_NAME}/"$user_name"/g" $temp_dir/tmp.yaml > $temp_dir/cfn_user.yaml
rm -rf $temp_dir/tmp.yaml

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

result_create_stack=
create_stack $temp_dir/cfn_user.yaml stayhome-user-$user_name &&
result_create_stack="y"

if [ -z ${result_create_stack} ];then
    aws ec2 delete-key-pair --key-name ${user_name} 
    exit 1
fi

# --------------------------------------------
#    Export information to file
# --------------------------------------------

ip_address=$(aws ec2 describe-instances --filter "Name=tag:Name,Values=$user_name" \
    --query 'Reservations[].Instances[].PublicIpAddress' --output text)

echo "## EC2 public IP address"     >> $info_file
echo $ip_address                    >> $info_file
echo ""                             >> $info_file
echo "## SSH Key"                   >> $info_file
cat ${user_dir}/${user_name}.pem  >> $info_file
exit 0





