#!/bin/bash

# Check for required arguments
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <common_name> <ttl>"
  exit 1
fi

# Assign arguments to variables
COMMON_NAME="$1"
TTL="$2"

# Define paths
NGINX_REPO="https://github.com/AndreyPogosyan/nginx-demo-config.git"
TMP_DIR="/tmp/nginx"
NGINX_CONF="/etc/nginx/nginx.conf"
SSL_DIR="/etc/nginx/ssl"
CERT_JSON="$SSL_DIR/vault_cert.json"
CERT_PEM="$SSL_DIR/vault_cert.pem"
KEY_PEM="$SSL_DIR/vault_key.pem"

# Ensure SSL directory exists
mkdir -p "$SSL_DIR"

# Check for and delete existing nginx directory and nginx.conf file
for path in "$TMP_DIR" "$NGINX_CONF"; do
  if [ -e "$path" ]; then
    rm -rf "$path"
    echo "Deleted $path."
  fi
done

# Clone the repository and copy nginx.conf
if git clone "$NGINX_REPO" "$TMP_DIR"; then
  echo "Repository cloned to $TMP_DIR."
  cp "$TMP_DIR/nginx.conf" "$NGINX_CONF" && echo "nginx.conf copied to $NGINX_CONF." || {
    echo "Failed to copy nginx.conf to $NGINX_CONF." >&2
    exit 1
  }
else
  echo "Failed to clone repository." >&2
  exit 1
fi

# Fetch certificate and key from Vault using dynamic common_name and ttl
if vault write -format=json pki-int/issue/servers common_name="$COMMON_NAME" ttl="$TTL" > "$CERT_JSON"; then
  jq -r .data.certificate "$CERT_JSON" > "$CERT_PEM"
  jq -r .data.private_key "$CERT_JSON" > "$KEY_PEM"
  jq -r .data.issuing_ca "$CERT_JSON" >> "$CERT_PEM"
  echo "Certificate and key saved to $SSL_DIR."
  rm "$CERT_JSON"
else
  echo "Failed to fetch certificate from Vault." >&2
  exit 1
fi

# Restart NGINX
if systemctl restart nginx; then
  echo "NGINX restarted successfully."
else
  echo "Failed to restart NGINX." >&2
  exit 1
fi
