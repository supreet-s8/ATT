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
stamp=`date +%s `
# -----------------


for ADAPTOR in $ADAPTORS; do

# --------- Collector Stats Dropped Flow, daily.

  collectorStatsDroppedFlow='';collectorStatsDroppedFlow=`$SSH $cnp0vip "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR dropped-flow interval-type 1-hour interval-count 24' 2>/dev/null" | tail -24 | awk 'BEGIN {SUM=0} {SUM+=$NF} END{print SUM}'`

  if [[ $collectorStatsDroppedFlow ]]; then
    echo "$stamp,collectorDaily,adaptorDroppedFlowDaily_${ADAPTOR},count,$collectorStatsDroppedFlow"
  else
    echo "$stamp,collectorDaily,adaptorDroppedFlowDaily_${ADAPTOR},count,0"
  fi

# --------- Collector Stats Total Flow, daily.

  collectorStatsTotalFlow='';collectorStatsTotalFlow=`$SSH $cnp0vip "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR total-flow interval-type 1-hour interval-count 24' 2>/dev/null" | tail -24 | awk 'BEGIN {SUM=0} {SUM+=$NF} END{print SUM}'`

  if [[ $collectorStatsTotalFlow ]]; then
    echo "$stamp,collectorDaily,adaptorTotalFlowDaily_${ADAPTOR},count,$collectorStatsTotalFlow"
  else
    echo "$stamp,collectorDaily,adaptorTotalFlowDaily_${ADAPTOR},count,0"
  fi

# ----------- Collector Stats Dropped Flow Percentage, daily.

collectorStatsDroppedFlowPercent='0'
if [[ $collectorStatsDroppedFlow && $collectorStatsTotalFlow -ne '0' ]]; then
   collectorStatsDroppedFlowPercent=`echo "scale=2;($collectorStatsDroppedFlow/$collectorStatsTotalFlow)*100"|bc 2>/dev/null`
    echo "$stamp,collectorDaily,adaptorDroppedFlowDaily_${ADAPTOR},percent,$collectorStatsDroppedFlowPercent"

  # Alert check.
    if [ `echo "${collectorStatsDroppedFlowPercent} >= ${threshold}" | bc 2>/dev/null` -eq '1' ]; then
      . ${BIN}/email.sh "$collectorStatsDroppedFlowPercent" "PERCENT_DROPPED_FLOW_ADAPTOR_DAILY_${ADAPTOR}" "$stamp" "$threshold" "$base"
    fi
else
    collectorStatsDroppedFlowPercent='N/A'
    echo "$stamp,collectorDaily,adaptorDroppedFlowDaily_${ADAPTOR},percent,$collectorStatsDroppedFlowPercent"
fi

done

# ----------------------------------------------------------------------------------------

