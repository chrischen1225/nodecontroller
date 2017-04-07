#!/bin/bash

# this script is specifically for (auto-)building images on the odroid.
# it copies a new waggle partition into a .img-file.

if [ $# -eq 0 ] ; then
  echo "usage: $0 <device>"
  echo ""
  echo "list of available devices:"
  blkid
  exit 1
fi

export DIR="/root"


ODROID_MODEL=$(head -n 1 /media/boot/boot.ini | cut -d '-' -f 1)
MODEL=""
if [ "${ODROID_MODEL}_"  == "ODROIDXU_" ] ; then
  echo "Detected device: ${ODROID_MODEL}"
  if [ -e /media/boot/exynos5422-odroidxu3.dtb ] ; then
    export MODEL="odroid-xu3"
  else
    export MODEL="odroid-xu"
    echo "Did not find the XU3/4-specific file /media/boot/exynos5422-odroidxu3.dtb."
    exit 1
  fi
elif [ "${ODROID_MODEL}_"  == "ODROIDC_" ] ; then
  echo "Detected device: ${ODROID_MODEL}"
  export MODEL="odroid-c1"
else
  echo "Could not detect ODROID model. (${ODROID_MODEL})"
  exit 1
fi


set -e
set -x

export OTHER_DEVICE=$1

if [ ! $(lsblk -o KNAME,TYPE ${OTHER_DEVICE} | grep -c disk) -eq 1 ] ; then
  echo "device $1 not found."
  exit 1
fi


OTHER_DEVICE=`basename ${OTHER_DEVICE}`
echo "OTHER_DEVICE: /dev/${OTHER_DEVICE}"


# probably not needed anyway....
export CURRENT_DEVICE=$(df | grep " \/$" | cut -f 1 -d ' ') ; echo "CURRENT_DEVICE: ${CURRENT_DEVICE}"
CURRENT_DEVICE=`basename ${CURRENT_DEVICE}`


function dev_suffix {

  if [[ $1 =~ ^"/dev/sd" ]] ; then
    echo ""
    return 0
  fi
  if [[ $1 =~ ^"/dev/mmcblk" ]] ; then
    echo "p"
    return 0
  fi
  if [[ $1 =~ ^"/dev/disk" ]] ; then
	echo "s"
	return 0
  fi

  echo "unknown"
  return 1
}


export OTHER_DEV_SUFFIX=`dev_suffix "/dev/${OTHER_DEVICE}"`
if [ "${OTHER_DEV_SUFFIX}_" == "unknown_" ] ; then
  exit 1
fi

export CURRENT_DEV_SUFFIX=`dev_suffix "/dev/${CURRENT_DEVICE}"`
if [ "${CURRENT_DEV_SUFFIX}_" == "unknown_" ] ; then
  exit 1
fi


echo "CURRENT_DEV_SUFFIX: ${CURRENT_DEV_SUFFIX}"
echo "OTHER_DEV_SUFFIX: ${OTHER_DEV_SUFFIX}"



# unmount in case it is already mounted (it might be already mounted, but with another mount point)
if [ $(df -h | grep -c /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2 ) == 1 ] ; then
  while ! $(umount /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2) ; do sleep 3 ; done
fi

export DATE=`date +"%Y%m%d"` ; echo "DATE: ${DATE}"
export NEW_IMAGE_PREFIX="${DIR}/waggle-${MODEL}-${DATE}" ; echo "NEW_IMAGE_PREFIX: ${NEW_IMAGE_PREFIX}"
export NEW_IMAGE="${NEW_IMAGE_PREFIX}.img" ; echo "NEW_IMAGE: ${NEW_IMAGE}"
export NEW_IMAGE_B="${NEW_IMAGE_PREFIX}_B.img" ; echo "NEW_IMAGE_B: ${NEW_IMAGE_B}"

# extract the report.txt from the new waggle image
export WAGGLE_ROOT="/media/waggleroot/"
mkdir -p ${WAGGLE_ROOT}
mount /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2 ${WAGGLE_ROOT}
if [ -e ${WAGGLE_ROOT}/root/report.txt ] ; then
  cp ${WAGGLE_ROOT}/root/report.txt ${NEW_IMAGE}.report.txt
else
  echo "no report found" > ${NEW_IMAGE}.report.txt
fi

if [ -e ${WAGGLE_ROOT}/root/rc.local.log ] ; then
  cp ${WAGGLE_ROOT}/root/rc.local.log ${NEW_IMAGE}.build_log.txt
else
  echo "no log found" > ${NEW_IMAGE}.build_log.txt
fi


# put original rc.local in place again
rm -f ${WAGGLE_ROOT}/etc/rc.local
cat <<EOF > ${WAGGLE_ROOT}/etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

[ ! -f /etc/ssh/ssh_host_dsa_key ]; dpkg-reconfigure openssh-server

exit 0
EOF

chmod +x ${WAGGLE_ROOT}/etc/rc.local

rm -f ${WAGGLEROOT}/etc/udev/rules.d/70-persistent-net.rules

# Set up static IP
echo "10.31.81.10" > ${WAGGLEROOT}/etc/waggle/NCIP
cat << EOF > ${WAGGLEROOT}/etc/network/interfaces
# created by Waggle autobuild

auto lo eth0
iface lo inet loopback

iface eth0 inet static
        address 10.31.81.10
        netmask 255.255.255.0
        
EOF



export ESTIMATED_FS_SIZE_BLOCKS=$(resize2fs -P /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2 | grep -o "[0-9]*") ; echo "ESTIMATED_FS_SIZE_BLOCKS: ${ESTIMATED_FS_SIZE_BLOCKS}"
#export BLOCK_SIZE=$(tune2fs -l /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2 | grep "^Block size:" | grep -o "[0-9]*") ; echo "BLOCK_SIZE: ${BLOCK_SIZE}"
export BLOCK_SIZE=`blockdev --getbsz /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2`

export ESTIMATED_FS_SIZE_KB=$(echo "${ESTIMATED_FS_SIZE_BLOCKS}*${BLOCK_SIZE}/1024" | bc) ; echo "ESTIMATED_FS_SIZE_KB: ${ESTIMATED_FS_SIZE_KB}"


export OLD_PARTITION_SIZE_KB=$(df -BK --output=size /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2 | tail -n 1 | grep -o "[0-9]\+") ; echo "OLD_PARTITION_SIZE_KB: ${OLD_PARTITION_SIZE_KB}"


# add 500MB
export NEW_PARTITION_SIZE_KB=$(echo "${ESTIMATED_FS_SIZE_KB} + (1024)*500" | bc) ; echo "NEW_PARTITION_SIZE_KB: ${NEW_PARTITION_SIZE_KB}"

# add 100MB
export NEW_FS_SIZE_KB=$(echo "${ESTIMATED_FS_SIZE_KB} + (1024)*100" | bc) ; echo "NEW_FS_SIZE_KB: ${NEW_FS_SIZE_KB}"


# unmount the boot partition
if [ $(df -h | grep -c /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}1 ) == 1 ] ; then
  while ! $(umount /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}1) ; do sleep 3 ; done
