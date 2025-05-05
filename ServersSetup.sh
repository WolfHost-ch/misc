#!/bin/bash

# Packages to install
PACKAGES=(
    "sl"
    "jq"
    "git"
    "vim"
    "npm"
    "ntp"
    "nano"
    "curl"
    "htop"
    "wget"
    "tree"
    "nmap"
    "iftop"
    "gnupg"
    "nodejs"
    "toilet"
    "chrony"
    "cowsay"
    "fortune"
    "ntpdate"
    "whiptail"
    "net-tools"
    "iputils-ping"
    "ca-certificates"
    "apt-transport-https"
    "software-properties-common"
)

ALIAS=(
    "alias update='sudo apt-get update;sudo apt-get upgrade -y'"
    "alias cls='clear'"
    "alias ll='ls -alF'"
    "alias home='cd ~'"
    "alias duh='du -h --max-depth=1'"
    "alias free='free -m'"
    "alias restartnetwork='sudo systemctl restart networking'"
    "alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'"
    "alias ports='netstat -tulanp'"
    "alias myip='hostname -I'"
)

DEF_WAIT=3
LOG_FILE="/tmp/server_setup.log"

# Check if user has sudo permissions
getting_sudo_permissions() {
    if [ $(id -u) -ne 0 ]; then
        sudo -v > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "\e[31mERROR\e[0m"
            echo "You need to have SUDO permissions to run this script."
            exit 1
        fi
    fi
}

# Check if required packages are installed
check_required_packages() {
    for pkg in whiptail toilet cowsay; do
        if ! dpkg -l | grep -q $pkg; then
            echo -e "\e[31mERROR\e[0m"
            echo "Package $pkg is required but not installed. Please install it first."
            exit 1
        fi
    done
}

# Function to select machine type
select_machine_type() {
    echo -n "Selecting machine type... "
    sleep $DEF_WAIT
    MACHINE_TYPE=$(whiptail --title "Setup Machine Type" --menu "Choose the machine type:" 15 60 5 \
    "manager" "Setup a manager" \
    "worker" "Setup a worker" \
    "storage" "Setup a storage" \
    "skip" "Skip this step" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ "$MACHINE_TYPE" == "skip" ]; then
        echo -e "\e[33mSkipped\e[0m"
        return
    fi
    echo -e "\e[32mOK\e[0m"
    echo -e "\n\e[32m===> Setting up as a $MACHINE_TYPE! \e[0m\n"
}

# Add alias to .bashrc
adding_aliases() {
    echo -n "Adding aliases... "
    for i in "${ALIAS[@]}"; do
        if ! grep -q "$i" ~/.bashrc; then
            echo "$i" >> ~/.bashrc
        fi
    done
    echo -e "\e[32mOK\e[0m"
}

# Update installed packages
installing_updates() {
    echo -n "Update packages... "
    sudo apt-get install apt-utils -y > /dev/null 2>&1
    sudo apt-get update > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}

# Upgrade installed packages
installing_upgrades() {
    echo -n "Upgrade packages... "
    sudo apt-get upgrade -y > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}

# Auto-remove unused packages
auto_removing_packages() {
    echo -n "Removing unused packages... "
    sudo apt-get autoremove -y > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}

