#!/bin/bash

# Define Version of bitwarden to use
BITWARDEN_VERSION="v2024.4.1"
BITWARDEN_TYPE="desktop"

# Define if Requirements Need to be Installed
INSTALL_REQUIREMENTS=${1-"yes"}

# Define Download Method
DOWNLOAD_METHOD="git"

# Abort on Errors
set -e

# Save Current Path
currentpath=$(pwd)

# Generate Timestamp
timestamp=$(date +"%Y%m%d-%H%M%S")

# Move old Data so we can start fresh
if [[ -d "clients" ]]
then
   mv clients _clients_backup_${timestamp}
fi

# SETUP INSTRUCTIONS
# - https://contributing.bitwarden.com/getting-started/tools/
# - https://contributing.bitwarden.com/getting-started/clients/
# - https://contributing.bitwarden.com/getting-started/clients/desktop/
# - https://www.rust-lang.org/tools/install
# - https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-ubuntu-20-04
# - https://github.com/bitwarden/clients/issues/3544#issuecomment-1249457832 - Cannot find module '@bitwarden/desktop-native-linux-x64-musl' since 2022.9.0

if [[ ${INSTALL_REQUIREMENTS} == "yes" ]]
then
   # Install Build Dependencies
   sudo apt install build-essential libsecret-1-dev libglib2.0-dev

   # Also install RPM in order to create RPM packages using rpmbuild (required by "npm run dist:lin")
   sudo apt-get install rpm

   # Bitwarden expects target to be x86_64-unknown-linux-musl, NOT x86_64-unknown-linux-gnu
   sudo apt install musl musl-dev musl-fts musl-tools

   # Install Zig
   # $HOME/.local/bin is already in my PATH set in/from ~/.bashrc and ~/.bash_profile
   ZIGVERSION=0.12.0
   wget https://ziglang.org/download/${ZIGVERSION}/zig-linux-x86_64-${ZIGVERSION}.tar.xz -O /tmp/zig-linux-x86_64-${ZIGVERSION}.tar.xz
   mkdir -p $HOME/.zig
   tar xf /tmp/zig-linux-x86_64-${ZIGVERSION}.tar.xz --strip-components 1 -C $HOME/.zig
   rm -f /tmp/zig-linux-x86_64-${ZIGVERSION}.tar.xz

   # Add to ~/.bash_profile
   echo -e "\n"
   echo "You should now add those to your $HOME/.bash_profile in order to set the right PATH so that zig can be found by npm"
   cat <<EOF
   #####################################################
   #####################################################

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

   #####################################################
   #####################################################
EOF
   echo "Please COPY the contents mentioned above. The <nano> File Editor will automatically be launched afterwards."
   read -p "Are you ready to modify your $HOME/.bash_profile file ? Press ENTER. " dummyvar
   echo -e "\n"

   # Open File for Editing
   nano ~/.bash_profile

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

   if [[ ! -f $HOME/.config/nvm/versions/node/${REQUIRED_NODE_VERSION}/bin/node ]]
   then
      npm install -g node@${REQUIRED_NODE_VERSION}
   fi

   if [[ ! -f $HOME/.config/nvm/versions/node/${REQUIRED_NPM_VERSION}/bin/npm ]]
   then
      npm install -g npm@${REQUIRED_NPM_VERSION}
   fi

   # You can also remove other versions with
   # "nvm uninstall v18.20.2"
fi

# Load Main Profile
# This includes the Settings for the NPM/Cargo/NodeJS Environment
source ~/.bashrc
source ~/.bash_profile

# Get Sources using git
# If Repository doesn't exists
if [[ "${DOWNLOAD_METHOD}" == "git" ]]
then
   if [[ ! -d "clients" ]]
   then
      git clone https://github.com/bitwarden/clients.git
      #git clone https://github.com/bitwarden/clients.git --depth 1 --branch ${BITWARDEN_TYPE}-${BITWARDEN_VERSION} clients
   fi
fi

