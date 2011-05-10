# Setup an alias for git-achievements

export PATH="$PATH:$ZSH/plugins/git-achievements"

# setup the git alias function.

# Since there are a few other scripts out there that alias the git command, let's check for them first, and use them.

pref_git_alias=$(echo "$aliases[git]" | sed -e 's/^[ \t]*//')
pref_git_func=$(echo "$functions[git]" | sed -e 's/^[ \t]*//')

rm -f $ZSH/plugins/git-achievements/pref_git_cmd

echo "#!/bin/zsh" > "$ZSH/plugins/git-achievements/pref_git_cmd"

    
if [ ! -z pref_git_func ]; then
    echo "$pref_git_func" >> "$ZSH/plugins/git-achievements/pref_git_cmd"
elif [ ! -z pref_git_alias ]; then
    echo "$pref_git_alias" >> "$ZSH/plugins/git-achievements/pref_git_cmd"
else
    echo "git" >> "$ZSH/plugins/git-achievements/pref_git_cmd"
fi

chmod +x "$ZSH/plugins/git-achievements/pref_git_cmd"
               
function git() {
    git-achievements "$@"
}
