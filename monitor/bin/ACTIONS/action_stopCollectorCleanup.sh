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
   threshold=''; threshold=`/bin/grep -w ^$base ${THRESHOLDS_ACTION} | sed 's/ //g' | awk -F= '{print $NF}' | awk -F: '{print $1}'`
   switch=''; switch=`/bin/grep -w ^$base ${THRESHOLDS_ACTION} | sed 's/ //g' | awk -F= '{print $NF}' | awk -F: '{print $2}'`
}
thresh
if [[ ! $threshold ]]; then threshold=90; fi; if [[ ! $switch ]]; then switch="off"; fi; if [[ $switch != "on" ]]; then exit; fi
#-------------------------------------------------------------------------------------------------
# Overriding SENDTO and SENDCC variables.
SENDTO="robert.phillips@guavus.com,samuel.joseph@guavus.com,shailendra.kumar@guavus.com,hannes.vanrooyen@guavus.com"
SENDCC="supreet.singh@guavus.com"
#-------------------------------------------------------------------------------------------------

Email='0'
stamp=`date +%s`
Date=`date`
msgFile='';msgFile="/tmp/$base-$stamp"
printf "To: ${SENDTO}\nCc: ${SENDCC}\nSubject: $DCNAME : $base.\n\n\n" >> ${msgFile}

sysUp='';sysUp=`$SSH $prefix$cnp0 "/bin/cat /proc/uptime" | awk -F '.' '{print $1}'`

if [[ $? -eq '0' && `echo "$sysUp <= $threshold" | bc` -eq '1' ]]; then

  Email='1'
  echo "System uptime found to be $sysUp, lesser than threshold of $threshold secs." >> ${msgFile}
  echo "ACTION_SUMMARY : $Date" >> ${msgFile}

  # Check for CleanupCollector job.
  running='0'
  if [[ `$SSH $prefix$cnp0 "/opt/tms/bin/pmx subshell oozie show coordinator RUNNING jobs 2>/dev/null | grep CleanupCollector"` ]]; then
     running='1'
  elif [[ `$SSH $prefix$cnp0 "/opt/tms/bin/pmx subshell oozie show coordinator PREP jobs 2>/dev/null | grep CleanupCollector"` ]]; then
     running='1'
  elif [[ `$SSH $prefix$cnp0 "/opt/tms/bin/pmx subshell oozie show workflow RUNNING jobs 2>/dev/null | grep CleanupCollector"` ]]; then
     running='1'
  else 
     echo "CleanupCollector job not found RUNNING/PREP in coordinator/workflow." >> ${msgFile}
  fi

  if [[ running -eq '1' ]]; then
     echo "CleanupCollector job found RUNNING. Initiating job termination..." >> ${msgFile}
     $SSH $prefix$cnp0 "/opt/tms/bin/pmx subshell oozie stop jobname CleanupCollector" 2>&1>/dev/null
     sleep 60
     stopped='0'
     if [[ `$SSH $prefix$cnp0 "/opt/tms/bin/pmx subshell oozie show coordinator RUNNING jobs 2>/dev/null | grep CleanupCollector"` ]]; then
        stopped='1'
     elif [[ `$SSH $prefix$cnp0 "/opt/tms/bin/pmx subshell oozie show coordinator PREP jobs 2>/dev/null | grep CleanupCollector"` ]]; then
        stopped='1'
     elif [[ `$SSH $prefix$cnp0 "/opt/tms/bin/pmx subshell oozie show workflow RUNNING jobs 2>/dev/null | grep CleanupCollector"` ]]; then
        stopped='1'
     else
        echo "CleanupCollector job not found RUNNING/PREP in coordinator/workflow." >> ${msgFile}
     fi

     if [[ $stopped -eq '0' ]]; then
        echo "STATUS : SUCCESS" >> ${msgFile}
     else
        echo "STATUS : FAILED" >> ${msgFile}  
        echo "Attention needed!"
     fi

  fi
fi

if [[ $Email -eq '1' ]]; then
   $NOTIFY < ${msgFile}
fi
/bin/rm -f ${msgFile} 2>/dev/null

# ----------------------------------------------------------------------------------------

