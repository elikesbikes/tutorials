Step 1. Install Starship
Select your operating system from the list below to view installation instructions:

Android
BSD
Linux
Install the latest version for your system:

curl -sS https://starship.rs/install.sh | sh


Step 2. Set up your shell to use Starship
Configure your shell to initialize starship. Select yours from the list below:

Bash
Add the following to the end of ~/.bashrc:

eval "$(starship init bash)"

Step 3. Configure Starship
Start a new shell instance, and you should see your beautiful new shell prompt. If you're happy with the defaults, enjoy!

If you're looking to further customize Starship:

Configuration (opens new window)– learn how to configure Starship to tweak your prompt to your liking

mkdir -p ~/.config && touch ~/.config/starship.toml