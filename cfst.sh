#!/bin/bash
clear
localport=8443
remoteport=443

if [ ! -f "cfst" ]; then
    echo 未发现测速程序cfst，开始下载
    wget https://gh-proxy.shyper.workers.dev/https://github.com/shyperwang/cfst/releases/latest/download/cfst-linux-mips32le.zip
    unzip cfst-linux-mips32le && chmod +x cfst
    rm -rf cfst-linux-mips32le.zip
    echo cfst测速程度下载完毕，准备开始测速
fi

declare -i speed
declare -i bandwith
declare -i n
declare -i m
declare -i datatype
declare -i count

datatype=0
api=`date +'%Y%m%d'`
starttime=`date +'%Y-%m-%d %H:%M:%S'`

testtype(){
clear
rm -rf iplist.txt data.txt meta.txt result.txt
echo
read -p "请设定期望下载速度（MB/s）：" bandwidth
clear
echo ----------------------------------------------
echo 开始筛测速，期望下载速度：$bandwidth MB/s
echo 当前时间：$starttime
echo ----------------------------------------------
echo CF节点IP列表获取方式
echo 1、xiu2原始方式获取IP列表，产生随机IP
echo 2、badafans获取IP列表，产生随机IP
echo 3、透过ASN及city从badafans获取生成的随机IP
echo 4、获取当前ASN及city下，在badafans测速过的前5个IP
echo ----------------------------------------------
read -r -p "选择CF节点IP列表获取方式？[1/2/3/4]:" datafiletype
if [[ "${datafiletype}" == "1" ]]; then
    echo 通过xiu2原始方式获取IP
    curl --retry 3 https://raw.githubusercontent.com/XIU2/CloudflareSpeedTest/master/ip.txt -o iplist.txt -#
    datatype=1
else
    if [[ "${datafiletype}" == "2" ]]; then
        echo badafans获取IP列表，产生随机IP
        curl --ipv4 --retry 3 https://update.freecdn.workers.dev -o data.txt -#
        for i in `cat data.txt | sed '1,7d'`
        do
            randomip=$(($RANDOM%256))
            echo 生成随机IP $i$randomip
            echo $i$randomip/24>>iplist.txt
        done
        datatype=2
    else
        if [[ "${datafiletype}" == "3" ]]; then
            echo 透过ASN及city从badafans获取生成的随机IP
            curl --ipv4 --retry 3 -v https://cfst.shyper.workers.dev/__down>meta.txt 2>&1
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
      	    datatype=3
        else
            if [[ "${datafiletype}" == "4" ]]; then
                echo 获取当前ASN及city下，在badafans测速过的前5个IP
                curl --ipv4 --retry 3 -v https://cfst.shyper.workers.dev/__down>meta.txt 2>&1
                asn=$(cat meta.txt | grep cf-meta-asn: | tr '\r' '\n' | awk '{print $3}')
                city=$(cat meta.txt | grep cf-meta-city: | tr '\r' '\n' | awk '{print $3}')
                latitude=$(cat meta.txt | grep cf-meta-latitude: | tr '\r' '\n' | awk '{print $3}')
                longitude=$(cat meta.txt | grep cf-meta-longitude: | tr '\r' '\n' | awk '{print $3}')
                echo 当前ASN：$asn, 当前city：$city
                curl --ipv4 --retry 3 "https://database.udpfile.com?asn=AS"$asn"&city="$city"&api="$api"" -o data.txt -#
                m=$(cat data.txt | wc -l)
                info=$(sed -n '1p' data.txt)
                if [[ ! "$info" =~ "Ooops" ]]; then
                    for i in `cat data.txt | sed ''$[$m-3]',$d'`
                    do
                        echo $i>>iplist.txt
                    done
                else
                    echo 当前ASN： $asn, 当前city： $city 没有发现ip,请重新运行脚本选择其他方式
                    break
                fi
                datatype=4
            else
                datatype=0
                echo 请选择正确获取方式
                testtype
            fi
        fi
    fi
fi
if [ ! -f "iplist.txt" ]; then
		echo 获取IP列表失败，请重新运行脚本选择其他方式
        exit 0
fi
sleep 3s
speedtest
}
speedtest(){
echo -----------------
echo 开始测速，期望速度$bandwidth MB/s
echo -----------------
if [ $datatype == "3" ]||[ $datatype == "4" ]; then
    ./cfst -f iplist.txt -allip -tl 500 -sl 0.01 -p 1 -o result.txt
else
    ./cfst -f iplist.txt -tl 500 -sl $bandwidth  -dn 3 -p 1 -o result.txt
fi
result
}
result(){
sleep 1s
if [ ! -f "result.txt" ]; then
    echo 未取得IP，请重新运行脚本选择其他方式
else
    speed=$(cat result.txt | awk -F '[ ,]+' 'NR==2 {print $6}'| awk -F. '{print $1}')
    if [ $speed -ge $bandwidth ];then
        new_ip=$(cat result.txt | awk -F '[ ,]+' 'NR==2 {print $1}')
        max=$[$speed*1024]
        endtime=`date +'%Y-%m-%d %H:%M:%S'`
        start_seconds=$(date --date="$starttime" +%s)
        end_seconds=$(date --date="$endtime" +%s)
        clear
        curl --ipv4 --resolve update.udpfile.com:443:$new_ip --retry 3 -s -X POST -d ''$new_ip-$max'' 'https://update.udpfile.com' -o temp.txt
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
        exit 0
    else
        echo 
        read -r -p "此次筛选ip未满足设定要求，设定网速为$bandwidth MB/s，此次筛选网速为 $speed MB/s，是否要替换?[y/n]:" changeStatus          
        if [[ "${changeStatus}" == "y" ]]; then
            new_ip=$(cat result.txt | awk -F '[ ,]+' 'NR==2 {print $1}')
            max=$[$speed*1024]
            endtime=`date +'%Y-%m-%d %H:%M:%S'`
            start_seconds=$(date --date="$starttime" +%s)
            end_seconds=$(date --date="$endtime" +%s)
            clear
            curl --ipv4 --resolve update.udpfile.com:443:$new_ip --retry 3 -s -X POST -d ''$new_ip-$max'' 'https://update.udpfile.com' -o temp.txt
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
            exit 0
        else
            echo 
            read -r -p "是否继续筛选？[y/n]:" goonStatus
            if [[ "${goonStatus}" == "y" ]]; then
                echo --------------------
                echo 1、现有模式重新测试
                echo 2、重新选择模式测试
                echo --------------------
                read -r -p "请选择继续测速方式？[1/2]:" goonType
                if [[ "${goonType}" == "1" ]]; then
                    echo 现有模式重新测试，20秒后重新启动
                    sleep 20s
                    speedtest
                else
                    if [[ "${goonType}" == "2" ]]; then
                        echo 重新选择模式测试，20秒后重新启动
                        sleep 20s
                        testtype
                    else
                        echo 选择错误，现在退出...
                        exit 0
                    fi
                fi
            else
                echo 现在退出...
                exit 0
            fi
        fi           
    fi
fi
}
testtype 1
speedtest 2
result 3