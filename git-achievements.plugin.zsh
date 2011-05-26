# git-achievements-zsh
# Copyright (c) 2011, David Lee <camperdave614@gmail.com>

# Based on code that is Copyright (c) 2010, Benjamin C. Meyer <ben@meyerhome.net>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the project nor the
#    names of its contributors may be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

ACTIONLOGFILE="$HOME/.git-achievements-action.log"
ACHIEVEMENTSLOGFILE="$HOME/.git-achievements.log"

GITACHIEVEMENTSGITEXECPATH=$(git --exec-path)

GITACHIEVEMENTSINDEXPATH="$ZSH/plugins/git-achievements/index"



autoload -U add-zsh-hook

log_action()
{
    echo "$@" >> "${ACTIONLOGFILE}"
    echo -n "Date: " >> "${ACTIONLOGFILE}"
    date >> "${ACTIONLOGFILE}"
}

output_achievement()
{
echo "
********************************************************************************
Git Achievement Unlocked!

$1
$2
********************************************************************************
" |  sed  -e :a -e 's/^.\{1,79\}$/ & /;ta'
}

unlock_achievement()
{
    export GITACHIEVEMENTSDONTRUN=1
    
    grep "$1" "${ACHIEVEMENTSLOGFILE}" > /dev/null 2>/dev/null
    if [ $? -eq 0 ] ; then
        return
    fi
    output_achievement "$@" >&2
    output_achievement "$@" >> "${ACHIEVEMENTSLOGFILE}"

    if [ "`git config --global achievement.upload`" = "true" ] ; then
        publish_achievements "$@"
    fi
    
    export GITACHIEVEMENTSDONTRUN=0
}

count_command()
{
    export power=`awk "BEGIN {n=0} /$1/ {n++} END { print log(n)/log(2) }" "$ACTIONLOGFILE"`
    export count=`awk "BEGIN {n=0} /$1/ {n++} END { print n }" "$ACTIONLOGFILE"`
    #export powerof2=`awk "BEGIN {n=0} /$1/ {n++} END { print and(n, n-1) }" "$ACTIONLOGFILE"`
    # mysys gawk it old and doesn't have the bitwise operation and :( so we have to use perl for now
    export powerof2=`echo 'use Env; $y=$ENV{'count'}; $x=($y & ($y-1)); print "$x\n" ' | perl -`

    # Set a default value of 0. Bug seems to occur when the achievement is unlocked
    if [ ${count:-0} -eq 1 ] ; then
        powerof2="1"
    fi
    #echo "cmd: $1 powerof2: $powerof2 power: $power count: $count"
}

hcount_unlock_achievement()
{
    title="${1}"
    description="${2}"
    power="$3"
    case $power in
        1|2|3)
        pre="Apprentice "
        ;;
        4|5|6)
        pre=""
        ;;
        *)
        pre="Master "
    esac
    unlock_achievement "${pre}${title} (Level ${power})" "${description}"
}

count_unlock_achievement()
{
    title="${1}"
    description="${2}"
    cmd="${3}"
    count_command "${cmd}"
    if [ "${powerof2}" = "0" ] ; then
        hcount_unlock_achievement "${title}" "${description}" "$power"
    fi
}

function unalias_command
{
    export GITACHIEVEMENTSDONTRUN=1
    #XXX maybe this should be recursive?
    
    inputCMD="$1"
    cmd=( $=inputCMD )
    
    local cmdline=$(git config --get "alias.$cmd[1]")
    echo $cmdline
    export GITACHIEVEMENTSDONTRUN=0
}

