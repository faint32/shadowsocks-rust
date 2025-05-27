#!/usr/bin/env bash
Green="\033[32m" && Red="\033[31m" && GreenBG="\033[42;37m" && RedBG="\033[41;37m" && NC="\033[0m" && YellowColor="\033[0;33m"
Info="${Green}[信息]${NC}"
Error="${Red}[错误]${NC}"
Tip="${YellowColor}[注意]${NC}"

Dir=$(dirname $(readlink -f $0))
cd $Dir

FOLDER="${HOME}/.ss_config"
CONF="$FOLDER/config.json"

DockerImg="teddysun/shadowsocks-rust"
DockerImage="${DockerImg}:alpine"
Hub="ss-rust"
default_port="33333"

API_URL="https://hub.docker.com/v2/repositories/teddysun/shadowsocks-rust"
latest_ver=`curl -s $API_URL | grep -oP 'alpine-\K[0-9.]+' | head -n 1`


SetPort(){
	while true
		do
		echo -e "${Tip} 本步骤不涉及系统防火墙端口操作，请手动放行相应端口！"
		echo -e "请输入对外开放端口 [1-65535]"
		read -e -p "(默认：${default_port})：" port
		[[ -z "${port}" ]] && port="${default_port}"
		echo $((${port}+0)) &>/dev/null
		if [[ $? -eq 0 ]]; then
			if [[ ${port} -ge 1 ]] && [[ ${port} -le 65535 ]]; then
				echo && echo "=================================="
				echo -e "端口：${Red_background_prefix} ${port} ${NC}"
				echo "==================================" && echo
				break
			else
				echo "输入错误, 请输入正确的端口。"
			fi
		else
			echo "输入错误, 请输入正确的端口。"
		fi
		done
}
SetTFO(){
	echo -e "是否开启 TCP Fast Open ？
==================================
${Green} 1.${NC} 开启  ${Green} 2.${NC} 关闭
=================================="
	read -e -p "(默认：1.开启)：" tfo
	[[ -z "${tfo}" ]] && tfo="1"
	if [[ ${tfo} == "1" ]]; then
		tfo=true
	else
		tfo=false
	fi
	echo && echo "=================================="
	echo -e "TCP Fast Open 开启状态：${Red_background_prefix} ${tfo} ${NC}"
	echo "==================================" && echo
}
SetPassword(){
	echo "请输入 Shadowsocks Rust 密码 [0-9][a-z][A-Z]"
	read -e -p "(默认：随机生成)：" password
	[[ -z "${password}" ]] && password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
	echo && echo "=================================="
	echo -e "密码：${Red_background_prefix} ${password} ${NC}"
	echo "==================================" && echo
}
SetCipher(){
	echo -e "请选择 Shadowsocks Rust 加密方式
==================================
 ${Green} 1.${NC} chacha20-ietf-poly1305 ${Green}(推荐)${NC}
 ${Green} 2.${NC} aes-128-gcm ${Green}(推荐)${NC}
 ${Green} 3.${NC} aes-256-gcm ${Green}(默认)${NC}
 ${Green} 4.${NC} plain ${Red}(不推荐)${NC}
 ${Green} 5.${NC} none ${Red}(不推荐)${NC}
 ${Green} 6.${NC} table
 ${Green} 7.${NC} aes-128-cfb
 ${Green} 8.${NC} aes-256-cfb
 ${Green} 9.${NC} aes-256-ctr
 ${Green}10.${NC} camellia-256-cfb
 ${Green}11.${NC} rc4-md5
 ${Green}12.${NC} chacha20-ietf
==================================
 ${Tip} AEAD 2022 加密（须v1.15.0及以上版本且密码须经过Base64加密）
==================================
 ${Green}13.${NC} 2022-blake3-aes-128-gcm ${Green}(推荐)${NC}
 ${Green}14.${NC} 2022-blake3-aes-256-gcm ${Green}(推荐)${NC}
 ${Green}15.${NC} 2022-blake3-chacha20-poly1305
 ${Green}16.${NC} 2022-blake3-chacha8-poly1305
 ==================================
 ${Tip} 如需其它加密方式请手动修改配置文件 !" && echo
	read -e -p "(默认: 3. aes-256-gcm)：" cipher
	[[ -z "${cipher}" ]] && cipher="3"
	if [[ ${cipher} == "1" ]]; then
		cipher="chacha20-ietf-poly1305"
	elif [[ ${cipher} == "2" ]]; then
		cipher="aes-128-gcm"
	elif [[ ${cipher} == "3" ]]; then
		cipher="aes-256-gcm"
	elif [[ ${cipher} == "4" ]]; then
		cipher="plain"
	elif [[ ${cipher} == "5" ]]; then
		cipher="none"
	elif [[ ${cipher} == "6" ]]; then
		cipher="table"
	elif [[ ${cipher} == "7" ]]; then
		cipher="aes-128-cfb"
	elif [[ ${cipher} == "8" ]]; then
		cipher="aes-256-cfb"
	elif [[ ${cipher} == "9" ]]; then
		cipher="aes-256-ctr"
	elif [[ ${cipher} == "10" ]]; then
		cipher="camellia-256-cfb"
	elif [[ ${cipher} == "11" ]]; then
		cipher="arc4-md5"
	elif [[ ${cipher} == "12" ]]; then
		cipher="chacha20-ietf"
	elif [[ ${cipher} == "13" ]]; then
		cipher="2022-blake3-aes-128-gcm"
	elif [[ ${cipher} == "14" ]]; then
		cipher="2022-blake3-aes-256-gcm"
	elif [[ ${cipher} == "15" ]]; then
		cipher="2022-blake3-chacha20-poly1305"
	elif [[ ${cipher} == "16" ]]; then
		cipher="2022-blake3-chacha8-poly1305"
	else
		cipher="aes-256-gcm"
	fi
	echo && echo "=================================="
	echo -e "加密：${Red_background_prefix} ${cipher} ${NC}"
	echo "==================================" && echo
}
InstallDeps(){
	# 分别检查命令是否存在, 分别添加
	cmds=()
	! command -v jq &> /dev/null && cmds+=("jq")
	! command -v gzip &> /dev/null && cmds+=("gzip")
	! command -v wget &> /dev/null && cmds+=("wget")
	! command -v curl &> /dev/null && cmds+=("curl")
	! command -v unzip &> /dev/null && cmds+=("unzip")
	if [[ ${release} == "centos" ]]; then
		! command -v xz &> /dev/null && cmds+=("xz")
	else
		! command -v xz &> /dev/null && cmds+=("xz-utils")
	fi
	if [[ ${#cmds[@]} -ne 0 ]]; then
		if [[ ${release} == "centos" ]]; then
			yum update && yum install -y "${cmds[@]}"
		else
			apt-get update && apt-get install -y "${cmds[@]}"
		fi
	fi
}
WriteCfg(){
	# 判断配置目录是否存在
	[[ ! -d ${FOLDER} ]] && mkdir -p ${FOLDER} && chmod 755 ${FOLDER}
	cat > ${CONF}<<-EOF
{
    "server": "::",
    "server_port": ${default_port},
    "password": "${password}",
    "method": "${cipher}",
    "fast_open": ${tfo},
    "mode": "tcp_and_udp",
    "user":"nobody",
    "timeout":300,
    "nameserver":"8.8.8.8"
}
EOF
	chmod 644 ${CONF}
}

ReadCfg(){
	[[ ! -e ${CONF} ]] && echo -e "${Error} Shadowsocks Rust 配置文件不存在！" && exit 1
	port=$(cat ${CONF}|jq -r '.server_port')
	password=$(cat ${CONF}|jq -r '.password')
	cipher=$(cat ${CONF}|jq -r '.method')
	tfo=$(cat ${CONF}|jq -r '.fast_open')
}

install_docker() {
	if [[ ${release} == "centos" ]]; then
		yum install -y yum-utils device-mapper-persistent-data lvm2
		yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
		yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	else
		curl -fsSL https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]')/gpg | sudo apt-key add -
		add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable"
		apt-get update && apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	fi
	systemctl start docker
	systemctl enable docker
	echo -e "${Green}Docker安装完成！${NC}"
}

# 检查docker是否安装，并检查docker服务是否运行
check_docker() {
    if ! command -v docker &> /dev/null; then
        read -e -p "${Red}Docker未安装，是否安装Docker？ [Y/n]：${NC}" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			install_docker
		else
			exit 1
		fi
    fi
    if ! docker info &> /dev/null; then
        echo -e "${Red}Docker服务未运行，请先启动Docker服务！${NC}"
        exit 1
    fi
}

check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
}

check_installed_status() {
	[[ ! -e ${CONF} ]] && echo -e "${Error} Shadowsocks Rust 没有安装，请检查！" && exit 1
}
check_status(){
	status=`docker inspect -f '{{.State.Status}}' $Hub 2>/dev/null`
}
check_version() {
	if docker ps -a | grep -q ${Hub}; then
		echo -e " ss-rust状态：${Green}已运行${NC}"
		v=`docker exec ss-rust ssservice --version | grep -oP '\K[0-9.]+'`
		echo -e " 当前版本：${Green}${v}${NC}"
		echo -e " 最新版本：${Green}${latest_ver}${NC}"
	else
		echo -e " ss-rust状态：${Red}未运行${NC}"
	fi

}

Start(){
	check_installed_status
	check_status
	[[ "$status" == "running" ]] && echo -e "${Info} Shadowsocks Rust 已在运行 ！" && exit 1
	docker run -d --log-driver=none -p $port:${default_port} -p $port:${default_port}/udp \
    --name $Hub --restart=unless-stopped -v $FOLDER:/etc/shadowsocks-rust $DockerImage
	check_status
	[[ "$status" == "running" ]] && echo -e "${Info} Shadowsocks Rust 启动成功 ！"
    sleep 2s
    StartMenu
}

Stop(){
	check_installed_status
	check_status
	[[ !"$status" == "running" ]] && echo -e "${Error} Shadowsocks Rust 没有运行，请检查！" && exit 1
	systemctl stop shadowsocks-rust
    sleep 3s
    StartMenu
}

Restart(){
	check_installed_status
	docker restart $Hub
	echo -e "${Info} Shadowsocks Rust 重启完毕 ！"
	sleep 3s
	View
    StartMenu
}

Install() {
    echo -e "${Green}正在安装 Shadowsocks Rust...${NC}"
    echo -e "${Info} 开始设置 配置..."
	SetPort
	SetPassword
	SetCipher
	SetTFO
	echo -e "${Info} 开始安装/配置 依赖..."
	InstallDeps
	echo -e "${Info} 正在拉取最新版本${Red}${latest_ver}${NC}镜像..."
	docker pull ${DockerImage}
	echo -e "${Info} 开始写入配置文件 ${CONF}"
	WriteCfg
    echo -e "${Info} 所有步骤 安装完毕，开始启动..."
	Start
}

Uninstall() {
	check_installed_status
	read -e -p "确定要卸载 Shadowsocks Rust ? [y/N]：" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_status
		docker stop $Hub
		docker rm $Hub
		docker images |grep "${DockerImg}" | awk '{print $3}'|xargs docker rmi
		rm -rf ${FOLDER}
		echo && echo "Shadowsocks Rust 卸载完成！" && echo
	else
		echo && echo "卸载已取消..." && echo
	fi
    sleep 3s
    StartMenu
}

Update() {
	check_installed_status
	if ! docker images | grep -q ${DockerImg}; then
		echo -e "${Red}Shadowsocks Rust 镜像未安装，进入安装步骤！${NC}"
		Install
		exit 1
	fi
	echo -e "${Green}正在停止 Shadowsocks Rust...${NC}"
	docker stop $Hub
	docker rm $Hub
	docker images |grep "${DockerImg}" | awk '{print $3}'|xargs docker rmi
	docker run -d --log-driver=none -p $port:${default_port} -p $port:${default_port}/udp \
    --name $Hub --restart=always -v $FOLDER:/etc/shadowsocks-rust $DockerImage
	echo -e "${Green}更新完成！${NC}"
}

View() {
    if [[ ! -e "${CONF}" ]]; then
        echo -e "${Red}配置文件不存在，请先安装 Shadowsocks Rust！${NC}"
        exit 1
    fi
    echo -e "${Green}当前配置文件内容：${NC}"
    cat $CONF
}
Status() {
    if [[ -e ${CONF} ]]; then
        status=$(docker inspect -f '{{.State.Status}}' ss-rust)
        echo -e "当前状态：${Green}${status}${NC}"
    else
        echo -e "${Red}Shadowsocks Rust未安装！${NC}"
    fi
}
Set(){
	check_installed_status
	echo && echo -e "你要做什么？
==================================
 ${Green}1.${NC}  修改 端口配置
 ${Green}2.${NC}  修改 密码配置
 ${Green}3.${NC}  修改 加密配置
 ${Green}4.${NC}  修改 TFO 配置
==================================
 ${Green}5.${NC}  修改 全部配置" && echo
	read -e -p "(默认：取消)：" modify
	[[ -z "${modify}" ]] && echo "已取消..." && exit 1
	if [[ "${modify}" == "1" ]]; then
		ReadCfg
		SetPort
		password=${password}
		cipher=${cipher}
		tfo=${tfo}
		WriteCfg
		Restart
	elif [[ "${modify}" == "2" ]]; then
		ReadCfg
		SetPassword
		port=${port}
		cipher=${cipher}
		tfo=${tfo}
		WriteCfg
		Restart
	elif [[ "${modify}" == "3" ]]; then
		ReadCfg
		SetCipher
		port=${port}
		password=${password}
		tfo=${tfo}
		WriteCfg
		Restart
	elif [[ "${modify}" == "4" ]]; then
		ReadCfg
		SetTFO
		cipher=${cipher}
		port=${port}
		password=${password}
		WriteCfg
		Restart
	elif [[ "${modify}" == "5" ]]; then
		ReadCfg
		SetPort
		SetPassword
		SetCipher
		SetTFO
		WriteCfg
		Restart
	else
		echo -e "${Error} 请输入正确的数字(1-5)" && exit 1
	fi
}

StartMenu(){
clear
check_sys
check_docker
action=$1
	echo && echo -e "
==================================
shadowsocks-rust的一键docker安装脚本
==================================
 ${Green} 1.${NC} 安装 Shadowsocks Rust Docker
 ${Green} 2.${NC} 更新 Shadowsocks Rust Docker
 ${Green} 3.${NC} 卸载 Shadowsocks Rust Docker
——————————————————————————————————
 ${Green} 4.${NC} 启动 Shadowsocks Rust Docker
 ${Green} 5.${NC} 停止 Shadowsocks Rust Docker
 ${Green} 6.${NC} 重启 Shadowsocks Rust Docker
——————————————————————————————————
 ${Green} 7.${NC} 设置 配置信息
 ${Green} 8.${NC} 查看 配置信息
 ${Green} 9.${NC} 查看 运行状态
——————————————————————————————————
 ${Green} 0.${NC} 退出脚本
==================================" && echo
	if ! command -v docker &> /dev/null; then
		echo -e " Docker状态：${Red}未安装,请先安装Docker${NC}"
	else
		echo -e " Docker状态：${Green}已安装${NC}"
	fi
	if ! docker info &> /dev/null; then
		echo -e " Docker运行：${Red}未运行${NC}"
	else
		echo -e " Docker运行：${Green}已运行${NC}"
	fi
	if docker images | grep -q ${DockerImg}; then
		echo -e " ss-rust镜像：${Green}已安装${NC}"
	else
		echo -e " ss-rust镜像：${Red}未安装${NC}"
	fi
	check_version
	[[ ! -e ${CONF} ]] && echo -e "${Red} Shadowsocks Rust 配置文件不存在！${NC}"
	echo
	read -e -p " 请输入数字 [0-9]：" num
	case "$num" in
		1)
		Install
		;;
		2)
		Update
		;;
		3)
		Uninstall
		;;
		4)
		Start
		;;
		5)
		Stop
		;;
		6)
		Restart
		;;
		7)
		Set
		;;
		8)
		View
		;;
		9)
		Status
		;;
		0)
		exit 1
		;;
		*)
		echo "请输入正确数字 [0-9]"
		;;
	esac
}
StartMenu