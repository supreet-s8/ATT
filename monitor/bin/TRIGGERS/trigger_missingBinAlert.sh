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
# Input Data Volume 

H1=`date -d "${LATENCY} hours ago" +%Y/%m/%d/%H`
#H1="2012/10/02/17"

out=''
for host in $cnp0vip
do
  #-----
  hostn='';hostn=`/bin/grep -w "$host" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $host "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$prefix$host"; fi
  #-----

 for k in 1 2
 do
 
  for adaptors in $ADAPTORS
  do  
   for i in 00 15 30 45 ## changed to 15 min
   do  
	val=`$SSH ${host} "$HADOOP dfs -ls /data/collector/output/${k}/${adaptors}/$H1/${i}/* 2>/dev/null" | grep DONE`
	if [[ ! $val ]]; then
		
		out+="$H1/${i};"
		 
  	fi	
   done

  if [[ $out ]]
  then
	. ${BIN}/email.sh "Following bins missing for adaptor ${adaptors} $out" "COLLECTOR_${k}_$cnp0vip" "$stamp" "N/A" "$base"
  fi
  done

out=''

 done

done

#####

### DataTransferJob missing bins
H2=`date -d "1 hours ago" +%Y/%m/%d/%H`

for i in `seq -w 00 05 55`
do
	val_df=`$SSH ${host} "$HADOOP dfs -ls /data/output/DataFactory/${H2}/${i}/* 2>/dev/null" | grep DONE`
	if [[ ! $val_df ]];then
		out_df+="$H1/${i};"
	fi
done

  if [[ $out_df ]]
  then
        . ${BIN}/email.sh "Following bins missing for DataFactory Job $out_df" "DataFactory_Job" "$stamp" "N/A" "$base"
  fi

out_df=''

