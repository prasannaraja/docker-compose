#!/bin/bash
# Installing Consul

# tput commands
CLEAR="tput clear"
DOWN="tput cud1"
BOLD="tput bold"
NORMAL="tput sgr0"
BLACK="tput setaf 0"
RED="tput setaf 1"
GREEN="tput setaf 2"
YELLOW="tput setaf 3"
BLUE="tput setaf 4"

$CLEAR
$DOWN
# Installation confirmation
printf "You have selected to install consul.\n\n"
read -p "Do you want to continue? [ yes / no ] : " USER_INPUT
USER_INPUT=${USER_INPUT:-yes}
$DOWN

# Convert user's choice to lowercase for case-sensitive comparison
USER_INPUT_LOWER=$(echo "$USER_INPUT" | tr '[:upper:]' '[:lower:]')

# Check the user's input
if [ "$USER_INPUT_LOWER" == "yes" ]; then
    $YELLOW
    printf "Consul installation confirmed.\n\n"
    $NORMAL
else
    printf "Consul installation cancelled.\n\n"
    exit
fi


# Specify the name of the systemd service
SERVICE_NAME="consul"

# Check if the service file exists
if [ -e "/usr/lib/systemd/system/$SERVICE_NAME.service" ]; then
    # Check if the service is active
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        $BOLD
        printf "There is an active $SERVICE_NAME. \n\n"
        $NORMAL
        # Check the version of the active node_exporter
        CONSUL_PATH="/usr/bin/$SERVICE_NAME"
        VERSION_INFO="$($CONSUL_PATH --version 2>&1 | awk '/Consul/ {print $2}')"
        $GREEN
        printf "Active Consul Version: $VERSION_INFO \n\n"
        $NORMAL
        printf "Do you want to remove it and replace with a new one? [ 1 / 2 ]\n\n"
        printf " 1: Remove manually the active node_exporter and replace it with a new one. \n\n"
        printf " 2: Don't do anything and exit.\n\n"
        read -rp "> " ACTION
        # Check the action to do
        $DOWN
        if [ -z "$ACTION" ]; then
            printf "Remove the active consul manually. \n\n"
            # Printing the suggested commands to remove the service.
            $YELLOW
            $BOLD
            printf "==========================================\n"
            $NORMAL
            printf "systemctl stop consul.service\n" 
            printf "rm -rf /data/consul\n" # data directory
            printf "sudo yum -y remove consul.x86_64\n"
            printf "rm -f /usr/bin/consul\n" # executable file
            printf "rm -f /usr/lib/systemd/system/consul.*\n" # service file
            $YELLOW
            $BOLD
            printf "==========================================\n\n"
            $NORMAL
            exit
        elif [ "$ACTION" -eq 1 ]; then
            printf "Remove the active consul manually. \n\n"
            # Printing the suggested commands to remove the service.
            $YELLOW
            $BOLD
            printf "==========================================\n"
            $NORMAL
            printf "systemctl stop consul.service\n" 
            printf "rm -rf /data/consul\n" # data directory
            printf "sudo yum -y remove consul.x86_64\n"
            printf "rm -f /usr/bin/consul\n" # executable file
            printf "rm -f /usr/lib/systemd/system/consul.*\n" # service file
            $YELLOW
            $BOLD
            printf "==========================================\n\n"
            $NORMAL
            exit
        elif [ "$ACTION" -eq 2 ]; then
            $DOWN
            printf "No action done.\n\n"
            exit
        else
            printf "Invalid input. Please enter 1 or 2.\n\n"
            exit 1
        fi
    else
        printf "There's a $SERVICE_NAME service that is not active. Remove the files manually.\n\n"
        $YELLOW
        $BOLD
        printf "==========================================\n"
        $NORMAL
        printf "systemctl stop consul.service\n" 
        printf "rm -rf /data/consul\n" # data directory
        printf "sudo yum -y remove consul.x86_64\n"
        printf "rm -f /usr/bin/consul\n" # executable file
        printf "rm -f /usr/lib/systemd/system/consul.*\n" # service file
        $YELLOW
        $BOLD
        printf "==========================================\n\n"
        $NORMAL
        exit
    fi
else
    printf "No $SERVICE_NAME service file found.\n\n"
    fi

# Curling Google to check if connected to a network
printf "Looking for a network...\n\n"
if curl google.com > /dev/null; then
    $DOWN
    $YELLOW
    printf "Network connected.\n\n"
    $NORMAL
else
    $DOWN
    printf "The server is not connected to the network. Please connect and try again.\n\n";
    exit 1
fi

# Download the file
if [ ! -f "/opt/consul_1.19.1_darwin_amd64.zip" ]; then
    wget https://releases.hashicorp.com/consul/1.19.1/consul_1.19.1_darwin_amd64.zip -P /opt
fi

# Extract the file
unzip /opt/consul_1.19.1_darwin_amd64.zip && mv consul /usr/bin

if [ ! -f "/etc/yum.repos.d/hashicorp.repo" ]; then
    cat >/etc/yum.repos.d/hashicorp.repo <<EOF
[hashicorp]
name=HashiCorp Stable - $basearch
baseurl=https://rpm.releases.hashicorp.com/RHEL/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://rpm.releases.hashicorp.com/gpg
EOF
fi

# Create a data directory
mkdir -p /data/consul

# Install
sudo yum -y install consul

# Modifying the default data directory
sed -i "s/\/opt\/consul/\/data\/consul/g" /etc/consul.d/consul.hcl;

IP=$(hostname -I | awk '{print $1}')

# Creating the configuration file
cat >/etc/consul.d/config.json <<EOF
{
    "datacenter": "dba",
    "data_dir": "/data/consul",
    "log_level": "INFO",
    "node_name": "dba-manager",
    "server": true,
    "bootstrap_expect": 1,
    "ui": true,
    "client_addr": "0.0.0.0",
    "bind_addr": "$IP"
}
EOF

USERNAME="consul"
# Check if the user exists
if id "$USERNAME" &>/dev/null; then
    echo
else
    sudo useradd "$USERNAME"
    printf "User '$USERNAME' has been created.\n\n"
fi
# Change the ownership
chown -R consul. /data/consul
chown -R consul. /etc/consul.d

# Service file content
SERVICE_CONTENT="[Unit]
Description=Consul
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/usr/bin/consul leave
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target"

TARGET_FILE="/usr/lib/systemd/system/consul.service"
# Replacing the default service file
echo "$SERVICE_CONTENT" | sudo tee $TARGET_FILE > /dev/null

# System reload, start, and status check
sudo systemctl daemon-reload
sudo systemctl start consul
sudo systemctl status consul

$DOWN

# Removing the file in /opt directory
if sudo systemctl is-active --quiet consul.service; then
    $DOWN
    $BOLD
    $YELLOW
    printf "======================================\n"
    $GREEN
    printf "Consul installed successfully!\n"
    $NORMAL
    $BOLD
    printf "Version: $VERSION_INFO\n"
    $YELLOW
    printf "======================================\n"
    $NORMAL
    $DOWN
else
    $DOWN
    $RED
    printf "Consul installation failed.\n\n"
    $NORMAL
    $DOWN
fi