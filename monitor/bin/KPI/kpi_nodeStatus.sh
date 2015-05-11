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
if [[ ! $threshold ]]; then threshold="false"; fi
#-------------------------------------------------------------------------------------------------

#-----
stamp=`date +%s`
#-----
# Node reachability
for host in $col $cmp; do

  #-----
  hostn='';hostn=`/bin/grep -w "$prefix$host" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $prefix$host "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$prefix$host"; fi
  #-----

  value='';value=`$SSH $prefix$host "/bin/hostname"`
  if [[ $? -eq '0' ]]; then
    echo "$stamp,availability,$value,boolean,true" 
    if [[ "true" == "$threshold" ]]; then
       . ${BIN}/email.sh "true" "$hostn" "$stamp" "${threshold}" "$base"
    fi
  else
    echo "$stamp,availability,$hostn,boolean,false"
    #alert "false" $hostn $stamp
    if [[ "false" == "$threshold" ]]; then
      . ${BIN}/email.sh "false" "$hostn" "$stamp" "${threshold}" "$base"
    fi
  fi
done 2>/dev/null

#####
