#!/usr/bin/bash

###################################################################################
#                                                                                 #
# firevigeo                                                                       #
#                                                                                 #
# version: 0.8.1                                                                  #
#                                                                                 #
# A tool to start multiple tor proxys with transparent loadbalancing feature!     #
# This tool redirect the complete traffic trough loadbalanced tor clients, with   #
#  - extra custom tor configs                                                     #
#  - an optionally conky Tor Network infobar!                                     #
#  - globaly transparent loadbalanced tor network subsystem!                      #
#  - seperate virtual dummy network cards for each tor client!                    #
#  - generate a random control-port password for each tor client!                 #
#  - and many more!                                                               #
#                                                                                 #
#  ________________________________________________________________________       #
#                                                                                 #
#   This tool require go-dispatch-proxy and redsocks proxy to work correct!       #
#                                                                                 #
#   __________________________________________________________________            #
#                                                                                 #
#                   Copyright (C) 2021-2022 Nonie689                              #
#                                                                                 #
#   Website: https://github.com/Nonie689/firevigeo-torloader                      #
#                                                                                 #
#                                                                                 #
# _____________________________________________________________________________   #
#   --- GNU GENERAL PUBLIC LICENSE ---                                            #
#                                                                                 #
#    This program is free software: you can redistribute it and/or modify         #
#    it under the terms of the GNU General Public License as published by         #
#    the Free Software Foundation, either version 3 of the License, or            #
#    (at your option) any later version.                                          #
#                                                                                 #
#    This program is distributed in the hope that it will be useful,              #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of               #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #
#    GNU General Public License for more details.                                 #
#                                                                                 #
#    You should have received a copy of the GNU General Public License            #
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.        #
#                                                                                 #
###################################################################################


## General
#
# program information
readonly prog_name="firevigeo"
readonly version="0.8.1"
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





## Display program version
print_version() {
    printf "%s\\n" "${prog_name} ${version}"
    printf "%s\\n\n" "${signature}"
    printf "%s\\n" "\License GPLv3: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>"
    printf "%s\\n" "This is free software: you are free to change and redistribute it."
    printf "%s\\n\n" "There is NO WARRANTY, to the extent permitted by law."
}


verbose_mode="false"

check_root() {
    if [[ "${UID}" -ne 0 ]]; then
        echo "Please run this program as a root!"
	echo 
	if ! $(echo $0|grep .sh); then
	  echo "Alternative add SETUID with:"
	  echo
	  echo "chown root:root $0"
	  echo "chmod u+s $0"
	  echo "chmod u+x $0"
	fi

	exit 121
    fi
}


ord() {
    LC_CTYPE=C printf '%d' "'$1"
}


__init__ () {

param_error=false

# Show programm info!
print_version


# Check depencies
not_there=false
if ! which tor &> /dev/null ; then
  echo "Found not tor! - Please install it!"
  not_there=true
fi

if ! which go-dispatch-proxy &> /dev/null ; then
  echo "Found not go-dispatch-proxy! - Please install it!"
  not_there=true
else
  setcap cap_net_raw=eip $(which go-dispatch-proxy)
fi

if ! which redsocks &> /dev/null ; then
  echo "Found not redsocks! - Please install it!"
  not_there=true
fi

if ! which conky &> /dev/null ; then
  echo "Found not conky - Please install it!"
  not_there=true
fi

if ! which proxychains &> /dev/null ; then
  echo "Found not proxychains - Please install it!"
  not_there=true
fi

if $not_there ; then
exit 2
fi

sleep 1

}

generate_random(){
shuf -i 10000-1000000 -n1
}

function __main__() {
  ###  Here is the main construct of this tool! 
  check_root
  __init__

  own_params "${@}"

}

get_date_time() {
#get date time formated"
  date +%Y.%m.%d\ at\ %h:%m
}


start_tor_servers_by_country() {
countr_count_num=60001
while read -r country_line
do
    country_port=$country_line
    let countr_count_num=countr_count_num+1
done < <(cat ${basename}/country_codes.lst | awk -F"[{}]" '{print $2}')

}

