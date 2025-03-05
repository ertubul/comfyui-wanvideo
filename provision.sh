#!/bin/bash

# Bu script, ComfyUI ve WanVideo modelleri için container hazırlama işlemlerini yapar
# Hata tespiti için verbose mod
set -e  # Hata durumunda script'in durmasını sağlar

# WanVideo I2V workflowi için özelleştirilmiş
DEFAULT_WORKFLOW="https://raw.githubusercontent.com/ertubul/comfyui-wanvideo/refs/heads/main/wanvideo-ertubul-720p.json"

# ComfyUI sürümü - Wan modelleriyle uyumlu sürüm
COMFYUI_COMMIT="b6af2b24ecf267a678fe9144581481de24b37013"  # ComfyUI WanVideo uyumlu sürüm

# WanVideo modelleri için gereken node'lar
NODES=(
    # Temel komponentler
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/cubiq/ComfyUI_essentials"
    
    # WanVideo desteği için gerekli node'lar
    "https://github.com/kijai/ComfyUI-WanVideoWrapper"
    "https://github.com/kijai/ComfyUI-KJNodes"
    
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

# WanVideo modelleri - diffusion_models dizinine
DIFFUSION_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-T2V-14B_fp8_e4m3fn.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-720P_fp8_e4m3fn.safetensors"
)

# Text encoders
TEXTENCODERS_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/open-clip-xlm-roberta-large-vit-huge-14_fp16.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors"
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

    # ComfyUI'yi spesifik versiyona ayarlama
    echo "ComfyUI'yi WanVideo için uyumlu sürüme ayarlama..."
    cd /opt/ComfyUI
    git fetch
    git checkout $COMFYUI_COMMIT
    cd /

    # Provisioning başlangıç mesajı
    provisioning_print_header
    
    # Düzgün çalışıp çalışmadığını kontrol etmek için HF_TOKEN'ı görüntüleme
    # Gerçek token'ı gizliyoruz ama geçerli bir token olup olmadığını kontrol ediyoruz
    if [[ -n "$HF_TOKEN" ]]; then
        echo "HF_TOKEN mevcut: ${HF_TOKEN:0:3}...${HF_TOKEN: -3}"
        provisioning_test_hf_token
    else
        echo "UYARI: HF_TOKEN belirlenmemiş. Hugging Face model indirmeleri başarısız olabilir."
    fi
    
    # Node'ları indirme
    provisioning_get_nodes
    
    # Modelleri indirme ve izinleri ayarlama
    echo "Model dizinlerini oluşturma..."
    mkdir -p "${WORKSPACE}/ComfyUI/models/diffusion_models"
    mkdir -p "${WORKSPACE}/ComfyUI/models/clip_vision"
    mkdir -p "${WORKSPACE}/ComfyUI/models/text_encoders"
    mkdir -p "${WORKSPACE}/ComfyUI/models/vae"
    mkdir -p "${WORKSPACE}/ComfyUI/models/frame_interpolation"
    
    # Dizinlere yazma izni verme
    chmod -R 777 "${WORKSPACE}/ComfyUI/models"
    
    # Modelleri indirme
    echo "Diffusion modellerini indirme..."
    provisioning_get_models "${WORKSPACE}/ComfyUI/models/diffusion_models" "${DIFFUSION_MODELS[@]}"
    
    echo "Text encoder modellerini indirme..."
    provisioning_get_models "${WORKSPACE}/ComfyUI/models/text_encoders" "${TEXTENCODERS_MODELS[@]}"
    
    echo "VAE modellerini indirme..."
    provisioning_get_models "${WORKSPACE}/ComfyUI/models/vae" "${VAE_MODELS[@]}"
    
    echo "CLIP Vision modellerini indirme..."
    provisioning_get_models "${WORKSPACE}/ComfyUI/models/clip_vision" "${CLIPVISION_MODELS[@]}"

    # FILM modelini indirme
    echo "FILM Frame Interpolation modelini indirme..."
    provisioning_download "https://huggingface.co/nguu/film-pytorch/resolve/887b2c42bebcb323baf6c3b6d59304135699b575/film_net_fp32.pt" "${WORKSPACE}/ComfyUI/models/frame_interpolation"
    
    # Default workflow ayarlama
    if [[ -n "$DEFAULT_WORKFLOW" ]]; then
        provisioning_get_default_workflow
    fi
    
    # İndirilen modelleri kontrol etme
    echo "İndirilen modelleri kontrol ediliyor..."
    provisioning_verify_downloads
    
    # Tamamlandı mesajı
    provisioning_print_end
}

