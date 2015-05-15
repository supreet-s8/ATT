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
# IO Profile
for host in $col $cmp; do

  #-----
  hostn='';hostn=`/bin/grep -w "$prefix$host" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $prefix$host "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$prefix$host"; fi
  #-----
  
  val=`$SSH $prefix$host "/usr/bin/iostat -x 1 1" | grep vdb`
  if [ $? -eq 0 ]
  then
  rrqm=`echo $val | awk '{print $2}'` 
  if [[ ! $rrqm ]]; then rrqm="N/A"; fi
  wrqm=`echo $val| awk '{print $3}'`
  if [[ ! $wrqm ]]; then wrqm="N/A" ;fi
  r=`echo $val | awk '{print $4}'`
  if [[ ! $r ]]; then r="N/A" ;fi
  w=`echo $val | awk '{print $5}'`
  if [[ ! $w ]]; then w="N/A" ;fi  
  rsec=`echo $val | awk '{print $6}'`
  if [[ ! $rsec ]]; then rsec="N/A" ;fi
  wsec=`echo $val | awk '{print $7}'`
  if [[ ! $wsec ]]; then wsec="N/A" ;fi
  avgrq=`echo $val | awk '{print $8}'`
  if [[ ! $avgrq ]]; then avgrq="N/A" ;fi
  avgqu=`echo $val | awk '{print $9}'`
  if [[ ! $avgqu ]]; then avgqu="N/A" ;fi
  await=`echo $val | awk '{print $10}'`
  if [[ ! $await ]]; then await="N/A" ;fi
  svctm=`echo $val | awk '{print $11}'`
  if [[ ! $svctm ]]; then svctm="N/A" ;fi
  util=`echo $val | awk '{print $12}'`
  if [[ ! $util ]]; then util="N/A" ;fi

  echo "$stamp,io_profile_vdb_$hostn,rrqm,seconds,$rrqm"
  echo "$stamp,io_profile_vdb_$hostn,wrqm,seconds,$wrqm"
  echo "$stamp,io_profile_vdb_$hostn,r,seconds,$r"
  echo "$stamp,io_profile_vdb_$hostn,w,seconds,$w"
  echo "$stamp,io_profile_vdb_$hostn,rsec,seconds,$rsec"
  echo "$stamp,io_profile_vdb_$hostn,wsec,seconds,$wsec"
  echo "$stamp,io_profile_vdb_$hostn,avgrq,seconds,$avgrq"
  echo "$stamp,io_profile_vdb_$hostn,avgqu,seconds,$avgqu"
  echo "$stamp,io_profile_vdb_$hostn,await,seconds,$await"
  echo "$stamp,io_profile_vdb_$hostn,svctm,seconds,$svctm"
  echo "$stamp,io_profile_vdb_$hostn,util,percent,$util"
fi
done 2>/dev/null

#####
