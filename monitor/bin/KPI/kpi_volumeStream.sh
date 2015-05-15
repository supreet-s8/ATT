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
if [[ ! $threshold ]]; then threshold=90; fi
if [[ `am_i_master` -eq '0' ]]; then exit 0; fi
#-------------------------------------------------------------------------------------------------

#-----
stamp=`date +%s`
#-----
# Volume Stream


for host in $col
do
  #-----
  hostn='';hostn=`/bin/grep -w "$prefix$host" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH "$prefix$host" "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$prefix$host"; fi
  #-----

        for feed in 1 2 3 4
        do
                val=`$SSH "$prefix$host" "cat /var/log/messages" | grep -i "MSP_RAW_${SITENAME}_${feed}"|grep -v grep | tail -1 | awk '{ print $NF }'`
	                processed=`echo $val|cut -d, -f1`
                if [[ ! $processed ]]; then processed="N/A"; fi
                skipped=`echo $val|cut -d, -f2`
                if [[ ! $skipped ]]; then skipped="N/A"; fi                
                echo "$stamp,msp_raw_stream_${hostn},processed_${feed},count,$processed"
                echo "$stamp,msp_raw_stream_${hostn},skipped_${feed},count,$skipped"        
	done
done

#####
