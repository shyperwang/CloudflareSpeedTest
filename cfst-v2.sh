#!/bin/bash
clear
localport=8443
remoteport=443

declare -i speed
declare -i bandwith
api=`date +'%Y%m%d'`
starttime=`date +'%Y-%m-%d %H:%M:%S'`

echo
read -p "请设定期望下载速度（MB/s）：" bandwidth
clear
echo ----------------------------------------------
echo 开始筛测速，期望下载速度：$bandwidth MB/s
echo 当前时间：`date "+%Y-%m-%d %H:%M"`
echo ----------------------------------------------
sleep 1

declare -i n
declare -i m
declare -i count
rm -rf anycast.txt iplist.txt data.txt
datafile="./iplist.txt"
# 获取IP列表
echo ----------------------------------------------
echo CF节点IP列表获取方式
echo 1、xiu2原始方式获取IP列表，产生随机IP
echo 2、badafans获取IP列表，产生随机IP
echo 3、透过ASN及city从badafans获取生成的随机IP
echo 4、获取当前ASN及city下，在badafans测速过的前5个IP
echo ----------------------------------------------
read -r -p "选择CF节点IP列表获取方式？[y/n]:" datafiletype
if [[ "${datafiletype}" == "1" ]]; then
    echo 通过xiu2原始方式获取IP
    curl --retry 3 https://raw.githubusercontent.com/XIU2/CloudflareSpeedTest/master/ip.txt -o iplist.txt -#
else
    if [[ "${datafiletype}" == "2" ]]; then
        echo badafans获取IP列表，产生随机IP
        curl --retry 3 https://update.freecdn.workers.dev -o data.txt -#
        for i in `cat data.txt | sed '1,7d'`
        do
            randomip=$(($RANDOM%256))
            echo 生成随机IP $i$randomip
            echo $i$randomip/24>>iplist.txt
        done
    else
        if [[ "${datafiletype}" == "3" ]]; then
            echo 透过ASN及city从badafans获取生成的随机IP
            curl --ipv4 --retry 3 -v https://cfsd.shyper.workers.dev/__down>meta.txt 2>&1
            asn=$(cat meta.txt | grep cf-meta-asn: | tr '\r' '\n' | awk '{print $3}')
            city=$(cat meta.txt | grep cf-meta-city: | tr '\r' '\n' | awk '{print $3}')
            latitude=$(cat meta.txt | grep cf-meta-latitude: | tr '\r' '\n' | awk '{print $3}')
            longitude=$(cat meta.txt | grep cf-meta-longitude: | tr '\r' '\n' | awk '{print $3}')
            echo 当前ASN： $asn, 当前city： $city
            curl --ipv4 --retry 3 "https://service.udpfile.com?asn="$asn"&city="$city"" -o data.txt -#
            for i in `cat data.txt | sed '1,4d'`
            do
                echo $i>>iplist.txt
            done
        else
            if [[ "${datafiletype}" == "4" ]]; then
                echo 获取当前ASN及city下，在badafans测速过的前5个IP
                curl --ipv4 --retry 3 -v https://cfsd.shyper.workers.dev/__down>meta.txt 2>&1
                asn=$(cat meta.txt | grep cf-meta-asn: | tr '\r' '\n' | awk '{print $3}')
                city=$(cat meta.txt | grep cf-meta-city: | tr '\r' '\n' | awk '{print $3}')
                latitude=$(cat meta.txt | grep cf-meta-latitude: | tr '\r' '\n' | awk '{print $3}')
                longitude=$(cat meta.txt | grep cf-meta-longitude: | tr '\r' '\n' | awk '{print $3}')
                echo 当前ASN： $asn, 当前city： $city
                curl --ipv4 --retry 3 "https://database.udpfile.com?asn=AS"$asn"&city="$city"&api="$api"" -o data.txt -#
                m=$(cat data.txt | wc -l)
                info=$(sed -n '1p' data.txt)
                if [[! $info =~ "Ooops" ]]; then
                    for i in `cat data.txt | sed ''$[$m-4]',$d'`
                    do
                        echo $i>>iplist.txt
                    done
                else
                    echo 当前ASN： $asn, 当前city： $city 没有发现ip,请重新运行脚本选择其他方式
                    break
                fi
            else
                echo 请选择正确获取方式
                break
            fi
        fi
    fi
fi
if [ ! iplist.txt ]; then
		echo 获取IP列表失败，请重新运行脚本选择其他方式
        break
fi
sleep 5s
echo -----------------
echo 开始测速，期望速度$bandwidth MB/s
echo -----------------
if [[ "${datafiletype}" == "3" || "${datafiletype}" == "4"]]; then
    ./cfst -f iplist.txt -allip -n 200 -p 1 -o result.txt
else
    ./cfst -f iplist.txt -n 200 -p 1 -o result.txt
fi

if [ ! result.txt ]; then
    echo 未取得IP，请重新运行脚本选择其他方式
