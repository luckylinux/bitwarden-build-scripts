#!/bin/bash

# Save Current Path
currentpath=$(pwd)

# SETUP INSTRUCTIONS
# - https://contributing.bitwarden.com/getting-started/tools/
# - https://contributing.bitwarden.com/getting-started/clients/
# - https://contributing.bitwarden.com/getting-started/clients/desktop/
# - https://www.rust-lang.org/tools/install
# - https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-ubuntu-20-04
# - https://github.com/bitwarden/clients/issues/3544#issuecomment-1249457832 - Cannot find module '@bitwarden/desktop-native-linux-x64-musl' since 2022.9.0

# Install Build Dependencies
sudo apt install build-essential libsecret-1-dev libglib2.0-dev

#  Also install RPM in order to create RPM packages using rpmbuild (required by "npm run dist:lin")
sudo apt-get install rpm

# Bitwarden expects target to be x86_64-unknown-linux-musl, NOT x86_64-unknown-linux-gnu
apt install musl musl-dev musl-fts musl-tools

# Install Zig
# $HOME/.local/bin is already in my PATH set in/from ~/.bashrc and ~/.bash_profile
ZIGVERSION=0.12.0
wget https://ziglang.org/download/${ZIGVERSION}/zig-linux-x86_64-${ZIGVERSION}.tar.xz -O /tmp/zig-linux-x86_64-${ZIGVERSION}.tar.xz
mkdir -p $HOME/.zig
tar xf /tmp/zig-linux-x86_64-${ZIGVERSION}.tar.xz --strip-components 1 -C $HOME/.zig
rm -f /tmp/zig-linux-x86_64-${ZIGVERSION}.tar.xz

# Add to ~/.bash_profile
echo "You should now add those to your $HOME/.bash_profile in order to set the right PATH so that zig can be found by npm"
cat <<EOF
# Append to PATH if not exist yet
# Prevents from appending to PATH every time
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$PATH:$HOME/.local/bin"
fi

# Append to PATH if not exist yet
# Prevents from appending to PATH every time
if [[ ":$PATH:" != *":$HOME/.zig:"* ]]; then
    export PATH="$PATH:$HOME/.zig"
fi
EOF
read "Are you ready to modify your $HOME/.bash_profile file ? Press ENTER. " dummyvar

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Load Main Profile
# This includes the Settings for the NPM/Cargo/NodeJS Environment
source ~/.bash_profile

# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Load Main Profile
# This includes the Settings for the NPM/Cargo/NodeJS Environment
source ~/.bash_profile

# Install NodeJS
# This version is SPECIFICALLY required by bitwarden-desktop
# required: { node: '^18.18.0', npm: '~9' },
# View ALL Available Versions of NPM: "npm view npm versions --json | jq"
# "npm ls -g" to list installed packages
# "npm list" also to list installed packages
#
REQUIRED_NODE_VERSION="v18.18.0"
REQUIRED_NPM_VERSION="9"
nvm install ${REQUIRED_NODE_VERSION}
nvm alias default ${REQUIRED_NODE_VERSION}
npm install -g node@${REQUIRED_NODE_VERSION}
npm install -g npm@${REQUIRED_NPM_VERSION}

# You can also remove other versions with
# "nvm uninstall v18.20.2"

# Load Main Profile
# This includes the Settings for the NPM/Cargo/NodeJS Environment
source ~/.bash_profile

# Abort on Errors
set -e

# If Repository doesn't exists
if [[ ! -d "clients" ]]
then
   git clone https://github.com/bitwarden/clients.git
fi

# Change Folder
cd clients || exit

# Save Repository Root Path
repositoryroot=$(pwd)

# Save it as full absolute Path
repositoryroot=$(realpath --canonicalize-missing ${repositoryroot})

# Update Local Repository
git fetch
git merge --ff-only

# Define Parameters
APP=bitwarden-desktop
export PKG_CONFIG_ALL_STATIC=1
export PKG_CONFIG_ALLOW_CROSS=1
NODE_ENV=production

# Install extra dependencies
# These may/may not be required
# To be verified
npm install tailwindcss
npm install autoprefixer
npm install postcss-nested
npm install @girs/node-glib-2.0
npm install electron-builder
# Maybe even Add electron-builder to your app devDependencies
npm install electron-builder --save-dev

# Install GLOBALLY is needed if you want to call "electron-builder" directly. Otherwise, the "electron-builder" executable will NOT be in PATH
npm i -g electron-builder

# Install Project Dependencies
# And start from Scratch
npm ci
#cargo add secret
#cargo add libsecret

# Replace Content
sed -Ei "s|(\s*?)max-width: 250px;|\1max-width: 600px;|g" ./apps/desktop/src/scss/left-nav.scss
sed -Ei "s|(\s*?)max-width: 350px;|\1max-width: 600px;|g" ./apps/desktop/src/scss/vault.scss

# Build native module
cd ${repositoryroot}/apps/desktop/desktop_native || exit

# Make sure we also can satisfy x86_64-unknown-linux-musl libraries
RUSTFLAGS="-C target-feature=-crt-static" cargo build --target=x86_64-unknown-linux-musl --profile release

# Add Target x86_64-unknown-linux-musl
# https://github.com/bitwarden/clients/issues/3544
rustup target add x86_64-unknown-linux-musl
npm run build -- --target x86_64-unknown-linux-musl
RUSTFLAGS="-C target-feature=-crt-static" cargo package --target=x86_64-unknown-linux-musl --allow-dirty

# The files will be available in ${repositoryroot}/apps/desktop/desktop_native/target/x86_64-unknown-linux-musl/release/libdesktop_native.so
cp ${repositoryroot}/apps/desktop/desktop_native/target/x86_64-unknown-linux-musl/release/libdesktop_native.so ${repositoryroot}/apps/desktop/desktop_native/desktop_native.linux-x64-musl.node
cp ${repositoryroot}/apps/desktop/desktop_native/target/x86_64-unknown-linux-gnu/release/libdesktop_native.so ${repositoryroot}/apps/desktop/desktop_native/desktop_native.linux-x64-gnu.node

####npm run build -- --target x86_64-unknown-linux-gnu
####npm run build --allow-dirty

# In case of errors run "npm list" and then "npm rm XXXX" for each of them
# Also applicable when changing Versions
# Also do "npm rm @bitwarden/clients" and "npm rm @bitwarden/desktop-native"

# Build App
cd ${repositoryroot}/apps/desktop || exit

#npm run electron --allow-dirty --target x86_64-unknown-linux-gnu
#npm run electron --allow-dirty

# This is the same/similar to building the desktop_native app from within the subfolder (see above)
####npm run build-native

# See also https://www.electron.build/cli.html for command line arguments and the different options
npm run build:main

# To build & Package in ALL Formats (AppImage, snap, rpm,. deb, FreeBSD, ...)
# This also OVERRIDES the "npm run build:main" we ran aboce and also builds the build:renderer/build:preload targets
####npm run dist:lin

# If you only want to build some types of Packages
# Reference: https://www.electron.build/configuration/linux#LinuxConfiguration-target
npm run clean:dist

# Only works if "electron-builder" was installed GLOBALLY using "npm i -g electron-builder"
electron-builder --x64 -p never --linux AppImage deb

# Files are available in
ls -l ${repositoryroot}/apps/desktop/dist/

# NOT NEEDED
####npm run pack:lin
####npm run publish:lin

# Change back to Script Path
cd ${currentpath} || exit
