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
   threshold=''; threshold=`/bin/grep -w ^$base $THRESHOLDS | sed 's/ //g' | awk -F= '{print $NF}'`
}
thresh
if [[ ! $threshold ]]; then threshold=90; fi
#-------------------------------------------------------------------------------------------------

#-----
stamp=`date +%s`
#-----
# Disk Monitoring
for host in $col $cmp; do

  #-----
  hostn='';hostn=`/bin/grep -w "$prefix$host" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $prefix$host "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$prefix$host"; fi
  #-----
  val='';
  for value in `$SSH $prefix$host "/bin/df -P | tail -n+3 | tr -s ' ' | sed 's/%//g'" | awk '{print $6";"$5}'`; do
     disk='';disk=`echo $value | awk -F ";" '{print $1}'`
     val=`echo $value | awk -F ";" '{print $2}'`	
    if [[ $val && $disk ]]; then
     echo "$stamp,diskUsed-$disk,$hostn,percent,$val" 
     #alert $value $hostn $stamp
     original_val=`echo $value | awk -F ";" '{print $2}'`     
     if [ `echo "${original_val} >= ${threshold}" | bc` -eq '1' ]; then
	. ${BIN}/email.sh "$value" "$hostn" "$stamp" "$threshold" "$base"
     fi
    else
     echo "$stamp,diskUsed-N/A,$hostn,percent,N/A"
    fi
  done 2>/dev/null
  if [[ ! $val ]] ; then
    echo "$stamp,diskUsed-N/A,$hostn,percent,N/A"
  fi
done 2>/dev/null

#####
