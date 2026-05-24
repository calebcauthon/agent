#!/bin/zsh

# Change Ghostty background image to a random file from ~/code/ghostty_background_images
# Usage: ghosttybg
ghosttybg() {
    local images_dir="$HOME/code/ghostty_background_images"
    local config_path="$HOME/Library/Application Support/com.mitchellh.ghostty/config"

    if [ ! -d "$images_dir" ]; then
        echo "Directory not found: $images_dir" >&2
        return 1
    fi

    if [ ! -f "$config_path" ]; then
        echo "Ghostty config not found: $config_path" >&2
        return 1
    fi

    setopt localoptions extendedglob null_glob nocaseglob

    # Collect common image types (case-insensitive via nocaseglob)
    local -a images
    images=($images_dir/*.{jpg,jpeg,png,gif,webp,heic,tiff,bmp,avif}(N))

    if [ ${#images[@]} -eq 0 ]; then
        echo "No images found in: $images_dir" >&2
        return 1
    fi

    # Pick a random image
    local idx=$(( (RANDOM % ${#images[@]}) + 1 ))
    local chosen="${images[$idx]}"

    # Build tilde-based path for config (keep ~ rather than $HOME)
    local basename="${chosen:t}"
    local tilde_path="~/code/ghostty_background_images/$basename"

    # Choose random position and fit
    local -a positions fits
    positions=(top-left top-center top-right center-left center center-right bottom-left bottom-center bottom-right)
    fits=(cover contain)

    local pidx=$(( (RANDOM % ${#positions[@]}) + 1 ))
    local fidx=$(( (RANDOM % ${#fits[@]}) + 1 ))
    local chosen_pos="${positions[$pidx]}"
    local chosen_fit="${fits[$fidx]}"

    local pos_value
    if [ "$chosen_pos" = "center" ]; then
        pos_value="center-center"
    else
        pos_value="$chosen_pos"
    fi

    # Update background-image line; preserve any leading indentation if present
    if /usr/bin/grep -Eq '^[[:space:]]*background-image[[:space:]]*=' "$config_path"; then
        /usr/bin/sed -E -i '' "s|^([[:space:]]*)background-image[[:space:]]*=.*$|\\1background-image = $tilde_path|" "$config_path"
    else
        printf '\nbackground-image = %s\n' "$tilde_path" >> "$config_path"
    fi

    # Update background-image-position
    if /usr/bin/grep -Eq '^[[:space:]]*background-image-position[[:space:]]*=' "$config_path"; then
        /usr/bin/sed -E -i '' "s|^([[:space:]]*)background-image-position[[:space:]]*=.*$|\\1background-image-position = $pos_value|" "$config_path"
    else
        printf '\nbackground-image-position = %s\n' "$pos_value" >> "$config_path"
    fi

    # Update background-image-fit
    if /usr/bin/grep -Eq '^[[:space:]]*background-image-fit[[:space:]]*=' "$config_path"; then
        /usr/bin/sed -E -i '' "s|^([[:space:]]*)background-image-fit[[:space:]]*=.*$|\\1background-image-fit = $chosen_fit|" "$config_path"
    else
        printf '\nbackground-image-fit = %s\n' "$chosen_fit" >> "$config_path"
    fi

    # echo "Set Ghostty background-image to: $tilde_path"
    # echo "Set Ghostty background-image-position to: $pos_value"
    # echo "Set Ghostty background-image-fit to: $chosen_fit"
}

# Ghostty configuration manager
ghoset() {
    local setting="$1"
    local value="$2"
    local config_file="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
    local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"

    # Handle different argument counts
    if [[ $# -eq 1 ]]; then
        # Display current and backup values
        ghoset_show "$setting"
        return $?
    elif [[ $# -ne 2 ]]; then
        echo "Usage:"
        echo "  ghoset <setting>           # Show current and backup values"
        echo "  ghoset <setting> <value>   # Set a new value"
        echo ""
        echo "Examples:"
        echo "  ghoset theme              # Show theme values"
        echo "  ghoset theme light        # Set theme to light"
        return 1
    fi

    # Setting a new value (original functionality)
    # Check if config file exists
    if [[ ! -f "$config_file" ]]; then
        echo "❌ Ghostty config file not found: $config_file"
        return 1
    fi

    # Create backup
    echo "📋 Creating backup of current config..."
    cp "$config_file" "$backup_file"

    # Check if setting exists and update/insert
    local setting_exists=false
    local new_content=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*${setting}[[:space:]]*= ]] || [[ "$line" =~ ^#[[:space:]]*${setting}[[:space:]]*= ]]; then
            # Setting exists, update it
            new_content+="${setting} = ${value}\n"
            setting_exists=true
            echo "✏️  Updating existing setting: $setting = $value"
        else
            new_content+="${line}\n"
        fi
    done < "$config_file"

    # If setting doesn't exist, add it
    if [[ "$setting_exists" == "false" ]]; then
        new_content+="\n# Added by ghoset command\n"
        new_content+="${setting} = ${value}\n"
        echo "✨ Adding new setting: $setting = $value"
    fi

    # Write updated config
    echo "$new_content" > "$config_file"

    # Verify the change
    if grep -q "^${setting}[[:space:]]*=" "$config_file"; then
        echo "✅ Successfully updated Ghostty config!"
        echo "📄 Backup saved as: $backup_file"
        echo "🎯 $setting is now set to: $value"
        echo ""
        echo "💡 Restart Ghostty or press Ctrl+R to reload the configuration."
    else
        echo "❌ Failed to update config. Restoring from backup..."
        cp "$backup_file" "$config_file"
        return 1
    fi
}

# Helper function to show current and backup values
ghoset_show() {
    local setting="$1"
    local config_file="$HOME/Library/Application Support/com.mitchellh.ghostty/config"

    if [[ ! -f "$config_file" ]]; then
        echo "❌ Ghostty config file not found: $config_file"
        return 1
    fi

    # Get current value
    local current_value=$(grep -E "^[[:space:]]*${setting}[[:space:]]*=" "$config_file" | sed -E "s/^[[:space:]]*${setting}[[:space:]]*=[[:space:]]*//" | head -1)

    if [[ -z "$current_value" ]]; then
        echo "🎯 Setting '$setting' is not currently set in your Ghostty config."
    else
        echo "🎯 Current $setting: $current_value"
    fi

    # Find most recent backup file
    local latest_backup=$(ls -t "$config_file".backup.* 2>/dev/null | head -1)

    if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
        # Get backup value
        local backup_value=$(grep -E "^[[:space:]]*${setting}[[:space:]]*=" "$latest_backup" | sed -E "s/^[[:space:]]*${setting}[[:space:]]*=[[:space:]]*//" | head -1)

        # Format backup timestamp
        local backup_timestamp=$(echo "$latest_backup" | sed -E "s/.*\.backup\.([0-9]{8}_[0-9]{6})$/\1/")
        local formatted_time=$(echo "$backup_timestamp" | sed -E 's/([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})/\1-\2-\3 \4:\5:\6/')

        echo "📋 Recent backup ($formatted_time):"

        if [[ -z "$backup_value" ]]; then
            echo "   $setting was not set in the backup"
        else
            echo "   $setting was: $backup_value"
        fi

        # Show change summary
        if [[ -n "$current_value" && -n "$backup_value" ]]; then
            if [[ "$current_value" != "$backup_value" ]]; then
                echo "🔄 Changed from '$backup_value' to '$current_value'"
            else
                echo "✨ No change - same value in backup and current config"
            fi
        elif [[ -n "$current_value" && -z "$backup_value" ]]; then
            echo "✨ Added new setting: was not set, now '$current_value'"
        elif [[ -z "$current_value" && -n "$backup_value" ]]; then
            echo "🗑️  Removed setting: was '$backup_value', now not set"
        fi

        echo ""
        echo "📁 Backup file: $(basename "$latest_backup")"
    else
        echo "📋 No backup files found yet."
    fi

    echo ""
    echo "💡 To set a new value: ghoset $setting <new-value>"
}


