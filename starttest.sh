#!/bin/bash


LIGHTDM_CONF="/etc/lightdm/lightdm.conf"

script_wd=$(dirname $(readlink -f $0))

check_username(){
	if [[ -f /opt/runuser ]]; then
		username=$(cat /opt/runuser)
	else
		# store the desktop user
		touch /opt/runuser

		if [[ $(id -u) -ne 0 ]]; then
			zenity --error --text="需要使用root权限执行脚本"
			exit 1
		fi
		username=$(who | awk '{print $1}')
		echo ${username} > /opt/runuser
	fi
}


init(){

	chmod a+x ${script_wd}/*.sh

	cp -f ${script_wd}/starttest.sh /usr/bin
	cp -f ${script_wd}/reboottest.sh /usr/bin
	cp -f ${script_wd}/shutdowntest.sh /usr/bin

	# create log files
	touch /opt/totalnumber
	# chmod 666 /opt/totalnumber
	touch /opt/currentnumber
	# chmod 666 /opt/currentnumber
	# store the test choice
	touch /opt/testchoice
	# chmod 666 /opt/testchoice


	# backup the lightdm config
	cp ${LIGHTDM_CONF} /etc/lightdm/lightdm.conf-starttest-backup

	
}

set_service(){
	# set the desktop user name in .service
	sed -i "s|/home/testuser/.Xauthority|/home/${username}/.Xauthority|g" ${script_wd}/starttest.service

	cp -f ${script_wd}/starttest.service /lib/systemd/system/starttest.service

	systemctl enable starttest
	systemctl start starttest
}


quit_test(){
	# clean sh scripts
	if [[ -f /usr/bin/reboottest.sh ]]; then
		rm -f /usr/bin/reboottest.sh
	fi
	if [[ -f /usr/bin/shutdowntest.sh ]]; then
		rm -f /usr/bin/shutdowntest.sh
	fi
	if [[ -f /usr/bin/starttest.sh ]]; then
		rm -f /usr/bin/starttest.sh
	fi
	if [[ -f /usr/bin/sleeptest.sh ]]; then
		rm -f /usr/bin/sleeptest.sh
	fi
	if [[ -f /usr/bin/suspendtest.sh ]]; then
		rm -f /usr/bin/suspendtest.sh
	fi

	# clean test logs
	if [[ -f /opt/totalnumber ]]; then
		rm -f /opt/totalnumber
	fi
	if [[ -f /opt/currentnumber ]]; then
		rm -f /opt/currentnumber
	fi
	if [[ -f /opt/testchoice ]]; then
		rm -f /opt/testchoice
	fi
	if [[ -f /opt/tested ]]; then
		rm -f /opt/tested
	fi
	if [[ -f /opt/runuser ]]; then
		rm -f /opt/runuser
	fi

	# restore lightdm config
	cp /etc/lightdm/lightdm.conf-starttest-backup ${LIGHTDM_CONF}

	# disable service
	systemctl disable starttest

	if [[ -f /lib/systemd/system/starttest.service ]]; then
		rm -f /lib/systemd/system/starttest.service
	fi
}

set_autologin(){
	autologin=$(grep 'autologin-user=' ${LIGHTDM_CONF})

	if [[ x${autologin} != x ]]; then
		# item found in LIGHTDM_CONF
		sed -i "s/.*autologin-user=.*/autologin-user=${username}/g" ${LIGHTDM_CONF}
	# lightdm.conf with SeatDefaults options
	else
		oldconf=$(grep '^\[SeatDefaults\]' ${LIGHTDM_CONF})
		newconf=$(grep '^\[Seat:.*\]' ${LIGHTDM_CONF})
		if [[ x${oldconf} != x ]]; then
			sed -i "/^\[SeatDefaults\]/aautologin-user=${username}" ${LIGHTDM_CONF}
		elif [[ x${newconf} != x ]]; then
			sed -i "/^\[Seat:.*\]/aautologin-user=${username}" ${LIGHTDM_CONF}
		else
			zenity --error --text="未知的lightdm.conf格式"
			exit 1
		fi
	fi
}


