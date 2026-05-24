#!/bin/zsh

# ML artifacts cleanup - removes model files and metaflow data blobs
mlclean() {
    local base_path="${1:-$HOME/Code/mlsoar}"
    local json_mode=false
    local auto_yes=false
    
    # Check for --json flag (could be first or second arg)
    if [[ "$1" == "--json" ]]; then
        json_mode=true
        base_path="${2:-$HOME/Code/mlsoar}"
    elif [[ "$2" == "--json" ]]; then
        json_mode=true
    fi
    
    # Check for -y/--yes flag (could be first, second, or third arg)
    if [[ "$1" == "-y" || "$1" == "--yes" ]]; then
        auto_yes=true
        if [[ -z "$2" || "$2" == "--json" ]]; then
            base_path="${3:-$HOME/Code/mlsoar}"
        else
            base_path="$2"
        fi
    elif [[ "$2" == "-y" || "$2" == "--yes" ]]; then
        auto_yes=true
    elif [[ "$3" == "-y" || "$3" == "--yes" ]]; then
        auto_yes=true
    fi
    
    if [[ ! -d "$base_path" ]]; then
        if [[ "$json_mode" == true ]]; then
            echo "{\"error\": \"Directory not found: $base_path\"}" >&2
        else
            echo "Error: Directory not found: $base_path"
        fi
        return 1
    fi
    
    if [[ "$json_mode" != true ]]; then
        echo "Scanning for ML artifacts in: $base_path"
        echo ""
    fi
    
    # Find model files in mlartifacts
    local model_files=($(find "$base_path" -path "*mlartifacts*" -type f \
        \( -name "*.pkl" -o -name "*.joblib" -o -name "*.h5" -o -name "*.pt" -o -name "*.pth" -o -name "*.onnx" \) \
        2>/dev/null))
    
    # Find data blobs in .metaflow/*/data/
    local metaflow_files=($(find "$base_path" -path "*/.metaflow/*/data/*" -type f 2>/dev/null))
    
    # Find Metaflow card runs directories
    local metaflow_runs_dirs=($(find "$base_path" -path "*/.metaflow/mf.cards/*/runs" -type d 2>/dev/null))
    
    # Find Training directories in metaflow_client tmp
    local metaflow_client_path="/System/Volumes/Data/private/tmp/metaflow_client"
    local training_dirs=()
    if [[ -d "$metaflow_client_path" ]]; then
        training_dirs=($(find "$metaflow_client_path" -maxdepth 1 -type d -name "*Training*" 2>/dev/null))
    fi
    
    # Calculate sizes (in KB)
    local model_size_kb=0
    local metaflow_size_kb=0
    local metaflow_runs_size_kb=0
    local training_size_kb=0
    
    if [[ ${#model_files[@]} -gt 0 ]]; then
        model_size_kb=$(du -sk "${model_files[@]}" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    fi
    
    if [[ ${#metaflow_files[@]} -gt 0 ]]; then
        metaflow_size_kb=$(du -sk "${metaflow_files[@]}" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    fi
    
    if [[ ${#metaflow_runs_dirs[@]} -gt 0 ]]; then
        metaflow_runs_size_kb=$(du -sk "${metaflow_runs_dirs[@]}" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    fi
    
    if [[ ${#training_dirs[@]} -gt 0 ]]; then
        training_size_kb=$(du -sk "${training_dirs[@]}" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    fi
    
    local total_size_kb=$((model_size_kb + metaflow_size_kb + metaflow_runs_size_kb + training_size_kb))
    
    # JSON output mode
    if [[ "$json_mode" == true ]]; then
        local model_size_gb=$(awk "BEGIN {printf \"%.2f\", $model_size_kb / 1024 / 1024}")
        local metaflow_size_gb=$(awk "BEGIN {printf \"%.2f\", $metaflow_size_kb / 1024 / 1024}")
        local metaflow_runs_size_gb=$(awk "BEGIN {printf \"%.2f\", $metaflow_runs_size_kb / 1024 / 1024}")
        local training_size_gb=$(awk "BEGIN {printf \"%.2f\", $training_size_kb / 1024 / 1024}")
        local total_size_gb=$(awk "BEGIN {printf \"%.2f\", $total_size_kb / 1024 / 1024}")
        
        echo "{\"base_path\":\"$base_path\",\"model_files\":{\"count\":${#model_files[@]},\"size_kb\":$model_size_kb,\"size_gb\":$model_size_gb},\"metaflow_data\":{\"count\":${#metaflow_files[@]},\"size_kb\":$metaflow_size_kb,\"size_gb\":$metaflow_size_gb},\"metaflow_runs\":{\"count\":${#metaflow_runs_dirs[@]},\"size_kb\":$metaflow_runs_size_kb,\"size_gb\":$metaflow_runs_size_gb},\"training_dirs\":{\"count\":${#training_dirs[@]},\"size_kb\":$training_size_kb,\"size_gb\":$training_size_gb},\"total\":{\"size_kb\":$total_size_kb,\"size_gb\":$total_size_gb}}"
        return 0
    fi
    
    # Display summary
    echo "Found artifacts:"
    echo "  Model files: ${#model_files[@]} files"
    if [[ $model_size_kb -gt 0 ]]; then
        local model_size_gb=$(awk "BEGIN {printf \"%.2f\", $model_size_kb / 1024 / 1024}")
        echo "    Size: ${model_size_gb} GB"
    else
        echo "    Size: 0 GB"
    fi
    
    echo "  Metaflow data blobs: ${#metaflow_files[@]} files"
    if [[ $metaflow_size_kb -gt 0 ]]; then
        local metaflow_size_gb=$(awk "BEGIN {printf \"%.2f\", $metaflow_size_kb / 1024 / 1024}")
        echo "    Size: ${metaflow_size_gb} GB"
    else
        echo "    Size: 0 GB"
    fi
    
    echo "  Metaflow card runs: ${#metaflow_runs_dirs[@]} directories"
    if [[ $metaflow_runs_size_kb -gt 0 ]]; then
        local metaflow_runs_size_gb=$(awk "BEGIN {printf \"%.2f\", $metaflow_runs_size_kb / 1024 / 1024}")
        echo "    Size: ${metaflow_runs_size_gb} GB"
    else
        echo "    Size: 0 GB"
    fi
    
    echo "  Metaflow client Training dirs: ${#training_dirs[@]} directories"
    if [[ $training_size_kb -gt 0 ]]; then
        local training_size_gb=$(awk "BEGIN {printf \"%.2f\", $training_size_kb / 1024 / 1024}")
        echo "    Size: ${training_size_gb} GB"
    else
        echo "    Size: 0 GB"
    fi
    
    if [[ $total_size_kb -eq 0 ]]; then
        echo ""
        echo "No artifacts found to clean."
        return 0
    fi
    
    local total_size_gb=$(awk "BEGIN {printf \"%.2f\", $total_size_kb / 1024 / 1024}")
    echo ""
    echo "Total: ${#model_files[@]} model files + ${#metaflow_files[@]} data blobs + ${#metaflow_runs_dirs[@]} runs dirs + ${#training_dirs[@]} training dirs = ${total_size_gb} GB"
    echo ""
    
    # Prompt for confirmation (skip if auto_yes is true)
    if [[ "$auto_yes" != true ]]; then
        echo -n "Delete these artifacts? (y/N): "
        read -q response
        echo ""
        
        if [[ "$response" != "y" && "$response" != "Y" ]]; then
            echo "Cancelled."
            return 0
        fi
    fi
    
    echo ""
    echo "Deleting artifacts..."
    
    # Delete model files
    local deleted_models=0
    for file in "${model_files[@]}"; do
        if command rm -f "$file" 2>/dev/null; then
            ((deleted_models++))
        fi
    done
    
    # Delete metaflow data blobs
    local deleted_metaflow=0
    for file in "${metaflow_files[@]}"; do
        if command rm -f "$file" 2>/dev/null; then
            ((deleted_metaflow++))
        fi
    done
    
    # Delete metaflow card runs
    local deleted_runs=0
    for runs_dir in "${metaflow_runs_dirs[@]}"; do
        if find "$runs_dir" -mindepth 1 -print0 2>/dev/null | xargs -0 command rm -rf 2>/dev/null; then
            ((deleted_runs++))
        fi
    done
    
    # Empty Training directories (delete contents but keep the dir)
    local deleted_training=0
    for training_dir in "${training_dirs[@]}"; do
        if find "$training_dir" -mindepth 1 -delete 2>/dev/null; then
            ((deleted_training++))
        fi
    done
    
    echo "Deleted: $deleted_models model files, $deleted_metaflow metaflow data blobs, $deleted_runs runs directories cleaned, $deleted_training training directories emptied"
    echo "Done."
}
