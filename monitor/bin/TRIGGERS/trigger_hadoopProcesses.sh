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
}
thresh

if [[ `am_i_master` -eq '0' ]]; then exit 0; fi
#-------------------------------------------------------------------------------------------------
# Service Alert
#-------------------------------------------------------------------------------------------------
stamp=`date +%s`
#-------------------------------------------------------------------------------------------------

# Hadoop Processes

# ----------------------------------------------------------------------------------------
#### NameNode 


ServiceStatus=''
pState=''
for host in $cnp0vip
do
	for process in datanode namenode secondarynamenode jobtracker
	do
		ServiceStatus=`$SSH $host "/bin/ps -ef" | grep "Dproc_${process}" | grep -v grep`
		if [ $? -ne 0 ]
		then
			pState="$pState $process"
		fi	
	done
        if [[ $pState ]]; then
	. ${BIN}/email.sh "Not_Running ($pState)" "NAMENODE_$host" "$stamp" "Running" "$base"
	fi
done

# ----------------------------------------------------------------------------------------

## Collector


ServiceStatus=''
pState=''

for host in $col
do
	for process in datanode namenode
	do
		ServiceStatus=`$SSH $prefix$host "/bin/ps -ef" | grep "Dproc_${process}" | grep -v grep`
                if [ $? -ne 0 ]
                then
			pState="$pState $process"
		fi
        done
	if [[ $pState ]]; then
	. ${BIN}/email.sh "Not_Running ($pState)" "COLLECTOR_$prefix$host" "$stamp" "Running" "$base"
	fi
done

# ----------------------------------------------------------------------------------------

## DataNode

ServiceStatus=''
for host in $cmp
do
	pState=''
        for process in datanode
        do
                ServiceStatus=`$SSH $prefix$host "/bin/ps -ef" | grep "Dproc_${process}" | grep -v grep`
                if [ $? -ne 0 ]
                then
			pState="$pState $process"
		fi
        done
	if [[ $pState ]]; then
	. ${BIN}/email.sh "Not_Running ($pState)" "DATANODE_$prefix$host" "$stamp" "Running" "$base"
	fi
done

# ----------------------------------------------------------------------------------------
