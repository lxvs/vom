#!/bin/bash
set -o nounset
set -o noglob

die () {
    while test $# -ge 1
    do
        printf >&2 "%s\n" "$1"
        shift
    done
    exit 1
}

CreateBat () {
    local mintty='"%ProgramFiles%\Git\usr\bin\mintty.exe"'
    local cmdflag='--title Vom /bin/bash --login -c "%bashcmd%"'
    if test "$uninstall"
    then
        printf "Remove bat file\n"
        test ! -e "$(cygpath "$WINDIR\\vom.bat")" && return
        if ! net session 1>/dev/null 2>&1
        then
            printf >&2 "warning: not enough permission to remove bat file, skipped\n"
            return 0
        fi
        rm -f "$(cygpath "$WINDIR\\vom.bat")"
    else
        test ! "$bat" && return
        printf "Create bat file\n"
        net session 1>/dev/null 2>&1 ||
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
        ['log']='Log File' \
        ['lua']='Lua Source File' \
        ['makefile']='Makefile Source File' \
        ['markdown']='Markdown File' \
        ['md']='Markdown File' \
        ['minttyrc']='Mintty Run Command Script' \
        ['nsh']='EFI Shell Script' \
        ['php']='PHP Source File' \
        ['profile']='Profile Script' \
        ['ps1']='PowerShell Source File' \
        ['py']='Python Script' \
        ['pyi']='Python Stub File' \
        ['sh']='Shell Script' \
        ['shtml']='SHTML Source File' \
        ['srt']='SubRip Subtitle File' \
        ['ssa']='Sub Station Alpha Subtitle File' \
        ['txt']='Text Document' \
        ['vb']='vb Source File' \
        ['vim']='Vimscript Source File' \
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
    InitFileTypeTable || return
    RegProgram || return
    RegMinttyPath || return
    RegTextType || return
    RegFileTypes || return
}

CheckOnlyMode () {
    test ! "$only" && return
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
    die "error: no matching operation in only mode"
}

Install () {
    IsOnWindows || die "error: system is not Windows"
    CheckOnlyMode
    Register || return
    CreateBat || return
}

IsOnWindows () {
    grep -Gqi '^win' <<<"${OS-}"
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
        *)
            die "error: invalid argument \`$1'"
            ;;
        esac
    done
}

main () {
    local uninstall= only= bat= batonly= reg=1 regonly=
    ParseArgs "$@"
    Install || return
}

main "$@"