# Get Sources using wget
if [[ "${DOWNLOAD_METHOD}" == "archive" ]]
then
   if [[ ! -f ${BITWARDEN_TYPE}-${BITWARDEN_VERSION}.tar.gz ]]
   then
      wget https://github.com/bitwarden/clients/archive/refs/tags/${BITWARDEN_TYPE}-${BITWARDEN_VERSION}.tar.gz -O ${BITWARDEN_TYPE}-${BITWARDEN_VERSION}.tar.gz
   fi

   mkdir -p clients
   tar xf ${BITWARDEN_TYPE}-${BITWARDEN_VERSION}.tar.gz --strip-components=1 -C clients/
fi

# Change Folder
cd clients || exit

# Save Repository Root Path
repositoryroot=$(pwd)

# Save it as full absolute Path
repositoryroot=$(realpath --canonicalize-missing ${repositoryroot})

# Update Local Repository
if [[ "${DOWNLOAD_METHOD}" == "git" ]]
then
   # Only relevant if using Master Branch with git
   git fetch
   git merge --ff-only
fi

# Define Parameters
APP=bitwarden-desktop
export PKG_CONFIG_ALL_STATIC=1
export PKG_CONFIG_ALLOW_CROSS=1
NODE_ENV=production

# Install Project Dependencies
# And start from Scratch
npm ci

#cargo add secret
#cargo add libsecret

# Install extra dependencies
# These may/may not be required
# To be verified
npm install tailwindcss
npm install autoprefixer
npm install postcss-nested
npm install @girs/node-glib-2.0
####npm install electron-builder

# Maybe even Add electron-builder to your app devDependencies
#npm install electron-builder --save-dev

# Install GLOBALLY is needed if you want to call "electron-builder" directly. Otherwise, the "electron-builder" executable will NOT be in PATH
npm i -g electron-builder

# Load Main Profile
# This includes the Settings for the NPM/Cargo/NodeJS Environment
source ~/.bashrc
source ~/.bash_profile

# Replace Content for the sidebar
sed -Ei "s|(\s*?)max-width: 250px;|\1max-width: 500px;|g" ./apps/desktop/src/scss/left-nav.scss
sed -Ei "s|(\s*?)max-width: 350px;|\1max-width: 500px;|g" ./apps/desktop/src/scss/vault.scss

# Switch to x86_64-unknown-linux-gnu instead of x86_64-unknown-linux-musl
# nativeBinding = require('./desktop_native.linux-x64-musl.node')
# nativeBinding = require('@bitwarden/desktop-native-linux-x64-musl')

sed -Ei "s|desktop_native.linux-x64-musl.node|desktop_native.linux-x64-gnu.node|g" ${repositoryroot}/apps/desktop/desktop_native/index.js
sed -Ei "s|desktop-native-linux-x64-musl|desktop-native-linux-x64-gnu|g" ${repositoryroot}/apps/desktop/desktop_native/index.js

echo "Copy the following Text and insert it at the TOP of the package.json file that is being opened."
cat <<EOF
  "directories": {
    "buildResources": "build",
    "app": "build"
  },
EOF

read -p "Copy the Text. Once ready, press ENTER. " dummyvar
nano ${repositoryroot}/apps/desktop/package.json
#nano ${repositoryroot}/apps/desktop/build/package.json

# Might also require editing these files
#${repositoryroot}/apps/desktop/package.json
#${repositoryroot}/apps/desktop/build/package.json
#${repositoryroot}/apps/desktop/desktop_native/target/package/desktop_native-0.0.0/package.json
#${repositoryroot}/apps/desktop/src/package.json

#read -r -d '' extratext << EOM
#  "directories": {
#    "buildResources": "build",
#    "app": "build"
#  },
#
#EOM
#
#sed  -i "/\s*?\"name\": \"@bitwarden/desktop\",/i ${extratext}" ${repositoryroot}/apps/desktop/package.json
#sed -i "2i ${extratext}" ${repositoryroot}/apps/desktop/package.json

