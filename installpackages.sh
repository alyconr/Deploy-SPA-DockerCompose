#!/bin/bash
IP_SERVER="localhost"
IP_PRIVATE="localhost"
USER="root"
SSH_KEYPEM_PATH=~/Desktop/ssh-keys-aws/REDHAT-KEYS.pem
SSH_KEYPUB_PATH=~/.ssh/id_rsa.pub
FLAG_FILE=~/.ssh/key_copied_flag

# Display help message
display_help() {
    cat <<EOF
Usage:
    installpackages.sh -m               Display this help message.
    installpackages.sh -u               Name of host's USER
    installpackages.sh -i                IP of the Public Server  to install
    installpackages.sh -s                IP of the Private Server to install
EOF
    exit 0
}
# Parse command-line options
parse_Options() {
    while getopts ":u:i:s:m" opt; do
      case $opt in
        u ) USER="$OPTARG";;
        i ) IP_SERVER="$OPTARG";;
        s ) IP_PRIVATE="$OPTARG";;
        m ) display_help ;;
        \?) echo "Invalid option: -"$OPTARG"" >&2; exit 1;;
        :) echo "Option -"$OPTARG" requires an argument." >&2; exit 1;;
      esac
    done
        
}
# Display configuration settings
display_configuration() {
    echo "Your REMOTE PUBLIC SERVER IP is "$IP_SERVER""
    echo "Your REMOTE PRIVATE IP is "$IP_PRIVATE""
    echo "Your USER is "$USER""
}

copy_public_key() {
    if [ ! -e "$FLAG_FILE" ]; then
        if [ -f "$SSH_KEYPEM_PATH" ]; then
            # Check if the public key exists
            if [ -f "$SSH_KEYPUB_PATH" ]; then
                cat "$SSH_KEYPUB_PATH" | ssh -i "$SSH_KEYPEM_PATH" "$USER@$IP_SERVER" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
                scp -r "$SSH_KEYPEM_PATH" "$USER@$IP_SERVER":~/
                touch "$FLAG_FILE" 
                 # Create flag file to indicate key has been copied
            else
                echo "Public key not found"
            fi
        else
            echo "private key not found"
        fi
    else
        echo "Flag file already exists"
    fi
}

# Install packages on the first server
install_packages_server_one() {
    ssh -o ControlMaster=no -T -f "$USER@$IP_SERVER" '
        sudo apt-get update
        sudo apt-get install ca-certificates curl gnupg -y
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg 
        echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -y
        sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
        sudo usermod -aG docker $USER
        newgrp docker
        chmod 400 REDHAT-KEYS.pem
        IP_PRIVATE='$IP_PRIVATE'
        ssh -i REDHAT-KEYS.pem $USER@$IP_PRIVATE "
            sudo apt-get update
            sudo apt-get install nodejs npm lsof -y
            echo "All packages installed press enter"
      
            
        "

    '
}



main () {
    parse_Options "$@"
    display_configuration
    copy_public_key
    install_packages_server_one
}

main "$@"


