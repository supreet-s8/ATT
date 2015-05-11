#!/bin/bash
# -----------------------------------------------------------------------------------------------------
ENVF="/data/scripts/monitor/etc/env.cfg"
if [[ -s $ENVF ]]; then
  source $ENVF 2>/dev/null
  if [[ $? -ne '0' ]]; then echo "Unable to load the environment file. Committing Exit!!!"; exit 127; fi
else
  echo "Unable to locate the environment file: $ENVF"; exit 127
fi
mount -o remount,rw / 2>/dev/null
# -----------------------------------------------------------------------------------------------------

function identifyClients {
PREFIX=''; PREFIX=`/opt/tps/bin/pmx.py show hadoop | egrep "client" | awk '{print $NF}' | awk -F. '{print $1"."$2"."$3"."}' | sort -u`
CLIENTS=''; CLIENTS=`/opt/tps/bin/pmx.py show hadoop | egrep "client" | awk '{print $NF}' | awk -F. '{print $4}' | sort -ru`

if [[ $CLIENTS ]]; then
col=''
for i in $CLIENTS; do
   if [[ $col ]]; then
   col="$i $col"
   else
   col="${i}"
   fi
done

# Check cluster enabled or not #
enabled=''; enabled=`/opt/tms/bin/cli -t 'en' 'conf t' 'show cluster configured' | grep 'Cluster enabled' | awk -F ':' '{print $NF}' | sed 's/ //g'`

if [[ "${enabled}" == 'yes' ]]; then  
   col11=''; col11=`/opt/tms/bin/cli -t 'en' 'conf t' 'show cluster global brief' | grep ^[0-9] | grep master | awk -F "." '{print $NF}' | sed 's/ //g'`
   col12=''; col12=`/opt/tms/bin/cli -t 'en' 'conf t' 'show cluster global brief' | grep ^[0-9] | grep standby | awk -F "." '{print $NF}' | sed 's/ //g'`
   cnp=''; col1=''; 

   if [[ $col11 && $col12 ]]; then 
      cnp="$col11 $col12"; col1="$col11 $col12"; 
      for i in $col; do
         if [[ "${i}" == "${col11}" || "${i}" == "${col12}" ]]; then continue; fi
         if [[ $col2 ]]; then
            col2="$col2 $i"
            else
            col2="${i}"
         fi
      done
   else 
      cnp=''; col1='';
      cnp="$col"; col1="$col";
   fi

else
   cnp=''; col1='';
   cnp="$col"; col1="$col"; 
fi

>${IP}
echo "prefix=\"$PREFIX\"" >> ${IP}
echo "col=\"$col\"" >> ${IP}
echo "cnp=\"$cnp\"" >> ${IP}
echo "col1=\"$col1\"" >> ${IP}
if [[ $col2 ]]; then
echo "col2=\"$col2\"" >> ${IP}
fi
fi
}

function identifyComputes {
SLAVES=''
SLAVES=`/opt/tps/bin/pmx.py show hadoop | egrep "slave" | awk '{print $NF}' | awk -F. '{print $4}' | sort -ru 2>/dev/null`
if [[ $SLAVES ]]; then
map=''
for i in $SLAVES; do
   if [[ $map ]]; then
   map="$i $map"
   else
   map="${i}"
   fi
done
#echo "map=\"$map\"" >> ${IP}
echo "cmp=\"$map\"" >> ${IP}
fi
}


function identifyVIPs {

# Check cluster enabled or not #
enabled=''; enabled=`/opt/tms/bin/cli -t 'en' 'conf t' 'show cluster configured' | grep 'Cluster enabled' | awk -F ':' '{print $NF}' | sed 's/ //g'`

if [[ "${enabled}" == 'yes' ]]; then
   cnp0vip='';cnp0vip=`/opt/tms/bin/cli -t 'en' 'conf t' 'show cluster configured' | grep "master virtual IP address" | awk '{print $NF}' | awk -F/ '{print $1}' 2>/dev/null`
   cnp0='';cnp0=`echo $cnp0vip | awk -F. '{print $4}'`
else
   cnp0vip=''
   cnp0vip=`/opt/tps/bin/pmx.py show hadoop | grep oozieServer | awk '{print $NF}' | sed 's/ //g'`
   if [[ ! $cnp0vip ]]; then
   count=0
   for i in $col; do
	cnp0vip="${PREFIX}${i}"
	cnp0="${i}"
        count=`expr $count + 1`
	if [[ $count -eq '1' ]]; then break; fi
   done
   else 
        cnp0=`echo $cnp0vip | awk -F. '{print $4}'`
   fi
fi

if [[ $cnp0vip ]]; then echo "cnp0vip=\"${cnp0vip}\"" >> ${IP}; fi
if [[ $cnp0 ]]; then echo "cnp0=\"$cnp0\"" >> ${IP}; fi
}

function identifyBkpDir {
COLBKPDIR='';COLBKPDIR=`${CLI} "show run full" | grep collector | grep backup-directory | awk '{print $NF}'`
if [[ $COLBKPDIR ]]; then echo "COLBKPDIR=\"${COLBKPDIR}\"" >> ${IP}; else echo "COLBKPDIR=\"/data/collector/edrAsn_backup\"" >> ${IP}; fi
}

function identifySiteName {
SITENAME="";SITENAME=`/opt/tms/bin/cli -t 'en' 'conf t' 'show run full' | grep "collector" | grep "output-directory" | head -1 | awk -F "/" '{print $NF}' | awk -F "." '{print $1}' 2>/dev/null`
if [[ $SITENAME ]]; then echo "SITENAME=\"${SITENAME}\"" >> ${IP}; else echo "SITENAME=\'\'" >> ${IP}; fi
}

function identifyAdaptors {
ADAPTORS='';LIST='';LIST=`/opt/tms/bin/cli -t 'en' 'internal query iterate subtree /nr/collector/instance/1/adaptor' | awk -F/ '{print $7}' | awk '{print $1}' | sort -u`

for i in ${LIST}; do
   if [[ $ADAPTORS ]]; then
   ADAPTORS="$i $ADAPTORS"
   else
   ADAPTORS="${i}"
   fi
done
if [[ $ADAPTORS ]]; then echo "ADAPTORS=\"${ADAPTORS}\"" >> ${IP}; else echo "ADAPTORS=\"edrAsn\"" >> ${IP}; fi

}

#-------------------------#
identifyClients
identifyComputes
identifyVIPs
identifyBkpDir
identifyAdaptors
identifySiteName
#-------------------------#