# Add Target x86_64-unknown-linux-musl
# Make sure we also can satisfy x86_64-unknown-linux-musl libraries
# https://github.com/bitwarden/clients/issues/3544
echo "Adding <x86_64-unknown-linux-musl> to targets for rustup"
rustup target add x86_64-unknown-linux-musl

# Build native module
cd ${repositoryroot}/apps/desktop/desktop_native || exit

# Load Main Profile
# This includes the Settings for the NPM/Cargo/NodeJS Environment
#source ~/.bashrc
#source ~/.bash_profile

# Ensure cargo env file is sourced.
#source "$HOME/.cargo/env"

# Echo
echo "Starting to build the <desktop/desktop_native> APP now"

# Note that target x86_64-unknown-linux-musl might instead link to x86_64-unknown-linux-gnu
# Need a way to "force" cargo to build libraries from scratch instead of using the existing ones
# https://users.rust-lang.org/t/target-x86-64-unknown-linux-musl-fails-to-link/50401/15
#
# Some other ideas
#https://github.com/sfackler/rust-openssl/issues/1627

# cargo build for x86_64-unknown-linux-musl
# If not specified, ldd links against x86_64-unknown-linux-gnu libraries. If specified, the required dependencies cannot be found
#echo "Running <cargo build --target=x86_64-unknown-linux-musl --profile release>"
###RUSTFLAGS="-C target-feature=-crt-static" cargo build --target=x86_64-unknown-linux-musl --profile release
###CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=x86_64-linux-musl-gcc LINKER=x86_64-linux-musl-gcc RUSTFLAGS="-C target-feature=-crt-static" cargo build --target=x86_64-unknown-linux-musl --profile release
#CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=x86_64-linux-musl-gcc LINKER=x86_64-linux-musl-gcc RUSTFLAGS="-C linker=rust-lld -C target-feature=-crt-static" cargo build --target=x86_64-unknown-linux-musl --profile release

#cargo package for x86_64-unknown-linux-musl
# If not specified, ldd links against x86_64-unknown-linux-gnu libraries. If specified, the required dependencies cannot be found
#echo "Running <cargo package --target=x86_64-unknown-linux-musl --allow-dirty>"
#####RUSTFLAGS="-C target-feature=-crt-static" cargo package --target=x86_64-unknown-linux-musl --allow-dirty
#CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=x86_64-linux-musl-gcc LINKER=x86_64-linux-musl-gcc RUSTFLAGS="-C target-feature=-crt-static" cargo package --target=x86_64-unknown-linux-musl --allow-dirty

# npm run build (due to missing libraries)
# This FAILS
#echo "Running <npm run build -- --target x86_64-unknown-linux-musl>"
#npm run build --target x86_64-unknown-linux-musl

# cargo build for x86_64-unknown-linux-gnu
#echo "Running <cargo build --target=x86_64-unknown-linux-gnu --profile release>"
RUSTFLAGS="-C target-feature=-crt-static" cargo build --target=x86_64-unknown-linux-gnu --profile release

#cargo package for x86_64-unknown-linux-gnu
#echo "Running <cargo package --target=x86_64-unknown-linux-gnu --allow-dirty>"
RUSTFLAGS="-C target-feature=-crt-static" cargo package --target=x86_64-unknown-linux-gnu --allow-dirty

# npm run build
# This SUCCEEDS
#echo "Running <npm run build x86_64-unknown-linux-gnu>"
#npm run build --target x86_64-unknown-linux-gnu
npm run build -- --target x86_64-unknown-linux-gnu --profile release
#npm run build -- --target x86_64-unknown-linux-gnu --allow-dirty

# The files will be available in ${repositoryroot}/apps/desktop/desktop_native/target/x86_64-unknown-linux-musl/release/libdesktop_native.so
echo "Copy Files built by <cargo> to the expected output location for <npm run build:main> that comes afterwards"

