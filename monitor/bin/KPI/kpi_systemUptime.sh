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
if [[ ! $threshold ]]; then threshold=1200; fi

#-----
stamp=`date +%s`
#-----
# System Uptime
for host in $col $cmp; do

  #-----
  hostn='';hostn=`/bin/grep -w "$prefix$host" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $prefix$host "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$host"; fi
  #-----

  val='';val=`$SSH $prefix$host "/bin/cat /proc/uptime" | awk -F "." '{print $1}'`
  if [[ $val ]]; then
    echo "$stamp,systemUptime,$hostn,seconds,$val" 
    #alert $val $hostn $stamp
    if [[ `echo "${val} <= ${threshold}" | bc` -eq '1' ]]; then
       . ${BIN}/email.sh "${val}" "$hostn" "$stamp" "${threshold}" "$base"
    fi
  else
    echo "$stamp,systemUptime,$hostn,seconds,N/A"
  fi
done 2>/dev/null

#####
