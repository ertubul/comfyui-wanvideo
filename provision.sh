#!/bin/bash

# Bu script, ComfyUI ve WanVideo modelleri için container hazırlama işlemlerini yapar
# Hata tespiti için verbose mod
set -e  # Hata durumunda script'in durmasını sağlar
set -x  # Her komutu ekrana yazdırır (debug için)

# Default workflow
DEFAULT_WORKFLOW="https://raw.githubusercontent.com/ertubul/comfyui-wanvideo/refs/heads/main/wanvideo-ertubul-720p.json"

# WanWrapper script'i - BU BÖLÜMÜ GÜNCELLEYIN
WAN_WRAPPER_SCRIPT="https://raw.githubusercontent.com/ertubul/comfyui-wanvideo/refs/heads/main/install_wan_wrapper.sh"

# Gerekli ComfyUI node'ları (WanVideo olmadan başlayacağız)
NODES=(
    # Temel komponentler
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/cubiq/ComfyUI_essentials"
    
    # Video işleme node'ları
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
    "https://github.com/city96/ComfyUI-GGUF"
    
    # Yardımcı node'lar
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
)

# Model dosyaları
DIFFUSION_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-T2V-14B_fp8_e4m3fn.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-720P_fp8_e4m3fn.safetensors"
)

# Text encoders
TEXTENCODERS_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/open-clip-xlm-roberta-large-vit-huge-14_fp16.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
)

# WanVideo VAE
VAE_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"
)

# CLIP Vision modelleri
CLIPVISION_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
)

### SCRIPT FONKSİYONLARI ###

function provisioning_start() {
    # Çevre değişkenlerini yükle
    if [[ ! -d /opt/environments/python ]]; then 
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    # Başlangıç mesajı
    provisioning_print_header
    
    # ComfyUI'yi doğru branch'e ayarlama
    echo "ComfyUI branch kontrolü yapılıyor..."
    if [[ "$COMFYUI_BRANCH" != "wan-model-release" ]]; then
        echo "⚠️ ComfyUI branch 'wan-model-release' değil. Değiştirmeyi deneyeceğiz..."
        cd "$WORKSPACE/ComfyUI"
        git fetch --all
        git checkout wan-model-release || echo "❌ Branch değiştirilemedi. Mevcutla devam ediliyor."
        cd /
    else
        echo "✅ ComfyUI doğru branch'de: wan-model-release"
    fi
    
    # HF Token kontrolü
    if [[ -n "$HF_TOKEN" ]]; then
        # Token var ama placeholder ya da köşeli parantez içeriyorsa düzelt
        if [[ $HF_TOKEN == *"{"* || $HF_TOKEN == *"}"* ]]; then
            echo "UYARI: HF_TOKEN içinde { } karakterleri bulundu. Temizleniyor..."
            # Placeholder parantezlerini temizle
            export HF_TOKEN=$(echo $HF_TOKEN | sed 's/[{}]//g')
            echo "HF_TOKEN düzeltildi: ${HF_TOKEN:0:3}...${HF_TOKEN: -3}"
        else
            echo "HF_TOKEN mevcut: ${HF_TOKEN:0:3}...${HF_TOKEN: -3}"
        fi
        
        # Token geçerli mi test et
        provisioning_test_hf_token
    else
        echo "UYARI: HF_TOKEN belirlenmemiş. Hugging Face model indirmeleri başarısız olabilir."
    fi
    
    # Model dizinleri ve izinleri
    echo "Model dizinlerini oluşturma ve izin verme..."
    mkdir -p "${WORKSPACE}/ComfyUI/models/diffusion_models"
    mkdir -p "${WORKSPACE}/ComfyUI/models/clip_vision"
    mkdir -p "${WORKSPACE}/ComfyUI/models/text_encoders"
    mkdir -p "${WORKSPACE}/ComfyUI/models/vae"
    mkdir -p "${WORKSPACE}/ComfyUI/models/frame_interpolation"
    
    # Tam izinler ver
    chmod -R 777 "${WORKSPACE}/ComfyUI/models"
    
    # Temel node'ları indir
    provisioning_get_nodes "${NODES[@]}"
    
    # Model dosyalarını indir
    echo "Diffusion modellerini indirme..."
    for model in "${DIFFUSION_MODELS[@]}"; do
        provisioning_download "$model" "${WORKSPACE}/ComfyUI/models/diffusion_models"
    done
    
    echo "Text encoder modellerini indirme..."
    for model in "${TEXTENCODERS_MODELS[@]}"; do
        provisioning_download "$model" "${WORKSPACE}/ComfyUI/models/text_encoders"
    done
    
    echo "VAE modellerini indirme..."
    for model in "${VAE_MODELS[@]}"; do
        provisioning_download "$model" "${WORKSPACE}/ComfyUI/models/vae"
    done
    
    echo "CLIP Vision modellerini indirme..."
    for model in "${CLIPVISION_MODELS[@]}"; do
        provisioning_download "$model" "${WORKSPACE}/ComfyUI/models/clip_vision"
    done

    # FILM modelini indir
    echo "FILM Frame Interpolation modelini indirme..."
    provisioning_download "https://huggingface.co/nguu/film-pytorch/resolve/887b2c42bebcb323baf6c3b6d59304135699b575/film_net_fp32.pt" "${WORKSPACE}/ComfyUI/models/frame_interpolation"
    
    # Default workflow ayarla
    if [[ -n "$DEFAULT_WORKFLOW" ]]; then
        provisioning_get_default_workflow
    fi
    
    # WanVideo wrapper kurulum script'ini çalıştır
    run_wan_wrapper_script
    
    # İndirilen modelleri kontrol et
    echo "İndirilen modelleri kontrol ediliyor..."
    provisioning_verify_downloads
    
    # Tamamlandı mesajı
    provisioning_print_end
}

