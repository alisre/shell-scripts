#!/bin/bash
speed_test_log="/tmp/speed_test.log"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
PLAIN='\033[0m'
function logger() {
  TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')
  case "$1" in
    debug)
      echo -e "$TIMESTAMP \033[36mDEBUG\033[0m $2" 
      ;;  
    info)
      echo -e "$TIMESTAMP \033[30;32mINFO\033[0m $2" 
      ;;  
    warn)
      echo -e "$TIMESTAMP \033[33mWARN\033[0m $2" 
      ;;  
    error)
      echo -e "$TIMESTAMP \033[30;31mERROR\033[0m $2"  && exit 1
      ;;  
    *)  
      ;;  
  esac
}

function StartTitle() {
    [ -z "${SOURCE}" ] && clear
    echo -e ' +-----------------------------------+'
    echo -e " | \033[0;1;35;95m⡇\033[0m  \033[0;1;33;93m⠄\033[0m \033[0;1;32;92m⣀⡀\033[0m \033[0;1;36;96m⡀\033[0;1;34;94m⢀\033[0m \033[0;1;35;95m⡀⢀\033[0m \033[0;1;31;91m⡷\033[0;1;33;93m⢾\033[0m \033[0;1;32;92m⠄\033[0m \033[0;1;36;96m⡀⣀\033[0m \033[0;1;34;94m⡀\033[0;1;35;95m⣀\033[0m \033[0;1;31;91m⢀⡀\033[0m \033[0;1;33;93m⡀\033[0;1;32;92m⣀\033[0m \033[0;1;36;96m⢀⣀\033[0m |"
    echo -e " | \033[0;1;31;91m⠧\033[0;1;33;93m⠤\033[0m \033[0;1;32;92m⠇\033[0m \033[0;1;36;96m⠇⠸\033[0m \033[0;1;34;94m⠣\033[0;1;35;95m⠼\033[0m \033[0;1;31;91m⠜⠣\033[0m \033[0;1;33;93m⠇\033[0;1;32;92m⠸\033[0m \033[0;1;36;96m⠇\033[0m \033[0;1;34;94m⠏\033[0m  \033[0;1;35;95m⠏\033[0m  \033[0;1;33;93m⠣⠜\033[0m \033[0;1;32;92m⠏\033[0m  \033[0;1;34;94m⠭⠕\033[0m |"
    echo -e ' +-----------------------------------+'
    logger info ' 欢迎使用 GNU/Linux 更换系统软件源脚本'
}

mirror_list_cn=(
    "mirrors.163.com"
    "mirrors.aliyun.com"
    "mirrors.tencent.com"
    "mirrors.huaweicloud.com"
    "mirrors.sohu.com"
    "mirrors.tuna.tsinghua.edu.cn"
    "mirrors.jlu.edu.cn"
    "mirror.bjtu.edu.cn"
    "mirrors.yun-idc.com"
    "mirrors.zju.edu.cn"
    "mirrors.neusoft.edu.cn"
    "mirrors.nju.edu.cn"
    "mirror.lzu.edu.cn"
    "mirror.sjtu.edu.cn"
    "mirrors.ustc.edu.cn"
    "mirror.iscas.ac.cn"
)

## check permission
function PermissionJudgment() {
    if [[ "$EUID" -ne '0' || $(id -u) != '0' ]]; then
        logger error "This script must be executed as root!"
    fi
}

## check if url is connected
function CheckConnect(){
    [ -z $1 ] && logger error "input is null" && exit 2
    Url=$1
    Code=`curl -f --connect-timeout 5 --retry 3 --location --insecure -I -m 10 -o /dev/null -s -w %{http_code} "$Url"`
    if [[ "$Code" == 200 ]];then
       return
    else
       return 1
    fi
}

## check if location is in CN
function CheckCN(){
    if CheckConnect http://dash.cloudflare.com/cdn-cgi/trace ;then
        curl --insecure --connect-timeout 3 --retry 3 --location  -f -s http://dash.cloudflare.com/cdn-cgi/trace | grep -qx 'loc=CN'
        if [ $? -eq 0 ];then
            IsCN=true
        fi
    elif CheckConnect ipinfo.io; then
        curl --insecure --connect-timeout 3 --retry 3 --location  -f -s ipinfo.io | grep "\"country\": \"CN\""
        if [ $? -eq 0 ];then
            IsCN=true
        fi
    fi
}

function GithubProxy(){
    if [ $IsCN == true ];then
        GithubProxy=https://mirror.ghproxy.com/https://raw.githubusercontent.com/
    else
        GithubProxy=https://raw.githubusercontent.com/
    fi
    echo "$GithubProxy"
}

