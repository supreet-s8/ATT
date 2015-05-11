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
if [[ ! $threshold ]]; then threshold=85; fi
#-------------------------------------------------------------------------------------------------

#-----
stamp=`date +%s`
#-----
# HDFS Util
  val='';val=`${HADOOP} dfsadmin -report 2>/dev/null | head -12 | grep "DFS Used%" | awk -F": " '{print $NF}' | sed 's/%//g'`
  if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
   if [[ $val ]]; then
    echo "$stamp,hdfsUtil,hdfsUsed,percent,$val" 
    #alert $val "HDFS" $stamp
    if [ `echo "${val} >= ${threshold}" | bc` -eq '1' ]; then
	. ${BIN}/email.sh "$val" "HDFS" "$stamp" "$threshold" "$base"
    fi
   else
    echo "$stamp,hdfsUtil,hdfsUsed,percent,N/A" 
   fi
  else 
   echo "$stamp,hdfsUtil,hdfsUsed,percent,N/A"
  fi


