#!/bin/bash

# Function to get the current hostname
get_hostname() {
    hostname | cut -d. -f1
}

# Function to get the current username
get_username() {
    whoami
}

# Function to get the home directory
get_home_directory() {
    echo "$HOME"
}

# Function to read a value from host.nix
get_host_nix_value() {
    local key="$1"
    local value
    if [ -f "darwin/host.nix" ]; then
        value=$(grep "^  $key = " darwin/host.nix | cut -d'"' -f2)
        echo "$value"
    fi
}

# Function to update host.nix
update_host_nix() {
    local hostname="$1"
    local username="$2"
    local fullname="$3"
    local email="$4"
    local home_directory="$5"
    
    cat > darwin/host.nix << EOF
{
  hostname = "${hostname}";
  username = "${username}";
  fullName = "${fullname}";
  email = "${email}";
  homeDirectory = "${home_directory}";
  enableWork = false;
  enableAISECHosts = false;
}
EOF
}

# Function to update flake.nix rayscripts path
update_flake_nix() {
    local rayscripts_path="$1"
    local temp_file="darwin/flake.nix.tmp"
    
    # Use sed to replace the rayscripts path while preserving the file
    sed "s|url = \"path:.*rayscripts\";|url = \"path:${rayscripts_path}\";|" darwin/flake.nix > "$temp_file"
    mv "$temp_file" darwin/flake.nix
}

# Main setup process
echo "Welcome to the dotfiles setup script!"
echo "This script will help you configure your system."
echo

# Get current values
current_hostname=$(get_hostname)
current_username=$(get_username)
current_home_directory=$(get_home_directory)
current_fullname=$(get_host_nix_value "fullName")
current_email=$(get_host_nix_value "email")

# Get user input with current values as defaults
echo "Please provide the following information (press Enter to keep current value):"
echo

read -p "Hostname [$current_hostname]: " hostname
hostname=${hostname:-$current_hostname}

read -p "Username [$current_username]: " username
username=${username:-$current_username}

read -p "Full Name [$current_fullname]: " fullname
fullname=${fullname:-$current_fullname}
while [ -z "$fullname" ]; do
    echo "Full name cannot be empty."
    read -p "Full Name: " fullname
done

read -p "Email [$current_email]: " email
email=${email:-$current_email}
while [ -z "$email" ]; do
    echo "Email cannot be empty."
    read -p "Email: " email
done

home_directory=${current_home_directory}

# Get the absolute path to rayscripts
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rayscripts_path="${script_dir}/rayscripts"

echo
echo "Summary of configuration:"
echo "------------------------"
echo "Hostname: $hostname"
echo "Username: $username"
echo "Full Name: $fullname"
echo "Email: $email"
echo "Home Directory: $home_directory"
echo "Rayscripts Path: $rayscripts_path"
echo

# Confirm with user
read -p "Do you want to proceed with these settings? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 1
fi

# Update configuration files
echo "Updating host.nix..."
update_host_nix "$hostname" "$username" "$fullname" "$email" "$home_directory"

echo "Updating flake.nix with rayscripts path..."
update_flake_nix "$rayscripts_path"

echo "Creating symlinks..."
sudo ./create_links.sh

echo
echo "Configuration complete!"
echo
echo "Next steps:"
echo "1. Install nix if not already installed:"
echo "   sh <(curl -L https://nixos.org/nix/install)"
echo
echo "2. Install xcode developer tools if not already installed:"
echo "   xcode-select --install"
echo
echo "3. Log in to your Apple ID for Mac App Store installations"
echo
echo "4. Install nix-darwin:"
echo "   nix run --extra-experimental-features nix-command --extra-experimental-features flakes nix-darwin/master#darwin-rebuild -- switch"
echo
echo "5. After installation, you can update the configuration using:"
echo "   darwin-rebuild switch" 
