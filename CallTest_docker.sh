#!/bin/bash 
set -e
#set -u

PATH=/usr/bin:/usr/local/bin:/bin
#Set variables
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
phone_value=$1
# defaults
crit_value=15
warn_value=30
#type of rounding from http://unix.stackexchange.com/questions/167058/how-to-round-floating-point-numbers-in-shell
round_precision=0
DoW=$(date +%A)
Month=$(date +%B)
Year=$(date +%Y)
dateofcheck=$(date +%d-%m-%Y)
Time=$(date +%T)
simptime=$(date +%R)
WeekNumber=$(date +"WN%V")
simpISO=$(date +%Y-%m-%d" "%H:%M:"00")
ISO=$(date +%Y-%m-%d" "%H:%M:%S)

#setup SIP server information
SIPusername=123456 #your service phone number
SIPpassword=hunter2 # yes, it's plaintext, deal with it
SIPproxy=proxy.freecall.net.au #byo.engin.com.au SIP proxy server 
SIPproxyport=5060 #proxy port

usage () { 
echo "calltest -c critical phonenumber"
echo 'EG calltest -c 15 01189998819991997253'
echo 'Warning is the warning marker, critical is the critical marker'
echo 'Returns value as performance data'
echo 'Warning and critical are whole numbers'
}

while getopts ":hw:c:" OPTION ; do
case $OPTION in
h)
usage
exit -1
;;
w)
warn_value="$OPTARG"
;;
c)
crit_value="$OPTARG"
;;

esac
done

date

#what's the public IP address of this computer
publicIP=$(ip addr show eth0 | grep -v 10. |  grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep --color=never -Eo '([0-9]*\.){3}[0-9]*')
#Calculate call length
CALLSTART=$(date +%s.%N)
perlextra="-I /usr/local/lib/perl5 -I /usr/local/lib/perl5/site_perl/5.24.1"
progoutput=$(/usr/bin/perl ${perlextra} -X /src/plugin/check_calls -T $warn_value --username $SIPusername --password $SIPpassword --leg $publicIP --registrar $SIPproxy:$SIPproxyport sip:$SIPusername@$SIPproxy $phone_value)
CALLEND=$(date +%s.%N)
CallLength=$(echo "$CALLEND - $CALLSTART" | bc | xargs printf "%.*f\n" $round_precision) #rounds with precision 0 by default

# Finish this damn thing off
exit_code=$STATE_OK
exit_msg="OK: calllength is $CallLength"
[[ $CallLength -le $warn_value ]] && { exit_msg="WARNING: Call Length is $CallLength this is less than $warn_value"; exit_code=$STATE_WARNING; }
[[ $CallLength -le $crit_value ]] && { exit_msg="CRITICAL: Call Length is $CallLength this is less than $crit_value"; exit_code=$STATE_CRITICAL; }

echo "$exit_msg | calllength=${CallLength}s"
#Create conservative estimate of call failure
SimplePassOrFail="DISREGARD THIS LINE OF DATA"
[[ $CallLength -le $crit_value ]] && { SimplePassOrFail="CALL BLOCKED BY CENTRELINK PHONE SYSTEM"; } #Fail Condition  
[[ $CallLength -gt $crit_value ]] && { SimplePassOrFail="SUCCESSFULLY ABLE TO ENTER PHONE QUEUE"; } #Pass Condition 
#create CSV line - detailed
echo  $phone_value, $SimplePassOrFail, $CallLength, $exit_msg, $DoW, $WeekNumber, $Month, $dateofcheck, $Time, $CALLSTART, $CALLEND, $progoutput, $ISO >> /tmp2/Centrelink-detailed-${Year}.csv
#create CSV line - simple
echo  $phone_value, $SimplePassOrFail, $DoW, $Month, $dateofcheck, $simptime, $WeekNumber, $simpISO >> /tmp2/github/IsCentrelinkDown_Independent_Centrelink_Blocked_Call_Statistics-${Year}.csv
exit $exit_code

