#!/bin/bash
#-------------------------------------------------------------------------------------------------
# HOURLY Collector stats being collected as an average of last 24 hours.
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
if [[ ! $threshold ]]; then threshold=0; fi
#-------------------------------------------------------------------------------------------------

# -----------------
# APPLICATION Stats
# -----------------
stamp=`date +%s `
# -----------------


for ADAPTOR in $ADAPTORS; do

# --------- Collector Stats Dropped Flow, hourly.

  collectorStatsDroppedFlow='0'; flow=''
  for colIp in $col1; do
      flow=`$SSH $prefix$colIp "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR dropped-flow interval-type 1-hour interval-count 24' 2>/dev/null" | tail -24 | awk 'BEGIN {SUM=0} {SUM+=$NF} END{print SUM}'`
      collectorStatsDroppedFlow=`echo "$collectorStatsDroppedFlow + $flow" | bc 2>/dev/null`
  done 
      # Hourly calculation.
      collectorStatsDroppedFlow=`echo "$collectorStatsDroppedFlow / 24" | bc 2>/dev/null`
      #if [[ $collectorStatsDroppedFlow ]]; then
         echo "$stamp,collector,adaptorDroppedFlow_${ADAPTOR},count,$collectorStatsDroppedFlow"
      #else
      #   echo "$stamp,collector,adaptorDroppedFlow_${ADAPTOR},count,0"
      #fi

# --------- Collector Stats Total Flow, hourly.

  collectorStatsTotalFlow='0';totalFlow=''
  for colIp in $col1; do
     totalFlow=`$SSH $prefix$colIp "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR total-flow interval-type 1-hour interval-count 24' 2>/dev/null" | tail -24 | awk 'BEGIN {SUM=0} {SUM+=$NF} END{print SUM}'`
     collectorStatsTotalFlow=`echo "$collectorStatsTotalFlow + $totalFlow" | bc 2>/dev/null`
  done
  # Hourly calculation.
  collectorStatsTotalFlow=`echo "$collectorStatsTotalFlow / 24" | bc 2>/dev/null`
  #if [[ $collectorStatsTotalFlow ]]; then
    echo "$stamp,collector,adaptorTotalFlow_${ADAPTOR},count,$collectorStatsTotalFlow"
  #else
  #  echo "$stamp,collector,adaptorTotalFlow_${ADAPTOR},count,0"
  #fi

# ----------- Collector Stats Dropped Flow Percentage, hourly.

collectorStatsDroppedFlowPercent='0'
if [[ $collectorStatsDroppedFlow && $collectorStatsTotalFlow -ne '0' ]]; then
   collectorStatsDroppedFlowPercent=`echo "scale=2;($collectorStatsDroppedFlow/$collectorStatsTotalFlow)*100"|bc 2>/dev/null`
    echo "$stamp,collector,adaptorDroppedFlow_${ADAPTOR},percent,$collectorStatsDroppedFlowPercent"

  # Alert check.
    if [ `echo "${collectorStatsDroppedFlowPercent} >= ${threshold}" | bc 2>/dev/null` -eq '1' ]; then
      . ${BIN}/email.sh "$collectorStatsDroppedFlowPercent" "PERCENT_DROPPED_FLOW_ADAPTOR_DAILY_${ADAPTOR}" "$stamp" "$threshold" "$base"
    fi
else
    collectorStatsDroppedFlowPercent='N/A'
    echo "$stamp,collector,adaptorDroppedFlow_${ADAPTOR},percent,$collectorStatsDroppedFlowPercent"
fi

done

# ----------------------------------------------------------------------------------------

