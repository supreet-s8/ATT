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
SENDTO="prashant.singh1@guavus.com,samuel.joseph@guavus.com,shailendra.kumar@guavus.com,hannes.vanrooyen@guavus.com"
SENDCC="supreet.singh@guavus.com"
#-------------------------------------------------------------------------------------------------

Email='0'
stamp=`date +%s`
Date=`date`
Hostname=`hostname`
msgFile='';msgFile="/tmp/$base-$stamp"
printf "To: ${SENDTO}\nCc: ${SENDCC}\nSubject: $DCNAME : $Hostname : DataFactory Job Missing bins \n\n\n" >> ${msgFile}

### DataTransferJob workaround

## get time from tmp file
 
run_time=`ssh -q root@${cnp0vip} "$HADOOP dfs -cat /data/dfdt_tmp_hdfs/metadata.txt 2>/dev/null" | tail -1 | sed 's/[A-Z]/ /g'`

if [ $? -ne 0 ]
then
	exit
fi 

## get bin time
bin_time=`ssh -q root@${cnp0vip} "$HADOOP dfs -cat /data/dfdt_tmp_hdfs/metadata.txt 2>/dev/null" | grep currentBinTime | cut -d= -f2 | sed 's/[A-Z]/ /g'`

bins=`ssh -q root@${cnp0vip} "$HADOOP dfs -cat /data/dfdt_tmp_hdfs/metadata.txt 2>/dev/null" | grep currentBinTime | cut -d= -f2 | sed 's/-/\//g' | sed 's/[A-Z]/\//g' | sed 's/:/\//g'`

epoc_bin_time=`date +%s -d"${bin_time}"`

epoc_run_time=`date +%s -d"${run_time}"`

cur_time=`date +%s`

time_diff=`echo "$cur_time - $epoc_run_time" | bc`

if [ $time_diff -ge 900 ]
then

	Email='1'
	work_flow_id=`/opt/oozie/bin/oozie jobs -oozie http://${cnp0vip}:8080/oozie -len  100000000 |grep RUNNING|sed 's/RUNNING/ RUNNING/g' | grep -w DataTransferJob | awk '{print $1}'`
	
	echo $work_flow_id
	
	out=`$HADOOP dfs -ls ${bins}/_DONE 2>/dev/null`
	
	if [ $? -ne 0 ]
	then
		
		dones=''
		for i in `seq -w $epoc_bin_time 300 $cur_time`
		do
				
			file_time=`date -d@"$i" +"%Y/%m/%d/%H/%M"`
			done_file=`$HADOOP dfs -ls /data/output/DataFactory/${file_time}/_DONE 2>/dev/null`
		
			if [ $? -ne 0 ]
			then
				dones+="/data/output/DataFactory/${file_time};"
			
			fi
		done
	
		if [[ $dones ]]
		then

			total_missing=`echo $dones|sed 's/;$//g'`
			echo "DataFactory Job Missing bins" >> ${msgFile}
			echo "DONE FILE- ${bins}/_DONE NOT FOUND" >> ${msgFile}
			echo "total missing bins till current time $Date : $total_missing" >> ${msgFile}
			echo "Creating missing bins" >>  ${msgFile}
			
			for t in `echo $total_missing | sed 's/;/\n/g'`
			do
				$HADOOP dfs -touchz ${t}/_DONE 2>/dev/null
			done

			echo "Missing bins created " >>  ${msgFile}
		fi

	else

		echo "DataTransferJob is Stuck on particular bin : ${bins}, but DONE FILE of particular bin is present. Please check" >> ${msgFile}
		echo "$out" >> ${msgFile}
				
	fi
	
fi

if [[ $Email -eq '1' ]]; then
   $NOTIFY < ${msgFile}
fi
/bin/rm -f ${msgFile} 2>/dev/null

# ----------------------------------------------------------------------------------------

