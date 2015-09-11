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
if [[ `am_i_master` -eq '0' ]]; then exit 0; fi
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
printf "To: ${SENDTO}\nCc: ${SENDCC}\nSubject: $DCNAME : $Hostname : DataFactory Job Missing bins \n\n\n" >> ${msgFile}

### DataTransferJob missing bins
H2=`date -d "1 hours ago" +%Y/%m/%d/%H`

for i in `seq -w 00 05 55`
do
	val_df=`$SSH $cnp0vip "$HADOOP dfs -ls /data/output/DataFactory/${H2}/${i}/* 2>/dev/null" | grep DONE`
	if [[ ! $val_df ]];then
		out_df+="$H2/${i};"
	fi
done

  if [[ $out_df ]]
  then

	Email='1'
	echo "DataFactory Job Missing bins" >> ${msgFile}
	echo "ACTION_SUMMARY : $Date" >> ${msgFile}
        echo "Following bins missing for DataFactory Job " >> ${msgFile}
	echo $out_df |sed 's/;/\n/g'  >> ${msgFile}

	last_bin_date=`echo $out_df|awk -F';' '{print $(NF-1)}'`
	format_last_bin_date=`echo $last_bin_date | awk -F'/' '{print $1"-"$2"-"$3" "$4":"$5}'`
	epc_format_last_bin_date=`date +%s -d"$format_last_bin_date"`
	epc_update_date=`echo "$epc_format_last_bin_date + 300" | bc`
	update_date=`date -d@"$epc_update_date" +'%Y-%m-%dT%H:%MZ'`
	
	echo "Initiating workaround steps, stopping DataTransferJob.." >> ${msgFile}
	
	$SSH $cnp0vip "/opt/tms/bin/pmx subshell oozie stop jobname DataTransferJob 2>/dev/null"
	sleep 60
	
	$SSH $cnp0vip "$HADOOP dfs -rmr /data/dfdt_tmp_hdfs/
	$SSH $cnp0vip "$HADOOP fs -rm /data/DataTransferJob/done.txt
	echo "Restarting the job with a start time set to $update_date" >> ${msgFile}
	$SSH $cnp0vip "/opt/tms/bin/pmx subshell oozie set job DataTransferJob attribute jobStart $update_date 2>/dev/null"
	$SSH $cnp0vip "/opt/tms/bin/pmx subshell oozie set job DataTransferJob action DfDataTransferAction attribute currentBinTime $update_date 2>/dev/null"
	$SSH $cnp0vip "/opt/tms/bin/pmx subshell oozie run job DataTransferJob 2>/dev/null"
	
  fi

out_df=''

if [[ $Email -eq '1' ]]; then
   $NOTIFY < ${msgFile}
fi
/bin/rm -f ${msgFile} 2>/dev/null

# ----------------------------------------------------------------------------------------

