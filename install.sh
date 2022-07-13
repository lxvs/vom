#!/bin/bash
set -o nounset

die () {
    while test $# -ge 1
    do
        printf >&2 "%s\n" "$1"
        shift
    done
    exit 1
}

Backup () {
    local f=$1
    local tb
    local i=1
    test ! "$bak" && return
    test ! -e "$f" && return
    test -d "$f" && rmdir -- "$f" 2>/dev/null && return
    tb="$f.tgz"
    if test -e "$tb"
    then
        tb="$f.$i.tgz"
        while test -e "$tb"
        do
            printf -v i "%d" "$((i+1))"
            tb="$f.$i.tgz"
        done
    fi
    printf "\`%s' exists, so create a backup \`%s'\n" "$f" "$tb"
    pushd "$(dirname "$f")" 1>/dev/null || return
    tar --remove-files -zcp -f "$tb" "$(basename "$f")" || return
    popd 1>/dev/null || return
}

CopyDotFiles () {
    local IFS=':'
    local f flocal
    test ! -d "$dotfilesdir" && return
    printf "Copy dot-files\n"
    pushd "$dotfilesdir" 1>/dev/null || return
    for f in *
    do
        test ! -f "$f" && continue
        flocal=".$f"
        printf "Copy \`%s' to \`%s'\n" "$f" "$HOME/$flocal"
        Backup "$HOME/$flocal" || return
        cp "$f" "$HOME/$flocal" || return
    done
    popd 1>/dev/null || return
}

CopyVimfiles () {
    local IFS=':'
    local d
    test ! -d "$vimfilesdir" && return
    printf "Copy Vim files\n"
    pushd "$vimfilesdir" 1>/dev/null || return
    GetVimDir
    CopyVimrc || return
    test -d "$dir" || mkdir -p -- "$dir" || return
    for d in *
    do
        test ! -d "$d" && continue
        printf "Copy \`%s' into \`%s'\n" "$d" "$dir/"
        Backup "$dir/$d" || return
        cp -r "$d" "$dir/" || return
    done
    popd 1>/dev/null || return
}

CopyVimrc () {
    local IFS=':'
    local rc
    local rclist="vimrc:.vimrc:_vimrc:NONE"
    local rclocal="$HOME/.vimrc"
    for rc in $rclist
    do
        test -e "$rc" && break
    done
    test "$rc" = "NONE" && return
    printf "Copy \`%s' to \`%s'\n" "$rc" "$rclocal"
    Backup "$rclocal" || return
    cp "$rc" "$rclocal" || return
}

GetVimDir () {
    local verb=Specified
    case $vimfiles in
    1)
        dir="$HOME/vimfiles"
        ;;
    '')
        dir="$HOME/.vim"
        ;;
    auto)
        verb=Detected
        if test -d "$HOME/vimfiles" && ! test -d "$HOME/.vim"
        then
            dir="$HOME/vimfiles"
        else
            dir="$HOME/.vim"
        fi
        ;;
    *)
        dir=$(realpath -- "$vimfiles")
        test -d "$dir" || mkdir -p -- "$dir" || die
        ;;
    esac
    printf "%s \`%s' as Vim personal directory\n" "$verb" "$dir"
}

CopyFiles () {
    local dir shdir copydir vimfilesdir dotfilesdir
    test "$uninstall" && return
    test ! "$copy" && return
    printf "Copy configuration files\n"
    shdir=$(dirname "$(realpath -- "$BASH_SOURCE")")
    copydir="$shdir/copy"
    vimfilesdir="$copydir/vimfiles"
    dotfilesdir="$copydir/dotfiles"
    if ! test -d "$copydir"
    then
        printf >&2 "warning: did not find directory \`%s', skipped\n" "$copydir"
        return 0
    fi
    CopyVimfiles || return
    CopyDotFiles || return
}

CreateBat () {
    local mintty='"%ProgramFiles%\Git\usr\bin\mintty.exe"'
    local cmdflag='--title Vom /bin/bash --login -c "%bashcmd%"'
    if test "$uninstall"
    then
        test ! "$iswindows" && return
        test ! -e "$(cygpath "$WINDIR\\vom.bat")" && return
        printf "Remove bat file\n"
        if ! test "$isprivileged"
        then
            printf >&2 "warning: not enough permission to remove bat file, skipped\n"
            return 0
        fi
        rm -f "$(cygpath "$WINDIR\\vom.bat")"
    else
        test ! "$bat" && return
        test "$iswindows" || die "error: system is not Windows"
        printf "Create bat file\n"
        test "$isprivileged" ||
            die "error: not enough permission to create bat file"
        printf >"$(cygpath "$WINDIR\\vom.bat")" "%s\r\n" \
            "@echo off" \
            "setlocal" \
            'set "bashcmd=/usr/bin/vim %*"' \
            'set "bashcmd=%bashcmd:"=\"%"' \
            "$mintty $cmdflag"
    fi
}