fi

# unmount the root partition
if [ $(df -h | grep -c /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2 ) == 1 ] ; then
  while ! $(umount /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2) ; do sleep 3 ; done
fi




# just for information: dumpe2fs -h ${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2

# verify partition:
e2fsck -f -y /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2




# detect start position of second partition
export START=$(fdisk -l /dev/${OTHER_DEVICE} | grep "/dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2" | awk '{print $2}') ; echo "partition START: ${START}"

export SECTOR_SIZE=`fdisk -l /dev/${OTHER_DEVICE} | grep "Sector size" | grep -o ": [0-9]*" | grep -o "[0-9]*"` ; echo "SECTOR_SIZE: ${SECTOR_SIZE}"

export FRONT_SIZE_KB=`echo "${SECTOR_SIZE} * ${START} / 1024" | bc` ; echo "FRONT_SIZE_KB: ${FRONT_SIZE_KB}"



if [ "${NEW_PARTITION_SIZE_KB}" -lt "${OLD_PARTITION_SIZE_KB}" ] ; then 

  echo "NEW_PARTITION_SIZE_KB is smaller than OLD_PARTITION_SIZE_KB"

  # shrink filesystem (that does not shrink the partition!)
  resize2fs -p /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2 ${NEW_FS_SIZE_KB}K


  partprobe  /dev/${OTHER_DEVICE}

  sleep 3

  ### fdisk (shrink partition)
  # fdisk: (d)elete partition 2 ; (c)reate new partiton 2 ; specify start posirion and size of new partiton
  set +e
  echo -e "d\n2\nn\np\n2\n${START}\n+${NEW_PARTITION_SIZE_KB}K\nw\n" | fdisk /dev/${OTHER_DEVICE}
  set -e


  partprobe  /dev/${OTHER_DEVICE}

  set +e
  resize2fs /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2
  set -e

  # does not show the new size
  fdisk -l /dev/${OTHER_DEVICE}

  # shows the new size (-b for bytes)
  partx --show /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2


  e2fsck -f /dev/${OTHER_DEVICE}${OTHER_DEV_SUFFIX}2

