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


#if [ -t 1 ]; then
#        export PS1="\e[1;34m[\e[1;33m\u@\e[1;32mdocker-\h\e[1;37m:\w\[\e[1;34m]\e[1;36m\\$ \e[0m"
#fi

####Custom Prompt


export PS1="\[\e[34m\]\@\[\e[m\]:\[\e[37m\][\[\e[m\]\[\e[31m\]\u\[\e[m\]@\[\e[33m\]\h\[\e[m\]:\[\e[31m\]\W\[\e[m\]\[\e[37m\]]\[\e[m\]\[\e[37m\]\\$\[\e[m\]"


#export PS1='\[\033[35;1m\]\u\[\033[0m\]@\[\033[31;1m\]\h \[\033[32;1m\]$PWD\[\033[0m\] [\[\033[35m\]\#\[\033[0m\]]\[\033[31m\]\$\[\033[0m\] '

### Initial Banner
echo -e "\E[1;36mVersion \E[1;32m${NPM_BUILD_VERSION:-2.0.0-dev} (${NPM_BUILD_COMMIT:-dev}) ${NPM_BUILD_DATE:-0000-00-00}\E[1;36m, OpenResty \E[1;32m${OPENRESTY_VERSION:-unknown}\E[1;36m, ${ID:-centos} \E[1;32m${VERSION:-unknown}\E[1;36m, Certbot \E[1;32m$(certbot --version)\E[0m"

# Custom Aliases
alias l='ls -lAsh --color'
alias ls='ls -C1 --color'
alias h='cd ~;clear;'
alias u="cd .."
alias ll="ls -lA --color=yes | less -r -E -X"
alias l="ls -l --color=yes "
alias p="ping -c 3 google.com"
alias vim="vi"


echo -e -n '\E[1;34m'
figlet -w 50 "NginxProxyManager"
echo "├──Emmanuel Loaiza"
echo "├──ELIKESBIKES"
echo "└──"$(date +"%B%e"), $(date +"%Y")
echo -e -n '\E[1;34m'
uptime
echo -e '\E[0m'