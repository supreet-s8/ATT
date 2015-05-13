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
 
stamp=`date +%s`

# Memory Util
for host in $col $cmp; do
  total='';used='';free=''
# ---------
  hostn='';hostn=`/bin/grep -w "$prefix$host" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $prefix$host "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$prefix$host"; fi
# ---------

  val1=''; val1=`$SSH $prefix$host "/usr/bin/free -m | grep ^[a-zA-Z] | head -1" | awk '{print $2";"$3";"$4}'` #awk '{printf ("%s,%s,memUtilPercent,%0.2f\n", '$stamp', '${hostn}', ($3/$2) * 100)}'
     total=`echo $val1 | ${AWK} -F ";" '{print $1}'`
     used=`echo $val1 | ${AWK} -F ";" '{print $2}'`
  if [[ $used ]]; then 
     val=$(awk "BEGIN {printf \"%.2f\",(${used}/${total})*100}")
     echo "$stamp,memUsed,$hostn,percent,$val";
     #alert $val $hostn $stamp
     if [ `echo "${val} >= ${threshold}" | bc` -eq '1' ]; then
 	. ${BIN}/email.sh "${val}" "$hostn" "$stamp" "${threshold}" "$base"
     fi
  else 
     echo "$stamp,memUsed,$hostn,percent,N/A";
  fi
done 2>/dev/null

#####
