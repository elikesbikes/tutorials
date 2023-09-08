Manually install on

Ubuntu 20.04 LTS (Focal)
Packages are available for x86 and ARM CPUs, in both 32-bit and 64-bit variants.

Add Tailscale’s package signing key and repository:

curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
Install Tailscale:

sudo apt-get update
sudo apt-get install tailscale
Connect your machine to your Tailscale network and authenticate in your browser:

sudo tailscale up
You’re connected! You can find your Tailscale IPv4 address by running:

tailscale ip -4
If the device you added is a server or remotely-accessed device, you may want to consider disabling key expiry to prevent the need to periodically re-authenticate.

You should be logged in and connected! Set up more devices to connect them to your network, or log in to the admin console to manage existing devices.