RegFileTypes () {
    local ft
    if test "$uninstall"
    then
        for ft in "${!ftt[@]}"
        do
            printf "Unregister file type \`%s'\n" "$ft"
            reg delete "$classes\\vom.$ft" //f 1>/dev/null 2>&1
            reg delete "$classes\\.$ft\\OpenWithProgids" //v "vom.$ft" //f 1>/dev/null 2>&1
        done
        return 0
    else
        for ft in "${!ftt[@]}"
        do
            printf "Register file type \`%s'\n" "$ft"
            reg add "$classes\\vom.$ft" //ve //t "$t_sz" //d "${ftt[$ft]}" //f 1>/dev/null || return
            reg add "$classes\\vom.$ft\\DefaultIcon" //ve //t "$t_ex" //d "$icon" //f 1>/dev/null || return
            reg add "$classes\\vom.$ft\\shell\\open" //v "Icon" //t "$t_ex" //d "$mintty" //f 1>/dev/null || return
            reg add "$classes\\vom.$ft\\shell\\open\\command" //ve //t "$t_ex" //d "$command" //f 1>/dev/null || return
            reg add "$classes\\.$ft\\OpenWithProgids" //v "vom.$ft" //t "$t_none" //f 1>/dev/null || return
        done
    fi
}

RegTextType () {
    if test "$uninstall"
    then
        printf "Unregister for text type\n"
        reg delete "$classes\\SystemFileAssociations\\text\\shell\\edit\\command" //f 1>/dev/null 2>&1
        reg delete "$classes\\SystemFileAssociations\\text\\shell\\open\\command" //f 1>/dev/null 2>&1
        return 0
    else
        printf "Register for text type\n"
        reg add "$classes\\SystemFileAssociations\\text\\shell\\edit\\command" //ve //t "$t_ex" //d "$command" //f 1>/dev/null || return
        reg add "$classes\\SystemFileAssociations\\text\\shell\\open\\command" //ve //t "$t_ex" //d "$command" //f 1>/dev/null || return
    fi
}

RegMinttyPath () {
    local apppaths='HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths'
    if test "$uninstall"
    then
        printf "Unregister Mintty path\n"
        reg delete "$apppaths\\mintty.exe" //f 1>/dev/null 2>&1
        return 0
    else
        printf "Register Mintty path\n"
        reg add "$apppaths\\mintty.exe" //ve //t "$t_ex" //d "$mintty" //f 1>/dev/null || return
    fi
}

RegProgram () {
    local text="Edit &with Vim on Mintty"
    if test "$uninstall"
    then
        printf "Unregister program\n"
        reg delete "$classes\\*\\shell\\vom" //f 1>/dev/null 2>&1
        reg delete "$classes\\Applications\\vom.exe" //f 1>/dev/null 2>&1
        return 0
    else
        printf "Register program\n"
        reg add "$classes\\*\\shell\\vom" //ve //t "$t_sz" //d "$text" //f 1>/dev/null || return
        reg add "$classes\\*\\shell\\vom" //v "Icon" //t "$t_ex" //d "$mintty" //f  1>/dev/null || return
        reg add "$classes\\*\\shell\\vom\\command" //ve //t "$t_ex" //d "$command" //f 1>/dev/null || return
        reg add "$classes\\Applications\\vom.exe\\DefaultIcon" //ve //t "$t_ex" //d "$icon" //f 1>/dev/null || return
        reg add "$classes\\Applications\\vom.exe\\shell\\open" //v "Icon" //t "$t_ex" //d "$mintty" //f 1>/dev/null || return
        reg add "$classes\\Applications\\vom.exe\\shell\\open\\command" //ve //t "$t_ex" //d "$command" //f 1>/dev/null || return
    fi
}