check_for_achievements()
{
    export GITACHIEVEMENTSDONTRUN=1
    
    # Anyone know of a cleaner way of checking for hooks?
    gitdir=`git rev-parse --git-dir 2>/dev/null`
    hooks=`ls -F $gitdir/hooks/ 2>/dev/null | grep -e '\*$' | grep -ve 'sample\*$' | wc -l`
    if [ ${hooks} -ge 1 ] ; then
        hcount_unlock_achievement "Carpenter" "Custom git hooks are installed which help catch issues before they are shared." "$hooks"
    fi

    # Custom command
    if [ -e "$GITACHIEVEMENTSGITEXECPATH/$1" ] && [[ $1 != "achievements" ]] && echo "$1" | grep -q -v ^- ; then
        unlock_achievement "Inventor ($1)" "Used a command that isn't part of the built in Git command"
    fi

    case $2 in
        --help )
            unlock_achievement "Student" "Accessed the documentation for a command with git [command] --help"
            return
            ;;
    esac

    local command=$1
    local expansion=$(unalias_command "$command")

    if [ $expansion ] ; then
      # not a real inventor
      unlock_achievement "Garage Inventor" "Used a custom alias for a Git command"
      command="$expansion"
    fi

    # echo "Command: $command" >&2
    
    case $command in
       add )
            count_unlock_achievement "Stone Mason" "Added files to the index area for inclusion in the next commit with git add" "$1"
            case $2 in
                *.gitignore )
                unlock_achievement "Caretaker" "Added a .gitignore file to a repository."
                ;;
                -p )
                count_unlock_achievement "Miller" "Add only part of a file to the stage $count times with git add -p." "add -p"
                ;;
            esac
            ;;
        am )
            count_unlock_achievement "Messenger" "Applied a patch using git am." "$1"
            ;;
        bisect )
            count_unlock_achievement "Hunter" "Used git bisect to perform a binary search to find which change introduced a bug." "$1"
            ;;
        blame )
            count_unlock_achievement "Investigator" "Used git blame to annotate a file with information about how each line changed." "$1"
            ;;
        bundle )
            count_unlock_achievement "Delivery Boy" "Move objects and refs by archive with git bundle." "$1"
            ;;
        cherry-pick )
            unlock_achievement "Cherry Picker" "Used git cherry-pick to add a sha from another branch into the current branch." "$1"
            ;;
        checkout )
            case $2 in
                -b )
                count_unlock_achievement "Blacksmith" "Created a branch using git checkout -b." "checkout -b"
                ;;
            esac
            ;;
        clean )
            count_unlock_achievement "Cleaning lady" "Remove untracked files from the working tree with git clean" "$1"
            ;;
        commit )
            count_unlock_achievement "Author" "Made 2^Level commits using git commit." "$1"
            if [ "`git log --pretty=oneline | wc -l`" -eq "1" ] ; then
                unlock_achievement "Let there be light" "Commit without a parent." "$1"
            fi
            case $2 in
                --amend )
                count_unlock_achievement "Seamstress" "amended a commit with git commit --amend." "commit --amend"
                ;;
                -s )
                count_unlock_achievement "Locksmith" "Add Signed-off-by line at the end of the commit log message using git commit -s." "commit -s"
                ;;
            esac
            ;;
        config )
            if [[ ( $# -ge 3 && $2 = "user.name" ) || ( $# -ge 4 && $3 = "user.name" ) ]] ; then
                unlock_achievement "Baptised" "Set global user name using git config."
            fi
            if [[ ( $# -ge 3 && $2 = "user.email" ) || ( $# -ge 4 && $3 = "user.email" ) ]] ; then
                unlock_achievement "Homeowner" "Set global email address using git config."
            fi
            ;;
        diff )
            case $2 in
                --cached )
                count_unlock_achievement "Goldsmith" "Reviewed patches before committing with git diff --cached." "diff --cached"
                ;;
            esac

            ;;
        fetch )
            count_unlock_achievement "Collector" "Fetches named heads or tags from another repository with git fetch" "$1"
            ;;
        filter-branch )
            count_unlock_achievement "Tree Trimmer" "Rewrite branches with git filter-branch" "$1"
            ;;
        format-patch )
            count_unlock_achievement "Archivist" "Prepare each commit with its patch in one file per commit with git format-patch" "$1"
            ;;
        gc )
            count_unlock_achievement "Chimney Sweeper" "Used git gc to run a number of housekeeping tasks on the current repository." "$1"
            ;;
        grep )
            count_unlock_achievement "Fisherman" "Look for specified patterns in the current repository with git grep." "$1"
            ;;
        imap-send )
            count_unlock_achievement "Postman" "Send a collection of patches from stdin to an IMAP folder with git imap-send" "$1"
            ;;
        init )
            count_unlock_achievement "Architect" "Created a new repository with git init." "$1"
            ;;
        instaweb )
            count_unlock_achievement "Web Designer" "Instantly browse your working repository in gitweb with git instaweb" "$1"
            ;;
        log )
            count_unlock_achievement "Historian" "Investigate the commit log using git log." "$1"
            case $2 in
                -p* )
                unlock_achievement "Dentist" "Extracted patches using git log -p."
                ;;
                -S* )
                unlock_achievement "Librarian" "Looked for change that introduce or remove a string with git log -S"
                ;;
            esac
            ;;
        merge )
            count_unlock_achievement "Banker" "Join two or more development histories together with git merge." "$1"
            ;;
        push )
            case $2 in
                -n|--dry-run )
                ;;
            * )
                # not a dry run
                count_unlock_achievement "Socialite" "pushed a branch to a remote repository using git push" "$1"
                case $2 in
                    -f )
                    count_unlock_achievement "Thug" "Forced pushed a branch with git push -f" "push -f"
                    ;;
                esac
                ;;
            esac
            ;;
        rebase )
            case $2 in
                -i )
                count_unlock_achievement "Butcher" "Performed an interactive rebase using git rebase -i." "rebase -i"
                ;;
                --onto )
                count_unlock_achievement "Pilgrim" "Performed a rebase using git rebase --onto." "rebase --onto"
                ;;
            esac
            ;;
        reflog )
            unlock_achievement "Weaver" "Investigate old branches by using git reflog"
            case $2 in
                --date=relative )
                unlock_achievement "Stamp Collector" "Investigate old branches by using git reflog --date=relative"
                ;;
            esac
            ;;
        remote )
            case $2 in
                add )
                count_unlock_achievement "Merchant" "Added an external repository with git remote add." "remote add"
                ;;
            esac
            ;;
        shell )
            unlock_achievement "Beach Lion" "Restricted login shell for GIT-only SSH access with git shell"
            ;;
        show )
            count_unlock_achievement "Presenter" "Shows one or more objects (blobs, trees, tags and commits) with git show" "$1"
            ;;
        show-branch )
            count_unlock_achievement "Gardner" "Shows the commit ancestry graph with git show-branch" "$1"
            ;;
        stash )
            count_unlock_achievement "Product Manager" "Stash the changes in a dirty working directory away with git stash." "$1"
            ;;
        submodule )
            case $2 in
                add )
                count_unlock_achievement "Cathedral Architect" "Added a submodule to a repository." "submodule add"
                ;;
                update )
                count_unlock_achievement "Cathedral Worker" "Cloned submodule repository and checked out commits specified by superproject." "submodule update"
                ;;
            esac
            ;;
        svn|p4 )
            count_unlock_achievement "Traveler" "Streamed changes between another rcs with git svn or git p4." "$1"
            ;;
        tag )
            count_unlock_achievement "Gipsy" "Create, list, delete a tag signed with GPG using git tag" "$1"
            ;;
        whatchanged )
            count_unlock_achievement "News Reader" "Show logs with difference each commit introduces with git whatchanged" "$1"
            ;;
        flow )
            count_unlock_achievement "Pedantic" "Use the flow extension to encourage an orderly and standardized branching model" "$1"
            ;;
        hash-object|update-index|commit-tree|update-ref )
            count_unlock_achievement "Plumber" "Use the internal plumbing commands of git." "$1"
            ;;
    esac
    
    export GITACHIEVEMENTSDONTRUN=0
}

