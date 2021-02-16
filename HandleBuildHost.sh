#!/bin/bash
##################################################################################################################
# This script:  HandleBuildHost.sh  - 	Stop/Start our Build hosts in Azure and setup environment 
					
# Script:       new_proxy_setup.sh  -	have an array of host to use 
#
# stop / start host in Azure
# Bamboo Agent are handled:
# Linux - systemd
# Windows - system service
#
#
#
#
#
#
##################################################################################################################
# version 0.2   stop+start scapBambooAgentFedora31Platform+scapBambooWin3 ok 
# version 0.3   Check Azure login before trying to use powershell
# version 0.4    ??
# version 0.5   now with show (show hosts to handle) and debug removed (can be set from cmd line (DEBUG=2 ./Hand..)
# version 0.6   Az.cli implemented
# version 0.7   Moved script from Bamboo to proxy_host
# version 0.8   If Host is used by another build dont shut it down  
# version 0.9   Corrected: check_host_proxy - dont do 
##################################################################################################################
#
version="initial 0.8"

help="HandleBuildHost.sh [ start / stop / check / restart / show ]  [Hostname] \n
example:  start host in Azure Cloud  ./HandleBuildHost.sh start [Hostname] \n
 \n
example: show host setup to be used  /HandleBuildHost.sh start \n"

# --- argument & environment section --- #########################################################################
#DEBUG=2
DEBUG=${DEBUG:-0}

argument=$1
host=$2

work_dir="/home/gbuilder"
log="$work_dir/azure_host_handle.log"
temp_file="/tmp/build_host_bamboo_tmp_file"

# Azure environment
az_group="Scap-Build-Machines"

# ssh_proxy_host=dev-build-fedora-29-app-3
ssh_proxy_host="172.16.29.142"
proxy_script="/home/gbuilder/new_proxy_setup.sh"
user=gbuilder

b_hostname="initial"
b_host_ip="initial"


# --- function section --- #######################################################################################

# --- start_host ---
function start_host()
{
local host=$1
local ret=9

# Before Starting Host we check:
#	1) is host running ?    ( if its running we exit )
#	2) is ssh_proxy process running on ssh_proxy host ?  ( if its running we shot it down )

###--------------------------------------------------------------------------------------------
# ---   1)  is host running ?    ( if its running we exit )
check_host_up $host expect_down  
ret=$?
if [ $ret = 0 ]
then
	[ $DEBUG -gt 0 ] && echo "DEBUG host was down as expected ret= $ret" | tee -a $log
else
	[ $DEBUG -gt 0 ] && echo "DEBUG host was not down as expected ret= $ret"
	echo "try to start host - but host seems to be running - exit" | tee -a $log
	echo "we do an exit 0 - dont want to stop a host before build :-)"
	# we is in a process of starting host - it seems to be started - there can be reasons for that - we dont 
	# want to stop the build job if things is fine , continue
	exit 0
fi

###--------------------------------------------------------------------------------------------
# ---   2) is ssh_proxy process running on ssh_proxy host ?  ( if its running we shot it down )

check_host_proxy $host stop

#pwsh -F $work_dir/Start_Azure_Host.ps1 $host
az vm start --name $host --resource-group $az_group

# we have to wait a while before starting ssh tunnel, to the host is propperly started

echo "Wait in loop for Azure host to come up (can take some time)"

for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22
do
check_host_up $host expect_up  > /dev/null
ret=$?
echo -e "$i \c"
[ $DEBUG -gt 0 ] && echo "DEBUG wait Start_Azure_Host ret= $ret waitcount = $i"
if [ $ret = 0 ]
then
	[ $DEBUG -gt 0 ] && echo "DEBUG wait Start_Azure_Host ret= $ret waitcount = $i"
	break
fi
sleep 5
done

check_host_proxy $host start

[ $DEBUG -gt 0 ] && echo "DEBUG Start_Azure_Host ret= $ret"
echo "start host $host end" >> $log
}

# --- stop_host ---
function stop_host()
{
local host=$1

check_host_up $host expect_up  
ret=$?

check_host_proxy $host stop

#pwsh -F $work_dir/Stop_Azure_Host.ps1 $host
az vm deallocate --name $host --resource-group $az_group

[ $DEBUG -gt 0 ] && echo "DEBUG Stop_Azure_Host ret= $ret"
echo "az vm deallocate --name $host --resource-group $az_group" >> $log
}
# --- check_host_up

function check_host_up()
{
local host=$1
local expect=$2    # value: expect_up - expect_down - check
local ret="xx"

echo $expect | egrep "^expect_up$|^expect_down$|^check$" > /dev/null
if [ $? != 0 ]
then
	echo "wrong parameter for function check_host_up : $expect "
	[ $DEBUG -gt 0 ] && echo "DEBUG ERROR check_host_up EXPECT PARAMETER WRONG !!!  ret = $ret expect = $expect host = $host"
	exit 2
fi
	

# find IP for hostname IP will be set in global $b_host_ip
check_host $host

/bin/nc -z $b_host_ip 22 2>/dev/null
ret=$?

[ $DEBUG -gt 0 ] && echo "DEBUG check_host_up ret = $ret expect = $expect host = $host"

if [ $expect = "check" ]
then
	echo "Host $host status: $ret  ( 0 = up )" | tee -a $log
	return $ret
fi


if [ $expect = "expect_up" ]
then
	if [ $ret = 0 ] 
	then
		echo "host running - as expected" | tee -a $log
		return $ret
	else
		echo "expect_up:  host not running - was expected to run!" | tee -a $log
		return $ret
	fi
fi

if [ $expect = "expect_down" ]
then
	if [ $ret != 0 ] 
	then
		echo "expect_down: host not running - as expected" | tee -a $log
		return 0
	else
		echo "host running - was not expected to run!" | tee -a $log
		return 1
	fi
fi

if [ $ret = 0 -a $expect = "expect_down" ]
then
	echo "host running, not nessesary to start once more, exit" | tee -a $log
	exit 2
fi 

return $ret
}

