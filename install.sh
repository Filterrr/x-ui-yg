#!/bin/bash
export LANG=en_US.UTF-8
sred='\033[5;31m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;36m'
bblue='\033[0;34m'
plain='\033[0m'
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
cur_dir=$(pwd)
if uname -a | grep -Eqi "freebsd"; then
release="freebsd"
else 
red "不支持当前的系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
vsid=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
#if [[ $(echo "$op" | grep -i -E "arch|alpine") ]]; then
if [[ $(echo "$op" | grep -i -E "arch") ]]; then
red "脚本不支持当前的 $op 系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
version=$(uname -r | cut -d "-" -f1)
[[ -z $(systemd-detect-virt 2>/dev/null) ]] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)
case $(uname -m) in
  aarch64) cpu=arm64 ;;
  x86_64|amd64) cpu=amd64 ;;
  *) red "目前脚本不支持$(uname -m)架构" && exit ;;
esac

v4v6(){
v4=$(curl -s4m5 icanhazip.com -k)
v6=$(curl -s6m5 icanhazip.com -k)
}

stop_x-ui() {
    # 设置你想要杀死的nohup进程的命令名
    xui_com="./x-ui run"
    xray_com="bin/xray-$release-$arch -c bin/config.json"
 
    # 使用pgrep查找进程ID
    PID=$(pgrep -f "$xray_com")
 
    # 检查是否找到了进程
    if [ ! -z "$PID" ]; then
        # 找到了进程，杀死它
        kill $PID
    
        # 可选：检查进程是否已经被杀死
        if kill -0 $PID > /dev/null 2>&1; then
            kill -9 $PID
        fi
    fi
    # 使用pgrep查找进程ID
    PID=$(pgrep -f "$xui_com")
 
    # 检查是否找到了进程
    if [ ! -z "$PID" ]; then
        # 找到了进程，杀死它
        kill $PID
    
        # 可选：检查进程是否已经被杀死
        if kill -0 $PID > /dev/null 2>&1; then
            kill -9 $PID
        fi
    fi
}

serinstall(){
green "下载并安装x-ui相关组件……"
stop_x-ui
#last_version=$(curl -Ls "https://api.github.com/repos/yonggekkk/x-ui-yg/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
curl -L -o x-ui-freebsd-amd64.tar.gz -# --retry 2 --insecure https://github.com/yonggekkk/x-ui-yg/releases/download/1.0/x-ui-freebsd-amd64.tar.gz
if [[ -e ./x-ui/ ]]; then
rm ./x-ui/ -rf
fi
tar zxvf x-ui-freebsd-amd64.tar.gz
rm -f x-ui-freebsd-amd64.tar.gz
cd x-ui
chmod +x x-ui bin/xray-freebsd-amd64
cp x-ui.sh ../x-ui.sh
chmod +x ../x-ui.sh
chmod +x x-ui.sh
}

userinstall(){
readp "设置 x-ui 登录用户名（回车跳过为随机6位字符）：" username
sleep 1
if [[ -z ${username} ]]; then
username=`date +%s%N |md5sum | cut -c 1-6`
fi
while true; do
if [[ ${username} == *admin* ]]; then
red "不支持包含有 admin 字样的用户名，请重新设置" && readp "设置 x-ui 登录用户名（回车跳过为随机6位字符）：" username
else
break
fi
done
sleep 1
green "x-ui登录用户名：${username}"
echo
readp "设置 x-ui 登录密码（回车跳过为随机6位字符）：" password
sleep 1
if [[ -z ${password} ]]; then
password=`date +%s%N |md5sum | cut -c 1-6`
fi
while true; do
if [[ ${password} == *admin* ]]; then
red "不支持包含有 admin 字样的密码，请重新设置" && readp "设置 x-ui 登录密码（回车跳过为随机6位字符）：" password
else
break
fi
done
sleep 1
green "x-ui登录密码：${password}"
./x-ui setting -username ${username} -password ${password} >/dev/null 2>&1
}

portinstall(){
echo
readp "设置 x-ui 登录端口[1-65535]（回车跳过为10000-65535之间的随机端口）：" port
sleep 1
if [[ -z $port ]]; then
port=$(shuf -i 10000-65535 -n 1)
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] 
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
fi
sleep 1
./x-ui setting -port $port >/dev/null 2>&1
green "x-ui登录端口：${port}"
}

pathinstall(){
echo
readp "设置 x-ui 登录根路径（回车跳过为随机3位字符）：" path
sleep 1
if [[ -z $path ]]; then
path=`date +%s%N |md5sum | cut -c 1-3`
fi
./x-ui setting -webBasePath ${path} >/dev/null 2>&1
green "x-ui登录根路径：${path}"
}

xuiinstall(){
serinstall
userinstall
portinstall
pathinstall
crontab -l > x-ui.cron
sed -i "" "/x-ui.log/d" x-ui.cron
echo "0 0 * * * cd $cur_dir/x-ui && cat /dev/null > x-ui.log" >> x-ui.cron
echo "@reboot cd $cur_dir/x-ui && nohup ./x-ui run > ./x-ui.log 2>&1 &" >> x-ui.cron
crontab x-ui.cron
rm x-ui.cron
nohup ./x-ui run > ./x-ui.log 2>&1 &
}


show_menu(){
clear
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "甬哥Github项目  ：github.com/yonggekkk"
white "甬哥Blogger博客 ：ygkkk.blogspot.com"
white "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "x-ui-yg脚本快捷方式：x-ui"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
green " 1. 一键安装 x-ui"
green " 2. 删除卸载 x-ui"
green " 3. 变更 x-ui 面板设置 【用户名密码、登录端口、根路径、还原面板】"
echo "----------------------------------------------------------------------------------"
green " 4. 查看 x-ui 运行日志"
green " 0. 退出脚本"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
echo -e "VPS状态如下："
echo -e "系统:$blue$op$plain  \c";echo -e "内核:$blue$version$plain  \c";echo -e "处理器:$blue$cpu$plain  \c";echo -e "虚拟化:$blue$vi$plain  \c";echo -e "BBR算法:$blue$bbr$plain"
v4v6
echo -e "本地IPV4地址：$blue$vps_ipv4$w4$plain
echo "------------------------------------------------------------------------------------"
show_status
echo "------------------------------------------------------------------------------------"
acp=$(./x-ui setting -show 2>/dev/null)
if [[ -n $acp ]]; then
if [[ $acp == *admin*  ]]; then
red "x-ui出错，请选择4重置用户名密码或者卸载重装x-ui"
else
xpath=$(echo $acp | awk '{print $8}')
xport=$(echo $acp | awk '{print $6}')
xip1=$(cat x-ui/xip 2>/dev/null | sed -n 1p)
if [ "$xpath" == "/" ]; then
pathk="$sred【严重安全提示: 请进入面板设置，添加url根路径】$plain"
fi
echo -e "x-ui登录信息如下："
echo -e "$blue$acp$pathk$plain" 
xuimb="http://${xip1}:${xport}${xpath}"
#echo -e "$blue登录地址(裸IP泄露模式-非安全)：$xuimb$plain"
fi
else
echo -e "x-ui登录信息如下："
echo -e "$red未安装x-ui，无显示$plain"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
echo
readp "请输入数字【0-13】:" Input
case "$Input" in     
 1 ) check_uninstall && xuiinstall;;
 2 ) check_install && uninstall;;
 3 ) check_install && xuichange;;
 4 ) check_install && show_log;;
 * ) exit 
esac
}
show_menu
