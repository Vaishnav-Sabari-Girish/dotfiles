$env.STARSHIP_SHELL = "nu"
$env.STARSHIP_CONFIG = ($env.HOME | path join ".config/starship/nu/starship.toml")
$env.EDITOR = "nvim"

def starship_left_prompt [] {
    starship prompt --status=0 --cmd-duration 0
}

$env.PROMPT_COMMAND = { || starship_left_prompt }
$env.PROMPT_COMMAND_RIGHT = ""
$env.PROMPT_INDICATOR = ""
$env.PROMPT_INDICATOR_VI_INSERT = ": "
$env.PROMPT_INDICATOR_VI_NORMAL = "〉"
$env.PROMPT_MULTILINE_INDICATOR = "::: "
