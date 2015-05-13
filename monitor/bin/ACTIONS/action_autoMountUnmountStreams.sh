#!/bin/bash
#-------------------------------------------------------------------------------------------------
BASEPATH="/data/scripts/monitor"
ENVF="${BASEPATH}/etc/env.cfg"
if [[ -s $ENVF ]]; then
  #source $ENVF 2>/dev/null
  /bin/chmod 755 ${ENVF}
  . ${ENVF}
  if [[ $? -ne '0' ]]; then echo "Unable to load the environment file. Committing Exit!!!"; exit 127; fi
else
  echo "Unable to locate the environment file: $ENVF"; exit 127
fi
mount -o remount,rw / 2>/dev/null
if [[ ! -s ${IP} ]]; then /bin/bash ${SITE}; else source ${IP}; fi
#-------------------------------------------------------------------------------------------------
function thresh {
   base=''; base=`basename $0 | awk -F_ '{print $2}' | awk -F. '{print $1}'`
   threshold=''; threshold=`/bin/grep -w ^$base ${THRESHOLDS_ACTION} | sed 's/ //g' | awk -F= '{print $NF}' | awk -F: '{print $1}'`
   switch=''; switch=`/bin/grep -w ^$base ${THRESHOLDS_ACTION} | sed 's/ //g' | awk -F= '{print $NF}' | awk -F: '{print $2}'`
}
thresh
if [[ ! $threshold ]]; then threshold=90; fi; if [[ ! $switch ]]; then switch="off"; fi; if [[ $switch != "on" ]]; then exit; fi
#-------------------------------------------------------------------------------------------------
# Overriding SENDTO and SENDCC variables.
SENDTO="robert.phillips@guavus.com,samuel.joseph@guavus.com,shailendra.kumar@guavus.com,hannes.vanrooyen@guavus.com"
SENDCC="supreet.singh@guavus.com"
#-------------------------------------------------------------------------------------------------

Email='0'
stamp=`date +%s`
Date=`date`
msgFile='';msgFile="/tmp/$base-$stamp"
Hostname=`hostname`
printf "To: ${SENDTO}\nCc: ${SENDCC}\nSubject: $DCNAME : $Hostname : $base.\n\n\n" >> ${msgFile}
echo "ACTION_SUMMARY : $Date" >> ${msgFile}

if [[ `/bin/ls /etc/fstab 2>/dev/null` ]]; then
   for nfsIp in `/bin/cat /etc/fstab | grep streams | awk -F ':' '{print $1}' | sed 's/ //g' | sort -u`; do
	/bin/ping -c 1 $nfsIp 2>&1>/dev/null
	if [[ $? -ne '0' ]]; then
	     for mountP in `/bin/cat /etc/fstab | grep streams | grep $nfsIp | awk '{print $2}' | sed 's/ //g' | sort -u`; do
      	     	/bin/umount -f -l $mountP 
		if [[ $? -eq '0' ]]; then
		   Email='1'
		   echo "Unmount unreachable NFS IP $nfsIp stream : $mountP" >> ${msgFile}
		fi
             done
        elif [[ $? -eq '0' ]]; then
	     val='';val=`/bin/df -P | grep $nfsIp 2>/dev/null`
	     if [[ $? -ne '0' ]]; then
		Email='1'
		for mountP in `/bin/cat /etc/fstab | grep streams | grep $nfsIp | awk '{print $2}' | sed 's/ //g' | sort -u`; do
			gval=''; gval=`/bin/cat /etc/fstab | grep $mountP | grep -w 'rw'`
			if [[ $? -eq '0' ]]; then
				/bin/mount -t nfs -o nolock,rw,vers=3 $nfsIp:$mountP $mountP
				if [[ $? -eq '0' ]]; then
				echo "Mount (read/write) reachable but unmounted NFS IP $nfsIp stream on $mountP" >> ${msgFile}
				fi
			else
				/bin/mount -t nfs -o nolock,ro,vers=3 $nfsIp:$mountP $mountP
				if [[ $? -eq '0' ]]; then
				echo "Mount (read-only) reachable but unmounted NFS IP $nfsIp stream on $mountP" >> ${msgFile}
				fi
			fi
		done

	     fi
	     
	
	fi
   done

fi

if [[ $Email -eq '1' ]]; then
   $NOTIFY < ${msgFile}
fi
/bin/rm -f ${msgFile} 2>/dev/null

# ----------------------------------------------------------------------------------------

