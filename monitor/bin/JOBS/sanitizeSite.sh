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
#-------------------------------------------------------------------------------------------------
kpiFile="`basename $0 | awk -F "." '{print $1}'`"
logFile='';logFile="${LOGS}/$kpiFile-`date +%Y%m%d.log`"
if [[ ! -e ${LOGS} ]]; then /bin/mkdir -p ${LOGS} 2>/dev/null; fi
#-------------------------------------------------------------------------------------------------

for sanScript in prepare-site.sh self-cleanup.sh; do
   /bin/bash ${BIN}/${sanScript} >> ${logFile}
   if [[ $? -eq '0' ]]; then
      echo "[`date +"%Y-%m-%d %H:%M:%S"`] : ${BIN}/${sanScript} : SUCCESS" >> ${logFile}
   else
      echo "[`date +"%Y-%m-%d %H:%M:%S"`] : ${BIN}/${sanScript} : FAILED"  >> ${logFile}
   fi
done

exit 0

