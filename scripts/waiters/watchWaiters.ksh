#!/bin/ksh
# monitor.waiters [ delay [ threshold [ onetimethreshold [ logfile ]]]]
#  Default Values: 30 2 0 /tmp/mmfs/monitor.waiters.log
# Every $delay seconds get GPFS waiters greater than $threshold from all nodes.
# If there are some, get all waiters from all nodes and append them to $logfile.
# If $onetimethreshold is greater than 0 and any of the waiters are larger,
# do the customizable commands below "Gather one time data here" to gather
# other system data.
# "touch $logdir/stop" to stop this script, where $logdir is the same directory as the $logfile.
 
# See if usage should be displayed
if [[ $1 == '-?' || $1 == '-h' || $1 == '--help' ]]; then
   echo "Usage: $0 [ delay [ threshold [ onetimethreshold [ logfile ]]]] "
   echo "    mode "
   exit
fi

delay=${1-30}
threshold=${2-2}
onetimethreshold=${3-0}
logfile=${4-"/tmp/mmfs/monitor.waiters.log"}

logdir=${logfile%/*}
[[ -z $logdir ]] && logdir=/tmp/mmfs
mkdir -p $logdir

PATH=$PATH:/usr/lpp/mmfs/bin:/usr/lpp/mmfs/samples/debugtools:/tmp/mmfs
export DSHPATH=$PATH

print "\nAppending waiter data to $logfile\nTo stop monitoring: touch $logdir/stop"
print "  Sample Interval: $delay seconds"
print "  Waiter threshold: $threshold seconds"
print "  Exit on Event $onetimethreshold"
# Redirect all output to the $logfile
exec 1>>$logfile 2>&1

# Remove old stop file and Loop until $logdir/stop file exists
triggered=0
rm -f $logdir/stop
while [[ ! -f $logdir/stop ]]; do
  print "$(date) =============================================================="

  # Get list of nodes that are in failure mode right now
  fail=$(mmfsadm dump cfgmgr | grep failed)
  [[ -n $fail ]] && mmfsadm dump cfgmgr | grep fail

  # Get waiters from all nodes that are longer than $threshold
  longwaiters="$(mmdsh -v -N all mmfsadm dump waiters $threshold 2>/dev/null)"
  if [[ -n $longwaiters ]]; then
    # If there was a threshold, go back and ask for all waiters
    [[ $threshold -ne 0 ]] && longwaiters="$(mmdsh -v -N all mmfsadm dump waiters 2>/dev/null)"
    # Print out the waiter list
    print "All waiters:\n$longwaiters"
    # If a trigger threshold was set see if any waiters meet the criteria
    if [[ $onetimethreshold != 0 && $triggered = 0 ]]; then
      print "$longwaiters" |
      while read node thread waiting seconds rest; do
        secs=${seconds%.*}
        if [[ $waiting = waiting && $secs -ge $onetimethreshold ]]; then
          print "Waiter for $seconds is greater than trigger threshold $onetimethreshold.\nOne time data gathering invoked."
          triggered=1

          # Gather one time data here

          break
        fi
      done
    fi
  fi
  # Collect additional data at each interval
  # Monitor Worker 1 thread usage
  mmfsadm dump mb | grep Worker1Threads | sed -e 's/^  //'

  # Watch some mfmsadm dump fs stats
  mmfsadm dump fs | egrep -A 1 "OpenFile counts|StatCache" | awk  \
    '{
      if ($1=="OpenFile" && $2=="counts:") {
          printf "%s %s %s %s %s %s %s %s %s %s ",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10
          child="OpenFile"
        }
      if ($1=="cached" && child=="OpenFile") {
          printf "%s %s %s maxFilesToCache %s ",$3,$4,$5,$8
          child=""
        }
      if ($1=="StatCache" && $2=="counts:") {
          printf ",%s %s %s %s %s %s %s %s %s %s, ",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10
          child="StatCache"
        }
      if ($1=="cached" && child=="StatCache") {
          printf "maxStatCache %s \n",$5
          child=""
        }
    }'


  # Collect Memory Statistics
  mmfsadm dump malloc | egrep -A 4 "^Statistics|^Delta" | awk 'BEGIN {  RS="--" } \
    { \
      if ($1=="Delta") { printf "Heap %s %s ,",$4,$5} \
      if ($1=="Statistics") { \
        if ( $5=="2" ) {
          printf "SharedSeg: %s %s %s %s %s %s %s %3.2f%% in use,",$9,$10,$11,$12,$24,$25,$26,(($9/$24)*100) \
        } \
        if ( $5=="3" ) {
          printf "TokenSeg: %s %s %s %s %s %s %s %3.2f%% in use\n",$9,$10,$11,$12,$24,$25,$26,(($9/$24)*100) \
        } \
      } \
    }'


sleep $delay
done
print "monitoring stopped $(date)"
 