link_to_git_docs()
{
    sed -e 's_git \([a-z0-9-]*\)_<a href="http://www.kernel.org/pub/software/scm/git/docs/git-\1.html">git-\1</a>_g' | sed -e 's/\/git-hooks/\/githooks/g'
}

clean_logged_achievements() 
{
    cat "${ACHIEVEMENTSLOGFILE}" | grep -ve '^$' | grep -v 'Git Achievement Unlocked!' | grep -v '*' | sed -e 's/^ *//g'  -e 's/ *$//g'
}

publish_achievements()
{
    
    export GITACHIEVEMENTSDONTRUN=1
    
    # git_achievements="$(which git-achievements)"
    # git_achievements_dir="$(dirname "${git_achievements}")"
    # if [ -L "${git_achievements}" ]; then
    #  case "$(dirname $(readlink ${git_achievements}))" in
    #    /*)
    #      git_achievements_dir="$(dirname $(readlink ${git_achievements}))"
    #      ;;
    #    *)
    #      git_achievements_dir="${git_achievements_dir}/$(dirname $(readlink ${git_achievements}))"
    #      ;;
    #  esac
    # fi

    # cd "${git_achievements_dir}"

    user=`git config --global user.name`

echo "
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\"/>
<title>${user}'s Git Achievements</title>
<link rel=\"alternate\" type=\"application/rss+xml\" title=\"rss feed\" href=\"index.rss\"/>
<link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\"/>
</head>
<body>
" > "$GITACHIEVEMENTSINDEXPATH.html"
    echo "<h2>${user}'s Git Achievements</h2>" >> "$GITACHIEVEMENTSINDEXPATH.html"

    # STATS
    cat "$ZSH/plugins/git-achievements/git-achievements.plugin.zsh" | grep 'unlock_achievement ' | grep -v ' sed ' | grep -v '\${' | sed -e 's/.*unlock_achievement //g' -e 's/^"//g' -e 's/"$//g' -e 's/\$power/X/g' -e 's/\$count/X/g' -e 's/\$hooks/X/g' | sort | awk -F"\" \"" '{ print "<li><div class=\"title\">" $1 "</div><div class=\"info\">" $2 "</div></li>" }' | link_to_git_docs > all.html
    total=`cat all.html | wc -l`

    unlockedCount=`clean_logged_achievements | awk '{ if (NR % 2 != 0) print $0 }' | sed -e 's/Apprentice //g' -e 's/Master //g' -e 's/(.*//g' | sort | uniq | wc -l`
    levels=`clean_logged_achievements | awk '{ if (NR % 2 != 0) print $0 }' | grep Level | sed -e 's/.* //g' -e 's/)//g' | awk '{ t=t+$0 } END { print t }'`
    onelevels=`clean_logged_achievements | awk '{ if (NR % 2 != 0) print $0 }' | wc -l`
    let points="${levels}"+"${onelevels}"
    echo "Unlocked ${unlockedCount}/$total <a href=\"http://github.com/icefox/git-achievements\">Git Achievements</a> for $points points<br>" >> "$GITACHIEVEMENTSINDEXPATH.html"

    unlocked=`cat "${ACHIEVEMENTSLOGFILE}" | grep Unlocked | wc -l`

    # Unlocked Achievements
    echo "<ul>" >> "$GITACHIEVEMENTSINDEXPATH.html"
    cat "${ACHIEVEMENTSLOGFILE}" | grep -ve '^$' | grep -v 'Git Achievement Unlocked!' | grep -v '*' | sed -e 's/^ *//g'  -e 's/ *$//g' | awk '{ if (NR % 2 != 0) printf "<li><div class=\"title\">" $0 "</div>"; else printf "  <div class=\"info\">" $0 "</div></li>\n" }' | link_to_git_docs | sort >> "$GITACHIEVEMENTSINDEXPATH.html"

    echo "</ul>" >> "$GITACHIEVEMENTSINDEXPATH.html"

    # Git Commands
    echo 'Git commands sorted by usage:' >> "$GITACHIEVEMENTSINDEXPATH.html"
    echo "<pre style=\"text-align: left\">" >> "$GITACHIEVEMENTSINDEXPATH.html"
    cat  "${ACTIONLOGFILE}" | grep -v Date | grep -v 'git-dir' | awk '{ print $1 }' | sort | uniq -c | sort -nr >> "$GITACHIEVEMENTSINDEXPATH.html"
    echo "</pre>" >> "$GITACHIEVEMENTSINDEXPATH.html"

    # Locked Achievements
    echo "<script type=\"text/javascript\">
function showLocked() {
    document.getElementById('locked').style.visibility = 'visible';
    document.getElementById('showlocked').style.visibility = 'hidden';
}
</script>
<a id=\"showlocked\" href=\"javascript:showLocked()\" >Show locked Achievements</a>
<div id=\"locked\">
There are $total Achievements. Some achievements can be leveled up depending on the number of times it is used (Used 2 times = level 1, 4 = level 2, 8 = level 3, 16 = level 4, 32 = level 5, etc)
<ul>" >> "$GITACHIEVEMENTSINDEXPATH.html"

    cat "$GITACHIEVEMENTSINDEXPATH.html" | sed -e 's/Apprentice //g' -e 's/Master //g'> temp.html
    cat all.html | while read line ;
    do
        stripedline=`echo $line | sed -e 's/<\/div>.*//g' -e 's/(.*//g' -e 's/Apprentice //g'`
        grep "$stripedline" temp.html > /dev/null
        if [ ! $? -eq 0 ] ; then
            echo $line >> "$GITACHIEVEMENTSINDEXPATH.html"
        fi
    done
    echo '</ul></div>' >> "$GITACHIEVEMENTSINDEXPATH.html"
    rm temp.html
    rm all.html

    echo "</body></html>" >> "$GITACHIEVEMENTSINDEXPATH.html"

    # Update the RSS feed
    echo '<?xml version="1.0" encoding="utf-8"?><rss version="2.0"><channel>' > "$GITACHIEVEMENTSINDEXPATH.rss"
    echo "<title>${user}'s Git Achievements</title>" >> "$GITACHIEVEMENTSINDEXPATH.rss"
    echo "<description></description>" >> "$GITACHIEVEMENTSINDEXPATH.rss"
    echo "<link></link>" >> "$GITACHIEVEMENTSINDEXPATH.rss"
    cat "${ACHIEVEMENTSLOGFILE}"  | grep -ve '^$' | grep -v 'Git Achievement Unlocked!' | grep -v '*' | sed -e 's/^ *//g'  -e 's/ *$//g' | awk '{ if (NR % 2 != 0) printf "<item><title>" $0 "</title>"; else printf "<description>" $0 "</description></item>\n" }' | tail -n 20 | sed '1!G;h;$!d' >> "$GITACHIEVEMENTSINDEXPATH.rss"
    echo '</channel></rss>' >> "$GITACHIEVEMENTSINDEXPATH.rss"

    abortcount=`git status | grep 'Changes to be committed' | wc -l`
    if [ ! $abortcount -eq 0 ] ; then
        echo "There are staged changes in the repository, updates let uncommitted"
        return
    fi

    if [ ! "`git config --global achievement.upload`" = "true" ] ; then
        echo "Global achievement.upload not set to true, updates left uncommited"
        return
    fi

    echo "Adding new achievements and publishing to origin."
    
    GITACHIEVEMENTSCURDIR=$(pwd)
    
    cd "$ZSH/plugins/git-achievements"
    
    git add index.html index.rss
    if [ -z "${1}" ] ; then
        message="Publishing updated achievement"
    else
        message="New achievement $1"
    fi
    git commit -qm "${message}"
    git push origin gh-pages
    
    cd $GITACHIEVEMENTSCURDIR
    
    export GITACHIEVEMENTSDONTRUN=0
}

