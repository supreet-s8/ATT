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

function alert {
  original=$1; node=$2; eventTimeE=$3;
  eventTime=`date -d @${eventTimeE} +"%F %T %Z"`
  dir="${ALERTS}/"`date +%Y`"/"`date +%m`"/"`date +%d`; file="att-daily-alerts-digest"
  notice='';notice="/tmp/$base-$stamp"
     if [[ ! -e ${dir} ]]; then /bin/mkdir -p $dir 2>/dev/null; fi
       printf "To: ${SENDTO}\nCc: ${SENDCC}\nSubject: ${DCNAME} : $base reached threshold for : $node\n\n\n" >> ${notice}
       echo "$eventTime : $base reached threshold for : $node : Values at : $original : Against : ${threshold}" >> ${dir}/${file}
       echo "$eventTime : $base reached threshold for : $node : Values at : $original : Against : ${threshold}" >> ${notice}
       echo "" >> ${notice}
       $NOTIFY < ${notice}
       /bin/rm -f ${notice}
}

#-------------------------------------------------------------------------------------------------
# Service Alert
#-------------------------------------------------------------------------------------------------
stamp=`date +%s`
#-------------------------------------------------------------------------------------------------

retryLog="/var/log/fileTransfer-`date -d '1 hour ago' +%Y%m%d`.log"

epT=`date -d "\`date -d '1 hour ago' +'%Y-%m-%d %H:00'\`" +%s`
retryingCount='0';successCount='0';droppedCount='0';
for STR in `$SSH $cnp0vip "/bin/cat ${retryLog} | sed 's/ //g' | awk -F "," '{if (\\$1>=$epT) print ;}'"`; do

	strType=`echo $STR | awk -F ":" '{print $2}' | sed 's/ //g'`
	
	case $strType in
	RETRY)
		count=`echo $STR | sed 's/ //g' | awk -F ":" '{print $NF}' | awk 'BEGIN{FS=","}; END{print NF}'`;
		retryingCount=`expr $retryingCount + $count`;;
		
	SUCCESS)
		count=`echo $STR | sed 's/ //g' | awk -F ":" '{print $NF}' | awk 'BEGIN{FS=","}; END{print NF}'`;
		successCount=`expr $successCount + $count`;;
	DROP)
		count=`echo $STR | sed 's/ //g' | awk -F ":" '{print $NF}' | awk 'BEGIN{FS=","}; END{print NF}'`;
                droppedCount=`expr $droppedCount + $count`;;

	esac

done 2>/dev/null 

echo "$stamp,fileTransfer,filesRetry,count,$retryingCount"
echo "$stamp,fileTransfer,filesDropped,count,$droppedCount" 
echo "$stamp,fileTransfer,filesSuccess,count,$successCount"

#    alert $droppedCount "filesDropped" $stamp

# ----------------------------------------------------------------------------------------