function run_wan_wrapper_script() {
    echo "🔄 WanVideo Wrapper kurulum script'i indiriliyor ve çalıştırılıyor..."
    
    # Script'i indirme
    wget -q -O /tmp/install_wan_wrapper.sh "$WAN_WRAPPER_SCRIPT"
    
    # İndirme başarılı mı kontrol et
    if [ $? -ne 0 ]; then
        echo "❌ WanVideo Wrapper script'i indirilemedi: $WAN_WRAPPER_SCRIPT"
        return 1
    fi
    
    # Çalıştırma izinleri ver
    chmod +x /tmp/install_wan_wrapper.sh
    
    # Script'i çalıştır
    echo "🚀 WanVideo Wrapper kurulum script'i çalıştırılıyor..."
    /tmp/install_wan_wrapper.sh
    
    # Çalıştırma başarılı mı kontrol et
    if [ $? -ne 0 ]; then
        echo "❌ WanVideo Wrapper kurulum script'i çalıştırılamadı"
        return 1
    fi
    
    echo "✅ WanVideo Wrapper kurulumu tamamlandı"
    return 0
}

function provisioning_test_hf_token() {
    echo "Hugging Face token testi yapılıyor..."
    url="https://huggingface.co/api/whoami-v2"
    response=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")
    
    if [ "$response" -eq 200 ]; then
        echo "✅ HF_TOKEN geçerli. Model indirme işlemi çalışacak."
    else
        echo "⚠️ UYARI: HF_TOKEN geçerli değil! (HTTP cevap kodu: $response)"
        echo "Token olmadan indirmeyi deneyeceğiz, ama hız sınırlamasına takılabilirsiniz."
    fi
}

function provisioning_get_nodes() {
    echo "ComfyUI node'larını indirme..."
    for repo in "$@"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        
        if [[ -d $path ]]; then
            echo "📦 Node güncelleniyor: ${repo}"
            ( cd "$path" && git pull )
        else
            echo "📥 Node indiriliyor: ${repo}"
            git clone --depth 1 "${repo}" "${path}"
        fi
        
        if [[ -e $requirements ]]; then
            echo "🧰 Gereksinimler yükleniyor: ${requirements}"
            if [[ -z $MAMBA_BASE ]]; then
                "$COMFYUI_VENV_PIP" install --no-cache-dir -r "$requirements"
            else
                micromamba run -n comfyui pip install --no-cache-dir -r "$requirements"
            fi
        fi
    done
}

function provisioning_get_default_workflow() {
    echo "Varsayılan workflow indiriliyor: ${DEFAULT_WORKFLOW}"
    workflow_json=$(curl -s "$DEFAULT_WORKFLOW")
    if [[ -n $workflow_json ]]; then
        echo "export const defaultGraph = $workflow_json;" > /opt/ComfyUI/web/scripts/defaultGraph.js
        echo "✅ Varsayılan workflow başarıyla ayarlandı."
    else
        echo "❌ HATA: Varsayılan workflow indirilemedi!"
    fi
}

