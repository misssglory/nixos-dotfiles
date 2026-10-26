# Optional short aliases and completion for the hydra-zellij CLI.
alias hstart='hydra-zellij start'
alias hreset='hydra-zellij reset'
alias hstop='hydra-zellij stop'
alias hstatus='hydra-zellij status'

if (( $+functions[compdef] )); then
  _hydra_zellij() {
    local -a commands
    commands=(
      'start:Create or focus the Hydra tab'
      'reset:Restart all five panes'
      'restart:Restart all five panes'
      'stop:Stop all five panes'
      'status:Show pane states'
      'focus:Focus the Hydra tab'
      'close:Stop and close the managed tab'
      'help:Show usage'
    )
    _describe 'hydra-zellij command' commands
  }
  compdef _hydra_zellij hydra-zellij
fi
