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
}
thresh
#-------------------------------------------------------------------------------------------------
# Service Alert
#-------------------------------------------------------------------------------------------------
stamp=`date +%s`
#-------------------------------------------------------------------------------------------------

for colIp in $col; do
collectorServiceStatus='N/A';
collectorServiceStatus=`$SSH $prefix$colIp "/opt/tms/bin/cli -t 'en' 'show pm process collector' " | grep "Current status" | awk -F ":" '{print $NF}' | sed 's/ //g'`
if [[ ${PIPESTATUS[0]} -ne '0' ]]; then collectorServiceStatus="N/A"; fi

  if [[ "${collectorServiceStatus}" != 'running' ]]; then
    #alert $collectorServiceStatus MASTER_COLLECTOR $stamp
    . ${BIN}/email.sh "$collectorServiceStatus" "COLLECTOR_$prefix$colIp" "$stamp" "running" "$base"
  fi
done
# ----------------------------------------------------------------------------------------

