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
# CPU Profile

for host in $col $cmp; do

  #-----
  hostn='';hostn=`/bin/grep -w "$prefix$host" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $prefix$host "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$prefix$host"; fi
  #-----
  
  val=`$SSH $prefix$host "/usr/bin/mpstat 1 1" | tail -1`
  usr=`echo $val | awk '{print $3}'` 
  if [[ ! $usr ]]; then usr="N/A"; fi
  nice=`echo $val| awk '{print $4}'`
  if [[ ! $nice ]]; then nice="N/A" ;fi
  sys=`echo $val | awk '{print $5}'`
  if [[ ! $sys ]]; then sys="N/A" ;fi
  iowait=`echo $val | awk '{print $6}'`
  if [[ ! $iowait ]]; then iowait="N/A" ;fi  
  irq=`echo $val | awk '{print $7}'`
  if [[ ! $irq ]]; then irq="N/A" ;fi
  soft=`echo $val | awk '{print $8}'`
  if [[ ! $soft ]]; then soft="N/A" ;fi
  steal=`echo $val | awk '{print $9}'`
  if [[ ! $steal ]]; then steal="N/A" ;fi
  guest=`echo $val | awk '{print $10}'`
  if [[ ! $guest ]]; then guest="N/A" ;fi
  idle=`echo $val | awk '{print $11}'`
  if [[ ! $idle ]]; then idle="N/A" ;fi

  echo "$stamp,CPU_Profile_$hostn,usr,percent,$usr"
  echo "$stamp,CPU_Profile_$hostn,nice,percent,$nice"
  echo "$stamp,CPU_Profile_$hostn,sys,percent,$sys"
  echo "$stamp,CPU_Profile_$hostn,iowait,percent,$iowait"
  echo "$stamp,CPU_Profile_$hostn,irq,percent,$irq"
  echo "$stamp,CPU_Profile_$hostn,soft,percent,$soft"
  echo "$stamp,CPU_Profile_$hostn,steal,percent,$stael"
  echo "$stamp,CPU_Profile_$hostn,guest,percent,$guest"
  echo "$stamp,CPU_Profile_$hostn,idle,percent,$idle"


done 2>/dev/null

#####
