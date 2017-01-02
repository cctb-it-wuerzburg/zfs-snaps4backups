#!/bin/bash

# name of the backup snapshot
backup_snapshot_name="backup-snap"

# date
datetime=$(date +"%Y%m%dT%H%M%S")

# getting a list of all zpools

zpools=($(sudo zpool list -H -o name))

for act_zpool in ${zpools[*]}
do
    # create an recursive snapshot
    sudo zfs snapshot -r ${act_zpool}@${backup_snapshot_name}

    # iteratate through all filesystems

    fs2backup=($(sudo zfs list -r -H -o name -t filesystem))
    for act_fs2backup in ${fs2backup[*]}
    do
	fs_mounted=$(sudo zfs get mounted -o value -H ${act_fs2backup})
	fs_mountpoint=$(sudo zfs get mountpoint -o value -H ${act_fs2backup})

	if [ ${fs_mounted} = "yes" ]
	then
	    #echo "Filesystem ${act_fs2backup} is mounted at ${fs_mountpoint}"
	    backup_path=${fs_mountpoint}"/.zfs/snapshot/"${backup_snapshot_name}"/"
	    if [ -e ${backup_path} ]
	    then
		echo ${backup_path}
	    #else
		#echo "Missing the path ${backup_path}">&2
	    fi
	    #echo "Path for backup is ${backup_path}">&2
	#else
	    #echo "Filesystem ${act_fs2backup} is not mounted">&2
	fi

    done
done
