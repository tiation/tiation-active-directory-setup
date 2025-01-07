#!/bin/bash

#################################################################
#           🌲 Multi-Forest AD Deployment Script                #
#       *Automates Samba AD Forests with Trusts*               #
#              Crafted for flexibility & scalability           #
#################################################################

# Load environment variables
ENV_FILE="/srv/ad-multi-forest/.env"
if [ -f "$ENV_FILE" ]; then
  source $ENV_FILE
else
  echo "🚨 Environment file not found. Please run the pre-install script first."
  exit 1
fi

# Variables
DOCKER_IMAGE="sambaorg/samba-ad-dc"
BASE_DIR="/srv/ad-multi-forest"
NETWORK_NAME="ad-network"
IPV4=$(curl -s ifconfig.me)
IPV6=$(curl -s ifconfig.me/ip6)

# Ensure Docker network exists
docker network ls | grep -q $NETWORK_NAME || docker network create $NETWORK_NAME

# Function to deploy Samba AD Domain Controller
function deploy_dc() {
  DOMAIN=$1
  ADMIN_PASS=$2

  if docker ps -a --format '{{.Names}}' | grep -q samba-$DOMAIN; then
    echo "⚠️ Domain Controller for $DOMAIN already exists. Connecting to existing domain..."
  else
    echo "🚧 Deploying Domain Controller for $DOMAIN..."
    docker run -d --name samba-$DOMAIN \
      --network $NETWORK_NAME \
      -e SAMBA_DOMAIN=$DOMAIN \
      -e SAMBA_REALM=${DOMAIN^^} \
      -e SAMBA_ADMIN_PASSWORD=$ADMIN_PASS \
      --restart unless-stopped \
      -p "1${DOMAIN:0:1}389:1389" \
      -p "1${DOMAIN:0:1}445:1445" \
      -p "1${DOMAIN:0:1}88:1088" \
      -p "1${DOMAIN:0:1}53:1053" \
      -v $BASE_DIR/samba/$DOMAIN:/var/lib/samba \
      $DOCKER_IMAGE
  fi
}

# Deploy root forest
deploy_dc $PRIMARY_DOMAIN $ADMIN_PASSWORD

# Deploy child or additional forests
for ADD_DOMAIN in $(grep ADDITIONAL_DOMAIN $ENV_FILE | cut -d'=' -f2); do
  deploy_dc $ADD_DOMAIN $ADMIN_PASSWORD
  
  # Attempt to establish trust with detected external domains
  echo "🔍 Searching for existing domains..."
  docker exec samba-$PRIMARY_DOMAIN samba-tool domain trust list | grep -q $ADD_DOMAIN
  if [ $? -ne 0 ]; then
    echo "🔗 Creating trust between $PRIMARY_DOMAIN and $ADD_DOMAIN..."
    docker exec samba-$PRIMARY_DOMAIN samba-tool domain trust create $ADD_DOMAIN --type=forest --adminpass=$TRUST_PASSWORD || \
    echo "⚠️ Trust creation between $PRIMARY_DOMAIN and $ADD_DOMAIN may have failed."
  else
    echo "✅ Trust with $ADD_DOMAIN already exists."
  fi

done

# Validation
for ADD_DOMAIN in $(grep ADDITIONAL_DOMAIN $ENV_FILE | cut -d'=' -f2); do
  docker exec samba-$PRIMARY_DOMAIN samba-tool domain trust list | grep -q $ADD_DOMAIN && \
  echo "✅ Trust with $ADD_DOMAIN established." || \
  echo "❌ Trust with $ADD_DOMAIN failed."
done

# Completion message
echo "🎉 Multi-Forest AD Deployment Complete. Access available at $IPV4 or $IPV6"
