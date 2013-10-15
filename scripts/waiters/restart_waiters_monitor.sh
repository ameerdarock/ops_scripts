#!/bin/bash

if [ -f /var/run/gpfs_monitor.pid ]; then
	PID=`cat /var/run/gpfs_monitor.pid`
	kill -HUP $PID
	sleep 180
fi
/root/parse_gpfs_waiters.pl