# Install specified packages
installing_packages() {
    echo -n "Installing packages... "
    local total=${#PACKAGES[@]}
    local count=0
    local failed=0
    for PACKAGE in "${PACKAGES[@]}"; do
        count=$((count + 1))
        local percent=$((count * 100 / total))
        sudo dpkg --configure -a > /dev/null 2>&1
        sudo timeout 300 apt-get install $PACKAGE -y >> "$LOG_FILE" 2>&1
        if [ $? -ne 0 ]; then
            printf "\r\033[K"
            echo -e "\e[31mFAILED to install $PACKAGE\e[0m"
            failed=1
        fi
        printf "\rInstalling packages... [%-25s] %d%%" "$(printf '#%.0s' $(seq 1 $((percent / 4))))" "$percent"
    done
    printf "\r\033[K"
    echo -ne "Installing packages... \e[34mVerifying...\e[0m"
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get upgrade -y > /dev/null 2>&1
    printf "\r\033[K"
    if [ $failed -ne 0 ]; then
        echo -e "Installing packages... \e[33mWARNING: Some packages failed to install\e[0m"
        sleep $DEF_WAIT
        exit 1
    else
        echo -e "Installing packages... \e[32mOK\e[0m"
    fi
}

# Sync time
sync_time() {
    echo -n "Syncing time... "
    sudo timedatectl set-timezone Europe/Paris > /dev/null 2>&1
    sudo ntpdate ntp.ubuntu.com > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}

# Create storage
create_storage() {
    echo -n "Creating mount point... "
    sudo mkdir -p /mnt/dockerdata > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
    echo -n "Changing permissions... "
    sudo chown ${USER}:${USER} /mnt/dockerdata > /dev/null 2>&1
    sudo chmod 777 /mnt/dockerdata > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}

# Downloading docker
downloading_docker() {
    echo -n "Downloading Docker... "
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 2>&1
    sudo apt-get update > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}

# Install docker
installing_docker() {
    echo -n "Installing Docker... "
    sudo apt-get install docker-ce docker-compose-plugin -y > /dev/null 2>&1
    sudo usermod -aG docker $USER > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}

# Install and configure keepalived
installing_keepalived() {
    echo -n "Installing Keepalived... "
    sudo apt install keepalived -y > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
        return
    fi

    INTERFACE_NAME=$(ip route | grep default | awk '{print $5}')
    STATE=$(whiptail --title "Keepalived State" --menu "Choose the state for this node:" 15 60 2 \
    "MASTER" "Set this node as MASTER" \
    "BACKUP" "Set this node as BACKUP" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        echo -e "\e[33mSkipped\e[0m"
        return
    fi

    PRIORITY=$(whiptail --title "Keepalived Priority" --inputbox "Enter the last 3 number of the node ID:" 10 60 100 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$PRIORITY" ]; then
        echo -e "\e[33mSkipped\e[0m"
        return
    fi

    echo -n "Configuring Keepalived... "
    sudo bash -c "cat > /etc/keepalived/keepalived.conf <<EOF
vrrp_instance VI_1 {
    state $STATE
    interface $INTERFACE_NAME
    virtual_router_id 42
    priority $PRIORITY
    advert_int 3
    authentication {
        auth_type PASS
        auth_pass WolfhostKeepalived
    }
    virtual_ipaddress {
        10.10.111.10
    }
}
EOF"
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
        return
    fi

    echo -n "Starting Keepalived service... "
    sudo systemctl enable keepalived > /dev/null 2>&1
    sudo systemctl start keepalived > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}

# Setup GlusterFS
setup_glusterfs() {
    echo -n "Installing GlusterFS... "
    sudo apt-get install -y glusterfs-server > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
        return
    fi

    echo -n "Starting GlusterFS service... "
    sudo systemctl enable glusterd > /dev/null 2>&1
    sudo systemctl start glusterd > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
        return
    fi
}

# Connect to the GlusterFS server
connect_storage() {
    echo -n "Installing GlusterFS client... "
    sudo apt-get install -y glusterfs-client > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
        return
    fi

    echo -n "Connecting to storage... "
    sudo mount -t glusterfs "storage1:storage2:/gv0" /mnt/dockerdata > /dev/null 2>&1
    if ! grep -q "storage1:storage2:/gv0 /mnt/dockerdata glusterfs defaults,_netdev 0 0" /etc/fstab; then
        echo "storage1:storage2:/gv0 /mnt/dockerdata glusterfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab > /dev/null 2>&1
    fi
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}

# Install TailScale
installing_tailscale() {
    echo -n "Installing Tailscale... "
    curl -fsSL https://tailscale.com/install.sh | sh > /dev/null 2>&1
    echo -e "\e[32mOK\e[0m"
    echo -n "Connecting to Tailscale... "
    sleep $DEF_WAIT

    while true; do
        TAILSCALE_AUTH_KEY=$(whiptail --title "Tailscale Auth Key" --inputbox "Enter your Tailscale auth key to login\nNote: you always login later by running 'sudo tailscail up'\n(leave blank to skip):" 10 70 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ] || [ -z "$TAILSCALE_AUTH_KEY" ]; then
            echo -e "\e[33mSkipped\e[0m"
            return
        fi

        # Validate Tailscale auth key format
        if [[ "$TAILSCALE_AUTH_KEY" == tskey-auth-* ]]; then
            break
        else
            whiptail --title "Invalid Key" --msgbox "The Tailscale auth key format is invalid. Please try again." 8 45
        fi
    done

    sudo tailscale up --advertise-tags=tag:wh --auth-key="$TAILSCALE_AUTH_KEY" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}

# Tailscale manger subnet setup
tailscale_manager_subnet() {
    echo -n "Setting up Tailscale subnet... "
    sudo tailscale up --advertise-routes=100.100.42.0/24 --accept-routes
    if [ $? -eq 0 ]; then
        echo -e "\e[32mOK\e[0m"
    else
        echo -e "\e[31mFAILED\e[0m"
    fi
}

# Main code
main() {
    getting_sudo_permissions
    clear
    echo -e "\e[34m/--------------------------\\"
    echo -e "| Starting server setup... |"
    echo -e "\\--------------------------/\e[0m\n"
    echo -e "\e[32m===> General setup! \e[0m\n"

    # General commands
    installing_updates
    installing_upgrades
    installing_packages
    auto_removing_packages
    sync_time
    adding_aliases
    downloading_docker
    installing_docker
    check_required_packages
    installing_tailscale
    select_machine_type

    # Handle different setups based on the user's input
    case $MACHINE_TYPE in
        manager)
            # create_storage // TODO: refactor with cephFs
            # connect_storage // TODO: refactor with cephFs
            # tailscale_manager_subnet
            # installing_keepalived
            ;;
        worker)
            # create_storage // TODO: refactor with cephFs
            # connect_storage // TODO: refactor with cephFs
            ;;
        storage)
            # setup_glusterfs // TODO: refactor with cephFs
            ;;
        *)
    esac

    echo ""
    toilet "Setup"
    toilet "Complete!"
    echo ""
    echo -e "Please \e[33mREBOOT\e[0m the machine as \e[33mSOON\e[0m as possible to apply the changes!" | cowsay
}

# Run the main function
main