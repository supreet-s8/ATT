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
if [[ ! $threshold ]]; then threshold=0; fi
#-------------------------------------------------------------------------------------------------

# -----------------
# APPLICATION Stats
# -----------------
tstamp=`date -d "\`date -d "$LATENCY hours ago" +"%Y-%m-%d %H:00:00"\`" +%s `
stamp=''
H=`date -d "${LATENCY} hours ago" +"%Y/%m/%d %H"`
# -----------------


for ADAPTOR in $ADAPTORS; do

# --------- Collector Stats Dropped Flow, hourly.

  collectorStatsDroppedFlow='';collectorStatsDroppedFlow=`$SSH $cnp0vip "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR dropped-flow interval-type 1-hour interval-count 24' 2>/dev/null | /bin/grep \"$H\" " | awk '{print $2" "$3" "$NF}'`
  #ds1='';ds1=`echo "$collectorStatsDroppedFlow" | awk '{print $1" "$2}'`
  ds1='';ds1=`echo "$collectorStatsDroppedFlow" | awk -F ':' '{print $1":"$2}'`
  if [[ $ds1 ]]; then
    stamp=`date -d "$ds1" +%s 2>/dev/null`
  fi
  if [[ ! $stamp ]]; then stamp=$tstamp; fi

  #stamp=`date -d "\`echo "$collectorStatsDroppedFlow" | awk '{print $1" "$2}'\`" +%s`
  collectorStatsDroppedFlow=`echo "$collectorStatsDroppedFlow" | awk '{print $NF}'`

  if [[ $collectorStatsDroppedFlow ]]; then
    echo "$stamp,collector,adaptorDroppedFlow_${ADAPTOR},count,$collectorStatsDroppedFlow"
  else
    echo "$stamp,collector,adaptorDroppedFlow_${ADAPTOR},count,0"
  fi

# --------- Collector Stats Total Flow, hourly.

  collectorStatsTotalFlow='';collectorStatsTotalFlow=`$SSH $cnp0vip "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR total-flow interval-type 1-hour interval-count 24' 2>/dev/null | /bin/grep \"$H\" " | awk '{print $2" "$3" "$NF}'`

  #ds2='';ds2=`echo "$collectorStatsTotalFlow" | awk '{print $1" "$2}'`
  ds2='';ds2=`echo "$collectorStatsTotalFlow" | awk -F ':' '{print $1":"$2}'`
  if [[ $ds2 ]]; then 
    stamp=`date -d "$ds2" +%s 2>/dev/null`
  fi
  if [[ ! $stamp ]]; then stamp=$tstamp; fi

  collectorStatsTotalFlow=`echo "$collectorStatsTotalFlow" | awk '{print $NF}'`
  if [[ $collectorStatsTotalFlow ]]; then
    echo "$stamp,collector,adaptorTotalFlow_${ADAPTOR},count,$collectorStatsTotalFlow"
    #alert $collectorStatsTotalFlow "TOTAL_FLOW_ADAPTOR_${ADAPTOR}" $stamp
  else
    echo "$stamp,collector,adaptorTotalFlow_${ADAPTOR},count,0"
    #alert '0' "TOTAL_FLOW_ADAPTOR_${ADAPTOR}" $stamp
  fi

# ----------- Collector Stats Dropped Flow Percentage, hourly.

collectorStatsDroppedFlowPercent='0'
if [[ $collectorStatsDroppedFlow && $collectorStatsTotalFlow -ne '0' ]]; then
   collectorStatsDroppedFlowPercent=`echo "scale=2;($collectorStatsDroppedFlow/$collectorStatsTotalFlow)*100"|bc 2>/dev/null`
    echo "$stamp,collector,adaptorDroppedFlow_${ADAPTOR},percent,$collectorStatsDroppedFlowPercent"

  # Alert check. Commented and introducing alert on the 24 hour average KPI.
    #if [ `echo "${collectorStatsDroppedFlowPercent} >= ${threshold}" | bc 2>/dev/null` -eq '1' ]; then
    #  . ${BIN}/email.sh "$collectorStatsDroppedFlowPercent" "PERCENT_DROPPED_FLOW_ADAPTOR_${ADAPTOR}" "$stamp" "$threshold" "$base"
    #fi
else
    collectorStatsDroppedFlowPercent='N/A'
    echo "$stamp,collector,adaptorDroppedFlow_${ADAPTOR},percent,$collectorStatsDroppedFlowPercent"
    #alert '0' "PERCENT_DROPPED_FLOW_ADAPTOR_${ADAPTOR}" $stamp
fi

done

# ----------------------------------------------------------------------------------------

