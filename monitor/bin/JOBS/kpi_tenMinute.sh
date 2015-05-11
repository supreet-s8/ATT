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
kpiDir='';kpiDir="${KPIS}/`date +%Y/%m/%d`"; kpiFile="`basename $0 | awk -F "." '{print $1}'`"
logFile='';logFile="${LOGS}/$kpiFile-`date +%Y%m%d.log`"
if [[ ! -e ${LOGS} ]]; then /bin/mkdir -p ${LOGS} 2>/dev/null; fi
if [[ ! -e ${kpiDir} ]]; then /bin/mkdir -p ${kpiDir} 2>/dev/null; fi
#-------------------------------------------------------------------------------------------------

for kpi in `echo ${!kpiFile} | sed s'/,/ /g'`; do
   /bin/bash ${KPIBINARY}/kpi_$kpi.sh >> ${kpiDir}/${kpiFile}
   if [[ $? -eq '0' ]]; then
      echo "[`date +"%Y-%m-%d %H:%M:%S"`] : ${KPIBINARY}/kpi_$kpi : SUCCESS" >> ${logFile}
   else
      echo "[`date +"%Y-%m-%d %H:%M:%S"`] : ${KPIBINARY}/kpi_$kpi : FAILED"  >> ${logFile}
   fi
done

