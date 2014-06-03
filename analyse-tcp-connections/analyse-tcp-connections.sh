#!/bin/bash
#
# DATE : Mon 2th Jun 2014
#
# AUTHOR : jascbu
#
# AIM : Understand what tcp connections are being tried
#       
# WHY : To understand more clearly what a server is doing
#
# HOW : Run a netstat every "f" seconds, parse the results and
#       then cross reference pid against ps
# 
# DEPENDENCIES :
#       1)  Netstat is run as sudo to get pid returned in 
#           netstat -ntp. Potential password prompt.
#
# NOTES :
#       1) If you are troubleshooting press enter after
#       all "#HELP#" to move the script behind it to
#       below it and make it active
#
#



##############################################################################
#
# GET ARGUMENTS
#
##############################################################################

while getopts 'f:t:i:h' OPT; do
  case $OPT in
    f)  frequency=$OPTARG;;
    t)  time=$OPTARG;;
    i)  ipaddress=$OPTARG;;
    h)  help="yes";;
    *)  unknown="yes";;
  esac
done

# Usage
HELP="HELP INFO - 

    Usage: $0 -f frequency in seconds  -t total test time in minutes -i IP address [ h ]

    Syntax:
        -f --> frequency in seconds that netstat will be run
        -t --> total test time in minutes
        -i --> IP address (the network address, not localhost) as dotted quad
        -h --> print this help screen

    Example: $0 -f 5 -t 10 -i 10.0.1.144

"

if [ "$help" = "yes" -o $# -lt 4 ]; then
  echo "$HELP"
  exit 0
fi


##############################################################################
#
# VARIABLES
#
##############################################################################

base_dir="/tmp/analyse-tcp-connections"

if [ -e "$base_dir" ]
then
  rm -r $base_dir
fi

mkdir $base_dir



netstat_all_connections=${base_dir}/netstat_all_connections.log

netstat_outbound_connections=${base_dir}/netstat_outbound_connections.log

netstat_inbound_connections=${base_dir}/netstat_inbound_connections.log

netstat_unique_destinations=${base_dir}/netstat_unique_destinations.log

netstat_unique_sources=${base_dir}/netstat_unique_sources.log

netstat_unique_source_ips=${base_dir}/netstat_unique_source_ips.log

netstat_unique_inbounds_by_local_service=${base_dir}/netstat_unique_inbounds_by_local_service.log

netstat_unique_inbounds_by_local_service_resolved=${base_dir}/netstat_unique_inbounds_by_local_service_resolved.log

netstat_unique_outbounds_by_local_service=${base_dir}/netstat_unique_outbounds_by_local_service.log

netstat_unique_outbounds_by_local_service_resolved=${base_dir}/netstat_unique_outbounds_by_local_service_resolved.log



escaped_ipaddress=$(echo $ipaddress | sed s@"\."@"\\\."@g)

repetitions=$(echo "$time $frequency" | awk '{ print $1 * 60 / $2}')


##############################################################################
#
# FUNCTIONS
#
##############################################################################


resolve_ip () {
    parsed_ip="^${ip}\ "
    resolved_ip=$(grep "$parsed_ip" /etc/hosts)
    if [ "$resolved_ip" ]
    then
        echo $resolved_ip
    else
        echo $ip
    fi
}




##############################################################################
#
# STEP 1
#
##############################################################################

echo " "
echo "Please be aware that the files could be serveral 100 MBs in size depending on the frequency, time of the test and
 the number of tcp connections present"
echo " "
echo "----- Starting in 5 seconds (CTRL+C to cancel) -----"
sleep 5
echo " "
echo "----- Starting Analysis -----"
echo " "


echo -n "..."

for (( count=1; count<=$repetitions; count++ ));
do 
    echo -n "${count}/${repetitions}....."
    sleep $frequency
    sudo netstat -ntp >> $netstat_all_connections
    
done



# Pull out outbound connections
grep "${escaped_ipaddress}\:[0-9][0-9][0-9][0-9][0-9]" $netstat_all_connections > $netstat_outbound_connections


# Pull out the inbound connections
grep -v "${escaped_ipaddress}\:[0-9][0-9][0-9][0-9][0-9]" $netstat_all_connections | grep tcp > $netstat_inbound_connections


# Pull out unique destinations
cat $netstat_outbound_connections |  awk '{print $5}' | sort -n | uniq > $netstat_unique_destinations

# Sort and order unique outbound connections by service
cat $netstat_outbound_connections | awk '{print $7 " " $5}' | sed s/":[0-9]*"/""/g | sort -n | uniq > $netstat_unique_outbounds_by_local_service

while read line
do
    ip=$(echo $line | grep -o "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*")
    echo $line | sed s/"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"/"$(resolve_ip)"/ >> $netstat_unique_outbounds_by_local_service_resolved
done < $netstat_unique_outbounds_by_local_service



# Pull out unique sources
cat $netstat_inbound_connections | awk '{print $5}' | sort -n | uniq > $netstat_unique_sources


# Pull out list
cat $netstat_unique_sources | sed s/":[0-9]*"/""/g | sort -n | uniq > $netstat_unique_source_ips

# Sort and order unique inbound connections by service
cat $netstat_inbound_connections | awk '{print $7 " " $5}' | sed s/":[0-9]*"/""/g | sort -n | uniq > $netstat_unique_inbounds_by_local_service


while read line
do
    ip=$(echo $line | grep -o "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*")
    echo $line | sed s/"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"/"$(resolve_ip)"/ >> $netstat_unique_inbounds_by_local_service_resolved

done < $netstat_unique_inbounds_by_local_service

echo " "
echo " "
echo "-----Analysis Complete -----"
echo " "
echo "Results are in ${base_dir}. Please read / copy and then, if you need the space delete them. They will be deleted on next run."
echo " "


exit
