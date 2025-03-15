#!/bin/bash
# ComfyUI custom node'ları için requirements yükleme scripti

# Log dizini oluştur
mkdir -p /workspace/requirements_logs

# ComfyUI custom_nodes dizinini belirle
CUSTOM_NODES_DIR="/workspace/ComfyUI/custom_nodes"

# Dizinin var olup olmadığını kontrol et
if [ ! -d "$CUSTOM_NODES_DIR" ]; then
    echo "Hata: ComfyUI custom_nodes dizini bulunamadı: $CUSTOM_NODES_DIR"
    exit 1
fi

echo "$(date) - Custom node gereksinimlerinin yüklenmesi başlatılıyor" | tee -a /workspace/requirements_logs/install.log

# custom_nodes dizinindeki tüm alt dizinleri tara
for NODE_DIR in "$CUSTOM_NODES_DIR"/*; do
    if [ -d "$NODE_DIR" ]; then
        NODE_NAME=$(basename "$NODE_DIR")
        echo "Custom node kontrol ediliyor: $NODE_NAME" | tee -a /workspace/requirements_logs/install.log
        
        # requirements.txt var mı kontrol et
        if [ -f "$NODE_DIR/requirements.txt" ]; then
            echo "[$NODE_NAME] requirements.txt bulundu, yükleniyor..." | tee -a /workspace/requirements_logs/install.log
            pip install -r "$NODE_DIR/requirements.txt" | tee -a /workspace/requirements_logs/install.log
            if [ $? -eq 0 ]; then
                echo "[$NODE_NAME] Gereksinimler başarıyla yüklendi" | tee -a /workspace/requirements_logs/install.log
            else
                echo "[$NODE_NAME] Gereksinimleri yüklerken hata oluştu" | tee -a /workspace/requirements_logs/install.log
            fi
        fi
        
        # Bazı node'lar setup.py kullanır
        if [ -f "$NODE_DIR/setup.py" ]; then
            echo "[$NODE_NAME] setup.py bulundu, yükleniyor..." | tee -a /workspace/requirements_logs/install.log
            pip install -e "$NODE_DIR" | tee -a /workspace/requirements_logs/install.log
        fi
        
        # Bazı node'lar install.py kullanır
        if [ -f "$NODE_DIR/install.py" ]; then
            echo "[$NODE_NAME] install.py bulundu, çalıştırılıyor..." | tee -a /workspace/requirements_logs/install.log
            python "$NODE_DIR/install.py" | tee -a /workspace/requirements_logs/install.log
        fi
    fi
done

# Hata mesajlarında bahsedilen eksik modülleri doğrudan yükle
echo "Hata mesajlarında belirtilen eksik paketler yükleniyor..." | tee -a /workspace/requirements_logs/install.log
pip install insightface piexif | tee -a /workspace/requirements_logs/install.log

echo "$(date) - Custom node gereksinimlerinin yüklenmesi tamamlandı" | tee -a /workspace/requirements_logs/install.log
