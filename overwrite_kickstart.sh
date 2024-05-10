generate_ks_cfg() {
    # Get the list of public SSH keys in the user's home directory
    ssh_keys=$(ls ~/.ssh/*.pub 2>/dev/null)

    # Check if there are any SSH keys available
    if [ -z "$ssh_keys" ]; then
        echo "No SSH keys found in ~/.ssh directory."
        return 1
    fi

    # Display available SSH keys and prompt user to select one
    echo "Available SSH keys:"
    select ssh_key in $ssh_keys "Cancel"; do
        if [ "$ssh_key" = "Cancel" ]; then
            echo "Operation canceled."
            return 1
        elif [ -f "$ssh_key" ]; then
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done

    # Get the username from the selected SSH key filename
    username=$(basename "$ssh_key" .pub)

    # Extract username and SSH key from selected SSH key file
    ssh_user=$(awk '{print $NF}' "$ssh_key")
    ssh_pub_key=$(cat "$ssh_key")

    # Generate password hashes for root and user
    root_password_hash=$(openssl passwd -6)
    user_password_hash=$(openssl passwd -6)

    # Generate the kickstart configuration file
    cat <<EOF > kickstart/ks.cfg
# Kickstart configuration for minimal CentOS installation

# System authorization information
auth --enableshadow --passalgo=sha512

# Use text mode install
text

# Run the installation
install

# Use graphical install
# graphical

# Root password (encrypted)
rootpw --iscrypted $root_password_hash

# System timezone
timezone UTC --isUtc

# Network information
network --bootproto=dhcp --device=eth0 --onboot=on --ipv6=auto --activate
network --hostname=minikube

# Firewall configuration
firewall --disabled

# Package selection
%packages
@base
@core
@development
%end

# Add user with SSH access and sudo privileges
user --name=user --groups=wheel --password=$user_password_hash --sshkey="$ssh_pub_key"

# Disable root SSH login
sshkey --username=root --disable

# Start SSH service
services --enabled=sshd

# Reboot after installation
reboot
EOF

    echo "Kickstart configuration file 'ks.cfg' generated successfully."
}

generate_ks_cfg