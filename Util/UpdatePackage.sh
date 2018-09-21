#!/bin/sh
VERSION="2018.08.23-05:19"
PKGS="git perl"

#colors
DEFAULT="$(printf "\\033[0;39m")"
WHITE_BOLD="$(printf "\\033[1m")"
WHITE_BG="$(printf "\\033[7m")"
RED="$(printf "\\033[0;31m")"

TMPDIR="/tmp/$$"
USERS="$(busybox cat /etc/passwd | busybox awk -F: '{if ($3 >= 1000 && $3 < 60000) print $1}')"

_usage() {
    printf "%s\\n" "Usage: ${PROGNAME} [OPTIONS] [+PKG ...] [-PKG ...] now"
    printf "%s\\n" "My favorite programs one command away."
    printf "\\n"
    printf "%s\\n" "Options:"
    printf "%s\\n" "  -u, --upgrade   force upgrade"
    printf "%s\\n" "  -l, --list      list available packages"
    printf "%s\\n" "  -V, --version   output version and exit"
    printf "%s\\n" "  -h, --help      show this help message and exit"
}

_print_version() {
    printf "%s\\n" "${VERSION}"
}

_list_available_pkgs() {
    for pkg in $PKGS; do
        printf "%s\\n" "${pkg}"
    done
}

_none_but_this_pkg() {
    [ -z "${1}" ] && return 1

    _list_available_pkgs | grep "^${1}$" >/dev/null 2>&1 || return 1

    if [ -z "${PKG_QUEUE}" ]; then
        PKG_QUEUE="${1}"
    else
        PKG_QUEUE="${PKG_QUEUE} ${1}"
    fi
}

_all_but_this_pkg() {
    [ -z "${1}" ] && return 1

    _list_available_pkgs | grep "^${1}$" >/dev/null 2>&1 || return 1

    if [ -z "${PKG_QUEUE}" ]; then
        PKG_QUEUE="$(printf "%s\\n" "${PKGS}"      | sed "s: ${1}::g")"
    else
        PKG_QUEUE="$(printf "%s\\n" "${PKG_QUEUE}" | sed "s: ${1}::g")"
    fi
}

_die() {
    if [ -z "${2}" ]; then
       [ -z "${1}" ] || printf "%s\\n" "${*}" >&2
        _usage >&2
    else
        printf "%b\\n" "${2}${*}${DEFAULT}" >&2
    fi
    exit 1
}

#Imprime mensaje centrado con fondo blanco conforme el numero de columnas de la terminal usada
_printfl() { #print lines
    command -v "tput" >/dev/null 2>&1 && _printfl_var_max_len="$(tput cols)"
    _printfl_var_max_len="${_printfl_var_max_len:-80}"
    if [ -n "${1}" ]; then
        _printfl_var_word_len="$(expr "${#1}" + 2)"
        _printfl_var_sub="$(expr "${_printfl_var_max_len}" - "${_printfl_var_word_len}")"
        _printfl_var_half="$(expr "${_printfl_var_sub}" / 2)"
        _printfl_var_other_half="$(expr "${_printfl_var_sub}" - "${_printfl_var_half}")"
        printf "%b" "${WHITE_BOLD}"
        printf '%*s' "${_printfl_var_half}" '' | tr ' ' -
        printf "%b" "${WHITE_BG}" #white background
        printf " %s " "${1}"
        printf "%b" "${DEFAULT}${WHITE_BOLD}"
        printf '%*s' "${_printfl_var_other_half}" '' | tr ' ' -
        printf "%b" "${DEFAULT}" #back to normal
        printf "\\n"
    else
        printf "%b" "${WHITE_BOLD}"
        printf '%*s' "${_printfl_var_max_len}" '' | tr ' ' -
        printf "%b" "${DEFAULT}"
        printf "\\n"
    fi
}

_unprint_previous_line() {
    printf "\033[1A" #override previous line
}

_unprintf() { #unprint sentence
    [ -z "${1}" ] && return 1
    printf "\\r"
    for i in $(seq 0 "${#1}"); do printf " "  ; done
    printf "\\r"
}

_printf_sleep() {
    [ -z "${2}" ] && return 1
    mensaje="${1} "
    segundos="${2}"

    while [ "${segundos}" -gt "0" ]; do
        _unprintf "${mensaje}"
        #Imprime el mensaje, remplaza el caracter X por el valor en segundos
        printf "%s\\n" "${mensaje}" | sed "s:X:${segundos}:g" | tr -d '\n'
        sleep 1 || {
            _unprintf "${mensaje}"
            return 1
        }
        segundos="$((segundos - 1))"
    done
    _unprintf "${mensaje}"
}

_is_root() {
    [ X"$(whoami)" = X"root" ]
}

_is_installed() {
    command -v "${1}" >/dev/null 2>&1
}

_last_cmd_ok() {
    [ X"${?}" = X"0" ]
}

_cmd_verbose() {
    [ -z "${1}" ] && return 1
    printf "%s \\n" "    $ ${*}"
    $@ || _die "there was an error with the above command, exiting ..." "${RED}"
}



_header() {
    _printfl "PostInstall Minos Setup"
    if [ -z "${UPGRADE}" ]; then
        printf "%b\\n" "About to ${WHITE_BOLD}install${DEFAULT} ..."
    else
        printf "%b\\n" "About to ${WHITE_BOLD}install and upgrade${DEFAULT} ..."
    fi
    printf "\\n"
    for pkg in $@; do printf " %b\\n" "${pkg}"; done
    printf "\\n"
    _printfl
}

####### Funciones especificas para por cada paquete ###

_perl() {
    _printfl "${pkg}"

    if _is_installed "${pkg}" && [ -z "${UPGRADE}" ]; then
        printf "%s\\n" "${pkg} ya esta instalado, salimos"
    else
        printf "%s\\n" "${pkg} no esta instalado, salimos"
    fi
    "${pkg}" --version
}

_git() {
    _printfl "${pkg}"

    if _is_installed "${pkg}" && [ -z "${UPGRADE}" ]; then
        printf "%s\\n" "${pkg} ya esta instalado, salimos"
    else
        printf "%s\\n" "${pkg} no esta instalado, salimos"
    fi
    "${pkg}" --version
}

#Instalacion de los paquetes
#Ejecuta la funcion, conforme el nombre del paquete obtenido
_install_pkgs() {
    for pkg in ${@}; do
        [ -z "${first}" ] && { _unprint_previous_line; first="done"; }
        _"$(printf "%s\\n" "${pkg}"|sed 's:-:_:g')"
    done
}

######## M A I N ##########

#Nombre del programa
PROGNAME="$(basename "${0}")"

if [ ! -t 0 ]; then
    #there is input comming from pipe or file, add to the end of $@
    set -- "${@}" $(cat)
fi

[ "${#}" -eq "0" ] && _die

for arg in "${@}"; do #parse options
    case "${arg}" in
        -h|--help)    _usage; exit ;;
        -V|--version) _print_version; exit ;;
        -l|--list)    _list_available_pkgs; exit ;;
        -u|--upgrade) UPGRADE=1; shift ;;
        +*) if ! _none_but_this_pkg "${arg#?}"; then
                _die "${PROGNAME}: '${arg} is not a valid pkg, use --list to see available recipes"
            fi
            ;;
        -*) if ! _all_but_this_pkg "${arg#?}"; then
                _die "${PROGNAME}: unrecognized option '${arg}'"
            fi
            ;;
        --*) _die "${PROGNAME}: Desconocido option '${arg}'" ;;
    esac
done

[ -z "${PKG_QUEUE}" ] && PKG_QUEUE="${PKGS}"

_header "${PKG_QUEUE}"
_is_root || _die "No eres usuario root!, se requieren privilegios de administrador" "${RED}"
#give the user a chance to cancel before starting
_printf_sleep "Por favor espera un momento, continuamos en X ..." "7" || exit 1
_install_pkgs "${PKG_QUEUE}"
