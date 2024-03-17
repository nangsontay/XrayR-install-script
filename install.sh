#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error：${plain} This script must be run as root user!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact the script author! ${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}Architecture detection failed, using default architecture: ${arch}${plain}"
fi

echo "Architecture: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "This software does not support 32-bit systems (x86), please use a 64-bit system (x86_64). If there is an error in detection, please contact the author."
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher version of the system! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher version of the system.！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher version of the system.！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed

check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_XrayR() {
    echo "Currently support SSPanel only"
    echo "Please enter API Host link:"
    read Api_Host
    echo "Please enter API Key:"
    read Api_Key
    echo "Please enter node number:"
    read node_num
    echo "Please enter node type (Node type: V2ray, Shadowsocks, Trojan, Shadowsocks-Plugin): "
    read node_type
    echo "Do you want to enable ProxyProtocol? (Y/N)"
    read choice_proxy_protocol
    if [[ $choice_proxy_protocol == "Y" || $choice_proxy_protocol == "y" ]]; then
        proxy_protocol="true"
        echo "Which version of ProxyProtocol do you want to send? (0/1/2, 0 for default(unsend))"
        read proxy_protocol_version
    else
        proxy_protocol="false"
    fi

    wget -qO- --no-check-certificate https://github.com/nangsontay/XrayR-install-script/raw/master/install_key.sh | bash
    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi

    mkdir /usr/local/XrayR/ -p
	  cd /usr/local/XrayR/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/zeropanel/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 XrayR 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 XrayR 版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 XrayR 最新版本：${last_version}，开始安装"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/nangsontay/XrayR-install-script/raw/master/xrayr_stable.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 XrayR 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        if [[ $1 == v* ]]; then
            last_version=$1
	else
	    last_version="v"$1
	fi
        url="https://github.com/nangsontay/XrayR-install-script/raw/master/xrayr_stable.zip"
        echo -e "Installing XrayR ${last_version}"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red} Failed to download XrayR ${last_version}. please submit issue on Github.${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    rm /etc/systemd/system/XrayR.service -f
    file="https://github.com/zeropanel/XrayR-release/raw/master/XrayR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file}
    #cp -f XrayR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    echo -e "${green}XrayR ${last_version}${plain} 安装完成，已设置开机自启"
    cp geoip.dat /etc/XrayR/
    cp geosite.dat /etc/XrayR/ 
    # Start modifying config file by user input
    if [[ ! -f /etc/XrayR/config.yml ]]; then
    sed -i "s/NodeID: \"\"/NodeID: \"${node_num}\"/" config.yml
    sed -i "s/ApiHost: \"\"/ApiHost: \"${Api_Host}\"/" config.yml
    sed -i "s/ApiKey: \"\"/ApiKey: \"${Api_Key}\"/" config.yml
    sed -i "s/NodeType: \"\"/NodeType: \"${node_type}\"/" config.yml
    if [[ $proxy_protocol == "true" ]]; then
      sed -i "s/ProxyProtocol: false/ProxyProtocol: true/" config.yml
    fi
    sed -i "s/ProxyProtocolVer: 0/ProxyProtocolVer: \"${proxy_protocol_version}\"/" config.yml
        cp config.yml /etc/XrayR/
        echo -e ""
        echo -e "For a new installation, please first refer to the tutorial: https://github.com/zeropanel/XrayR, and configure the necessary content in the configuration file: /etc/XrayR/config.yml"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR restarted successfully${plain}"
        else
            echo -e "${red}XrayR may have failed to start, please use XrayR log to check the log information later. If it cannot start, the configuration format may be changed, please go to the wiki to check: https://github.com/zeropanel/XrayR/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/XrayR/dns.json ]]; then
        cp dns.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/route.json ]]; then
        cp route.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/rulelist ]]; then
        cp rulelist /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/fuzzypn.crt ]]; then
        cp fuzzypn.crt /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/fuzzypn.key ]]; then
        cp fuzzypn.key /etc/XrayR/
    fi
    curl -o /usr/bin/XrayR -Ls https://github.com/nangsontay/XrayR-install-script/raw/master/XrayR.sh
    chmod +x /usr/bin/XrayR
    ln -s /usr/bin/XrayR /usr/bin/xrayr # 小写兼容
    chmod +x /usr/bin/xrayr
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "Usage of XrayR management script (XRayR or xrayr): "
    echo "------------------------------------------"
    echo "XrayR                    - Display management menu (more features)"
    echo "XrayR start              - Start XrayR"
    echo "XrayR stop               - Stop XrayR"
    echo "XrayR restart            - Restart XrayR"
    echo "XrayR status             - Check XrayR status"
    echo "XrayR enable             - Set XrayR to start on boot"
    echo "XrayR disable            - Cancel XrayR start on boot"
    echo "XrayR log                - Check XrayR logs"
    echo "XrayR update             - Update XrayR"
    echo "XrayR update x.x.x       - Update to specific version of XrayR"
    echo "XrayR config             - Display content of configuration file"
    echo "XrayR install            - Install XrayR"
    echo "XrayR uninstall          - Uninstall XrayR"
    echo "XrayR version            - Check XrayR version"
    echo "------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
# install_acme
install_XrayR $1
