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

RegFileTypes () {
    local ft
    local icon='%SystemRoot%\system32\imageres.dll,-102'
    if test "$uninstall"
    then
        for ft in "${!ftt[@]}"
        do
            printf "Unregister file type \`%s'\n" "$ft"
            reg delete "$classes\\vimom.$ft" //f 1>/dev/null 2>&1
            reg delete "$classes\\.$ft\\OpenWithProgids" //v "vimom.$ft" //f 1>/dev/null 2>&1
        done
        return 0
    else
        for ft in "${!ftt[@]}"
        do
            printf "Register file type \`%s'\n" "$ft"
            reg add "$classes\\vimom.$ft" //ve //t "$t_sz" //d "${ftt[$ft]}" //f 1>/dev/null || return
            reg add "$classes\\vimom.$ft\\DefaultIcon" //ve //t "$t_ex" //d "$icon" //f 1>/dev/null || return
            reg add "$classes\\vimom.$ft\\shell\\open" //v "Icon" //t "$t_ex" //d "$mintty" //f 1>/dev/null || return
            reg add "$classes\\vimom.$ft\\shell\\open\\command" //ve //t "$t_ex" //d "$command" //f 1>/dev/null || return
            reg add "$classes\\.$ft\\OpenWithProgids" //v "vimom.$ft" //t "$t_none" //f 1>/dev/null || return
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

RegProgram () {
    local text="Edit &with Vim on Mintty"
    if test "$uninstall"
    then
        printf "Unregister program\n"
        reg delete "$classes\\*\\shell\\vimom" //f 1>/dev/null 2>&1
        return 0
    else
        printf "Register program\n"
        reg add "$classes\\*\\shell\\vimom" //ve //t "$t_sz" //d "$text" //f 1>/dev/null || return
        reg add "$classes\\*\\shell\\vimom" //v "Icon" //t "$t_ex" //d "$mintty" //f  1>/dev/null || return
        reg add "$classes\\*\\shell\\vimom\\command" //ve //t "$t_ex" //d "$command" //f 1>/dev/null || return
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
        ['vimrc']='Vim Run Command File' \
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
    local t_sz="REG_SZ" t_ex="REG_EXPAND_SZ" t_none="REG_NONE"
    local -A ftt
    InitFileTypeTable || return
    RegProgram || return
    RegTextType || return
    RegFileTypes || return
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
        *)
            die "error: invalid argument \`$1'"
            ;;
        esac
    done
}

main () {
    local uninstall=
    ParseArgs "$@"
    IsOnWindows && Register
}

main "$@"
