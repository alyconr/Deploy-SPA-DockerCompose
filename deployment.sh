#!bin/bash
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

while getopts ":u:i:s:d:f:e:m" opt; do
      case $opt in
        d ) DOCKER_COMPOSE_DIR="$OPTARG";;
        f ) EXPRESS_DIR="$OPTARG";;
        i ) IP_DOCKER="$OPTARG";;
        s ) IP_EXPRESS="$OPTARG";;
        u ) USER="$OPTARG";;
        e ) BULD_ENV="$OPTARG";;
        m )
            echo "Usage:"
            echo "    deployment.sh -m               Display this help message."
            echo "    deployment.sh -d               Name of the docker compose Directory"
            echo "    deployment.sh -f               Name of the express Directory"
            echo "    deployment.sh -i                IP of the host to deploy docker-compose"
            echo "    deployment.sh -u               Name of USER to deploy to the host" 
            echo "    deployment.sh -s               IP of the host to deploy express server"
            echo "    deployment.sh -e               Choose build environment: 'prod' or 'dev' (default is 'prod')"
            exit 0
            ;;
        \?) echo "Invalid option: -"$OPTARG"" >&2
            exit 1;;
        : ) echo "Option -"$OPTARG" requires an argument." >&2
            exit 1;;
      esac
    done

echo "Your Docker Compose working directory is "$DOCKER_COMPOSE_DIR""
echo "Your Express working directory is "$EXPRESS_DIR""
echo "Your REMOTE DOCKER IP is "$IP_DOCKER""
echo "Your REMOTE EXPRESS IP is "$IP_EXPRESS""
echo "Your USER is "$USER""
echo "Your build environment is "$BULD_ENV""

# before Copy the private key to the remote host to be able to ssh without password, remember to  run ssh-keygen in your local machine

# Check if the private key file exists
if [ -f "$SSH_KEYPEM_PATH" ]; then
    # Check if the public key exists
    if [ -f "$SSH_KEYPUB_PATH" ]; then
        
         cat $SSH_KEYPUB_PATH | ssh -i $SSH_KEYPEM_PATH $USER@$IP_DOCKER "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys" && cat $SSH_KEYPUB_PATH | ssh -i $SSH_KEYPEM_PATH $USER@$IP_EXPRESS "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
    else 
        echo "Public key not found"
    fi
else
    echo "Private key not found"

fi

#  Delete old versions 
if [ -d "$DOCKER_COMPOSE_DIR" ]; then rm -Rf $DOCKER_COMPOSE_DIR ./$DOCKER_COMPOSE_DIR.tar.gz && ssh $USER@$IP_DOCKER << EOF
    rm -Rf ~/PROJECTS/
    mkdir ~/PROJECTS/
    chmod -R 777 ~/PROJECTS/
    docker stop  \$(docker ps -a -q)
    docker rm -f \$(docker ps -a -q)
    sudo docker rmi $DOCKERHUB_NAME_SPACE/spa-app:$DOCKER_TAG_SNAPSHOT
EOF
fi

# Delete old versions 
if [ -d "$EXPRESS_DIR" ]; then rm -Rf $EXPRESS_DIR ./$EXPRESS_DIR.tar.gz && ssh $USER@$IP_EXPRESS << EOF
    rm -Rf ~/EXPRESS/
    mkdir ~/EXPRESS/
    chmod -R 777 ~/EXPRESS/
    kill -9 \$(sudo lsof -t -i:5000)
    
EOF
fi

# Build and bindle the app
if [ $BULD_ENV == "dev" ]; then
    npm run build-dev
else
    npm run build-prod
        
fi

  docker build -t $DOCKERHUB_NAME_SPACE/spa-app:$DOCKER_TAG_SNAPSHOT -f nginx/Dockerfile .
 for component in spa-app; do
        docker push $DOCKERHUB_NAME_SPACE/$component:$DOCKER_TAG_SNAPSHOT
    done

# Create the new working directory to deploy docker-compose
mkdir $DOCKER_COMPOSE_DIR

cp -r ./nginx ./$DOCKER_COMPOSE_DIR
cp -r ./docker-compose.yml ./$DOCKER_COMPOSE_DIR
cp -r ./package.json ./$DOCKER_COMPOSE_DIR


mkdir $EXPRESS_DIR
cp -r ./dist ./$EXPRESS_DIR
cp -r ./server.js ./$EXPRESS_DIR
cp -r ./package.json ./$EXPRESS_DIR

# compress the working directory tar.gz
tar -zcvf $DOCKER_COMPOSE_DIR.tar.gz $DOCKER_COMPOSE_DIR
tar -zcvf $EXPRESS_DIR.tar.gz $EXPRESS_DIR

# Copy the compress project directory to the host
scp -r ./$DOCKER_COMPOSE_DIR.tar.gz $USER@$IP_DOCKER:~/PROJECTS/
scp -r ./$EXPRESS_DIR.tar.gz $USER@$IP_EXPRESS:~/EXPRESS/


# if the copy is successful
if [ $? -eq 0 ]; then 
    echo "Copy Folders successful"
    if [ $? -eq 0 ]; then
    ssh $USER@$IP_DOCKER << EOF
    cd ~/PROJECTS/
    tar -xvzf $DOCKER_COMPOSE_DIR.tar.gz
    cd $DOCKER_COMPOSE_DIR
    sed -i "s#image: $DOCKERHUB_NAME_SPACE/spa-app:latest#image: $DOCKERHUB_NAME_SPACE/spa-app:$DOCKER_TAG_SNAPSHOT#g" docker-compose.yml
    docker compose up -d
    
EOF
    fi     
     
else
    echo "Deployment failed"
fi   

#  express deploy

if [ $? -eq 0 ]; then 
    echo "Deployment successful"
    if [ $? -eq 0 ]; then
    ssh $USER@$IP_EXPRESS << EOF
    cd ~/EXPRESS/
    tar -xvzf $EXPRESS_DIR.tar.gz
    cd $EXPRESS_DIR
    npm install
    npm run server-prod &

    
EOF
    fi     
     
else
    echo "Deployment failed"
fi