function CheckOsType(){
    OS=$(cat /etc/os-release | grep -E "^NAME=" | awk -F '=' '{print$2}' | sed "s/[\'\"]//g"|awk '{print $1}')
    OS_Version=$(cat /etc/os-release  | grep -E "^VERSION_ID=" | awk -F '=' '{print$2}' | sed "s/[\'\"]//g")
    CodeName=$(cat /etc/os-release |grep -E "^VERSION_CODENAME" | awk -F '=' '{print$2}')
    cat /etc/os-release | grep "PRETTY_NAME=" -q && System_Pretty_Name="$(cat /etc/os-release | grep -E "^PRETTY_NAME=" | awk -F '=' '{print$2}' | sed "s/[\'\"]//g")"
    if [[ -z $OS ]] || [[ -z $OS_Version ]]; then
            logger error  "This OS seems to be  an unsupported distribution.Supported distros are Ubuntu, Debian, AlmaLinux, Rocky Linux, CentOS and Fedora."
    fi
    case "$OS" in
        Debian)
            if [[ "${OS_Version:0:1}" != [8-9] && "${OS_Version:0:2}" != 1[0-3] ]]; then
                logger error "The system version is not supported"
            fi
        ;;
        Ubuntu)
            if [[ "${OS_Version:0:2}" != 1[4-9] && "${OS_Version:0:2}" != 2[0-4] ]]; then
                logger error "The system version is not supported"
            fi
        ;;
        CentOS)
            if [[ "${OS_Version:0:1}" != [7-9] ]]; then
                logger error "The system version is not supported"
            fi
        ;;
        "CentOS Stream"|Rocky|AlmaLinux)
            if [[ "${OS_Version:0:1}" != [8-9] ]]; then
                logger error "The system version is not supported"
            fi
        ;;
        Fedora)
            if [[ "${OS_Version:0:2}" != [3-4][0-9] ]]; then
                logger error "The system version is not supported"
            fi
        ;;
        Red)
            if [[ "${OS_Version:0:1}" != [7-9] ]]; then
                logger error "The system version is not supported"
            fi
        ;;
    esac
    ## 判定系统处理器架构
    case "$(uname -m)" in
    x86_64)
        DEVICE_ARCH="x86_64"
        ;;
    aarch64)
        DEVICE_ARCH="ARM64"
        ;;
    armv7l)
        DEVICE_ARCH="ARMv7"
        ;;
    armv6l)
        DEVICE_ARCH="ARMv6"
        ;;
    i686)
        DEVICE_ARCH="x86_32"
        ;;
    *)
        DEVICE_ARCH="$(uname -m)"
        ;;
    esac

    Source_Branch="${OS,,}"
    Source_Branch="${Source_Branch// /-}"
    case "${OS}" in
        Debian)
            case ${OS_Version:0:1} in
            8 | 9)
                Source_Branch="debian-archive"
                ;;
            *)
                Source_Branch="debian"
                ;;
            esac
            ;;
        CentOS)
            if [[ "${DEVICE_ARCH}" == "x86_64" ]]; then
                Source_Branch="centos"
            else
                Source_Branch="centos-altarch"
            fi
            ;;
        Ubuntu)
            if [[ "${DEVICE_ARCH}" == "x86_64" ]] || [[ "${DEVICE_ARCH}" == *i?86* ]]; then
                Source_Branch="ubuntu"
            else
                Source_Branch="ubuntu-ports"
            fi
            ;;
        "CentOS Stream")
            case ${OS_Versio:0:1} in
            8)
                if [[ "${DEVICE_ARCH}" == "x86_64" ]]; then
                    Source_Branch="centos"
                else
                    Source_Branch="centos-altarch"
                fi
                ;;
            *)
                Source_Branch="centos-stream"
                ;;
            esac
            ;;
        Red)
            case ${OS_Version:0:1} in
            9)
                Source_Branch="rocky"
                ;;
            *)
                Source_Branch="centos"
                ;;
            esac
            ;;
        Arch)
            if [[ "${DEVICE_ARCH}" == "x86_64" ]] || [[ "${DEVICE_ARCH}" == *i?86* ]]; then
                Source_Branch="archlinux"
            else
                Source_Branch="archlinuxarm"
            fi
            ;;
    esac
}