# --- check_host

# check that host is known in new_proxy_setup.sh on ssh_proxy_host="172.16.29.142"
# if host is known b_hostname & b_host_ip are set  (b_ = build)
function check_host()
{
local _host=$1
[ $DEBUG -gt 0 ] && echo "DEBUG check_host host = $host"

$proxy_script show all | grep $host > $temp_file
if [ $? != 0 ]
then
	echo "Error: Host not found in script $proxy_script"
	rm -f $temp_file
	exit 2
fi

b_hostname=`cat $temp_file | cut -d ":" -f 2 | awk '{ print $1 }'`
b_host_ip=`cat $temp_file | cut -d ":" -f 3 | awk '{ print $1 }'`
rm -f $temp_file

return 0

}

# --- check_host_proxy

function check_host_proxy()
{
local host=$1
# This function can
# 1) stop:     stop ssh_proxy  -  Kill process for ssh tunnel for build servers on ssh_proxy_host
# 2) start:    start ssh_proxy -  Start ssh tunnels for build servers for Bamboo & Git
# 3) check_p:  check that process for ssh tunnels is running
# 4) check_t:  check tunnel from build host to proxy host 

[ $DEBUG -gt 1 ] && echo "DEBUG check_host_proxy start "

# should be: check_p | stop | start | check_t | status
local proxy_manage=$2
local ret="xx"

[ $DEBUG -gt 1 ] && echo "DEBUG check_host_proxy start 2 "

check_host $host

[ $DEBUG -gt 1 ] && echo "DEBUG check_host_proxy b_hostname: $b_hostname  b_ip: $b_host_ip"

case $proxy_manage in
check_t)
ssh $user@$b_host_ip ssh chk@localhost -p 2222 cat status | grep OK > /dev/null
ret=$?
[ $DEBUG -gt 0 ] && echo "DEBUG check_host_proxy git ssh connection  check_t ret= $ret"
return $ret
;;
check_p)
$proxy_script status $b_hostname
ret=$?
[ $DEBUG -gt 0 ] && echo "DEBUG check_host_proxy check_p ret= $ret"
return $ret
;;
stop)
$proxy_script stop $b_hostname
ret=$?
[ $DEBUG -gt 0 ] && echo "DEBUG check_host_proxy stop ret= $ret"

;;
start)
$proxy_script start $b_hostname
ret=$?
[ $DEBUG -gt 0 ] && echo "DEBUG check_host_proxy start ret= $ret"
return $ret
;;
status)
$proxy_script status $host
return $?
;;
*)
[ $DEBUG -gt 0 ] && echo "we dont get here !!!!"
echo xxxxxxxxxxxxxxxxx
;;
esac
}

# --- check_azure_connection
function check_azure_connection()
{
local ret=initial

[ $DEBUG -gt 0 ] && echo "Check Azure Connection"

# pwsh -F $work_dir/Check_Azure_Login.ps1  > $temp_file
az account list  > $temp_file
cat $temp_file >> $log

grep "cloudName" $temp_file
ret=$?
if [ $ret != 0 ]
then
	[ $DEBUG -gt 0 ] && echo "Check Azure Connection - there is a problem"
	echo "There is a problem with the connection to Azure"
	echo "In a powershell at bamboo host, do a 'Connect-AzAccount' login! "
	echo "ERROR exit!"
	rm -f $temp_file
	return 2
fi
rm -f $temp_file
return 0
}

##################################################################################################################

[ $DEBUG -gt 0 ] && echo "DEBUG on $DEBUG"

date >> $log

case $argument in

test)
# check_host_proxy scapBambooAgentFedora31Platform status
# check_host_up $host expect_up
# check_host_up $host check           # return 0 on success (success = host up)
# check_host_proxy $host check_p   
check_azure_connection

exit 0
;;
start)
check_azure_connection
start_host $host
echo "Start host done" >> $log
exit 0
;;
stop)
check_azure_connection
stop_host $host
exit 0
;;
restart)
check_azure_connection
stop_host $host
start_host $host
exit 0
;;
check)
check_azure_connection
check_host_up $host check
check_host_proxy $host status
exit 0
;;
check_host_up)
check_host_up $host check
exit 0
;;
check_host_proxy)
check_host_proxy $host status
ret=$?
# if tunnel is down the next command will hang up, and we have just confirmed that process is down above......

# if ret = 0 ssh process running   
if [ $ret = 0 ]
then
	# not implemented in windows
	
	check_host_proxy $host check_t
	if [ $ret = 0 ]
	then
	echo "ssh tunnel from $host  via localhost port 2222 to git host OK"
	else
	echo "ERROR:ssh tunnel from $host  via localhost port 2222 to git host!"
	fi
else
	exit $ret
fi

exit 0
;;
show)
$proxy_script show all
exit 0
;;
help)
echo -e $help
exit 0
;;
*)
echo "Error:No or wrong argument, exit!"
echo -e $help
exit 2
;;

esac
