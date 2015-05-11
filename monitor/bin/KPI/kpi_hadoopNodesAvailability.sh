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
if [[ ! $threshold ]]; then threshold=1; fi
#-------------------------------------------------------------------------------------------------

#-----
stamp=`date +%s`
#-----
# HDFS Util
  value='';value=`${HADOOP} dfsadmin -report 2>/dev/null | awk 'NR==11{ print; }' | awk '{print $4";"$3";"$6}' | sed 's/(//g'`
  if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
   if [[ $value ]]; then
    total='';available='';dead=''
    total=`echo $value | awk -F ";" '{print $1}'`;available=`echo $value | awk -F ";" '{print $2}'`;dead=`echo $value | awk -F ";" '{print $3}'`
    echo "$stamp,hdfsNodes,nodeStatus_Total,count,$total" 
    echo "$stamp,hdfsNodes,nodeStatus_Available,count,$available" 
    echo "$stamp,hdfsNodes,nodeStatus_Dead,count,$dead" 
    #alert $dead "HDFS" $stamp
    if [[ `echo "$dead >= $threshold" | bc` -eq '1' ]]; then
	. ${BIN}/email.sh "$dead" "HDFS" "$stamp" "$threshold" "$base"
    fi
   else
    echo "$stamp,hdfsNodes,nodeStatus_Total,count,N/A" 
    echo "$stamp,hdfsNodes,nodeStatus_Available,count,N/A" 
    echo "$stamp,hdfsNodes,nodeStatus_Dead,count,N/A" 
   fi
  else 
    echo "$stamp,hdfsNodes,nodeStatus_Total,count,N/A" 
    echo "$stamp,hdfsNodes,nodeStatus_Available,count,N/A" 
    echo "$stamp,hdfsNodes,nodeStatus_Dead,count,N/A" 
  fi

######
