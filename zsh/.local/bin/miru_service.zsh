# ~/.local/bin/miru_service.zsh

_MIRU_PROJECT_DIR="$HOME/Desktop/My_Projects/miru"
_MIRU_SERVICE="miru.service"

_miru_stop_service() {
    if systemctl --user is-active --quiet "$_MIRU_SERVICE"; then
        systemctl --user stop "$_MIRU_SERVICE"
        echo -e "\033[0;33m🛑 miru: stopped $_MIRU_SERVICE\033[0m"
    fi
}

_miru_start_service() {
    if ! systemctl --user is-active --quiet "$_MIRU_SERVICE"; then
        systemctl --user start "$_MIRU_SERVICE"
        echo -e "\033[0;32m▶️ miru: started $_MIRU_SERVICE\033[0m"
    fi
}

# Runs when a new shell opens inside the project
_miru_service_init() {
    if [[ "$PWD" == "$_MIRU_PROJECT_DIR"* ]]; then
        _miru_stop_service
    fi
}

# Runs on every directory change
_miru_service_chpwd() {
    if [[ "$PWD" == "$_MIRU_PROJECT_DIR"* ]]; then
        _miru_stop_service
    elif [[ "$OLDPWD" == "$_MIRU_PROJECT_DIR"* ]]; then
        _miru_start_service
    fi
}

_miru_service_init

autoload -U add-zsh-hook
add-zsh-hook chpwd _miru_service_chpwd