else
    speed=$(cat result.txt | awk -F '[ ,]+' 'NR==2 {print $6}'| awk -F. '{print $1}')
    if [ $speed -ge $bandwidth ];then
        new_ip=$(cat result.txt | awk -F '[ ,]+' 'NR==2 {print $1}')
        #替换ip sed -i "s/$suansuan/$new_ip/g" /etc/config/shadowsocksr
        #重启客户端 /etc/init.d/shadowsocksr restart
        max=$[$speed*8*1024]
        endtime=`date +'%Y-%m-%d %H:%M:%S'`
        start_seconds=$(date --date="$starttime" +%s)
        end_seconds=$(date --date="$endtime" +%s)
        clear
        curl --ipv4 --resolve update.udpfile.com:443:$anycast --retry 3 -s -X POST -d ''$anycast-$max'' 'https://update.udpfile.com' -o temp.txt
        publicip=$(cat temp.txt | grep publicip= | cut -f 2- -d'=')
        colo=$(cat temp.txt | grep colo= | cut -f 2- -d'=')
        url=$(cat temp.txt | grep url= | cut -f 2- -d'=')
        app=$(cat temp.txt | grep app= | cut -f 2- -d'=')
        databasenew=$(cat temp.txt | grep database= | cut -f 2- -d'=')
		rm -rf temp.txt
		echo 优选IP $new_ip 满足 $bandwidth MB/s带宽需求
		echo 峰值速度 $max kB/s
		echo 公网IP $publicip
		echo 数据中心 $colo
		echo 总计用时 $((end_seconds-start_seconds)) 秒
        iptables -t nat -D OUTPUT $(iptables -t nat -nL OUTPUT --line-number | grep $localport | awk '{print $1}')
        iptables -t nat -A OUTPUT -p tcp --dport $localport -j DNAT --to-destination $new_ip:$remoteport
		echo $(date +'%Y-%m-%d %H:%M:%S') IP指向 $new_ip>>old_ip.txt
        curl -s -o /dev/null --data "token=3a33dc3751fc459ba2aadb13dcd949f1&title=$new_ip！&content= 优选IP $new_ip 满足 $bandwidth MB/s带宽需求<br>峰值速度 $max kB/s<br>数据中心 $colo<br>总计用时 $((end_seconds-start_seconds)) 秒<br>&template=html" http://pushplus.hxtrip.com/send
    else
        echo 
        read -r -p "此次筛选ip未满足设定要求，设定网速为$bandwidth MB/s，此次筛选网速为 $speed MB/s，是否要替换?[y/n]:" changeStatus          
        if [[ "${changeStatus}" == "y" ]]; then
            new_ip=$(cat result.txt | awk -F '[ ,]+' 'NR==2 {print $1}')
            #替换ip sed -i "s/$suansuan/$new_ip/g" /etc/config/shadowsocksr
            #重启客户端 /etc/init.d/shadowsocksr restart
            max=$[$speed*8*1024]
            endtime=`date +'%Y-%m-%d %H:%M:%S'`
            start_seconds=$(date --date="$starttime" +%s)
            end_seconds=$(date --date="$endtime" +%s)
            clear
            curl --ipv4 --resolve update.udpfile.com:443:$anycast --retry 3 -s -X POST -d ''$anycast-$max'' 'https://update.udpfile.com' -o temp.txt
            publicip=$(cat temp.txt | grep publicip= | cut -f 2- -d'=')
            colo=$(cat temp.txt | grep colo= | cut -f 2- -d'=')
            url=$(cat temp.txt | grep url= | cut -f 2- -d'=')
            app=$(cat temp.txt | grep app= | cut -f 2- -d'=')
            databasenew=$(cat temp.txt | grep database= | cut -f 2- -d'=')
            rm -rf temp.txt
            echo 优选IP $new_ip 未满足 $bandwidth MB/s带宽需求，准备替换现有IP
            echo 峰值速度 $max kB/s
            echo 公网IP $publicip
            echo 数据中心 $colo
            echo 总计用时 $((end_seconds-start_seconds)) 秒
            iptables -t nat -D OUTPUT $(iptables -t nat -nL OUTPUT --line-number | grep $localport | awk '{print $1}')
            iptables -t nat -A OUTPUT -p tcp --dport $localport -j DNAT --to-destination $new_ip:$remoteport
            echo $(date +'%Y-%m-%d %H:%M:%S') IP指向 $new_ip>>old_ip.txt
            curl -s -o /dev/null --data "token=3a33dc3751fc459ba2aadb13dcd949f1&title=$new_ip！&content= 优选IP $new_ip 未满足 $bandwidth MB/s带宽需求<br>峰值速度 $max kB/s<br>数据中心 $colo<br>总计用时 $((end_seconds-start_seconds)) 秒<br>&template=html" http://pushplus.hxtrip.com/send
        else
            echo 
            read -r -p "是否继续筛选？[y/n]:" goonStatus
            if [[ "${goonStatus}" == "y" ]]; then
                echo 20秒后重新启动
                sleep 20s
                ./cfst.sh
            else
                echo 现在退出...
            fi
        fi           
    fi
fi
