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
   threshold=''; threshold=`/bin/grep -w ^$base $THRESHOLDS | sed 's/ //g' | awk -F= '{print $NF}'`
}
thresh
if [[ ! $threshold ]]; then threshold=90; fi
if [[ `am_i_master` -eq '0' ]]; then exit 0; fi
#-------------------------------------------------------------------------------------------------

#-----
stamp=`date +%s`
#-----
# Idle_Job_Alert

#####  JOB_LIST=<job name>:<frequency in min>

JOB_LIST="DataFactoryJob:10,DataFactoryJob2:10"

for list in `echo $JOB_LIST|sed 's/,/\n/g'`
do
	
	job=`echo $list|cut -d: -f1`
	job_freq=`echo $list|cut -d: -f2 ` 
	job_freq_stamp=`echo $job_freq*60 | bc`  ## change frequency(min) to seconds
	if [[ ! $job_freq ]]
	then
		##### default frequency 1 hour

		job_freq=3600  
	fi
	
	val=`/opt/oozie/bin/oozie jobs -oozie http://172.30.14.50:8080/oozie -len  100000000 |grep RUNNING|sed 's/RUNNING/ RUNNING/g' |grep -w $job|awk '{print $6" "$7}'`
	
	job_stamp=`date +%s -d"$val"`
	
	job_time_lag=`echo "($stamp-$job_stamp)/60" | bc`

	if [ $job_time_lag -gt $job_freq_stamp ]	## Alert if job running time is more than job threshold(job_freq_stamp)
	then
		. ${BIN}/email.sh "$job_time_lag min" "JOB IDLE ALERT FOR $job" "$stamp" "$job_freq min" "$base"
	fi
done

#####