start_tor_servers() {
  # Killall runnig tor processes if existing!
  for tor_pid in $(ps aux | grep -E "tor -f /etc/tor/torrc\." | grep -v "grep" | awk '{print $2}'); do
    kill $tor_pid
  done
  modprobe dummy &> /dev/null
  start=$1
  end=$2
  
  readonly number_torsrv_wanted="$(expr $end -  $start)"
  readonly script="$0"
  readonly basename="$(dirname $script)"

  echo "Change DNS service to use Tor DNS service!"
  echo "nameserver 127.0.0.1" > /etc/resolv.conf

  #  Early inititialisation part -  Setting up start variables with needet init values!
  # Stores the executing start date.
  readonly _cdate="$(date +%Y%m%d)"
  readonly _init_date="$(get_date_time)"

  readonly _init_random="$(generate_random)"
  readonly _tor_pass_readable="$_cdate$_init_random"
  readonly _tor_hashpass="$(tor --hash-password $_tor_pass_readable| tail -1)"
  # Variables related to the log file. Divided into three parts due
  # to the better possibility of manipulation for the user.
  readonly _log_directory="/var/log"
  readonly _log_file="firevigeo-prepare.${_cdate}.log"
  readonly _log_stdout="${_log_directory}/firevigeo-prepare.stdout.log"
  readonly _log_path="${_log_directory}/${_log_file}"
  readonly _torrc_config="/etc/tor/torrc"
  readonly _proxychain_config="/etc/proxychains"

  counter=0
  counter_rw=1
  dnsport=53
  ip_addr=10

  # Saved new hashed pass as readable file at: /etc/tor/hashed_pass
  echo "Saved new Tor Control password store file at: /etc/tor/hashed_pass" && echo && echo -e "##############################################################################################\n####### Passwords for all tor  processed started with firevigeo! #############################\n####### Generated on:  $_init_date for Tor Proxy Number from $start till $end ! ####\n############################################################################################\n####### Number of Tor Proxy clients = ${number_torsrv_wanted}! ##################################################\n# Readable Tor password #########\npass_plain=$_tor_pass_readable\n\n# Hash-encoded Tor password #####\npass_hash=$_tor_hashpass" > /etc/tor/hashed_pass && chmod 600  /etc/tor/hashed_pass

   # Copy uncomplete conky config to  systemfolder!    ----    Using  files from script  ."/data/config"  folder
   if ! test -d /etc/conky/cpu-colors-edit/ ; then
     echo "Create system settings folder for conkyrc file!" 
     mkdir -p "/etc/conky/cpu-colors-edit/" 2> /dev/null
   fi

   # Generate custom conky and proxychain setting section!
   echo "Generate custom conky and proxychains settings!" 
   cp -f "${basename}/data/config/conkyrc" "/etc/conky/cpu-colors-edit/.conkyrc"


   # Generate for each Tor client custom settings and start the Tor Proxy clients!
   echo -e "\nGenerate for each Tor client custom settings and start the Tor Proxy clients!"

   ### Run  forloop and create custom configs for conky and proxychain!
   for number in $(seq $start $end)
    do
	newcontrolport="$(expr $number + 1100)"
    printf "Generate Tor socks: $number "

    # Create  proxychain config foreach tor proxy device with new settings !
    cp "${basename}/data/config/proxychains.conf" $_proxychain_config.$counter_rw.conf
    echo "socks4 10.0.0.$ip_addr $number" >> $_proxychain_config.$counter_rw.conf

    # Add  custom conkycode to conkyrc  tor displaying tor proxy stuff!
    echo \${goto 12}\${voffset 0}\${font Ubuntu:style=Bold:size=8}Tor $counter_rw IP: \${alignr}\${color2}\${execp proxychains -q -f $_proxychain_config.$counter_rw.conf 'curl -s https://myip.privex.io/index.json| jq  -r .ip' }\${color} >> /etc/conky/cpu-colors-edit/.conkyrc
  
    # Set torrc config
    # Add foreach Tor-Gateway device extra torrc options with new custom settings!!

    echo "ExcludeNodes {es},{us},{ca},{de},{li},{at},{gb},{la},{au},{nz},{dk},{fr},{nl},{lt},{ng},{nf},{no},{ma},{cz},{fi},{et},{fx},{gf},{pf},{ie},{tf},{so},{sv},{pa},{gq},{no},{dj},{gs},{re},{hr},{ky},{gn},{ht},{hm},{gw},{gi},{gr},{gl},{cl},{cc},{cg},{co},{cl},{cd},{cx},{tc},{hu},{vc},{is},{be},{in},{is},{hu},{hn},{ht},{bg},{vg},{io},{lu},{mt},{mx},{mv},{ml},{mh},{mn},{mn},{me},{bw},{ba},{bo},{mm},{mc},{mn},{me},{ph},{np},{an},{bh},{by},{be},{am},{ar},{aq},{dz},{al},{af},{ne},{lr},{lb},{lv},{cf},{ly},{it},{uk},{se},{um},{ru},{sa},{cn},{ae},{uy},{uz},{va},{ve},{vi},{gq},{tj},{lv},{eh},{eh},{zw},{sd},{iq},{sk},{za},{lk},{sd},{sz},{tz},{to},{tn},{tv},{ug},{il},{ir},{tm},{kr},{sy},{az},{tr},{vn},{gq},{am},{kg},{kz},{by},{ua},{uz},{tj},{ir},{lb},{mm},{na},{np},{ps},{bd},{ph},{pl},{pt},{qa},{sm},{ly},{pr},{ye},{??} StrictNodes 1" > $_torrc_config.$number
    echo "ExitNodes {tj},{tw},{th},{jp},{ro},{vg},{br},{lc},{ge},{gh},{co},{dm},{do},{gp},{ke},{kp},{pk},{nc},{rs},{pg},{gt},{ec},{ad},{sb},{py},{pe},{lk},{tz},{ug},{vn},{cr},{sl},{ni},{zm},{tz},{sr},{kw},{sn},{kh},{bd},{id},{gy} StrictNodes 1" >> $_torrc_config.$number
    echo "User tor" >> $_torrc_config.$number
    echo "Sandbox 1" >> $_torrc_config.$number
    echo "HardwareAccel 1" >> $_torrc_config.$number
    echo "BandwidthBurst 1547483647" >> $_torrc_config.$number
    echo "BandwidthRate 1547483647" >> $_torrc_config.$number
    #echo "ConnLimit $(ulimit -H -n)" >> $_torrc_config.$number
    echo "NewCircuitPeriod 90" >> $_torrc_config.$number
    mkdir /var/lib/tor.$number &> /dev/null
    mount -t tmpfs tmpfs /var/lib/tor.$number -o size=35m &> /dev/null
    cp -rp "/var/lib/tor" "/var/lib/tor.$number" &> /dev/null
    chown tor "/var/lib/tor.$number"
    echo "DataDirectory /var/lib/tor.$number" >> $_torrc_config.$number
    echo "SocksPort 10.0.0.$ip_addr:$number" >> $_torrc_config.$number
    ip_addr_list="$ip_addr_list 10.0.0.$ip_addr:$number"
    echo "ControlPort $newcontrolport" >> $_torrc_config.$number
    echo "HashedControlPassword $_tor_hashpass" >> $_torrc_config.$number
    # Enable only at the first tor client a DNS service!
    if test $counter -eq 0 ; then
      echo "DNSPort $dnsport" >> $_torrc_config.$number
    fi

    ip link add veth$counter type dummy  &> /dev/null 
    ip addr add 10.0.0.$ip_addr/24 brd + dev veth$counter label veth$counter:0  &> /dev/null 
    ip link set dev veth$counter up  &> /dev/null

    let counter=counter+1
    let counter_rw=counter_rw+1
    let ip_addr=ip_addr+1

    #Start tor proxy router for virtual  network card! Then check the  execution succeed!
    tor -f $_torrc_config.$number &> /dev/null & 

    if [ $? -eq 0 ] ; then
      echo " -- Tor $counter started!"
    else
      echo " -- Failed to start Tor!"
    fi

    # End of loop for creating custom new settings!
 done


   # Save conkyrc to users folder!
   UHOME="/home"
   # get list of all users
  _USERS="$(awk -F':' '{ if ( $3 >= 500 ) print $1 }' /etc/passwd)"
  for u in $_USERS
  do
     _dir="${UHOME}/${u}"
     if [ -d "$_dir" ]
     then
	 mkdir -p $_dir/.conky/cpu-colors-edit 2> /dev/null 
         cmp --silent -- /etc/conky/cpu-colors-edit/.conkyrc "$_dir/.conky/cpu-colors-edit/.conkyrc" || cp -f /etc/conky/cpu-colors-edit/.conkyrc "$_dir/.conky/cpu-colors-edit/" && chown $(id -un $u):$(id -gn $u) "$_dir/.conky/cpu-colors-edit/.conkyrc"
     fi
  done

  #Reset currently used \iptables.rules
  echo
  echo "Disable Network to unload iptables.rules, to prevent IP leaks!"
  default_ifname="$(netstat -r | awk ' {print $8}' | head -3 | tail -1)"
  default_ip_addr="$(ip a | grep ${default_ifname} | tail -1| awk '{print $2}')"
  default_broadcast_addr="$(ip a | grep ${default_ifname} | tail -1| awk '{print $4}')"
  default_gateway="$(ip route | head -1  | awk '{print $3}')"

  for net_dev in $(ip a | grep -E "UP ."| grep default | awk '{print $2}' | awk -F':' '{print $1}'); do
     ip link set dev $net_dev down &> /dev/null
  done
  
  ip link set dev ${default_ifname} down &> /dev/null
  echo "Unload currently used iptables.rules!"

  while true ; do
    if test `iptables --list | wc -l` -ne 8 ; then 
      reset_iptables
    else
     break
    fi
  done
     # Save iptables.rule, if not exist in system settings folder!
     if test ! -f  /etc/iptables/redsocks-go-balanced.rules && ! test `cmp --silent "${basename}/data/config/redsocks.rules"  "/etc/iptables/redsocks-go-balanced.rules"` ; then echo "Save redsocks iptables rules!";cp -f "${basename}/data/config/redsocks.rules"  "/etc/iptables/redsocks-go-balanced.rules"; fi
     # Load iptables
     echo "Loading new custom iptables rules!"
     cat /etc/iptables/redsocks-go-balanced.rules | iptables-restore  -c -w 2 &> /dev/null
     if [ "$?" -ne 0 ] ; then
       echo "Error! - Failed to load new custom iptables rules!"
       echo "Default Network are still disabled!"
       echo
       for net_dev in $(ip a | grep -E "DOWN ."| grep default | awk '{print $2}' | awk -F':' '{print $1}'); do
          ip link set dev $net_dev UP &> /dev/null
       done
       exit 22
     else
       ip addr add default_ip_addr brd + dev ${default_ifname} &> /dev/null; ip link set dev ${default_ifname} up &> /dev/null 
     fi

     iptables -A INPUT -p udp -m udp --dport 137 -j ACCEPT
     iptables -A INPUT -p udp -m udp --dport 138 -j ACCEPT
     iptables -A INPUT -p tcp -m tcp --dport 139 -j ACCEPT
     iptables -A INPUT -p tcp -m tcp --dport 445 -j ACCEPT

     # Wait for real iptables load finish!
     sleep 0.5

     if test `iptables --list | grep -E "target     prot opt source               destination"| wc -l` -gt 14 ; then
       echo "Iptables Loading done! -- System is now complete proxyfing traffic by loadbalancer!"
     fi

     pidof redsocks &> /dev/null || echo "Info -- Redsocks daemon is not running! Redsocks is required! Please don't forget to start this daemon after done this!" && echo
     pidof go-dispatch-proxy &> /dev/null || echo "Info -- Go-dispatch-proxy is not running! Go-dispatch-proxy is required! Please don't forget to start this after done this!" && echo

  echo "Finished custom systm configuration!"
  echo
  echo " -- Some additionaly infos for user --"
  echo
  echo "Tor ControlPort password in clear text is: $_tor_pass_readable"
  echo "Tor ControlPort password in coded text is: $_tor_hashpass"
  echo
  echo "Start Load Balancer with: go-dispatch-proxy -lport 4711 -tunnel $ip_addr_list"

  start_tor_servers_by_country
  exit 0
}


