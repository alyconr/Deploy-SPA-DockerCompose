#!/bin/bash

# Default configuration
DOCKER_COMPOSE_DIR="WebpackBabelDockerDeploy"
EXPRESS_DIR="dist"
IP_DOCKER="localhost"
IP_EXPRESS="localhost"
USER="root"
BULD_ENV="prod"
DOCKERHUB_NAME_SPACE="810129"
VERSION="1.0.0"
DOCKER_TAG_SNAPSHOT=$(echo VERSION)-$( git rev-parse --short HEAD)-SNAPSHOT
SSH_KEYPEM_PATH=~/Desktop/ssh-keys-aws/REDHAT-KEYS.pem
SSH_KEYPUB_PATH=~/.ssh/id_rsa.pub
FLAG_FILE=~/.ssh/key_copied_flag

# Display usage help
display_help() {
    cat <<EOF
Usage in order:
    deployment.sh -m               Display this help message.
    deployment.sh -u               Name of USER to deploy to the host
    deployment.sh -i               IP of the host to deploy Docker Compose
    deployment.sh -s               IP of the host to deploy Express server
    deployment.sh -d               Name of the Docker Compose Directory
    deployment.sh -f               Name of the Express Directory   
    deployment.sh -e               Choose build environment: 'prod' or 'dev' (default is 'prod')
EOF
    exit 0
}

# Parse command-line options
parse_options() {
    while getopts ":u:i:s:d:f:e:m" opt; do
        case $opt in
            d) DOCKER_COMPOSE_DIR="$OPTARG" ;;
            f) EXPRESS_DIR="$OPTARG" ;;
            i) IP_DOCKER="$OPTARG" ;;
            s) IP_EXPRESS="$OPTARG" ;;
            u) USER="$OPTARG" ;;
            e) BULD_ENV="$OPTARG" ;;
            m) display_help ;;
            \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
            :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
        esac
    done
}

# Display configuration settings
display_configuration() {
    echo "Your Docker Compose working directory is $DOCKER_COMPOSE_DIR"
    echo "Your Express working directory is $EXPRESS_DIR"
    echo "Your REMOTE DOCKER IP is $IP_DOCKER"
    echo "Your REMOTE EXPRESS IP is $IP_EXPRESS"
    echo "Your USER is $USER"
    echo "Your build environment is $BULD_ENV"
}

# Copy public key to remote servers
copy_public_key() {
  if [ ! -e "$FLAG_FILE" ]; then
    if [ -f "$SSH_KEYPEM_PATH" ] && [ -f "$SSH_KEYPUB_PATH" ]; then
        cat "$SSH_KEYPUB_PATH" | ssh -i "$SSH_KEYPEM_PATH" "$USER@$IP_DOCKER" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
         scp -r "$SSH_KEYPEM_PATH" "$USER@$IP_DOCKER":~/ 
        touch "$FLAG_FILE"  # Create flag file to indicate key has been copied
    else
        echo "Public or Private  key not found"
    fi
    else echo "Flag file already exists"
  fi
}

# Delete old versions and clean up Docker containers on Docker Compose host
cleanup_remote_hosts() {
    if [ -d "$DOCKER_COMPOSE_DIR" ]; then
        rm -Rf "$DOCKER_COMPOSE_DIR" ./"$DOCKER_COMPOSE_DIR.tar.gz"
        rm -Rf "$EXPRESS_DIR" ./"$EXPRESS_DIR.tar.gz"
               
        ssh -T "$USER@$IP_DOCKER" <<EOF
            rm -Rf ~/PROJECTS/
            mkdir ~/PROJECTS/
            chmod -R 777 ~/PROJECTS/
            docker stop \$(docker ps -a -q)
            docker rm -f \$(docker ps -a -q)
            sudo docker rmi "$DOCKERHUB_NAME_SPACE/spa-app:$DOCKER_TAG_SNAPSHOT"
            IP_EXPRESS='$IP_EXPRESS'
            chmod 400 ~/REDHAT-KEYS.pem
            ssh -i ~/REDHAT-KEYS.pem $USER@$IP_EXPRESS "
            sudo rm -Rf ~/EXPRESS/
            mkdir ~/EXPRESS/            
            chmod -R 777 ~/EXPRESS/
            "
EOF
    fi
}


# Build and bundle the app based on the build environment
build_and_bundle_app() {
    if [ "$BULD_ENV" == "dev" ]; then
        npm run build-dev
    else
        npm run build-prod
    fi

    docker build -t "$DOCKERHUB_NAME_SPACE/spa-app:$DOCKER_TAG_SNAPSHOT" -f nginx/Dockerfile .
    for component in spa-app; do
        docker push "$DOCKERHUB_NAME_SPACE/$component:$DOCKER_TAG_SNAPSHOT"
    done
}

# Deploy Docker Compose and Express server
deploy_services() {
    # Create and copy project directories
    mkdir "$DOCKER_COMPOSE_DIR"
    cp -r ./nginx "./$DOCKER_COMPOSE_DIR"
    cp -r ./docker-compose.yml "./$DOCKER_COMPOSE_DIR"
    cp -r ./package.json "./$DOCKER_COMPOSE_DIR"

    mkdir "$EXPRESS_DIR"
    cp -r ./dist "./$EXPRESS_DIR"
    cp -r ./server.js "./$EXPRESS_DIR"
    cp -r ./package.json "./$EXPRESS_DIR"

    # Compress the working directories
    tar -zcvf "$DOCKER_COMPOSE_DIR.tar.gz" "$DOCKER_COMPOSE_DIR"
    tar -zcvf "$EXPRESS_DIR.tar.gz" "$EXPRESS_DIR"

    # Copy compressed directories to hosts
    scp -r ./"$DOCKER_COMPOSE_DIR.tar.gz" "$USER@$IP_DOCKER:~/PROJECTS/"
    scp -r ./"$EXPRESS_DIR.tar.gz" "$USER@$IP_DOCKER:~/"
  

    # If the copy is successful
    if [ $? -eq 0 ]; then
        echo "Copy Folders successful"
        ssh -T "$USER@$IP_DOCKER" <<EOF
            cd ~/PROJECTS/
            tar -xvzf "$DOCKER_COMPOSE_DIR.tar.gz"
            cd "$DOCKER_COMPOSE_DIR"
            sed -i "s#image: $DOCKERHUB_NAME_SPACE/spa-app:latest#image: $DOCKERHUB_NAME_SPACE/spa-app:$DOCKER_TAG_SNAPSHOT#g" docker-compose.yml
            docker compose up -d
            IP_EXPRESS='$IP_EXPRESS'
            chmod 400 ~/REDHAT-KEYS.pem
            scp -i ~/REDHAT-KEYS.pem -r ~/EXPRESS-FOLDER.tar.gz $USER@$IP_EXPRESS:~/EXPRESS/
            ssh -T -i ~/REDHAT-KEYS.pem "$USER@$IP_EXPRESS" "
                cd ~/EXPRESS/
                tar -xvzf "$EXPRESS_DIR.tar.gz"
                cd "$EXPRESS_DIR"
                sudo npm install
                sudo npm install -g pm2
                sudo pm2 -f start server.js
            "          
EOF
    else
        echo "Deployment failed"
    fi

}

# Main function
main() {
    parse_options "$@"
    display_configuration
    copy_public_key
    cleanup_remote_hosts
    build_and_bundle_app
    deploy_services
}

# Run the script
main "$@"