function CheckCloudVendors(){
    ORG=$(curl --insecure --connect-timeout 5 --retry 3 --location  -f -s ipinfo.io | grep "\"org\":")
    if [ $IsCN == true ] && echo $ORG |grep Tencent > /dev/null 2>&1;then
        CloudVendor=Tencent
    elif [ $IsCN == true ] && echo $ORG |grep Alibaba > /dev/null 2>&1 ;then
        CloudVendor=Alibaba
    elif [ $IsCN == true ] && echo $ORG |grep Huawei > /dev/null 2>&1;then
        CloudVendor=Huawei
    elif [ $IsCN == true ] ;then
        CloudVendor=Other
    fi
}
## 选择软件源
function ChooseMirrors() {
    mirrors_speedtest_curl() {
        local output=$(timeout 60 curl -l --insecure --connect-timeout 5 --retry 3 -o /dev/null -s -w '%{speed_download}\t%{size_download}\t%{time_total}\n' "$1" 2>&1)
        local speed=$(printf '%s' "$output"| awk '{printf "%.2f",$1/1024/1024}')
        local time=$(printf '%s' "$output" | awk '{printf "%.2f",$3}')
        local size=$(printf '%s' "$output" | awk '{printf "%.1f",$2/1024/1024}')
        [ -z "$speed" ] && speed=0KB/s time=60s size=null
        printf "${YELLOW}%-30s${CYAN}%-18s${PLAIN}%-25s${RED}%-10s${PLAIN}\n" "$2"  "${size}" "${time}" "${speed}"
        echo "$2  $speed" >>$speed_test_log
    }

    function CheckSpeed(){
        local fast_mirror
        local mirs=()
        local list_arr_sum
        list_arr_sum="$(eval echo $@)"
        mirs=($list_arr_sum)
        [ -z ${mirs[0]} ] && logger error "input mirros is null"
        [ -f "$speed_test_log" ] && rm -rf $speed_test_log
        printf "%-30s%-15s%-25s%-14s\n" "Site Name" "File Size(MB)" "Download Time(s)" "Download Speed(MB/s)"
        for i in ${mirs[@]};do
            if CheckConnect $i/$Source_Branch/;then
                mirrors_speedtest_curl "${i}/centos/filelist.gz" ${i}
            fi
        done
    }
    function Title() {
        local system_name="${System_Pretty_Name:-"${OS} ${OS_Version}"}"
        local arch="${DEVICE_ARCH}"
        local date_time time_zone
        date_time="$(date "+%Y-%m-%d %H:%M:%S")"
        time_zone="$(timedatectl status 2>/dev/null | grep "Time zone" | awk -F ':' '{print$2}' | awk -F ' ' '{print$1}')"

        logger info ''
        logger info " 运行环境 ${system_name} ${arch}"
        logger info " 系统时间 ${date_time} ${time_zone}"
    }
    Title
    local Mirrors
    if [[ "$IsCN" == "true" ]]; then
        case "$CloudVendor" in 
            Tencent)
                Mirrors="mirrors.tencentyun.com"
                fast_mirror="$Mirrors"
            ;;
            Alibaba)
                Mirrors="mirrors.cloud.aliyuncs.com"
                fast_mirror="$Mirrors"
            ;;
            Huawei)
                Mirrors="mirrors.myhuaweicloud.com"
                fast_mirror="$Mirrors"
            ;;
            Other)
                Mirrors="${mirror_list_cn[@]}"
                CheckSpeed $Mirrors
                sort -k 2 -n -r -o $speed_test_log $speed_test_log
                fast_mirror=$(head -n 1 $speed_test_log | cut -d ' ' -f1)
            ;;
        esac
        logger info "The fastest mirror is $fast_mirror"
    fi

}

function ChangeDebianMirror(){
    mirror=$(cat /etc/apt/sources.list |grep -E '^deb http' |awk -F'/' '{print $3}'|head -1)
    if [[ "$mirror" == "$fast_mirror" ]];then
        logger warn "The mirror is already $fast_mirror"
        exit 0
    fi
    cp /etc/apt/sources.list /etc/apt/sources.list.$(date "+%Y%m%d$s%H%M%S").bak 
    case "$OS_Version" in
        8 | 9 | 10 | 11)
            source_suffix="main contrib non-free"
        ;;
        *)
            source_suffix="main contrib non-free non-free-firmware"
        ;;
    esac
    echo "${tips} 