reset_iptables() {
     iptables -F
     iptables -X
     iptables -t nat -F
     iptables -t nat -X
     iptables -P INPUT ACCEPT
     iptables -P FORWARD ACCEPT
     iptables -P OUTPUT ACCEPT
     sleep 0.5
}


param_num_check() {
     if [[ "$#" -gt 1 ]]; then
        if [[ $2 -lt 5000 || $2 -gt 60000 ]]; then
          echo "Failure wrong Value! - The start Tor-Proxy range is 5000-60000!"
          exit 2
        fi
        if [[ $3 -lt 5000 || $3 -gt 60000 ]]; then
          echo "Failure wrong Value! - The End Tor-Proxy range is 5000-60000!"
          exit 3
        fi
        if [[ $2 -gt $3 ]]; then
          echo "Start Tor-Proxy are not be allowed to be smaller then End Tor-Proxy!"
          exit 999
        fi
     fi
}

_help_(){
print_version
echo "firevigeo-prepare [OPTIONS]"
echo
echo "OPTIONS:"
echo -e "   -h|--help                              Shows this help message!"
echo -e "   -k|--kill                              Kills all Tor Proxys!"
echo -e "   -r|--runtime-check                     Checks firevigeo runtime state status!"
echo -e "   -s|--start    #Start_Port #End_Port    Start firevigeo Tor-Proxys [optional own Port range]!"
echo -e "   -n|--new-id   #Start_Port #End_Port    Start firevigeo Tor-Proxys [optional own Port range]!"

}