function provisioning_download() {
    url="$1"
    output_dir="$2"
    filename=$(basename "$url" | sed 's/\?.*//')  # URL parametrelerini kaldır
    
    echo "📥 İndiriliyor: ${url} -> ${output_dir}/${filename}"
    
    # Dizini oluştur ve izinlerini ayarla
    mkdir -p "$output_dir"
    chmod 777 "$output_dir"
    
    # İndirme denemeleri - 3 deneme yap
    max_retries=3
    retry_count=0
    success=false
    
    while [ $retry_count -lt $max_retries ] && [ "$success" != "true" ]; do
        # HF_TOKEN varsa ve URL huggingface.co'dan ise kullan
        if [[ -n "$HF_TOKEN" && "$url" == *"huggingface.co"* ]]; then
            echo "🔑 Hugging Face token kullanılıyor (deneme $((retry_count+1))/$max_retries)..."
            wget --header="Authorization: Bearer $HF_TOKEN" \
                 --content-disposition \
                 --show-progress \
                 --continue \
                 -P "$output_dir" "$url" && success=true
        else
            wget --content-disposition \
                 --show-progress \
                 --continue \
                 -P "$output_dir" "$url" && success=true
        fi
        
        # İndirme başarılı değilse bekle ve yeniden dene
        if [ "$success" != "true" ]; then
            retry_count=$((retry_count+1))
            if [ $retry_count -lt $max_retries ]; then
                echo "⚠️ İndirme başarısız oldu. Yeniden deneniyor... ($retry_count/$max_retries)"
                sleep 5  # Yeniden denemeden önce biraz bekle
            fi
        fi
    done
    
    # İndirme sonucunu kontrol et
    if [ "$success" == "true" ]; then
        # İndirilen dosyayı doğrula
        find "$output_dir" -type f -name "$filename" -o -name "$(basename "$url" | cut -d? -f1)" | while read file; do
            file_size=$(du -h "$file" | cut -f1)
            echo "✅ Başarıyla indirildi: $file ($file_size)"
            # Dosyaya herkesin erişebilmesi için izin ver
            chmod 666 "$file"
        done
        return 0
    else
        echo "❌ HATA: $url dosyası $max_retries denemeye rağmen indirilemedi!"
        return 1
    fi
}

function provisioning_verify_downloads() {
    echo "🔍 İndirilen dosyaları doğrulama..."
    
    # Model dizinlerini listele ve dosya sayısını göster
    for dir in "${WORKSPACE}/ComfyUI/models"/*; do
        if [ -d "$dir" ]; then
            file_count=$(find "$dir" -type f | wc -l)
            dir_size=$(du -sh "$dir" | cut -f1)
            echo "📁 Dizin: $dir - $file_count dosya ($dir_size)"
            
            # Dosya listesini göster
            if [ "$file_count" -gt 0 ]; then
                find "$dir" -type f -name "*.safetensors" -o -name "*.pt" | while read file; do
                    file_size=$(du -h "$file" | cut -f1)
                    echo "  - $(basename "$file") ($file_size)"
                done
            else
                echo "  ⚠️ UYARI: Bu dizinde dosya bulunamadı!"
            fi
        fi
    done
    
    # İndirme şeması oluştur
    echo "📊 İndirme özeti:"
    echo "-----------------------"
    echo "✅ Diffusion modelleri: $(find "${WORKSPACE}/ComfyUI/models/diffusion_models" -type f | wc -l) dosya"
    echo "✅ Text encoders: $(find "${WORKSPACE}/ComfyUI/models/text_encoders" -type f | wc -l) dosya"
    echo "✅ VAE modelleri: $(find "${WORKSPACE}/ComfyUI/models/vae" -type f | wc -l) dosya"
    echo "✅ CLIP Vision: $(find "${WORKSPACE}/ComfyUI/models/clip_vision" -type f | wc -l) dosya"
    echo "✅ Frame Interpolation: $(find "${WORKSPACE}/ComfyUI/models/frame_interpolation" -type f | wc -l) dosya"
    echo "-----------------------"
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          WanVideo Container Setup          #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\n##############################################\n#                                            #\n#          Kurulum tamamlandı!               #\n#                                            #\n#    ComfyUI arayüzü başlatılıyor...        #\n#                                            #\n##############################################\n\n"
}

# Ana fonksiyonu çalıştır
provisioning_start
