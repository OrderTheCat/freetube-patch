#!/bin/bash
set -e

REPO_URL="git@github.com:YOUR_USERNAME/io.freetubeapp.FreeTube.git"
REPO_DIR="$HOME/io.freetubeapp.FreeTube"

# Install deps
sudo pacman -S --needed flatpak flatpak-builder nodejs npm

# Clone repo
if [ ! -d "$REPO_DIR" ]; then
    git clone "$REPO_URL" "$REPO_DIR"
fi

# Build
cd "$REPO_DIR"
flatpak-builder --user --install --force-clean --install-deps-from=flathub build io.freetubeapp.FreeTube.yml

# Update script
mkdir -p ~/.local/bin
cat > ~/.local/bin/freetube-update.sh << 'EOF'
#!/bin/bash
REPO_DIR="$HOME/io.freetubeapp.FreeTube"
MANIFEST="$REPO_DIR/io.freetubeapp.FreeTube.yml"

LATEST=$(curl -s https://api.github.com/repos/FreeTubeApp/FreeTube/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
CURRENT=$(grep -oP 'freetube-\K[0-9][0-9a-z.-]*' "$MANIFEST" | head -1)

if [ "$LATEST" != "$CURRENT" ]; then
    echo "Updating FreeTube: $CURRENT -> $LATEST"
    sed -i "s/freetube-${CURRENT}/freetube-${LATEST}/g" "$MANIFEST"
    cd "$REPO_DIR"
    flatpak-builder --user --install --force-clean --install-deps-from=flathub build "$MANIFEST"
    echo "Done: $LATEST"
else
    echo "Already up to date: $CURRENT"
fi
EOF
chmod +x ~/.local/bin/freetube-update.sh

# Systemd timer
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/freetube-update.service << 'EOF'
[Unit]
Description=Update patched FreeTube Flatpak

[Service]
Type=oneshot
ExecStart=%h/.local/bin/freetube-update.sh
EOF

cat > ~/.config/systemd/user/freetube-update.timer << 'EOF'
[Unit]
Description=Daily FreeTube update check

[Timer]
OnCalendar=08:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user enable --now freetube-update.timer

# Cleanup
rm -rf "$REPO_DIR/build"
sudo pacman -Rns --noconfirm nodejs npm

echo "Done. Run: flatpak run io.freetubeapp.FreeTube"   
