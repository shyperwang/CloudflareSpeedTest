#!/bin/bash
# random cloudflare anycast ip
declare -i bandwidth
declare -i speed
read -p "请设置期望到 CloudFlare 服务器的带宽大小(单位 Mbps):" bandwidth
speed=bandwidth*128*1024
starttime=`date +'%Y-%m-%d %H:%M:%S'`
api=`date +'%Y%m%d'`

declare -i m
declare -i n
declare -i per
rm -rf temp data.txt meta.txt log.txt anycast.txt temp.txt
while true
do
    echo DNS解析获取CF节点IP
    while true
	do
        if [ ! -f "meta.txt" ]
        then
            curl --ipv4 --retry 3 -v https://speed.cloudflare.com/__down>meta.txt 2>&1
        else
            asn=$(cat meta.txt | grep cf-meta-asn: | tr '\r' '\n' | awk '{print $3}')
            city=$(cat meta.txt | grep cf-meta-city: | tr '\r' '\n' | awk '{print $3}')
            latitude=$(cat meta.txt | grep cf-meta-latitude: | tr '\r' '\n' | awk '{print $3}')
            longitude=$(cat meta.txt | grep cf-meta-longitude: | tr '\r' '\n' | awk '{print $3}')
            curl --ipv4 --retry 3 "https://database.udpfile.com?asn=AS"$asn"&city="$city"&api="%api"" -o data.txt -#
            break
        fi
    done
    if [ -f "data.txt" ]
    then
        break
    fi
    done
declare -i address
address = "https://database.udpfile.com?asn=AS"$asn"&city="$city"&api="%api""
echo $address
m=$(cat data.txt | wc -l)
first=$(sed -n '1p' data.txt)
    if [[ $first =~ "Ooops" ]]
    then
        echo 没有发现ip,请重新运行脚本
    else
        for i in `cat data.txt | sed ''$[$m-4]',$d'`
        do
            echo $i>>anycast.txt
        done
    fi
./cfst -f anycast.txt -n 200 -p 1 -o result.txt