git-achievements-zsh-preexec-in()
{
    
    if [ ! -z $GITACHIEVEMENTSDONTRUN ]; then
        # echo "DONTRUN: $GITACHIEVEMENTSDONTRUN"
    fi
    
    # export GITACHIEVEMENTSDONTRUN=1
        
    inputCMD="$1"
    cmd=( $=inputCMD )
    if [ $cmd[1] = "git" ]; then
        if [ "$cmd[2]" = "achievements" ]; then
            if [ ! -z $cmd[3] ]; then
               case $cmd[3] in
                    -p|--publish )
                        publish_achievements
                        ;;
                    -l|--list )
                        cat "${ACHIEVEMENTSLOGFILE}"
                        ;;
                    * )
                       echo "Git Achievements"
                        count=`cat "${ACHIEVEMENTSLOGFILE}" 2> /dev/null | grep Unlocked | wc -l`
                        echo ""
                        echo "You currently have: $count achievements"
                        echo ""
                        echo "Options:"
                        echo "    -l --list    Show all achievements."
                        echo "    -p --publish Generate achievements html files and if achievements.upload is set to \"true\" add the files and push to origin."
                        ;;
                esac
            else
                echo "Git Achievements"
                count=`cat "${ACHIEVEMENTSLOGFILE}" 2> /dev/null | grep Unlocked | wc -l`
                echo ""
                echo "You currently have: $count achievements"
                echo ""
                echo "Options:"
                echo "    -l --list    Show all achievements."
                echo "    -p --publish Generate achievements html files and if achievements.upload is set to \"true\" add the files and push to origin."
            fi
        else
            export GITACHIEVEMENTSDOCHECK=0
            export GITACHIEVEMENTSLINE="$cmd[2,${#cmd}]"
        fi
        
    else
        export GITACHIEVEMENTSDOCHECK=1
    fi
        
    # export GITACHIEVEMENTSDONTRUN=0
}

