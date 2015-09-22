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
if [[ ! $threshold ]]; then threshold=40; fi

# -----------------
# APPLICATION Stats
# -----------------
stamp=`date -d "\`date -d "$LATENCY hours ago" +"%Y-%m-%d %H:00:00"\`" +%s `
TZDATE=`TZ=$TIMEZ date -d "\`date -d "$LATENCY hours ago"\`" +%Y%m%d%H`
H=`date -d "${LATENCY} hours ago" +%Y%m%d%H`
H2=`date -d "${LATENCY} hours ago" +%Y/%m/%d/%H`
# -----------------

# --------- Incoming raw record file size for an hour

incomingRawFileSize='0';incomingSize=''
for colIp in $col1; do
  incomingSize=`$SSH $prefix$colIp "/bin/find $COLBKPDIR -mmin -300 -type f -name TrafficEventLog*${TZDATE}*.gz 2>/dev/null | xargs stat -c %s 2>/dev/null" | awk 'BEGIN { SUM=0 } { SUM += $1 } END { print SUM }'`
  incomingRawFileSize=`echo "$incomingRawFileSize + $incomingSize" | bc 2>/dev/null`
done

  if [[ $incomingRawFileSize ]]; then
    echo "$stamp,hdfs,incomingFileSize,bytes,$incomingRawFileSize"
  else
    echo "$stamp,hdfs,incomingFileSize,bytes,0"
  fi

# --------- Outgoing compressed record file size for an hour

  aggregate='';aggregate=`${HADOOP} dfs -dus ${OUTCOMPRESSEDFILES_HDFS}/$H2/*/*aggregate_data* 2>/dev/null | awk 'BEGIN {SUM=0} {SUM+=$NF} END {print SUM}'`
  if [[ ${PIPESTATUS[0]} -ne '0' ]]; then aggregate="N/A"; fi

  msisdn='';msisdn=`${HADOOP} dfs -dus ${OUTCOMPRESSEDFILES_HDFS}/$H2/*/*msisdn_data* 2>/dev/null | awk 'BEGIN {SUM=0} {SUM+=$NF} END {print SUM}'`
  if [[ ${PIPESTATUS[0]} -ne '0' ]]; then msisdn="N/A"; fi

  domain='';domain=`${HADOOP} dfs -dus ${OUTCOMPRESSEDFILES_HDFS}/$H2/*/*domain_data* 2>/dev/null | awk 'BEGIN {SUM=0} {SUM+=$NF} END {print SUM}'`
  if [[ ${PIPESTATUS[0]} -ne '0' ]]; then domain="N/A"; fi

  processedFileSizeTotal='';processedFileSizeTotal=`expr $aggregate + $domain + $msisdn`

  printf "%s,hdfs,processedFileSize_Primary,bytes,%s\n%s,hdfs,processedFileSize_Domain,bytes,%s\n%s,hdfs,processedFileSize_MSISDN,bytes,%s\n%s,hdfs,processedFileSize_Total,bytes,%d\n" $stamp $aggregate $stamp $domain $stamp $msisdn $stamp $processedFileSizeTotal;

# --------- Total number of MAPR output records for 3 pipes.

 pri='0';dom='0';msi='0';mapRTot='0'
 for pipeline in `${HADOOP} dfs -text ${OUTCOMPRESSEDFILES_HDFS}/${H2}/*/mr_stats_df_kpi_output_records* 2>/dev/null`; do
   pipe='';pipe=`echo $pipeline | awk -F ":" '{print $2}'`
   count='';count=`echo $pipeline | awk -F ":" '{print $3}'`

   case "$pipe" in 
	"primaryPipeline")
		pri=`expr $pri + $count`;;
	"domainSecondaryPipeline")
		dom=`expr $dom + $count`;;
	"msisdnSecondaryPipeline")
		msi=`expr $msi + $count`;;
   esac

 done
      mapRTot=`expr $pri + $dom + $msi`
      echo "$stamp,hdfs,processedMapRecords_Primary,count,$pri"
      echo "$stamp,hdfs,processedMapRecords_Domain,count,$dom"
      echo "$stamp,hdfs,processedMapRecords_MSISDN,count,$msi"
      echo "$stamp,hdfs,processedMapRecords_Total,count,$mapRTot"

# --------- Ratio of Incoming Raw File Size Vs Total Outgoing Cube Size of all 3 pipelines.

      ratioAll='0';ratioPrimary='0'
      if [[ ${processedFileSizeTotal} -eq '0' ]]; then
	echo "$stamp,hdfs,compression_Total,ratio,N/A"
      else 
        ratioAll=$(awk "BEGIN {printf \"%.2f\",(${incomingRawFileSize}/${processedFileSizeTotal})}")
	echo "$stamp,hdfs,compression_Total,ratio,$ratioAll"
	#alert $ratioAll "RawFileSize Vs CompressedOutgoingFileSize" $stamp
        # Commenting alert based on compression ratio since included this in estimated compression ratio.
  	#if [[ `echo "${ratioAll} < ${threshold}" | bc` -eq '1' ]]; then
	#	. ${BIN}/email.sh "${ratioAll}" "RawFileSize Vs CompressedOutgoingFileSize" "$stamp" "$threshold" "$base"
	#fi
      fi

      if [[ ${aggregate} -eq '0' ]]; then      
	echo "$stamp,hdfs,compression_Primary,ratio,N/A"
      else
        ratioPrimary=$(awk "BEGIN {printf \"%.2f\",(${incomingRawFileSize}/${aggregate})}")
	echo "$stamp,hdfs,compression_Primary,ratio,$ratioPrimary"
      fi

# ----------------------------------------------------------------------------------------
# Compression ratio based on estimated raw file size from processed collector output.
      incomingRawFileSize='0'
      H1=`date -d "${LATENCY} hours ago" +%Y/%m/%d/%H`
      val=`$HADOOP dfs -dus /data/collector/output/{1,2}/edrAsn/$H1/*/* 2>/dev/null | grep -v DONE | awk 'BEGIN {sum = 0} { sum+= $NF } END { print sum }'`
      incomingRawFileSize=`echo "scale=2;($val)*$FACTOR" | bc 2>/dev/null`

      if [[ ${processedFileSizeTotal} -eq '0' ]]; then
        echo "$stamp,hdfs,estimated_compression_Total,ratio,N/A"
      else
        ratioAll=$(awk "BEGIN {printf \"%.2f\",(${incomingRawFileSize}/${processedFileSizeTotal})}")
        echo "$stamp,hdfs,estimated_compression_Total,ratio,$ratioAll"
	if [[ `echo "${ratioAll} != 0" | bc` -eq '1' ]]; then
        if [[ `echo "${ratioAll} < ${threshold}" | bc` -eq '1' ]]; then
                . ${BIN}/email.sh "${ratioAll}" "EstimatedRawFileSize Vs CompressedOutgoingFileSize" "$stamp" "$threshold" "$base"
        fi
	fi
      fi

      if [[ ${aggregate} -eq '0' ]]; then
        echo "$stamp,hdfs,estimated_compression_Primary,ratio,N/A"
      else
        ratioPrimary=$(awk "BEGIN {printf \"%.2f\",(${incomingRawFileSize}/${aggregate})}")
        echo "$stamp,hdfs,estimated_compression_Primary,ratio,$ratioPrimary"
      fi
# ----------------------------------------------------------------------------------------
