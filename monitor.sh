#!/bin/bash
########################################################
# Author: jason du
# Mail: jincan.du@outlook.com
# Created Time: Tue 15 Jan 2019 03:19:17 PM CST
# Last modified: Tue 15 Jan 2019 03:19:17 PM CST
########################################################
item=$1
ip=$2
passwd=$3
mysqlpwd=$4
ssh="sshpass -p $passwd ssh $ip"

function check_ip() {
    VALID_CHECK=$(echo $ip|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo $ip|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$">/dev/null;
    then
        retval=$?
        if [ ${VALID_CHECK:-no} != "yes" ];
        then
            retval=$?
            echo "IP $ip not available!"
            exit $retval
        fi
    else
        echo "IP format error!"
        exit $retval
    fi
}

function check_ip_available() {
    loss=`ping -f -c 10 -f $ip |grep loss |awk -F "%" '{print $1}' |awk '{print $NF}'`
    if [ $loss -ne 0 ]
    then
        echo "ip unreachable"
        exit 1
    fi
}

function check_passwd() {
    $ssh "free -m" &>/dev/null 
    retval=$?
    if [ $retval -ne 0 ]
    then
        echo "passwd is fail"
        exit $retval
    fi
}

function check_mysqlpwd() {
    mysqlbin=`$ssh "ps -ef" |grep mysql[d]|awk 'NR==2{print $8}'|sed 's#mysqld##g'` 
    mysqlconf=`$ssh "ps -ef" |grep mysql[d]|awk -F "=" 'NR==1{print $2}'`
    $ssh "cp $mysqlconf ${mysqlconf}.old && echo -e \"[mysqladmin]\nuser=root\npassword=dbrootpwd\">>$mysqlconf"
    $ssh "$mysqlbin/mysqladmin extended-status" &>/dev/null 
    retval=$?
    if [ $retval -ne 0 ]
    then
        echo "mysql password fail"
        exit $retval
    fi
}


function mysql() {
    log=/tmp/mysql.log
    check_ip
    check_ip_available
    check_passwd
    check_mysqlpwd
    echo -e "\033[31m ------------host $ip mysql--------------\033[0m"
    mysqlbin=`$ssh "ps -ef" |grep mysql[d]|awk 'NR==2{print $8}'|sed 's#mysqld##'`
    $ssh "$mysqlbin/mysqladmin -r -i 1 -c 10 ext"|awk -F "|" '$2 ~/Queries|Com_select |Com_insert |Com_update |Com_delete /{print $3}'|tr "\n" " " >>$log       
    if [ -f $log  ]
    then
        awk '{print "mysql","QPS:"$NF,"Com_delete:"$(NF-1),"Com_insert:"$(NF-2),"Com_select:"$(NF-3),"Com_update:"$(NF-4)}' $log
        rm -rf $log
        $ssh "cp ${mysqlconf}.old $mysqlconf && rm -rf ${mysqlconf}.old"
    fi
}

function memory() {
    check_ip
    check_ip_available
    check_passwd
    echo -e "\033[31m ------------host $ip memory--------------\033[0m"
    $ssh "free -m" |grep -v Swap
    echo ""
}

function cpu() {
    check_ip 
    check_ip_available
    check_passwd
    echo -e "\033[31m ------------host $ip cpu--------------\033[0m"
    $ssh "iostat" |grep -v Linux|egrep -v "^$" |egrep "^[ |avg]"
    echo ""
}


function hd() {
    check_ip 
    check_ip_available
    check_passwd
    echo -e "\033[31m ------------host $ip hd--------------\033[0m"
    $ssh "df -h" |egrep -v "^tmpfs" |grep -v tmpfs
    echo ""
}

function nic() {
    check_ip
    check_ip_available
    check_passwd
    echo -e "\033[31m ------------host $ip nic--------------\033[0m"
    $ssh "ifstat" |grep -v "#"|grep -v lo |egrep -v "^[ ]+"
    echo ""
}

function io() {
    check_ip
    check_ip_available
    check_passwd
    echo -e "\033[31m ------------host $ip io--------------\033[0m"
    $ssh "iostat" |grep -v "Linux"|egrep -v "^[ ]+"|egrep -v "^$"|grep -v avg
    echo ""
}

function nginx() {
    check_ip
    check_ip_available
    check_passwd
    echo -e "\033[31m ------------host $ip io--------------\033[0m"
    $ssh "curl -s localhost/nginx-status" |tr "\n" " "|awk '{print "conections:"$3,"requests:"$8,"writing:"$14,"waiting:"$NF}'
    echo ""
}
                                                                
function php() {
    check_ip
    check_ip_available
    check_passwd
    echo -e "\033[31m ------------host $ip io--------------\033[0m"
    $ssh "curl -s localhost/php-status" |egrep -v "pool|manager|time|since" |awk -F ":" '{print $1":",$2}'
    echo ""
}

function tcp() {
    check_ip
    check_ip_available
    check_passwd
    echo -e "\033[31m ------------host $ip tcp--------------\033[0m"
    netstat -n | awk '/^tcp/{s[$NF]++}END{for(a in s) print a":",s[a]}'
    echo ""
}
function  all() {
    memory
    cpu
    hd
    nic
    io
    tcp
}




if [ $# -eq 0 ]
then
    echo -e "Usage:\nbash $0 mysql ip passwd mysqlpwd\nbash $0 {cpu|memory|hd|io|nic} ip passwd"
    exit 1
elif [ $# -eq 4 ]
then
    if [ $item == mysql ]
    then
        mysql
    else
        echo "Usage:bash $0 mysql ip passwd mysqlpwd"
        exit 1
    fi
elif [ $# -eq 3 ]
then
    if [ $item == memory  ]
    then
        memory
    elif [ $item == cpu ]
    then
        cpu
    elif [ $item == all ]
    then
        all
    elif [ $item == hd ]
    then
        hd
    elif [ $item == nic ]
    then
        nic
    elif [ $item == io ]
    then
        io
    elif [ $item == tcp ]
    then
        tcp
    elif [ $item == nginx ]
    then
        nginx
    elif [ $item == php ]
    then
        php
    else
         echo -e "Usage:\nbash $0 mysql ip passwd mysqlpwd\nbash $0 {cpu|memory|hd|io|nic} ip passwd"
         exit 1
    fi
else
    echo -e "Usage:\nbash $0 mysql ip passwd mysqlpwd\nbash $0 {cpu|memory|hd|io|nic|all} ip passwd"
    exit 1
fi