InitFileTypeTable () {
    ftt=( \
        ['asl']='ACPI Source Language File' \
        ['ass']='ASS Subtitle File' \
        ['bash']='Bash Script' \
        ['bashrc']='Bash Run Command Script' \
        ['bash_history']='Bash History File' \
        ['bash_login']='Bash Login Script' \
        ['bash_logout']='Bash Logout Script' \
        ['bash_profile']='Bash Profile Script' \
        ['c']='C Source File' \
        ['c++']='C++ Source File' \
        ['cfg']='Configuration File' \
        ['conf']='Configuration File' \
        ['config']='Configuration File' \
        ['cpp']='C++ Source File' \
        ['cs']='C# Source File' \
        ['css']='Cascading Style Sheet File' \
        ['csv']='Comma Separated Values File' \
        ['diff']='Diff File' \
        ['dockerfile']='Dockerfile Source File' \
        ['editorconfig']='Editor Configuration File' \
        ['git']='git Source File' \
        ['gitattributes']='Git Attributes File' \
        ['gitconfig']='Git Configuration File' \
        ['gitignore']='Git Ignore File' \
        ['go']='Go Source File' \
        ['groovy']='Groovy Source File' \
        ['h']='C Header Source File' \
        ['h++']='C++ Header Source File' \
        ['hpp']='C++ Header Source File' \
        ['htm']='HTML Source File' \
        ['html']='HTML Source File' \
        ['ini']='INI Configuration File' \
        ['java']='Java Source File' \
        ['js']='JavaScript Source File' \
        ['json']='JavaScript Object Notation File' \
        ['lesshst']='Less History File' \
        ['log']='Log File' \
        ['lua']='Lua Source File' \
        ['makefile']='Makefile Source File' \
        ['markdown']='Markdown File' \
        ['md']='Markdown File' \
        ['minttyrc']='Mintty Run Command Script' \
        ['netrc']='Netrw Run Command Script' \
        ['netrwhist']='Netrw History File' \
        ['nsh']='EFI Shell Script' \
        ['patch']='Patch File' \
        ['php']='PHP Source File' \
        ['profile']='Profile Script' \
        ['ps1']='PowerShell Source File' \
        ['py']='Python Script' \
        ['pyi']='Python Stub File' \
        ['rej']='Patch Rejected Hunks File' \
        ['sh']='Shell Script' \
        ['shtml']='SHTML Source File' \
        ['srt']='SubRip Subtitle File' \
        ['ssa']='Sub Station Alpha Subtitle File' \
        ['txt']='Text Document' \
        ['vb']='vb Source File' \
        ['vim']='Vimscript Source File' \
        ['viminfo']='Viminfo File' \
        ['vimrc']='Vim Run Command Script' \
        ['xml']='Extensible Markup Language File' \
        ['yaml']='YAML File' \
        ['yml']='YAML File' \
        ['zsh']='Zsh Script' \
    )
}

Register () {
    local classes='HKCU\SOFTWARE\Classes'
    local mintty='%ProgramFiles%\Git\usr\bin\mintty.exe'
    local minttycmdflag='--title "%1" /bin/bash --login -c "/usr/bin/vim -- \"%1\""'
    local command="$mintty $minttycmdflag"
    local icon='%SystemRoot%\system32\imageres.dll,-102'
    local t_sz="REG_SZ" t_ex="REG_EXPAND_SZ" t_none="REG_NONE"
    local -A ftt
    test ! "$reg" && return
    test "$iswindows" || die "error: system is not Windows"
    InitFileTypeTable || return
    RegProgram || return
    RegMinttyPath || return
    RegTextType || return
    RegFileTypes || return
}

CheckOnlyMode () {
    test ! "$only" && return
    test $((regonly+batonly+copyonly)) -eq 1 ||
        die "error: multiple \`only' opreations specified"
    if test "$regonly"
    then
        Register
        exit
    fi
    if test "$batonly"
    then
        CreateBat
        exit
    fi
    if test "$copyonly"
    then
        CopyFiles
        exit
    fi
    die "error: no matching operation in only mode"
}

Install () {
    Register || return
    CreateBat || return
}

CheckPrivilege () {
    net session 1>/dev/null 2>&1 && isprivileged=1
}

CheckWindows () {
    if test "$WINDIR"
    then
        iswindows=1
        CheckPrivilege
        test "$reg" = "auto" && reg=1
        test "$bat" = "auto" && bat=$isprivileged
    else
        iswindows=
        test "$reg" = "auto" && reg=
        test "$bat" = "auto" && bat=
    fi
}

ParseArgs () {
    while test $# -ge 1
    do
        case $1 in
        -u|--uninstall)
            uninstall=1
            shift
            ;;
        -b|--create-bat)
            bat=1
            shift
            ;;
        --no-create-bat)
            test "$batonly" &&
                die "error: \`no-create-bat' and \`create-bat-only' cannot be used together"
            bat=
            shift
            ;;
        --create-bat-only)
            bat=1
            only=1
            batonly=1
            shift
            ;;
        -r|--register)
            reg=1
            shift
            ;;
        --no-register)
            test "$regonly" &&
                die "error: \`no-register' and \`register-only' cannot be used together"
            reg=
            shift
            ;;
        --register-only)
            reg=1
            only=1
            regonly=1
            shift
            ;;
        --copy)
            copy=1
            shift
            ;;
        --no-copy)
            test "$copyonly" &&
                die "error: \`no-copy' and \`copy-only' cannot be used together"
            copy=
            shift
            ;;
        --copy-only)
            copy=1
            only=1
            copyonly=1
            shift
            ;;
        --vimfiles)
            vimfiles=1
            shift
            ;;
        --no-vimfiles)
            vimfiles=
            shift
            ;;
        --auto-vimfiles)
            vimfiles=auto
            shift
            ;;
        --vimfiles=*)
            vimfiles=${1#--vimfiles=}
            shift
            ;;
        --backup)
            bak=1
            shift
            ;;
        --no-backup)
            bak=
            shift
            ;;
        *)
            die "error: invalid argument \`$1'"
            ;;
        esac
    done
}

main () {
    local uninstall= only= bat=auto batonly= reg=auto regonly=
    local copy=1 copyonly= vimfiles=auto bak=1
    local iswindows= isprivileged= WINDIR=${WINDIR-}
    ParseArgs "$@"
    CheckWindows
    CheckOnlyMode
    Install || return
    CopyFiles || return
}

main "$@"
