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
#H1="2015/03/25/17"
stamp1=`date -d "${LATENCY} hours ago" +%s`
for host in $cnp0vip
do
  #-----
  hostn='';hostn=`/bin/grep -w "$host" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $host "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$prefix$host"; fi
  #-----
 
 for adaptors in $ADAPTORS
 do  
  for i in `seq -w 00 05 55`
  do  
	stamp=`echo "$stamp1+($i*60)" | bc 2>/dev/null`
	val=`$SSH ${host} "$HADOOP dfs -dus /data/collector/output/${adaptors}/$H1/${i}/* 2>/dev/null | grep -v DONE" | awk 'BEGIN {sum = 0} { sum+= $NF } END { print sum }'` 
	comp_ratio=`echo "scale=2;($val)*$FACTOR" | bc 2>/dev/null`
    	echo "$stamp,estimated_input_data_volume,${hostn},bytes,$comp_ratio" 
  done
 done

done

#####
