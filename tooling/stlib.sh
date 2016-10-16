#!/bin/bash

if [ -z $LOG_FILE_PATH ]; then
	echo "LOG_FILE_PATH var is not defined."
	echo "Define this var before including this lib."
	exit -1;
fi

if [ -z $BASTION_HOSTNAME ]; then
	echo "BASTION_HOSTNAME var is not defined."
	echo "Define this var before including this lib."
	exit -1;
fi

if [ -z $DEMO_ROOT ]; then
	echo "DEMO_ROOT var is not defined."
	echo "Define this var before including this lib."
	exit -1;
fi

function aws_get_ami_id {
	ami_name=$1
        amis=`aws ec2 describe-images --owners self`
        echo $amis |  python -c "
import sys, json;
amis_arr=json.load(sys.stdin)['Images']
for ami in amis_arr:
    if 'Tags' in ami:
        tags=ami['Tags']
        for tag in tags:
            if tag['Key'] == 'Name' and tag['Value'] == '${ami_name}':
                print(str(ami['ImageId']))
"
}

function aws_get_ami_snap_id {
	ami_name=$1
        snapshots=`aws ec2 describe-snapshots --owner-ids self`
        echo $snapshots |  python -c "
import sys, json;
snaps_arr=json.load(sys.stdin)['Snapshots']
for snap in snaps_arr:
    if 'Tags' in snap:
        tags=snap['Tags']
        for tag in tags:
            if tag['Key'] == 'Name' and tag['Value'] == '${ami_name}':
                print(str(snap['SnapshotId']))
"
}

function packer_build {
	PACKER_STACK=$1
	PACKER_VARS_FILE_NAME=$2
	PACKER_ROOT=$DEMO_ROOT/packer_aws_$PACKER_STACK

	ami_id=`aws_get_ami_id $ami_name`
	if [ "x$ami_id" == "x" ]; then
		cd $PACKER_ROOT
		if [ $? -ne 0 ] ; then
			echo "Problem with $PACKER_STACK stack : unable to cd into $PACKER_ROOT"
			return -1
		fi

		echo "... build $PACKER_STACK ami ..."
		packer build -var-file params/$PACKER_VARS_FILE_NAME $PACKER_STACK.json 1>$LOG_FILE_PATH 2>&1
	else
		echo "... $PACKER_STACK ami exists already ..."
	fi
}

function packer_clean {
	ami_name=$1

	ami_id=`aws_get_ami_id $ami_name`
	snapshots_id=`aws_get_ami_snap_id $ami_name`

        if [ "x$ami_id" != "x" ]; then
		echo "... deregister ami $ami_name (ami id: $ami_id) ..."
                aws ec2 deregister-image --image-id $ami_id
        fi
	if [ "x$snapshots_id" != "x" ]; then
		for snapshot_id in $snapshots_id; do
			echo "... delete snapshot $ami_name (snapshot id: $snapshot_id) ..."
			aws ec2 delete-snapshot --snapshot-id $snapshot_id
		done
	fi
}

function ssh_configure_bastion {
        bastion_ip=`cat $LOG_FILE_PATH | grep "bastion = " | sed -e "s/bastion = //g"`
        echo "... setting new bastion ip ($bastion_ip) for $BASTION_HOSTNAME ..."
        ssh_conf_hostname_line=`awk '$0 == "Host '"$BASTION_HOSTNAME"'" {i=1;next};i && i++ <= 2' ~/.ssh/config | grep Hostname`
        if [ "x$ssh_conf_hostname_line" != "x" ]; then
                sed -i "s/$ssh_conf_hostname_line/\tHostname $bastion_ip/g" ~/.ssh/config
        else
                printf "\nHost $BASTION_HOSTNAME" >> ~/.ssh/config
                printf "\n\tUser admin" >> ~/.ssh/config
                printf "\n\tHostname $bastion_ip" >> ~/.ssh/config
                printf "\n\tPort 22" >> ~/.ssh/config
                printf "\n\tForwardAgent yes" >> ~/.ssh/config
        fi
}

function ssh_remote_script {
        SCRIPT_PATH=$1
        echo "... remote exec on bastion ($SCRIPT_PATH) ..."
        ssh -o StrictHostKeyChecking=no $BASTION_HOSTNAME < $SCRIPT_PATH 1>$LOG_FILE_PATH 2>&1
}

function ssh_tunnel_service_down {
	SERVICE_HOST=$1
        ssh_pid=`ps -aef | grep ssh | grep $SERVICE_HOST | awk '{print $2}'`
        if [ "x$ssh_pid" != "x" ]; then
                kill $ssh_pid
        fi
}

function ssh_tunnel_service_up {
        SERVICE_HOST=$1
        SERVICE_NAME=$2
        SERVICE_PORT=$3
        ssh -o StrictHostKeyChecking=no -f -N -q -L $SERVICE_PORT:$SERVICE_HOST:$SERVICE_PORT $BASTION_HOSTNAME
        echo "... you can reach $SERVICE_NAME UI via http://localhost:$SERVICE_PORT ..."
}

function terraform_provision {
	TERRAFORM_STACK=$1
	TERRAFORM_ROOT=$DEMO_ROOT/terraform_aws_$TERRAFORM_STACK

	cd $TERRAFORM_ROOT
	if [ $? -ne 0 ]; then
		echo "Problem with $TERRAFORM_STACK stack : unable to cd into $TERRAFORM_ROOT"
		return -1
	fi

	echo "... $TERRAFORM_STACK - plan ..."
	terraform plan 1>$LOG_FILE_PATH 2>&1		
        if [ $? -ne 0 ]; then
                cat $LOG_FILE_PATH
                echo "Error while planning $TERRAFORM_STACK... Exit."
                exit -1
        fi

        echo "... $TERRAFORM_STACK - apply ..."
        terraform apply 1>$LOG_FILE_PATH 2>&1
        if [ $? -ne 0 ]; then
		echo "... $TERRAFORM_STACK - apply (2) ..."
 		terraform apply 1>$LOG_FILE_PATH 2>&1
 		if [ $? -ne 0 ]; then
 	                cat $LOG_FILE_PATH
         	        echo "Error while applying $TERRAFORM_STACK... Exit."
                 	exit -1
 		fi
        fi
}

function terraform_destroy {
        TERRAFORM_STACK=$1
        TERRAFORM_ROOT=$DEMO_ROOT/terraform_aws_$TERRAFORM_STACK

        cd $TERRAFORM_ROOT
        if [ $? -ne 0 ]; then
                echo "Problem with $TERRAFORM_STACK stack : unable to cd into $TERRAFORM_ROOT"
                return -1
        fi

        echo "... $TERRAFORM_STACK - destroy ..."
        terraform destroy -force 1>$LOG_FILE_PATH 2>&1
        if [ $? -ne 0 ]; then
                cat $LOG_FILE_PATH
                echo "Error while destroying $TERRAFORM_STACK... Exit."
                exit -1
        fi
}
