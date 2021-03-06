#!/usr/bin/env bash

################################################################################
#                                                                              #
# firevigeo                                                                    #
#                                                                              #
# version: 0.1.0                                                               #
#                                                                              #
# An extra tool to add multiple tor instances as a direct                      #
# firejail network backend!                                                    #
#                                                                              #
# Copyright (C) 2015-2021 Brainf+ck                                            #
#                                                                              #
#                                                                              #
# GNU GENERAL PUBLIC LICENSE                                                   #
#                                                                              #
# This program is free software: you can redistribute it and/or modify         #
# it under the terms of the GNU General Public License as published by         #
# the Free Software Foundation, either version 3 of the License, or            #
# (at your option) any later version.                                          #
#                                                                              #
# This program is distributed in the hope that it will be useful,              #
# but WITHOUT ANY WARRANTY; without even the implied warranty of               #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #
# GNU General Public License for more details.                                 #
#                                                                              #
# You should have received a copy of the GNU General Public License            #
# along with this program.  If not, see <http://www.gnu.org/licenses/>.        #
#                                                                              #
################################################################################


## General
#
# program information
readonly prog_name="firevigeo"
readonly version="0.1.0"
readonly signature="Copyright (C) 2022 Nonie689"
readonly git_url="https://github.com/Nonie689/firevigeo-torloader"

# set colors for stdout
export red="$(tput setaf 1)"
export green="$(tput setaf 2)"
export yellow="$(tput setaf 3)"
export blue="$(tput setaf 4)"
export magenta="$(tput setaf 5)"
export cyan="$(tput setaf 6)"
export white="$(tput setaf 7)"
export b="$(tput bold)"
export reset="$(tput sgr0)"

check_root

readonly config_dir="/usr/share/firevigeo/conf-data"
# backups:
readonly backup_dir="/usr/share/firevigeo/conf-backups"


chmod u-s /usr/bin/firejail

cp /etc/resolv.conf $backup_dir
echo 127.0.0.1 > /etc/resolv.conf 

## Display program version
print_version() {
    printf "%s\\n" "${prog_name} ${version}"
    printf "%s\\n" "${signature}"
    printf "%s\\n" "License GPLv3: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>"
    printf "%s\\n" "This is free software: you are free to change and redistribute it."
    printf "%s\\n" "There is NO WARRANTY, to the extent permitted by law."
    exit 0
}


## On reset
#cp $backup_dir /etc/resolv.conf


check_root() {
    if [[ "${UID}" -ne 0 ]]; then
        die "Please run this program as a root!"
    fi
}


check_settings() {
    info "Check program settings"

    # tor package
    if ! hash tor 2>/dev/null; then
        die "tor isn't installed, exit"
    fi

    # directories
    if [[ ! -d "${backup_dir}" ]]; then
        die "directory '${backup_dir}' not exist, run makefile first!"
    fi

    if [[ ! -d "${config_dir}" ]]; then
        die "directory '${config_dir}' not exist, run makefile first!"
    fi



    # /usr/lib/systemd/system/tor.service
    grep -q -x '\[Service\]' /usr/lib/systemd/system/tor.service
    local rstring1=$?

    grep -q -x 'User=root' /usr/lib/systemd/system/tor.service
    local rstring2=$?

    grep -q -x 'Group=root' /usr/lib/systemd/system/tor.service
    local rstring3=$?

    grep -q -x 'Type=simple' /usr/lib/systemd/system/tor.service
    local rstring4=$?

    # if required strings does not exists copy tor.service file from
    # /usr/share/archtorify/data
    if [[ "$rstring1" -ne 0 ]] ||
       [[ "$rstring2" -ne 0 ]] ||
       [[ "$rstring3" -ne 0 ]] ||
       [[ "$rstring4" -ne 0 ]]; then

        printf "%s\\n" "Set file: /usr/lib/systemd/system/tor.service"

        replace_file /usr/lib/systemd/system/tor.service tor.service
    fi


    # /var/lib/tor permissions
    #
    # required:
    # -rwx------  tor tor
    # (700)
    if [[ "$(stat -c '%U' /var/lib/tor)" != "tor" ]] &&
        [[ "$(stat -c '%a' /var/lib/tor)" != "700" ]]; then

        printf "%s\\n" "Set permissions of /var/lib/tor directory"
        chown -R tor:tor /var/lib/tor
        chmod -R 700 /var/lib/tor
    fi

    # /etc/tor/torrc
    if [[ ! -f /etc/tor/torrc ]]; then
        die "/etc/tor/torrc file not exist, check Tor configuration"
    fi


   # Check torrc settings!


    # if torrc exist grep required strings
    grep -q -x 'User tor' /etc/tor/torrc
    local rstring1=$?

    grep -q -x 'SocksPort 9050 IsolateClientAddr IsolateClientProtocol IsolateDestAddr' /etc/tor/torrc
    local rstring2=$?

    grep -q -x 'DNSPort 53' /etc/tor/torrc
    local rstring3=$?

    grep -q -x 'TransPort 9040 IsolateClientAddr IsolateClientProtocol IsolateDestAddr' /etc/tor/torrc
    local rstring4=$?


jq '.Body'


## Check public IP address
#
# Make an HTTP request to the ip api service on the list, if the
# first request fails, try with the next, then print the IP address.
#
# Thanks to "NotMilitaryAI" for this function
check_ip() {
    info "Check public IP Address"

    local url_list=(
        'http://ip-api.com/'
	'https://ipinfo.io/widget  -H "Referer: https://ipinfo.io/"  -H "Cookie: flash="'
	'https://myip.privex.io/index.json'
	'https://address.computer/index.json'
	'https://myip.vc/index.json')

    for url in "${url_list[@]}"; do
        local request="$(curl -s "$url")"
        local response="$?"

        if [[ "$response" -ne 0 ]]; then
            continue
        fi

        printf "%s\\n" "${request}"
        break
    done
}


check_cia_isp() {
curl -s 'http://ip-api.com/' && curl -s 'http://ip-api.com/' | grep isp | awk '{for(i=3;i<=NF-1;i++) printf $i" "; print ""}'|grep CIA && change_ip || \
curl -s 'https://ipinfo.io/widget' && curl -s 'https://ipinfo.io/widget'  -H "Referer: https://ipinfo.io/"  -H "Cookie: flash=" | jq .asn | jq .name |grep CIA && change_ip || \
curl -s 'https://myip.privex.io/index.json' && curl -s 'https://myip.privex.io/index.json' | jq .geo | jq .as_name |grep CIA && change_ip || \
curl -s 'https://address.computer/index.json' && curl -s 'https://address.computer/index.json' | jq .geo | jq .as_name |grep CIA && change_ip || \
curl -s 'https://myip.vc/index.json' && curl -s 'https://myip.vc/index.json' | jq .geo | jq .as_name |grep CIA && change_ip || \
	info "\n${green}  [Info] @@@ ${yellow}All test without result no CIA ISP found!"
}
