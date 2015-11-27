#!/bin/bash

TOOL="att-monitoring-v12.tgz"
BASEPATH='/tmp/install-monitor'
SRCFILE="${BASEPATH}/${TOOL}"
INSTALLPATH="/data/scripts"
DEST='/tmp'
SSH='/usr/bin/ssh -q -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  -l root '
ENVF="$INSTALLPATH/monitor/etc/env.cfg"
SOURCE=''


function identifyNN {
	echo "-----Calibrating Namenode IPs"
	MASTER=''; MASTER=`/opt/tms/bin/cli -t "en" "conf t" "show cluster master" | grep "Node internal address" | awk -F ":" '{print $2}' | awk -F "," '{print $1}' | sed 's/ //g'`
	
	STANDBY=''; STANDBY=`/opt/tms/bin/cli -t "en" "conf t" "show cluster standby" | grep "Node internal address" | awk -F ":" '{print $2}' | awk -F "," '{print $1}' | sed 's/ //g'`
	NN=''
	if [[ ! $MASTER && ! $STANDBY ]]; then 
		NN=`/opt/tps/bin/pmx.py show hadoop | grep -i client | awk '{print $NF}'`
	else 
		NN="$MASTER $STANDBY"
	fi
}

function identifySiteName {
# edit the env.cfg to update this variable.
#DCNAME=
	echo "-----Calibrating Site Code"
	DC='';DC=`/opt/tms/bin/cli -t "en" "conf t" "show run full" | grep "output-directory" | grep collector | awk -F/ '{print $NF}' | awk -F. '{print $1}'`

}

function iNstall {
	echo "-----Installing AT&T Monitoring Framework"
	for host in ${NN}; do
	   ${SSH} $host '/bin/mount -o remount,rw /'
        if [[ `${SSH} $host "/bin/ls ${INSTALLPATH}/monitor/bin/KPI/kpi-* 2>/dev/null"` ]]; then 
	   ${SSH} $host "/bin/rm -rf ${INSTALLPATH}/monitor/bin/KPI/kpi-* 2>/dev/null" 
  	fi
	   ${SSH} $host "/bin/mkdir -p ${INSTALLPATH}"
	   /usr/bin/scp -q ${SRCFILE} root@${host}:${DEST}
	   ${SSH} $host "/bin/tar zxvf ${DEST}/${TOOL} -C ${INSTALLPATH}" 1>/dev/null
	   ${SSH} $host "/bin/chmod -R 755 ${INSTALLPATH}/*"
	done

}

function askTimezone {
#TIMEZ=
#Alaska=AKDT, Aleutian=HADT, Arizona=MST, Central=CDT, East-Indiana=EDT, Eastern=EDT, Hawaii=HST, Indiana-Starke=CDT, Michigan=EDT, Mountain=MDT, Pacific=PDT, Pacific-New=PDT, Samoa=SST

while [[ ${SOURCE} != [0-9] && ${SOURCE} -ne '10' ]]; do
clear
read -p "Select TimeZone of the Raw Data Source

	SNo.   TimeZone
	---------------------
        1  --> Alaska/AKDT
        2  --> Aleutian/HADT
        3  --> Arizona/MST
        4  --> Central/Indiana-Starke/CDT/CST
        5  --> Eastern/East-Indiana/Michigan/EDT/EST
        6  --> Hawaii/HST
	7  --> Mountain/MDT
        8  --> Pacific/PDT/PST
        9  --> Samoa/SST
	10 --> UTC
        0  --> EXIT
	---------------------

Provide action serial number: " SOURCE
done
if [[ $SOURCE -eq '0' ]]; then echo -e "Committing clean exit!\n"; exit 127; fi
}

function supplySource {
case $SOURCE in
		1)
			SOURCE="US/Alaska";;
		2)
			SOURCE="US/Aleutian";;
		3)
			SOURCE="US/Arizona";;
		4)
			SOURCE="US/Central";;
		5)
			SOURCE="US/Eastern";;
		6)
			SOURCE="US/Hawaii";;
		7)
			SOURCE="US/Mountain";;
		8)
			SOURCE="US/Pacific";;
		9)
			SOURCE="US/Samoa";;
		10)
			SOURCE="UTC";;
esac
}

function createSite {
	echo "-----Creating Site Architecture Footprints"
	for host in ${NN}; do
                ${SSH} ${host} "/bin/bash ${INSTALLPATH}/monitor/bin/prepare-site.sh 2>/dev/null"
        done

}

function setEnvFile {
	echo "-----Setting Environment"
	for host in ${NN}; do
		${SSH} ${host} "/bin/sed -i 's/DCNAME=.*/DCNAME=\"${DC}\"/' ${ENVF} 2>/dev/null"
		${SSH} ${host} "/bin/sed -i 's;TIMEZ=.*;TIMEZ=${SOURCE};' ${ENVF} 2>/dev/null"
	done

}

function linkJobs {
	echo "-----Scheduling Jobs"
	for host in ${NN}; do
		${SSH} $host "/bin/rm -rf /etc/cron.d/att.cron 2&>1 >/dev/null"
	   	${SSH} $host "cd /etc/cron.d/ ; /bin/ln -s ${INSTALLPATH}/monitor/etc/att.cron ./att.cron"
		${SSH} $host "/opt/tms/bin/cli -t 'en' 'conf t' 'pm process crond restart'"
	done
}

# MAIN
clear
askTimezone
supplySource
identifyNN
identifySiteName
iNstall
setEnvFile
createSite
linkJobs
echo "-----Install Complete!"