function provisioning_test_hf_token() {
    echo "Hugging Face token testi yapılıyor..."
    url="https://huggingface.co/api/whoami-v2"
    response=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")
    
    if [ "$response" -eq 200 ]; then
        echo "HF_TOKEN geçerli. Model indirme işlemi çalışacak."
    else
        echo "UYARI: HF_TOKEN geçerli değil! Token düzeltilmeli ({{}} karakterleri olmamalı)."
    fi
}

function provisioning_get_nodes() {
    echo "ComfyUI node'larını indirme..."
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        
        if [[ -d $path ]]; then
            echo "Node güncelleniyor: ${repo}"
            ( cd "$path" && git pull )
        else
            echo "Node indiriliyor: ${repo}"
            git clone "${repo}" "${path}" --recursive
        fi
        
        if [[ -e $requirements ]]; then
            echo "Gereksinimler yükleniyor: ${requirements}"
            if [[ -z $MAMBA_BASE ]]; then
                "$COMFYUI_VENV_PIP" install -r "$requirements"
            else
                micromamba run -n comfyui pip install -r "$requirements"
            fi
        fi
    done
}

function provisioning_get_default_workflow() {
    echo "Varsayılan workflow indiriliyor: ${DEFAULT_WORKFLOW}"
    workflow_json=$(curl -s "$DEFAULT_WORKFLOW")
    if [[ -n $workflow_json ]]; then
        echo "export const defaultGraph = $workflow_json;" > /opt/ComfyUI/web/scripts/defaultGraph.js
        echo "Varsayılan workflow başarıyla ayarlandı."
    else
        echo "HATA: Varsayılan workflow indirilemedi!"
    fi
}

function provisioning_download() {
    url="$1"
    output_dir="$2"
    filename=$(basename "$url" | sed 's/\?.*//')  # URL parametrelerini kaldır
    
    echo "İndiriliyor: ${url} -> ${output_dir}/${filename}"
    
    # HF_TOKEN varsa ve URL huggingface.co'dan ise kullan
    if [[ -n "$HF_TOKEN" && "$url" == *"huggingface.co"* ]]; then
        echo "Hugging Face token kullanılıyor..."
        wget --header="Authorization: Bearer $HF_TOKEN" \
             --content-disposition \
             --show-progress \
             --continue \
             -P "$output_dir" "$url"
    else
        wget --content-disposition \
             --show-progress \
             --continue \
             -P "$output_dir" "$url"
    fi
    
    # İndirme başarısını kontrol et
    if [ $? -ne 0 ]; then
        echo "HATA: ${url} indirilemedi!"
        return 1
    else
        # İndirilen dosyayı doğrula
        find "$output_dir" -type f -name "$filename" -o -name "$(basename "$url" | cut -d? -f1)" | while read file; do
            echo "Başarıyla indirildi: $file ($(du -h "$file" | cut -f1))"
            # Dosyaya herkesin erişebilmesi için izin ver
            chmod 666 "$file"
        done
    fi
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
    
    dir="$1"
    mkdir -p "$dir"
    chmod 777 "$dir"
    
    shift
    models=("$@")
    
    echo "${#models[@]} model ${dir} konumuna indiriliyor..."
    
    for url in "${models[@]}"; do
        provisioning_download "$url" "$dir"
    done
}

function provisioning_verify_downloads() {
    echo "İndirilen dosyaları doğrulama..."
    
    # Model dizinlerini listele ve dosya sayısını göster
    for dir in "${WORKSPACE}/ComfyUI/models"/*; do
        if [ -d "$dir" ]; then
            file_count=$(find "$dir" -type f | wc -l)
            dir_size=$(du -sh "$dir" | cut -f1)
            echo "Dizin: $dir - $file_count dosya ($dir_size)"
            
            # Dosya listesini göster
            if [ "$file_count" -gt 0 ]; then
                find "$dir" -type f -name "*.safetensors" -o -name "*.pt" | while read file; do
                    file_size=$(du -h "$file" | cut -f1)
                    echo "  - $(basename "$file") ($file_size)"
                done
            else
                echo "  UYARI: Bu dizinde dosya bulunamadı!"
            fi
        fi
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          WanVideo Container Setup          #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nKurulum tamamlandı: ComfyUI başlatılıyor...\n\n"
}

# Ana fonksiyonu çalıştır
provisioning_start
