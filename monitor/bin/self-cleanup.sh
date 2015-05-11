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

function retention {
   KPIRET=''; KPIRET=`/bin/grep -w ^KPIRETENTION $THRESHOLDS | sed 's/ //g' | awk -F= '{print $NF}'`
   ALERTRET=''; ALERTRET=`/bin/grep -w ^ALERTRETENTION $THRESHOLDS | sed 's/ //g' | awk -F= '{print $NF}'`
   LOGRET=''; LOGRET=`/bin/grep -w ^ALERTRETENTION $THRESHOLDS | sed 's/ //g' | awk -F= '{print $NF}'`
   if [[ ! KPIRET ]]; then KPIRET='7'; fi
   if [[ ! ALERTRET ]]; then ALERTRET='7'; fi 
}
#retention

#-------------------------------------------------------------------------------------------------

#-----
#stamp=`date +%s`
#-----

echo "[`date +"%Y-%m-%d %H:%M:%S"`] : Executing cleanup."
/bin/find $ALERTS -mindepth 2 -type d -mtime +${ALERTRETENTION} -exec rm -rf {} \; 2>/dev/null
if [[ $? -ne '0' ]]; then echo "[`date +"%Y-%m-%d %H:%M:%S"`] : Unable to clean the alerts!!!"; fi
/bin/find $KPIS -mindepth 2 -type d -mtime +${KPIRETENTION} -exec rm -rf {} \; 2>/dev/null
if [[ $? -ne '0' ]]; then echo "[`date +"%Y-%m-%d %H:%M:%S"`] : Unable to clean the KPIs!!!"; fi
/bin/find $LOGS -type f -mtime +${LOGRETENTION} -exec rm -rf {} \; 2>/dev/null
if [[ $? -ne '0' ]]; then echo "[`date +"%Y-%m-%d %H:%M:%S"`] : Unable to clean the logs!!!"; fi
echo "[`date +"%Y-%m-%d %H:%M:%S"`] : Cleanup completed...!"

exit 0

