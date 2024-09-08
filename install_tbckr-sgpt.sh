#!/bin/bash
# Install tbckr-sgpt Linux client
# https://github.com/tbckr/sgpt

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please run as root or use sudo." >&2
  exit 1
fi

read -r -p "This script will modify system-level settings. Please ensure you have the necessary backups or snapshots in place. Do you want to proceed? (yes/no): " response
if [[ "$response" != "yes" ]]; then
  echo "Acknowledgment not given. Exiting."
  exit 1
fi

base_url="https://github.com/tbckr/sgpt/"
releases_url="${base_url}/releases"
arch="$(uname -m)"
os="$(uname -s)"

if [[ "${os}" == "Linux" ]]; then
  if command -v apt &> /dev/null; then
    echo "Installing curl and lynx..."
    apt install -y curl lynx || {
      echo "Failed to install curl and lynx" 
      exit 1
    }
  elif command -v rpm &> /dev/null; then
    echo "Installing curl and lynx..."
    dnf install -y curl lynx || {
      echo "Failed to install curl and lynx" 
      exit 1
    }
  elif command -v apk &> /dev/null; then
    echo "Installing curl and lynx..."
    apk add --no-cache curl lynx || {
      echo "Failed to install curl and lynx"
      exit 1
    }
  else
    echo "Unsupported package manager"
    exit 1
  fi
else
  echo "Unsupported OS"
  exit 1
fi

latest_version="$(curl -s -k ${releases_url} | \
lynx -dump -stdin -force_html -width=10000 -nolist -nobold -nocolor "$@" | \
grep -Po '(?<=v)[0-9]+\.[0-9]+(?:\.[0-9]+)*(?:[a-z]*)' | sort -Vru | head -1)"

if [ -z "${latest_version}" ]; then
  echo "Failed to get latest version"
  exit 1
fi

if [[ "${os}" == "Linux" ]]; then
  # Check if it's a DEB-based system
  if command -v apt &> /dev/null; then
    case "${arch}" in
      "x86_64")
        file_extention="amd64.deb"
        ;;
      "aarch64")
        file_extention="arm64.deb"
        ;;
      "armv7l")
        file_extention="armhf.deb"
        ;;
      *)
        echo "Unsupported architecture"
        exit 1
        ;;
    esac

  # Check if it's an RPM-based system
  elif command -v rpm &> /dev/null; then
    case "${arch}" in
      "x86_64")
        file_extention="x86_64.rpm"
        ;;
      "aarch64")
        file_extention="aarch64.rpm"
        ;;
      "armv7l")
        file_extention="armv7hl.rpm"
        ;;
      *)
        echo "Unsupported architecture"
        exit 1
        ;;
    esac

  # Check if it's an APK-based system
  elif command -v apk &> /dev/null; then
    case "${arch}" in
      "x86_64")
        file_extention="x86_64.apk"
        ;;
      "aarch64")
        file_extention="aarch64.apk"
        ;;
      "armv7l")
        file_extention="armv7.apk"
        ;;
      *)
        echo "Unsupported architecture"
        exit 1
        ;;
    esac

  else
    echo "Unsupported Linux distribution"
    exit 1
  fi
else
  echo "Unsupported OS"
  exit 1
fi

download_package="sgpt_${latest_version}_${file_extention}"

echo "Downloading ${download_package}..."
curl -s -L -O "${releases_url}/download/v${latest_version}/${download_package}" || \
(echo "Failed to download ${download_package}" && exit 1)

echo "Downloaded ${download_package}"

if [[ "${os}" == "Linux" ]]; then
  if command -v apt &> /dev/null; then
    echo "Installing ${download_package}..."
    dpkg -i "./${download_package}" || {
      echo "Failed to install ${download_package} with dpkg"
      exit 1
    }
    apt install -f -y || {
      echo "Failed to fix missing dependencies"
      exit 1
    }
  elif command -v rpm &> /dev/null; then
    echo "Installing ${download_package}..."
    rpm -i "./${download_package}" || {
      echo "Failed to install ${download_package} with rpm"
      exit 1
    }
  elif command -v apk &> /dev/null; then
    echo "Installing ${download_package}..."
    apk add --allow-untrusted "./${download_package}" || {
      echo "Failed to install ${download_package} with apk"
      exit 1
    }
  else
    echo "Unsupported package manager"
    exit 1
  fi
else
  echo "Unsupported OS"
  exit 1
fi