git-achievements-zsh-preexec()
{
    # echo "preexec: $1" >&2
    if [ -z $GITACHIEVEMENTSDONTRUN ]; then
        git-achievements-zsh-preexec-in $1
    elif [ $GITACHIEVEMENTSDONTRUN -eq 0 ]; then
        git-achievements-zsh-preexec-in $1
    fi

}

git-achievements-zsh-precmd()
{

#   TODO: FIX THE CONDITIONAL SO THAT IT EXECUTES IF GITACHIEVEMENTSDOCHECK is either 0 or not defined.

    lastRet=$?
    if [ ! -z $GITACHIEVEMENTSDOCHECK ]; then
        if [ $GITACHIEVEMENTSDOCHECK -eq 0 ]; then

            if [ $lastRet -eq 0 ]; then
                export GITACHIEVEMENTSDONTRUN=1
                log_action $GITACHIEVEMENTSLINE
                check_for_achievements $GITACHIEVEMENTSLINE
                export GITACHIEVEMENTSDONTRUN=0
            fi
        fi
    fi
    
    }

GITACHIEVEMENTSALIASACHIEVEMENTS=$(unalias_command "achievements")
    
if [ -z $GITACHIEVEMENTSALIASACHIEVEMENTS ]; then
    git config --global alias.achievements "!true"
fi
 
add-zsh-hook preexec git-achievements-zsh-preexec
add-zsh-hook precmd git-achievements-zsh-precmd