select_choice(){
	SHUTDOWN="关机测试"
	REBOOT="重启测试"
	SUSPEND="待机测试"
	SLEEP="休眠测试"

	SELECTION=$(zenity --list --radiolist --title="测试工具"  --text="选择您想操作的一项功能"  --column "" --column "请您选择" True "$SHUTDOWN"  Fasle "$REBOOT"   Fasle "$SUSPEND" Fasle "$SLEEP") 

	if [ -e $SELECTION ] ; then 
		exit;
	fi
	if [ "$SELECTION"  =  "$SHUTDOWN"  ] ;then
		set_autologin

	 	maxnumber=$(zenity  --entry --text="请您输入需要关机测试的次数")
		if [ -e ${maxnumber} ] ;then 
			exit 
		fi
		echo ${maxnumber} > /opt/totalnumber
		echo "0" > /opt/currentnumber
		echo "shutdown" > /opt/testchoice

		set_service
		sleep 2
		/usr/bin/shutdowntest.sh
	fi
	if [ "$SELECTION"  =  "$REBOOT"  ]; then
		set_autologin

		maxnumber=$(zenity  --entry --text="请您输入需要重启测试的次数")
		if [ -e ${maxnumber} ] ;then 
			exit 
		fi
		echo ${maxnumber} > /opt/totalnumber
		echo "0" > /opt/currentnumber
		echo "reboot" > /opt/testchoice
		
		set_service
		sleep 2
		/usr/bin/reboottest.sh

	fi
	# if [ "$SELECTION" = "$SUSPEND"  ] ;then
	# 	maxnumber=$(zenity  --entry --text="请您输入需要待机测试的次数")
	# 	if [ -e ${maxnumber} ] ;then 
	# 		exit 
	# 	fi
	# 	echo ${maxnumber} > /opt/LogSuspendNo;
	# 	chmod 666 /opt/LogSuspendNo;
	# 	SuspendTest.sh;
	# fi
	# if [ "$SELECTION"  =  "$SLEEP"  ] ;then
	# 	maxnumber=$(zenity  --entry --text="请您输入需要休眠测试的次数")
	# 	if [ -e ${maxnumber} ] ;then 
	# 		exit 
	# 	fi
	# 	echo ${maxnumber} > /opt/LogSleepNo;
	# 	chmod 666 /opt/LogSleepNo;
	# 	SleepTest.sh;
	# fi
}

show_result(){
	choice=$(cat /opt/testchoice)
	maxnumber=$(cat /opt/totalnumber)
	currentnumber=$(cat /opt/currentnumber)
	testtime=$(date +%s)

	if [[ x${choice} == 'xshutdown' ]]; then
		zenity --info --text="关机测试执行结束，预期执行${maxnumber}次，实际执行${currentnumber}次，测试结果存放在/opt/shutdowntest-${testtime}"
		echo "关机测试执行结束，预期执行${maxnumber}次，实际执行${currentnumber}次" > /opt/shutdowntest-${testtime}
	elif [[ x${choice} == 'xreboot' ]]; then
		zenity --info --text="重启测试执行结束，预期执行${maxnumber}次，实际执行${currentnumber}次，测试结果存放在/opt/reboottest-${testtime}"
		echo "重启测试执行结束，预期执行${maxnumber}次，实际执行${currentnumber}次" > /opt/reboottest-${testtime}
	fi
}

# main scripts
check_username

if [[ ! -f /usr/bin/starttest.sh ]]; then
	init
fi

# exec the test passed
if [[ -f /opt/tested ]]; then
	show_result
	quit_test
	exit 0
fi


if [[ -f /opt/testchoice ]]; then
	choice=$(cat /opt/testchoice)
else
	zenity --error --text="测试初始化失败，测试中止"
	exit 1
fi


if [[ x${choice} == 'x' ]]; then
	#no choice set, ask the user
	select_choice
elif [[ x${choice} == 'xshutdown' ]]; then
	# TODO: replace sleep 20 with a more reliable method
	sleep 20
	/usr/bin/shutdowntest.sh
elif [[ x${choice} == 'xreboot' ]]; then
	sleep 20
	/usr/bin/reboottest.sh
else
	zenity --error --text="测试类型错误，测试中止"
	exit 1
fi

