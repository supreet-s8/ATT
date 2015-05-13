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
kpiFile="`basename $0 | awk -F "." '{print $1}'`"
logFile='';logFile="${LOGS}/$kpiFile-`date +%Y%m%d.log`"
if [[ ! -e ${LOGS} ]]; then /bin/mkdir -p ${LOGS} 2>/dev/null; fi
#-------------------------------------------------------------------------------------------------

function sendReport {
  size=$1; site=$2;
  dir="/tmp"; fileM="mail-$stamp-$size-hour"; fileA="report-$stamp-$size-hour"
  notice=''; notice="$dir/$fileM"; attach="$dir/$fileA"
  if [[ ! -e ${dir} ]]; then /bin/mkdir -p $dir 2>/dev/null; fi
     printf "To: ${SENDTO}\nCc: ${SENDCC}\nSubject: Site report for last $size hour(s) : $site\n\n\n" >> ${notice}
     /usr/bin/perl ${BIN}/$repScript --hours=$size > ${attach}
     /bin/cat ${attach} | /usr/bin/uuencode ${fileA}.xls >> ${notice} 2>/dev/null
     echo "" >> ${notice}
     $NOTIFY < ${notice}
     /bin/rm -f ${notice} ${attach}
  
}

#-----
stamp=`date +%s`
#-----
repScript="site-report"
if [[ ! ${REPORTSIZE} ]]; then REPORTSIZE=2; fi
if [[ ! ${SITENAME} ]]; then SITENAME='ATT-SITE'; fi
sendReport ${REPORTSIZE} ${SITENAME}
if [[ $? -eq '0' ]]; then
      echo "[`date +"%Y-%m-%d %H:%M:%S"`] : ${BIN}/${repScript} : SUCCESS" >> ${logFile}
else
      echo "[`date +"%Y-%m-%d %H:%M:%S"`] : ${BIN}/${repScript} : FAILED"  >> ${logFile}
fi

