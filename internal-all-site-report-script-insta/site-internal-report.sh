#!/bin/bash
#-------------------------------------------------------------------------------------------------
Akron='107.76.138.46'
Allen='107.246.18.220'
Arlington='107.246.77.76'
Bothell='107.76.163.60'
Broadway='107.246.110.58'
Chicago='107.76.105.58'
Concord='107.246.57.45'
Gainesville='107.76.42.220'
Houston='107.76.79.74'
VanNuys='107.76.20.58'
VTC2='107.76.236.234'
#--------------
stamp=`date +%s`
SITES="Akron Allen Arlington Bothell Broadway Chicago Concord Gainesville Houston VanNuys VTC2"
printf "Site_Name,Overall_HDFS_Used,Nodes_available,Nodes_down,/data/collector_Used,KFPS,Input_Files_Count,Collector_latest_DONE,Process_State,DF_JOB_Done,DF_JOB2_Done,CleanupCollector_Done\n"
for siteN in $SITES; do siteIp=${!siteN};
# HDFS Used:
hdfs='NA';hdfs=`/usr/bin/ssh -q root@${siteIp} "/opt/hadoop/bin/hadoop dfsadmin -report 2>/dev/null | head -8 | grep 'DFS Used%'" | awk '{print $NF}'`

# Number of Nodes available/Nodes down:
nodesA='NA';nodesA=`/usr/bin/ssh -q root@${siteIp} "/opt/hadoop/bin/hadoop dfsadmin -report 2>/dev/null | grep 'Datanodes available'" | awk '{print $3}'`
nodesD='NA';nodesD=`/usr/bin/ssh -q root@${siteIp} "/opt/hadoop/bin/hadoop dfsadmin -report 2>/dev/null | grep 'Datanodes available'" | awk '{print $6}'`

# /data/collector used size percent
sizeP='NA';sizeP=`/usr/bin/ssh -q root@${siteIp} "/bin/df -P | grep '/data/collector'" | awk '{print $(NF-1)}'`

#Current KFPS
totalF='';totalF=`/usr/bin/ssh -q root@${siteIp} "/opt/tms/bin/cli -t 'en' 'conf t' 'collector stats instance-id 1 adaptor-stats edrAsn total-flow interval-type 5-min' | grep ^1" | awk '{print $NF}'`
currentK='NA';currentK=`echo "($totalF / 300) / 1024" | bc`

# Number of files in feeds directory
fileC='NA'; fileC=`/usr/bin/ssh -q root@${siteIp} "/bin/ls /data/collector/edrAsn | wc -l"`

# _DONE time:
lastDone='NA';lastDone=`/usr/bin/ssh -q root@${siteIp} "/opt/hadoop/bin/hadoop fs -lsr /data/collector/output/edrAsn/  2>/dev/null | grep DONE | tail -1" | awk -F '/' '{print $6"/"$7"/"$8"/"$9"/"$10}'`

#Process running:
pState='NA'
pCount='';pCount=`/usr/bin/ssh -q root@${siteIp} "ps -ef | grep hadoop | grep -v grep | egrep -i 'node|jobTracker'" | awk '{print $2 , $9}' | grep -v jar | grep -v ^$ | sed s/-Dproc_//g | wc -l`
if [[ $pCount -ne '5' ]]; then
  for process in datanode namenode secondarynamenode jobtracker; do
  count='';count=`/usr/bin/ssh -q root@${siteIp} "ps -ef | grep hadoop | grep -v grep | egrep -i 'node|jobTracker'" | awk '{print $2 , $9}' | grep -v jar | grep -v ^$ | sed s/-Dproc_//g | wc -l`
  if [[ $process -eq "namenode" ]]; then
    expected=2
  else
    expected=1
  fi

  if [[ $count -ne "$expected" ]]; then
     pState="$pState $process"
  fi
  done
else
  pState='Running'
fi

#DF Jobs done.txt

doneDF='NA';doneDF=`/usr/bin/ssh -q root@${siteIp} "/opt/hadoop/bin/hadoop dfs -cat /data/DataFactoryJob/done.txt 2>/dev/null"`
doneDF2='NA';doneDF2=`/usr/bin/ssh -q root@${siteIp} "/opt/hadoop/bin/hadoop dfs -cat /data/DataFactoryJob2/done.txt 2>/dev/null"`
doneCC='NA';doneCC=`/usr/bin/ssh -q root@${siteIp} "/opt/hadoop/bin/hadoop dfs -cat /data/CleanupCollector/done.txt 2>/dev/null"`

printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" "$siteN" "$hdfs" "$nodesA" "$nodesD" "$sizeP" "$currentK" "$fileC" "$lastDone" "$pState" "$doneDF" "$doneDF2" "$doneCC"
done
