#!/bin/bash

###############################################################
#            🎩 Magic AD Setup Wizard for Ubuntu              #
#                *Namecheap + Samba AD*                      #
#            Created with ❤️ for lazy sysadmins              #
###############################################################

# Pre-install script to set up Namecheap CLI, environment files, and domain selection for AD setup
# This script prepares the environment for the primary AD setup script.
# It installs Namecheap CLI, configures a .env file, and sets up domain details.

# Install Namecheap CLI
apt update && apt install -y python3-pip
pip3 install namecheap --break-system-packages

# Create environment directory
ENV_DIR="/srv/ad-setup"
mkdir -p $ENV_DIR
ENV_FILE="$ENV_DIR/.env"

# 🛠️ Let's get those API keys in order!
read -p "Enter Namecheap API key: " NAMECHEAP_API_KEY
read -p "Enter Namecheap API username: " NAMECHEAP_API_USER
read -p "Enter API environment (sandbox or production, default production): " NAMECHEAP_ENV
NAMECHEAP_ENV=${NAMECHEAP_ENV:-production}

# 🔑 Configuring Namecheap CLI
namecheap configure --username $NAMECHEAP_API_USER --api-key $NAMECHEAP_API_KEY --env $NAMECHEAP_ENV

# 🚀 Fetching domains from Namecheap account...
DOMAINS=($(namecheap domains getList --format json | jq -r '.CommandResponse.DomainGetListResult.Domain[].Name'))

if [ ${#DOMAINS[@]} -eq 0 ]; then
  echo "😞 No domains found in your Namecheap account. Exiting."
  exit 1
fi

# 📜 Available domains (Pick your weapon of choice!)
echo "Available Domains:"
for i in ${!DOMAINS[@]}; do
  echo "$i) ${DOMAINS[$i]}"
done

# 🖱️ Choose your destiny
read -p "Select the domain for AD setup (0-${#DOMAINS[@]}): " DOMAIN_INDEX
SELECTED_DOMAIN=${DOMAINS[$DOMAIN_INDEX]}

# 🌐 Choose subdomain or roll with 'ad'
read -p "Enter subdomain (e.g., 'ad' or 'dc', default 'ad'): " SUBDOMAIN
SUBDOMAIN=${SUBDOMAIN:-ad}
FQDN="$SUBDOMAIN.$SELECTED_DOMAIN"

# 📄 Writing to .env file like a pro
cat <<EOL > $ENV_FILE
DOMAIN=$FQDN
ADMIN_PASSWORD=P@ssw0rd123!
TRUST_PASSWORD=Tru5tP@ss!
EOL

echo "✅ Environment file created at $ENV_FILE with domain $FQDN."

# 🧰 Installing extra tools (Docker + dependencies)
apt install -y docker.io docker-compose curl jq

# 🤖 Offer to run the next step immediately
read -p "Would you like to run the primary AD setup script now? (y/n): " RUN_SETUP
if [ "$RUN_SETUP" == "y" ]; then
  echo "🔄 Fetching and running the AD setup script..."
  mkdir -p $ENV_DIR/scripts
  curl -o $ENV_DIR/scripts/ad-setup.sh https://raw.githubusercontent.com/tiation/ad-setup/main/ad-setup.sh
  chmod +x $ENV_DIR/scripts/ad-setup.sh
  bash $ENV_DIR/scripts/ad-setup.sh
else
  echo "🛑 Setup script not executed. Run it later from $ENV_DIR/scripts/ad-setup.sh."
fi

# 🏁 Finish line reached
echo "🚦 Pre-install script complete. Ready for the next steps!"
