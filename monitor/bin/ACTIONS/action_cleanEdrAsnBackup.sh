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
Hostname=`hostname`
msgFile='';msgFile="/tmp/$base-$stamp"
printf "To: ${SENDTO}\nCc: ${SENDCC}\nSubject: $DCNAME : $Hostname : $base.\n\n\n" >> ${msgFile}

if [[ `/bin/mount | grep -w '/data/collector'` ]]; then 
mountPoint=''; mountPoint=`/bin/mount | grep -w '/data/collector' | awk -F'(' '{print $2}' | awk -F, '{print $1}'`
if [[ $mountPoint == "rw" ]]; then 
    currentUtilization=''; currentUtilization=`/bin/df -P | grep -w "/data/collector" | awk '{print $5}' | sed 's/%//g'`
    if [[ $currentUtilization && ${PIPESTATUS[0]} -eq '0' ]]; then
	if [[ `echo "$currentUtilization >= $threshold" | bc` -eq '1' ]]; then
	# PERFORM THE DESIGNATED ACTION.
	    Email='1'
	    echo "ACTION_SUMMARY : $Date" >> ${msgFile}
	    echo "Disk utilization of /data/collector is found to be ${currentUtilization}%" >> ${msgFile}
	# Get count of files, exit if NIL.
	    count='0';count=`/bin/ls /data/collector/edrAsn_backup/*.gz 2>/dev/null | wc -l`
	    if [[ $count -ne '0' ]]; then
	       echo "Performing cleanup action /bin/rm -f /data/collector/edrAsn_backup/*.gz on $count files." >> ${msgFile}
	       /bin/rm -f /data/collector/edrAsn_backup/*.gz 2>/dev/null
	       if [ $? -eq 0 ]; then
	   	   echo "STATUS : SUCCESS" >> ${msgFile}
		   currentUtilization=''; currentUtilization=`/bin/df -P | grep -w "/data/collector" | awk '{print $5}' | sed 's/%//g'`
		   echo "Disk utilization of /data/collector now stands to be ${currentUtilization}%" >> ${msgFile}
	       else
	  	   echo "STATUS : FAILED : Exit status $?" >> ${msgFile}
	       fi
	    else
	# Found NIL file count.
		echo "NIL compressed files found to be cleaned, under /data/collector/edrAsn_backup" >> ${msgFile}
		echo "Need attention!" >> ${msgFile}
	    fi
	
	    #echo "" >> ${msgFile}
	fi
    fi
else
   Email='1'
   echo "$Date : Mount point /data/collector does not found to be mounted in r/w mode." >> ${msgFile}
fi
else
   Email='1'
   echo "$Date : Mount point /data/collector does not found to be mounted in r/w mode." >> ${msgFile}
fi

if [[ $Email -eq '1' ]]; then
   $NOTIFY < ${msgFile}
fi
/bin/rm -f ${msgFile} 2>/dev/null

# ----------------------------------------------------------------------------------------