else
  echo "NEW_PARTITION_SIZE_KB is NOT smaller than OLD_PARTITION_SIZE_KB"
fi


# add size of boot partition
COMBINED_SIZE_KB=`echo "${NEW_PARTITION_SIZE_KB} + ${FRONT_SIZE_KB}" | bc` ; echo "COMBINED_SIZE_KB: ${COMBINED_SIZE_KB}"




# from kb to mb
export BLOCKS_TO_WRITE=`echo "${COMBINED_SIZE_KB}/1024" | bc` ; echo "BLOCKS_TO_WRITE: ${BLOCKS_TO_WRITE}"





dd if=/dev/${OTHER_DEVICE} bs=1M count=${BLOCKS_TO_WRITE} | xz -1 --stdout - > ${NEW_IMAGE}.xz_part
# xz -1 creates a 560MB file in 18.5 minutes

mv ${NEW_IMAGE}.xz_part ${NEW_IMAGE}.xz

# create second dd with different UUIDs
if [ -e /usr/lib/waggle/nodecontroller/scripts/change_partition_uuid.sh  ] ; then
  /usr/lib/waggle/nodecontroller/scripts/change_partition_uuid.sh /dev/${OTHER_DEVICE}
  
  dd if=/dev/${OTHER_DEVICE} bs=1M count=${BLOCKS_TO_WRITE} | xz -1 --stdout - > ${NEW_IMAGE_B}.xz_part
  mv ${NEW_IMAGE_B}.xz_part ${NEW_IMAGE_B}.xz
fi


if [ -e ${DIR}/waggle-id_rsa ] ; then
  md5sum ${NEW_IMAGE}.xz > ${NEW_IMAGE}.xz.md5sum 
  scp -o "StrictHostKeyChecking no" -v -i ${DIR}/waggle-id_rsa ${NEW_IMAGE}.xz ${NEW_IMAGE}.xz.md5sum waggle@terra.mcs.anl.gov:/mcs/www.mcs.anl.gov/research/projects/waggle/downloads/unstable
  
  if [ -e ${NEW_IMAGE_B}.xz ] ; then
    # upload second image with different UUID's
    md5sum ${NEW_IMAGE_B}.xz > ${NEW_IMAGE_B}.xz.md5sum
    scp -o "StrictHostKeyChecking no" -v -i ${DIR}/waggle-id_rsa ${NEW_IMAGE_B}.xz ${NEW_IMAGE_B}.xz.md5sum waggle@terra.mcs.anl.gov:/mcs/www.mcs.anl.gov/research/projects/waggle/downloads/unstable
  fi
  
  
  if [ -e ${NEW_IMAGE}.report.txt ] ; then 
    scp -o "StrictHostKeyChecking no" -v -i ${DIR}/waggle-id_rsa ${NEW_IMAGE}.report.txt waggle@terra.mcs.anl.gov:/mcs/www.mcs.anl.gov/research/projects/waggle/downloads/unstable
  fi
  
  if [ -e ${NEW_IMAGE}.build_log.txt ] ; then 
    scp -o "StrictHostKeyChecking no" -v -i ${DIR}/waggle-id_rsa ${NEW_IMAGE}.build_log.txt waggle@terra.mcs.anl.gov:/mcs/www.mcs.anl.gov/research/projects/waggle/downloads/unstable
  fi
  
fi



###################################################

# Variant A: create archive on ODROID and push final result to remote location
# or
# Variant B: Pull disk dump from ODROID and create image archive on PC 
 


###  Variant A  ###
# on ONDROID
#  create diskdump 
#dd if=/dev/${OTHER_DEVICE} of=./newimage.img bs=1M count=${BLOCKS_TO_WRITE}

# compress (xz --keep option to save space)
#xz newimage.img
#md5sum newimage.img.xz > newimage.img.xz.md5sum
#scp report.txt newimage.img.xz newimage.img.xz.md5sum <to_somewhere>

###  Variant A2  ###


###  Variant B  ###
# on your computer
#scp root@<odroid_ip>:/root/report.txt .
#ssh root@<odroid_ip> "dd if=/dev/${OTHER_DEVICE} bs=1M count=${BLOCKS_TO_WRITE}" | dd of="newimage.img" bs=1m
#xz --keep newimage.img
# Linux:
#md5sum newimage.img.xz > newimage.img.xz.md5sum
# OSX:
#md5 -r newimage.img.xz > newimage.img.xz.md5sum
