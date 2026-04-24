# ~/.local/bin/boat_tracker.zsh

_BOAT_PROJECTS_DIR="$HOME/Desktop/My_Projects"

# Core tracking logic (Start/Switch)
_boat_start_tracking() {
    # Extract the top-level project folder name
    local rel_path="${PWD#$_BOAT_PROJECTS_DIR/}"
    local project_name="${rel_path%%/*}"
    
    # Append today's date to create a unique daily session name
    local today=$(date +%Y-%m-%d)
    local activity_name="${project_name}_${today}"

    # Fetch the currently active boat session
    local current_status=$(boat get 2>&1)

    # If boat isn't already tracking this exact daily activity, switch to it
    if [[ "$current_status" != *"$activity_name"* ]]; then
        
        # Pause any currently running activity to prevent overlap
        boat pause >/dev/null 2>&1
        
        # 1. Strip ANSI colors from `boat list` 
        # 2. Find the exact activity name
        # 3. Extract the numeric ID from the first column of the most recent match
        local existing_id=$(boat list | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -w "$activity_name" | tail -n 1 | awk '{print $1}')

        if [[ -n "$existing_id" ]]; then
            # Activity exists: Resume it by its unique ID
            boat start "$existing_id" >/dev/null 2>&1
        else
            # Activity doesn't exist today: Create it
            boat new "$activity_name" >/dev/null 2>&1
            
            # Fetch its newly assigned ID and start it
            local new_id=$(boat list | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -w "$activity_name" | tail -n 1 | awk '{print $1}')
            if [[ -n "$new_id" ]]; then
                boat start "$new_id" >/dev/null 2>&1
            fi
        fi
        
        echo -e "\033[0;36m⛵ boat-cli: Tracking $project_name (Session: $activity_name)\033[0m"
    fi
}

# Runs only when a new shell opens
_boat_auto_track_init() {
    if [[ "$PWD" == "$_BOAT_PROJECTS_DIR"/* ]]; then
        _boat_start_tracking
    fi
}

# Runs every time you change directories (cd, z, etc.)
_boat_auto_track_chpwd() {
    if [[ "$PWD" == "$_BOAT_PROJECTS_DIR"/* ]]; then
        # We navigated INTO or WITHIN the project directory
        _boat_start_tracking
    elif [[ "$OLDPWD" == "$_BOAT_PROJECTS_DIR"/* ]]; then
        # We navigated OUT OF the project directory to somewhere else
        boat pause >/dev/null 2>&1
        echo -e "\033[0;33m⛵ boat-cli: Tracking paused (left project directory)\033[0m"
    fi
}

# 1. Check once on shell startup 
_boat_auto_track_init

# 2. Hook into directory changes
autoload -U add-zsh-hook
add-zsh-hook chpwd _boat_auto_track_chpwd
