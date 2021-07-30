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
declare -i first
rm -rf icmp temp data.txt meta.txt log.txt anycast.txt temp.txt
mkdir icmp
echo DNS解析获取CF节点IP
curl --ipv4 --retry 3 -v https://speed.cloudflare.com/__down>meta.txt 2>&1
asn=$(cat meta.txt | grep cf-meta-asn: | tr '\r' '\n' | awk '{print $3}')
city=$(cat meta.txt | grep cf-meta-city: | tr '\r' '\n' | awk '{print $3}')
latitude=$(cat meta.txt | grep cf-meta-latitude: | tr '\r' '\n' | awk '{print $3}')
longitude=$(cat meta.txt | grep cf-meta-longitude: | tr '\r' '\n' | awk '{print $3}')
curl --ipv4 --retry 3 "https://database.udpfile.com?asn=AS"$asn"&city="$city"&api="%api"" -o data.txt -#
m=$(cat data.txt | wc -l)
first=$(sed -n '1p' data.txt)
echo $first
if [ $first -ge "Ooops!!!" ]
then
echo 没有发现ip,请重新运行脚本
break
else
for i in `cat data.txt | sed ''$[$m-4]',$d'`
do
echo $i>>anycast.txt
done
fi
 ./cfst -f anycast.txt -n 200 -p 1 -o test-result.txt