deb ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName} ${source_suffix} 
# deb-src ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName} ${source_suffix}  
deb ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName}-updates ${source_suffix} 
# deb-src ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName}-updates ${source_suffix} 
deb ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName}-backports ${source_suffix} 
# deb-src ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName}-backports ${source_suffix} 
deb ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName}-security ${source_suffix}" >/etc/apt/sources.list
    apt-get update -y
}
function ChangeUbuntuMirror(){
    mirror=$(cat /etc/apt/sources.list |grep -E '^deb http' |awk -F'/' '{print $3}'|head -1)
    if [[ "$mirror" == "$fast_mirror" ]];then
        logger warn "The mirror is already $fast_mirror"
        exit 0
    fi
    cp /etc/apt/sources.list /etc/apt/sources.list.$(date "+%Y%m%d$s%H%M%S").bak 
    source_suffix="main restricted universe multiverse"
    echo "${tips}
deb ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName} ${source_suffix} 
# deb-src ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName} ${source_suffix}  
deb ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName}-updates ${source_suffix} 
# deb-src ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName}-updates ${source_suffix} 
deb ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName}-backports ${source_suffix} 
# deb-src ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName}-backports ${source_suffix} 
deb ${WebProtocol}${fast_mirror}/${Source_Branch}/ ${CodeName}-security ${source_suffix}" >/etc/apt/sources.list
    apt-get update -y
}
function ChangeRedMirror(){
    case "${OS}" in
        Rocky)
            case ${OS_Version:0:1} in
                8)
                   sed -e 's|^mirrorlist=|#mirrorlist=|g' \
-e "s|^#baseurl=http://dl.rockylinux.org/\$contentdir|baseurl=${WebProtocol}${fast_mirror}/${Source_Branch}|g" \
-i.bak \
/etc/yum.repos.d/Rocky-AppStream.repo \
/etc/yum.repos.d/Rocky-BaseOS.repo \
/etc/yum.repos.d/Rocky-Extras.repo \
/etc/yum.repos.d/Rocky-PowerTools.repo
               ;;
               9)
                   sed -e 's|^mirrorlist=|#mirrorlist=|g' \
-e "s|^#baseurl=http://dl.rockylinux.org/\$contentdir|baseurl=${WebProtocol}${fast_mirror}/${Source_Branch}|g" \
-i.bak \
/etc/yum.repos.d/rocky-extras.repo \
/etc/yum.repos.d/rocky.repo
               ;;
            esac
            dnf makecache
        ;;
        AlmaLinux)
            sed -e 's|^mirrorlist=|#mirrorlist=|g' \
-e "s|^# baseurl=https://repo.almalinux.org|baseurl=${WebProtocol}${fast_mirror}|g" \
-i.bak \
/etc/yum.repos.d/almalinux*.repo
        ;;
        Centos)
            case ${OS_Version:0:1} in
                7)
                    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
-e "s|^#baseurl=http://mirror.centos.org/centos|baseurl=${WebProtocol}${fast_mirror}/${Source_Branch}|g" \
-i.bak \
/etc/yum.repos.d/CentOS-*.repo
                ;;
                8)
                    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
-e 's|^#baseurl=http://mirror.centos.org/$contentdir|baseurl=${WebProtocol}${fast_mirror}/${Source_Branch}|g' \
-i.bak \
/etc/yum.repos.d/CentOS-*.repo
                ;;
            esac
            yum makecache
        ;;
        "CentOS Stream")   
            sed -i.bak \
-e 's|^mirrorlist=|#mirrorlist=|' \ 
-e 's|^#baseurl=|baseurl=|' \ 
-e 's|http://mirror.centos.org|${WebProtocol}${fast_mirror}|' \ 
/etc/yum.repos.d/CentOS-*.repo
            yum clean all && yum makecache
        ;; 
    esac
    
}
function UpdateMirrors() {
    if [[ "$CloudVendor" != "Other" ]];then
        WebProtocol="http://"
    else
        WebProtocol="https://"
    fi
    local tips="## 默认禁用源码镜像以提高速度，如需启用请自行取消注释"
    case "${OS}" in
        Debian)
            ChangeDebianMirror
        ;;    
        Ubuntu)
            ChangeUbuntuMirror
        ;;
        Red | CentOS |Rocky|AlmaLinux| "CentOS Stream")
            cp -a /etc/yum.repos.d /etc/yum.repos.d.$(date "+%Y%m%d$s%H%M%S").bak 
            ChangeRedMirror
        ;;
        Arch)
            cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.$(date "+%Y%m%d$s%H%M%S").bak 
            sed -i "1i\Server = ${WebProtocol}${fast_mirror}/${Source_Branch}/\$repo/os/\$arch" /etc/pacman.d/mirrorlist
            pacman -Syyu
        ;;
    esac
    
}
function RunEnd() {
    logger info "---------- Finish the update mirror ----------"
}
function Combin_Function() {
    PermissionJudgment
    CheckCN
    CheckOsType
    CheckCloudVendors
    StartTitle
    ChooseMirrors
    UpdateMirrors
    RunEnd
}

#CommandOptions "$@"
Combin_Function