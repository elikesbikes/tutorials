# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend


# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

####Custom Prompt

export PS1="\[$(tput bold)\]\[$(tput setaf 6)\]\@ \[$(tput setaf 2)\][\[$(tput setaf 3)\]\[$(tput setaf 39)\]\u\[$(tput setaf 81)\]@\[$(tput setaf 77)\]\h \[$(tput setaf 226)\]\w \[$(tput setaf 2)\]]\[$(tput setaf 4)\]\\$ \[$(tput sgr0)\]"

PS1=$(ip route get 1.1.1.1 | awk -F"src " '"'"'NR == 1{ split($2, a," ");print a[1]}'"'"')

#export PS1='\[\033[35;1m\]\u\[\033[0m\]@\[\033[31;1m\]\h \[\033[32;1m\]$PWD\[\033[0m\] [\[\033[35m\]\#\[\033[0m\]]\[\033[31m\]\$\[\033[0m\] '

### Initial Banner

export PS1="\[$(tput bold)\]\[$(tput setaf 6)\]\@ \[$(tput setaf 2)\][\[$(tput setaf 3)\]\[$(tput setaf 39)\]\u\[$(tput setaf 81)\]@\[$(tput setaf 77)\]\h \[$(tput setaf 226)\]\w \[$(tput setaf 2)\]]\[$(tput setaf 4)\]\\$ \[$(tput sgr0)\]"
# Custom Aliases
alias rm='rm -i'
alias mv='mv -i'
alias u="cd .."
alias ls='ls -lA --color=yes | less -r -E -X'
alias cp='cp -ip'
alias rm='rm -i'
alias mv='mv -i'
alias ll='ls -A | less -r -E -X'
alias p="ping -c 3 google.com"
alias l="ll"
alias vim="vi"


echo -e -n '\E[1;34m'
figlet -w 50 "NginxProxyManager"
echo "├──Emmanuel Loaiza"
echo "├──ELIKESBIKES"
echo "└──"$(date +"%B%e"), $(date +"%Y")
echo -e -n '\E[1;34m'
uptime
echo -e '\E[0m'


