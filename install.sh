#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}hata：${plain} root olarak çalıştırınız！\n" && exit 1

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
    echo -e "${red}Sistem sürümü algılanmadı, lütfen komut dosyası yazarıyla iletişime geçin！${plain}\n" && exit 1
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
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
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
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
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
    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi

    mkdir /usr/local/XrayR/ -p
	cd /usr/local/XrayR/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/XrayR-project/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}XrayR sürümü algılanamadı, Github API sınırının ötesinde olabilir, lütfen daha sonra tekrar deneyin veya yüklenecek XrayR sürümünü manuel olarak belirtin${plain}"
            exit 1
        fi
        echo -e "检测到 XrayR 最新版本：${last_version}，开始安装"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/XrayR-project/XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}XrayR indirilemedi, lütfen sunucunuzun Github'dan dosya indirebildiğinden emin olun${plain}"
            exit 1
        fi
    else
        if [[ $1 == v* ]]; then
            last_version=$1
	else
	    last_version="v"$1
	fi
        url="https://github.com/XrayR-project/XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip"
        echo -e "kurulumu başlat XrayR ${last_version}"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}indirilemedi XrayR ${last_version} Başarısız oldu, bu sürümün mevcut olduğundan emin olun${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    rm /etc/systemd/system/XrayR.service -f
    file="https://github.com/XrayR-project/XrayR-release/raw/master/XrayR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file}
    #cp -f XrayR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    echo -e "${green}XrayR ${last_version}${plain} Kurulum tamamlandı ve açılışta otomatik olarak başlayacak şekilde ayarlandı."
    cp geoip.dat /etc/XrayR/
    cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
        echo -e ""
        echo -e "Yeni kurulum, lütfen önce öğreticiye bakın：https://github.com/XrayR-project/XrayR，Gerekli içeriği yapılandırın"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR başarıyla yeniden başlatıldı ${plain}"
        else
            echo -e "${red}XrayR Başlatılamayabilir, lütfen daha sonra günlük bilgilerini görüntülemek için XrayR günlüğünü kullanın, başlatılamıyorsa, yapılandırma biçimi değiştirilmiş olabilir, lütfen kontrol etmek için wikiye gidin：https://github.com/XrayR-project/XrayR/wiki${plain}"
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

     # 设置节点序号
    echo "Düğüm numarasını ayarla"
    echo ""
    read -p "Sunucu id giriniz:" node_id
    [ -z "${node_id}" ]
    echo "---------------------------"
    echo "Ayarladığınız sunucu id: ${node_id}"
    echo "---------------------------"
    echo ""

    # 选择协议
    echo "Sunucu türünü seçin (varsayılan V2ray)"
    echo ""
    read -p "Lütfen kullandığınız protokolü girin(V2ray, Shadowsocks, Trojan):" node_type
    [ -z "${node_type}" ]
    
    # Girilmezse, varsayılan V2ray'dir.
    if [ ! $node_type ]; then 
    node_type="V2ray"
    fi

    echo "---------------------------"
    echo "Seçtiğiniz protokol ${node_type}"
    echo "---------------------------"
    echo ""

    # 输入域名（TLS）
    echo "alan adınızı girin"
    echo ""
    read -p "Lütfen alan adınızı girin (sunucu.onvao.net) TLS etkin değilse, lütfen Enter'a basın:" node_domain
    [ -z "${node_domain}" ]

    # Varsayılan olarak  sunucu.onvao.net ayarlanacak
    if [ ! $node_domain ]; then 
    node_domain="sunucu.onvao.net"
    fi

    # 写入配置文件
    echo "Yapılandırma dosyası yazmaya çalışılıyor...."
    wget https://cdn.jsdelivr.net/gh/muzaffer72/XrayR-V2Boardson/config.yml -O /etc/XrayR/config.yml
    sed -i "s/NodeID:.*/NodeID: ${node_id}/g" /etc/XrayR/config.yml
    sed -i "s/NodeType:.*/NodeType: ${node_type}/g" /etc/XrayR/config.yml
    sed -i "s/CertDomain:.*/CertDomain: \"${node_domain}\"/g" /etc/XrayR/config.yml
    echo ""
    echo "Yazma tamamlandı, XrayR hizmeti yeniden başlatılmaya çalışılıyor..."
    echo


    curl -o /usr/bin/XrayR -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/XrayR.sh
    chmod +x /usr/bin/XrayR
    ln -s /usr/bin/XrayR /usr/bin/xrayr # 小写兼容
    chmod +x /usr/bin/xrayr

    systemctl daemon-reload
    XrayR restart
    echo "güvenlik duvarı kapatılıyor！"
    echo
    systemctl disable firewalld
    systemctl stop firewalld
    echo "XRAYR Hizmeti yeniden başlatılmıştır, lütfen iyi eğlenceler！"
    echo

    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "Yönetim betiği kullanım yöntemi (xrayr yürütmesiyle uyumlu, büyük/küçük harfe duyarsız): "
    echo "------------------------------------------"
    echo "XrayR                    - Anamenü"
    echo "XrayR start              - Başlat"
    echo "XrayR stop               - Durdur"
    echo "XrayR restart            - Yeniden Başlat"
    echo "XrayR status             - Durum Sorgula"
    echo "XrayR enable             - Aktifleştir"
    echo "XrayR disable            - Pasifleştir"
    echo "XrayR log                - Log"
    echo "XrayR update             - Xrayr Güncelle"
    echo "XrayR update x.x.x       - Belirli sürüme güncelle"
    echo "XrayR config             - Yapılandırma dosyası içeriğini göster"
    echo "XrayR install            - Xrayr  Kur"
    echo "XrayR uninstall          - Xrayr Kaldır"
    echo "XrayR version            - Version sorgula"
    echo "------------------------------------------"
    echo "XrayR Sürümüne Dayalı Tek Adımlı Komut Dosyası"
    echo "Telegram: https://t.me/shadowsocksvpn"
    echo "Github: https://github.com/muzaffer72/XrayR-V2Boardson"
    echo "Powered by Muzaffer Şanlı"
}

echo -e "${green}kurulumu başlat${plain}"
install_base
# install_acme
install_XrayR $1
