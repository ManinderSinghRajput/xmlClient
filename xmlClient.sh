#!/bin/bash
#Initial Draft -> Maninder Singh
#
# By default it take filename as an inpiut which consists of a xml request
#
# Other option:
# i:custom -> For entering custom request
# e:<filename> -> to first edit and then send the request
# cmd:<command> -> to run the command
#

trap cleanup 1 2 15 21

seprator="============================================================================================================================================================="

cleanup()
{
  echo "Session_Stopped"
  exec 9>&- 
  exec 9<&-
  exit 1
}

usage()
{
  echo "./naeClient <hostname/hostIP> <Port>"
  exit -1
}

if [ $# -ne 2 ];then
  usage
fi

readResponse()
{
  if [ ! -e $1 ];then
    echo "Given file [$1] does not exist. Try again."
    echo $seprator
    return
  fi
  if [ "X$1" == "X" ];then
    echo "Request file name is empty. Try again."
    echo $seprator
    return
  fi
  echo "Request:"
  cat $1| grep -v "^#"
  if [ $? -ne 0 ];then
    echo "Try again"
    echo $seprator
    return
  fi
  cat $1 | grep -v "^#" >&9
  echo $seprator
  echo "Response:"
  response="<ManiCustom>"
  while :
  do
    line=`timeout 0.3 cat <&9`
    if [ "X$line" == "X" ];then
      break
    fi
    response=`echo $response$line`
  done
  response=`echo "$response</ManiCustom>"`
  echo "$response"| xmllint --format - | sed 1d| grep -v "<ManiCustom>\|</ManiCustom>"
  echo $seprator
}

readResponseCustom()
{
  echo "Enter Request(After complete request and newline, Press Ctrl+D):"
  request=$(</dev/stdin)
  echo $request | grep -v "^#" >&9
  echo $seprator
  echo "Response:"
  response="<ManiCustom>"
  while :
  do
    line=`timeout 0.3 cat <&9`
    if [ "X$line" == "X" ];then
      break
    fi
    response=`echo $response$line`
  done
  response=`echo "$response</ManiCustom>"`
  echo "$response"| xmllint --format - | sed 1d | grep -v "<ManiCustom>\|</ManiCustom>"
  echo $seprator
}


exec 9<>/dev/tcp/$1/$2
selfPort=`netstat -natp | grep $$ | awk '{print $4}' | cut -d ':' -f2`
echo "Session_Started"
echo $seprator
echo "  fd used is 9"
echo "  Used port [$selfPort] to connect $1:$2"
echo $seprator

while :
do
  read -e filename
  if [[ ${filename:0:2} == e: ]];then
    vi ${filename:2}
    readResponse ${filename:2}
  elif [[ ${filename:0:4} =~ ^cmd:* ]];then
    echo $seprator
    ${filename:4}
    echo $seprator
  elif [[ ${filename} == i:custom ]];then
    readResponseCustom
  else
    readResponse $filename
  fi
  netstat -natp 2>/dev/null| grep $selfPort | grep "ESTABLISHED" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Connection closed from server side. Quitting"
    break
  fi
done