# musl target
if [[ -f "${repositoryroot}/apps/desktop/desktop_native/target/x86_64-unknown-linux-musl/release/libdesktop_native.so" ]]
then
   cp ${repositoryroot}/apps/desktop/desktop_native/target/x86_64-unknown-linux-musl/release/libdesktop_native.so ${repositoryroot}/apps/desktop/desktop_native/desktop_native.linux-x64-musl.node
fi

# gnu target
if [[ -f "${repositoryroot}/apps/desktop/desktop_native/target/x86_64-unknown-linux-musl/release/libdesktop_native.so" ]]
then
   cp ${repositoryroot}/apps/desktop/desktop_native/target/x86_64-unknown-linux-gnu/release/libdesktop_native.so ${repositoryroot}/apps/desktop/desktop_native/desktop_native.linux-x64-gnu.node
fi

####npm run build -- --target x86_64-unknown-linux-gnu
####npm run build --allow-dirty

# In case of errors run "<npm list>" and then "<npm rm XXXX>" for each of them
# Also applicable when changing Versions
# Also do "<npm rm @bitwarden/clients>" and "<npm rm @bitwarden/desktop-native>"

# Build App
echo "Starting to build the <desktop> APP now"
cd ${repositoryroot}/apps/desktop || exit

# This is the same/similar to building the desktop_native app from within the subfolder (see above)
npm run build-native

# See also https://www.electron.build/cli.html for command line arguments and the different options
#echo "Running <npm run build:main>"
##### This can result in musl library being required, while musl desktop-native is NOT working correclty
#####npm run build:main
# This is equivalent to: <cross-env NODE_ENV=production webpack --config webpack.main.js>
#${repositoryroot}/node_modules/.bin/cross-env NODE_ENV=production ${repositoryroot}/node_modules/.bin/webpack --config webpack.main.js
#npm run build:main

# Build WITHOUT cross-compiling
#NODE_ENV=production ${repositoryroot}/node_modules/.bin/webpack --config webpack.main.js

# To just run the app without building the Package:
#npm run electron --allow-dirty --target x86_64-unknown-linux-gnu
#npm run electron --allow-dirty
# This is needed otherwise we get a index.html ERR_FILE_NOT_FOUND
# Quit the Application immediately. Disable stopping on errors since this WILL trigger an Error !
#
# This is what actually creates the ./buildf/ folder and populates its Content
#set +e
#NODE_ENV=production node ./scripts/start.js
#set +e

# Call again
#npm run build:main

# To build & Package in ALL Formats (AppImage, snap, rpm,. deb, FreeBSD, ...)
# This also OVERRIDES the "<npm run build:main>" we ran above and also builds the build:renderer/build:preload targets
#npm run dist:lin

# Run with cross-env
# Must also do build:preload and build:renderer, otherwise index.html will NOT exist inside the build/ directory !
#npm run build:preload
#npm run build:main
#npm run build:renderer

# Run WITHOUT cross-env
NODE_ENV=production ${repositoryroot}/node_modules/.bin/webpack --config webpack.preload.js
NODE_ENV=production ${repositoryroot}/node_modules/.bin/webpack --config webpack.main.js
NODE_ENV=production ${repositoryroot}/node_modules/.bin/webpack --config webpack.renderer.js

# If you only want to build some types of Packages
# Reference: https://www.electron.build/configuration/linux#LinuxConfiguration-target
echo "<Running npm run clean:dist>"
npm run clean:dist

# Only works if "<electron-builder>" was installed GLOBALLY using "<npm i -g electron-builder>"
#echo "Running <electron-builder --x64 -p never --linux AppImage deb>"
#electron-builder --x64 -p never --linux AppImage deb
echo "Running <electron-builder --x64 -p never --linux AppImage>"
electron-builder --x64 -p never --linux AppImage

# Files are available in
echo "Files are avilable in: ${repositoryroot}/apps/desktop/dist/"
ls -l ${repositoryroot}/apps/desktop/dist/

# NOT NEEDED
#npm run pack:lin
#npm run publish:lin

# Change back to Script Path
cd ${currentpath} || exit
