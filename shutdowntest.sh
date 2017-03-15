#!/bin/bash

maxnumber=$(cat /opt/totalnumber)
currentnumber=$(cat /opt/currentnumber)
Timeout=10

if [[ ${currentnumber} -eq ${maxnumber} ]]; then
	zenity --info --text="您已经完成总共${maxnumber}次关机测试"
	touch /opt/tested
	systemctl restart starttest
elif [[ ${currentnumber} -gt ${maxnumber} ]]; then
	zenity --error --text="关机测试遇到未知错误，执行测试次数超过设置"
	exit 1
elif [[ ${currentnumber} -lt ${maxnumber} ]]; then
	currentnumber=$(expr ${currentnumber} + 1)
	echo ${currentnumber} > /opt/currentnumber
	count=0
	(
		while [ ${count} -lt ${Timeout} ]; do
			echo $((${count}*100/${Timeout}))
		    echo "#执行关机测试${maxnumber}次，系统将进行第${currentnumber}次关机测试，${Timeout}秒后关机"
		    sleep 1
		    ((count+=1))
		done
	) |
	zenity --progress --title="关机测试" --auto-close

	# cancel the test
	if [[ $(echo $?) -ne 0 ]]; then
		# do clean in starttest.sh
		zenity --info --text="系统关机测试取消,准备测试${maxnumber}次，已进行$(expr ${currentnumber} - 1)次关机测试" --title="关机测试"
		touch /opt/tested
		systemctl restart starttest
	else
		# poweroff the system
		systemctl poweroff
	fi
fi