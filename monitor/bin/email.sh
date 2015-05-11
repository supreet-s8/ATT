#!/bin/bash
#-------------------------------------------------------------------------------------------------
mount -o remount,rw / 2>/dev/null
#-------------------------------------------------------------------------------------------------

if [[ "${ALERTS_SWITCH}" == "on" ]]; then 
  if [[ $# -ne '5' ]]; then exit; fi
  original=$1; node=$2; eventTimeE=$3; threshold=$4; base=$5
  eventTime=`date -d @${eventTimeE} +"%F %T %Z"`
  dir="${ALERTS}/"`date +%Y`"/"`date +%m`"/"`date +%d`; file="att-daily-alerts-digest"
    notice='';notice="/tmp/$base-$eventTimeE"
     if [[ ! -e ${dir} ]]; then /bin/mkdir -p $dir 2>/dev/null; fi
       printf "To: ${SENDTO}\nCc: ${SENDCC}\nSubject: ${DCNAME} : $base reached threshold for : $node\n\n\n" >> ${notice}
       echo "$eventTime : $base reached threshold for : $node : Values at : $original : Against : ${threshold}" >> ${dir}/${file}
       echo "$eventTime : $base reached threshold for : $node : Values at : $original : Against : ${threshold}" >> ${notice}
       echo "" >> ${notice}
       $NOTIFY < ${notice}
       /bin/rm -f ${notice}
fi