own_params() {
    start=5090
    end=5100
    if ! test -z $2; then
      start=${2}
    fi
    if ! test -z $3; then
      end=${3}
    fi

    if [[ "$#" -eq 0 ]]; then
        printf "%s\\n" "${prog_name}: Argument required"
        printf "%s\\n" "Try '${prog_name} --help' for more information."
        exit 1
    fi

    if [[ "$#" -gt 0 ]]; then
    case $1 in
      -h|--help)
        _help_
        exit 0
        shift ;;

      -k|--kill)
        if [[ "$#" -gt 1 ]]; then
          echo "To much parameters are given!"
          exit 9
        fi
        for tor_pid in $(ps aux | grep -E "tor -f /etc/tor/torrc\." | grep -v "grep" | awk '{print $2}'); do
          kill $tor_pid
        done

        for net_dev in $(ip a | grep -E "DOWN ."| grep default | awk '{print $2}' | awk -F':' '{print $1}'); do
          ip link set dev $net_dev up &> /dev/null
        done

        echo Done stopped all Tor instances!
        echo
        echo "Unload currently used iptables.rules!"
        reset_iptables
        iptables-restore /etc/iptables/iptables.rules & > /dev/null && echo "Restarted iptables with default system firewall rules!"
        echo "Change DNS service to use Google DNS service!"
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo
        echo "Done!"
        shift ;;

      -r|--runtime-check)
        if [[ "$#" -gt 1 ]]; then
          echo "To much parameters are given!"
          exit 9
        fi

        fail=false
        if [[ $(ps aux | grep -E "tor -f /etc/tor/torrc." | grep -v "grep"| wc -l) -gt 0 ]]; then
          echo "Tor Services running!"
          if [[ $(ps aux | grep -E "redsocks" | grep -v "grep"| wc -l) -gt 0 ]]; then
            echo " ** Redsocks runs!"
          else
            echo " ** [Warn] Redocks not running!"
            fail=true
          fi
          if [[ $(ps aux | grep -E "go-dispatcher" | grep -v "grep"| wc -l) -gt 0 ]]; then
            echo " ** Go-dispatcher loadbalancer running!"
          else
            echo " ** [Warn] Go-dispatche loadbalancer not running!"
            fail=true
          fi
          #####
          if $fail; then
            echo
            echo " ** Firevigeo runtime dependencies are not running!"
          else
            echo " Firevigeo is running!"
          fi
        else
          echo " Firevigeo is not running completely!"
        fi
        shift ;;

      -n|--new-id)
        param_num_check $1 $start $end
        start_tor_servers $start $end
        shift ;;

      -s|--start)
        param_num_check $1 $start $end
        start_tor_servers $start $end
        shift ;;

      *)
        echo Error Invalid Option!
        exit 1
        ;;
    esac
  fi
}


__main__ "${@}"


