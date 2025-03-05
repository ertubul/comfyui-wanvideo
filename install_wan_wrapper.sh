#!/bin/bash
# WanVideo wrapper kurulum script'i
set -e

echo "==== WanVideo Wrapper Manuel Kurulum ===="

# Doğru ComfyUI yolu belirleme
COMFYUI_DIR="/workspace/ComfyUI"
CUSTOM_NODES_DIR="${COMFYUI_DIR}/custom_nodes"

# Dizinlerin varlığını kontrol et
if [ ! -d "$COMFYUI_DIR" ]; then
  echo "❌ HATA: $COMFYUI_DIR dizini bulunamadı!"
  exit 1
fi

if [ ! -d "$CUSTOM_NODES_DIR" ]; then
  echo "📁 Custom nodes dizini oluşturuluyor..."
  mkdir -p "$CUSTOM_NODES_DIR"
fi

# WanVideo Wrapper repo'sunu klonla
REPO_URL="https://github.com/kijai/ComfyUI-WanVideoWrapper"
TARGET_DIR="${CUSTOM_NODES_DIR}/ComfyUI-WanVideoWrapper"

if [ -d "$TARGET_DIR" ]; then
  echo "🔄 Mevcut repo güncelleniyor..."
  cd "$TARGET_DIR"
  git pull
else
  echo "📥 Repo klonlanıyor: $REPO_URL"
  git clone "$REPO_URL" "$TARGET_DIR"
fi

# KJNodes repo'sunu da klonla (bağımlılık olabilir)
KJNODES_URL="https://github.com/kijai/ComfyUI-KJNodes"
KJNODES_DIR="${CUSTOM_NODES_DIR}/ComfyUI-KJNodes"

if [ -d "$KJNODES_DIR" ]; then
  echo "🔄 KJNodes repo'su güncelleniyor..."
  cd "$KJNODES_DIR"
  git pull
else
  echo "📥 KJNodes repo'su klonlanıyor..."
  git clone "$KJNODES_URL" "$KJNODES_DIR"
fi

# Bağımlılıkları yükle
echo "📦 WanVideo Wrapper bağımlılıkları yükleniyor..."
cd "$TARGET_DIR"
python -m pip install -r requirements.txt

echo "📦 KJNodes bağımlılıkları yükleniyor..."
cd "$KJNODES_DIR"
if [ -f "requirements.txt" ]; then
  python -m pip install -r requirements.txt
fi

echo "✅ Kurulum tamamlandı!"
echo "🔄 ComfyUI'yi yeniden başlatın ve node'ların eklendiğini kontrol edin."
