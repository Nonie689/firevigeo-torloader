#!/usr/bin/bash

###################################################################################
#                                                                                 #
# firevigeo                                                                       #
#                                                                                 #
# version: 0.9.3                                                                  #
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
#                   Copyright (C) 2023 Nonie689                                   #
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


### Init area make some general needed things
##
### set program  information and const variabels!

## for net_dev in $(ip link | awk -v n=2 'NR%n==1' | awk -F ':' '{print $2}' | grep -v lo)
#do
#  if test $(echo "$default_ifname" | wc -c) -ne 0 && [ test ${default_ifname} = ${net_dev} ]
#  then
#     interface_name="$default_ifname"
#  else
#     echo "$default_ifname" | grep enp && interface_name="eth$eth_count" && let eth_count=eth_count+1
#     echo "$default_ifname" | grep wls && interface_name="wlan$wlan_count" &&  let wlan_count=wlan_count+1
#  fi
#
#  net_path="$(sudo udevadm info /sys/class/net/$net_dev | grep -E 'ID_PATH=' | awk -F '=' '{print $2}')"
#
#  # Creating new systemd network rename.link file
#  echo "[Match]" > /etc/systemd/network/10-rename-$net_dev.link
#  echo "Path=$net_path" >> /etc/systemd/network/10-rename-$net_dev.link
#  echo "[Link]" >> /etc/systemd/network/10-rename-$net_dev.link
#  echo "Name=$interface_name" >> /etc/systemd/network/10-rename-$net_dev.link
#done

readonly prog_name="firevigeo"
readonly version="0.9.3"
readonly signature="Copyright (C) 2023 Nonie689"
readonly git_url="https://github.com/Nonie689/firevigeo-torloader"

# script some const to set to work correct

script="$0"
basename="$(dirname $script)"

LC_ALL=C
verbose_mode="false"

# default tor dns port!

readonly dnsport=53

# place where the comfig where!
readonly _torrc_config="/etc/tor/torrc"
readonly _proxychain_config="/etc/proxychains"

# set colors for stdout
readonly red="$(tput setaf 1)"
readonly green="$(tput setaf 2)"
readonly yellow="$(tput setaf 3)"
readonly blue="$(tput setaf 4)"
readonly magenta="$(tput setaf 5)"
readonly cyan="$(tput setaf 6)"
readonly white="$(tput setaf 7)"
readonly b="$(tput bold)"
readonly reset="$(tput sgr0)"

# set tor proxy options Stores the executing start date.
_cdate="$(date +%Y%m%d)"	  # execution date variable!
_init_date="$(date +%Y.%m.%d\ at\ %h:%m)"  # init date variable

_init_random="$(shuf -i 10000-1000000 -n1)"
_tor_pass_readable="${_cdate}${_init_random}"
_tor_hashpass="$(tor --hash-password $_tor_pass_readable| tail -1)"


min_speed=18000
count=0

# Variables related to the log file. Divided into three parts due
# to the better possibility of manipulation for the user.

readonly _log_directory="/var/log"
_log_file="firevigeo.${_cdate}.log"
readonly _log_stdout="${_log_directory}/firevigeo.stdout.log"
_log_path="${_log_directory}/${_log_file}"


###############################################
## Declare programm functions programm area ##
#############################################

## Display program version
print_version() {
    printf "%s\\n" "${prog_name} ${version}"
    printf "%s\\n\n" "${signature}"
    printf "%s\\n" "License GPLv3: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>"
    printf "%s\\n" "This is free software: you are free to change and redistribute it."
    printf "%s\\n\n" "There is NO WARRANTY, to the extent permitted by law."
    sleep 0.5
}

check_root() {
    if [[ "${UID}" -ne 0 ]]; then
        echoerr "please run this program as a root!"
    	echo
        exit 121
    fi
}

exclude_tor_relay() {
  # Set parameter variable!
  parameter=$1

  # Store command output results to variable!!
  output_1=$(
  
  while true
    do
    python $basename/exclude-slow-tor-relays-ng -d /var/lib/tor.$parameter/ -i $_torrc_config.$parameter -b $min_speed 2> /dev/null | grep -vE 'Could not find or read consensus file.' && break || sleep 1.25
       done
   )
   
   # Sleep a moment and reload torrc config
   sleep 0.25
     
   kill -1 $(ps -aux | grep -E "tor -f $_torrc_config.$parameter" | grep -v 'grep' | awk '{print $2}' | head -n 1)
      
}

# Print echo functions!!
echoerr() { echo -e "$red[Error] $reset** $@" 1>&2; }
echowarn() { echo -e  "$yellow[Warn] $reset** $@" 1>&2; }
echoinfo() { echo -e "$cyan[Info] $reset** $@"; }

ord() {
    env LC_CTYPE=C printf '%d' "$1"
}

__init__ () {

param_error=false

# Check depencies
not_there=false

## Test missing runtime dependencies!!

python -c "import stem" &> /dev/null || bash -c "echoerr 'python stem not found! - Please install it!' && not_there=true"

if ! which tor &> /dev/null ; then
  echoerr "tor not found! - Please install it!"
  not_there=true
fi

if ! which go-dispatch-proxy &> /dev/null ; then
  echoerr "go-dispatch-proxy not found! - Please install it!"
  not_there=true
else
  setcap cap_net_raw=eip $(which go-dispatch-proxy)
fi

if ! which redsocks &> /dev/null ; then
  echoerr "redsocks not found! - Please install it!"
  not_there=true
fi

if ! which conky &> /dev/null ; then
  echowarn "conky not found! - Please install this optional dependency!"
fi

if ! which proxychains &> /dev/null ; then
  echowarn "proxychains not found! - Please install this optional dependency!" 
fi


### Exit if dependencies are missing that are really need by this tool

if $not_there ; then
  exit 2
else
  # get current used network values and save them

  default_ifname="$(route | grep default | awk '{print $8}')"
  if test $(echo "$default_ifname" | wc -l) -eq 0
  then
    echoerr "no default network interface selected!"
    echo $default_ifname
    exit 6
  fi

  default_ip_addr="$(ip a | grep $default_ifname | tail -1| awk '{print $2}')"
  default_broadcast_addr="$(ip a | grep $default_ifname | tail -1| awk '{print $4}')"
  default_gateway="$(ip route | head -1  | awk '{print $3}')"


  echo
  #echoinfo "Disable Network to unload iptables.rules, to prevent IP leaks!"
  # Disable default network interface
  #ip link set dev ${default_ifname} down &> /dev/null

  fi
  
  # Create virtual dummy network
  modprobe dummy    # load dummy network module!
  ip link add virt0 type dummy  2> /dev/null
  ip addr add 10.0.0.10/24 brd + dev virt0 label virt0:0  2> /dev/null
  ip link set dev virth0 up  2> /dev/null
  
  # Enables ip forwarding in the system kernel!
  
  echo "1" > /proc/sys/net/ipv4/ip_forward &> /dev/null
  sysctl net.ipv4.ip_forward=1 &> /dev/null
  
  # Load the iptables module in the kernel!
  modprobe ip_tables
  
  # Enable connection tracking! -- [connection status is taken into account]
  modprobe ip_conntrack
  
  # Additional functions for IRC!
  modprobe ip_conntrack_irc
  
  # Additional info for FTP!
  modprobe ip_conntrack_ftp

}

generate_random(){
   shuf -i 10000-1000000 -n1
}

function __main__() {
  ###  Here is the main construct of this tool!

  # Show programm info!

  print_version

  # Use parameters!
  own_params "${@}"
}

function get_date_time() {
# print date with time in basic format"
  date +%Y.%m.%d\ at\ %h:%m
}

start_tor_servers_by_country() {
country_count_num=60001
for country_port in $(cat ${doc_dir}/country_codes.lst | awk -F"[{}]" '{print $2}');do
    let countrycontrolport=country_count_num+1000
    cp $_torrc_config $_torrc_config.$country_port
    echo "ExitNodes {$country_port} StrictNodes 1" >> $_torrc_config.$country_port
    echo "User tor" >> $_torrc_config.$country_port
    echo "Sandbox 1" >> $_torrc_config.$country_port
    echo "HardwareAccel 1" >> $_torrc_config.$country_port
    echo "BandwidthBurst 1547483647" >> $_torrc_config.$country_port
    echo "BandwidthRate 1547483647" >> $_torrc_config.$country_port
    #echo "ConnLimit $(ulimit -H -n)" >> $_torrc_config.$number
    echo "NewCircuitPeriod 90" >> $_torrc_config.$country_port
    mkdir /var/lib/tor.$country_port &> /dev/null
    mount -t tmpfs tmpfs /var/lib/tor.$country_port -o size=35m &> /dev/null
    #cp -rp "/var/lib/tor" "/var/lib/tor.$number" &> /dev/null
    chown tor:tor "/var/lib/tor.$country_port"
    echo "DataDirectory /var/lib/tor.$country_port" >> $_torrc_config.$country_port
    echo "SocksPort 10.0.0.10:$country_count_num" >> $_torrc_config.$country_port
    echo "ControlPort $countrycontrolport" >> $_torrc_config.$country_port
    echo "HashedControlPassword $_tor_hashpass" >> $_torrc_config.$country_port
    echo "RunAsDaemon 1" >> $_torrc_config.$country_port


    #ip link add veth$counter type dummy  &> /dev/null
    #ip addr add 10.0.0.$ip_addr/24 brd + dev veth$counter label veth$counter:0  &> /dev/null
    #ip link set dev veth$counter up  &> /dev/null

    let country_count_num=country_count_num+1
done

}

start_tor_servers() {
  check_root
  __init__

  # Killall runnig tor processes if existing!
  for tor_pid in $(ps aux | grep -E "tor -f /etc/tor/torrc.*" | grep -v "grep" | awk '{print $2}'); do
     kill $tor_pid &> /dev/null && echo Kill TOR-PID: $tor_pid
  done

  start=$1
  end=$2

  readonly number_torsrv_wanted="$(expr $end -  $start)"

#  if test -d /usr/share/firevigeo/data; then
#     readonly data_dir=/usr/share/firevigeo/
#     readonly doc_dir=/usr/share/doc/firevigeo/
#  else
     readonly data_dir=$basename
     readonly doc_dir=$basename
#  fi

  counter=0
  counter_rw=1
  ip_addr=10

  # Saved new hashed pass as readable file at: /etc/tor/hashed_pass
  echo "Saved new Tor Control password store file at: /etc/tor/hashed_pass" 
  echo
  echo -e "##############################################################################################\n####### Passwords for all tor  processed started with firevigeo! #############################\n####### Generated on:  $_init_date for Tor Proxy Number from $start till $end ! ####\n############################################################################################\n####### Number of Tor Proxy clients = ${number_torsrv_wanted}! ##################################################\n# Readable Tor password #########\npass_plain=$_tor_pass_readable\n\n# Hash-encoded Tor password #####\npass_hash=$_tor_hashpass" > /etc/tor/hashed_pass && chmod 600  /etc/tor/hashed_pass

   # Copy uncomplete conky config to  systemfolder!    ----    Using  files from script /data/config"  folder
   if ! test -d /etc/conky/cpu-colors-edit/ ; then
     echo "Create conky system settings folder!"
     mkdir -p "/etc/conky/cpu-colors-edit/" &> /dev/null
   fi

   # Generate custom conky and proxychain setting section!
   echo "Generate custom conky and proxychains settings!"
   cp -f "${data_dir}/data/config/conkyrc" "/etc/conky/cpu-colors-edit/.conkyrc"


   # Generate for each Tor client custom settings and start the Tor Proxy clients!
   echo -e "\nGenerate for each Tor client custom settings and start the Tor Proxy clients!"
   if ! $(pidof stubby &> /dev/null); then
     echo
     echo "You are not using stubby DNS-Resolver!"
     echo "Please install it to use DNS over TLS!"
     echo
     echo "see: https://dnsprivacy.org/wiki/display/DP/DNS+Privacy+Daemon+-+Stubby"
     echo
   fi


   ### Run  forloop and create custom configs for conky and proxychain!
   for number in $(seq $start $end)
    do
   	newcontrolport="$(expr $number + 2500)"
    printf "Generate Tor socks: $number "

    # Create a modified  proxychain config for every tor proxy!
    cp "${data_dir}/data/config/proxychains.conf" $_proxychain_config.$counter_rw.conf
    echo "socks4 10.0.0.10 $number" >> $_proxychain_config.$counter_rw.conf

    # Add  custom conkycode to conkyrc  tor displaying tor proxy stuff!
    echo \${goto 12}\${voffset 0}\${font Ubuntu:style=Bold:size=8}Tor $counter_rw IP: \${alignr}\${color2}\${execp proxychains -q -f $_proxychain_config.$counter_rw.conf 'curl -s https://myip.privex.io/index.json| jq  -r .ip' }\${color} >> /etc/conky/cpu-colors-edit/.conkyrc

    # Create modified torrc config for every tor proxy on $_torrc_config.$number!!
    echo "ExcludeNodes {es},{us},{ca},{de},{li},{at},{gb},{la},{au},{nz},{dk},{fr},{nl},{lt},{ng},{nf},{ma},{cz},{fi},{et},{so},{sv},{be},{by},{be},{ly},{it},{uk},{se},{um},{ru},{cn},{uy},{uz},{zw},{sk},{sz},{tz},{tv},{ug},{kr},{sy},{tr},{kg},{kz},{ua},{uz},{ph},{pl},{pt},{sm},{ly},{??} StrictNodes 1" > $_torrc_config.$number
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
    #cp -rp "/var/lib/tor" "/var/lib/tor.$number" &> /dev/null
    chown tor:tor "/var/lib/tor.$number"
    echo "DataDirectory /var/lib/tor.$number" >> $_torrc_config.$number
    echo "SocksPort 10.0.0.10:$number" >> $_torrc_config.$number
    echo "ControlPort $newcontrolport" >> $_torrc_config.$number
    echo "HashedControlPassword $_tor_hashpass" >> $_torrc_config.$number
    echo "RunAsDaemon 0" >> $_torrc_config.$number

    # Enable only at the first tor client a DNS service!
    if test $counter -eq 0 && ! $(pidof stubby &> /dev/null) ; then
      echo "DNSPort 127.0.0.1:$dnsport" >> $_torrc_config.$number
    fi

    # Add tor proxy ip address to tor-proxy list tuple
    ip_addr_list="$ip_addr_list 10.0.0.10:$number"

    let counter=counter+1
    let counter_rw=counter_rw+1
    #let ip_addr=ip_addr+1

    #Start tor proxy router for virtual  network card! Then check the  execution succeed!
    nohup tor -f $_torrc_config.$number &> /dev/null &

    if [ $? -eq 0 ] ; then
      echoinfo "tor $counter started!"
    else
      echowarn "failed to start Tor!"
    fi

    # End of loop for creating custom new settings!
 done


   # Exclude slow relays and reloard torrc config!
   echo
   echo
   echoinfo "Excluding slow tor relays!!"
   echo

   for number in $(seq $start $end)
   do
     exclude_tor_relay $number &
   done

   
   # Waiting for that all slow relay excluding jobs are finised!
   
   sleep 2.5
   
   while true
   do
     sleep 0.125
     ps -aux | grep -e "exclude-slow-tor-relays-ng" | grep -v grep &> /dev/null && continue
     break
   done

   echo
   echo Completed updating of relays to relays faster then $min_speed!
   echo
   
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

     #Reset currently used iptables.rules
     echo

     echoinfo "Unload currently used iptables.rules!"
     reset_iptables

     # Save iptables.rule to system settings folder!
     cp $basename/data/config/redsocks.rules /etc/iptables/redsocks-go-balanced.rules &> /dev/null
     cp $basename/data/config/redsocks.conf /etc/redsocks.conf

     # Load redsocks-go-balanced iptables rules
     echoinfo "Loading new custom iptables rules!"
     iptables-restore -c -w 2 < /etc/iptables/redsocks-go-balanced.rules

     if [ "$?" -ne 0 ] ; then
       echoerr "failed to load new custom iptables rules!"
       echo
       exit 404
    else
       echoinfo "system loaded new iptables rule!"
     fi


    #ip link set dev $default_ifname up 1> /dev/null
    #ip addr add $default_ip_addr brd + dev ${default_ifname} 1> /dev/null

     #while true
     #do
     #   sleep 0.5
     #   if test $(sudo sudo iptables-save | wc -l) -gt 24; then
     #     echoinfo "iptables Loading done! -- System is now complete proxyfing traffic by loadbalancer!"
     #     break
     #   fi
     #done

  echoinfo "Change DNS service to use 127.0.0.1!"
  echo "nameserver 127.0.0.1" > /etc/resolv.conf

  echo "Finished custom system configuration!"
  echo
  echo " -- Some additionaly infos for user --"
  echo
  echoinfo "Tor ControlPort password in clear text is: $_tor_pass_readable"
  echoinfo "Tor ControlPort password in coded text is: $_tor_hashpass"
  echo

  pidof redsocks &> /dev/null && echo "Redsocks daemon already running!" || echowarn "Redsocks daemon isn't running!\n Starting redsocks daemon!\mPlease start redsocks!"
  (pidof go-dispatch-proxy &> /dev/null && ps -aux | grep -E "go-dispatch-proxy -lhost 10.0.0.10 -lport 4711 -tunnel $ip_addr_list") &> /dev/null && echo && echo && echoinfo "go-dispatch-proxy loadbalancer is running correctly!" ||  echowarn "go-dispatch-proxy loadbalacer uses not the correct tunnel proxys! \n\nPlease fix it!" 
  
  echo
  echo
  echo You should run: killall go-dispatch-proxy
  echo
  echo You start the loadbalancer with: 
  echo "   go-dispatch-proxy -lhost 10.0.0.10 -lport 4711 -tunnel $ip_addr_list"
  echo
  echo

  #start_tor_servers_by_country
  exit 0
}


reset_iptables() {
  while true ; do
     if $(sudo iptables-save | grep 31338 &> /dev/null); then
        iptables -F
        iptables -X
        iptables -t nat -F
        iptables -t nat -X
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        sleep 0.5
      else
        break
     fi
   done
}


param_num_check() {
     if [[ "$#" -gt 1 ]]; then
        if [[ $2 -lt 10000 || $2 -gt 60000 ]]; then
          echo "Failure wrong Value! - The start Tor-Proxy range is 10000-60000!"
          exit 2
        fi
        if [[ $3 -lt 10000 || $3 -gt 60000 ]]; then
          echo "Failure wrong Value! - The End Tor-Proxy range is 10000-60000!"
          exit 3
        fi
        if [[ $2 -gt $3 ]]; then
          echo "Start Tor-Proxy are not be allowed to be smaller then End Tor-Proxy!"
          exit 999
        fi
     fi
}

_help_(){
echo "firevigeo-prepare [OPTIONS]"
echo
echo "OPTIONS:"
echo -e "   -h|--help                              Shows this help message!"
echo -e "   -k|--kill                              Kills all Tor Proxys!"
echo -e "   -r|--runtime-check                     Checks firevigeo runtime state status!"
echo -e "   -s|--start    #Start_Port #End_Port    Start firevigeo Tor-Proxys [optional own Port range]!"

}


own_params() {
    start=10001
    end=10020
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

        check_root
        __init__
        # Killall runnig tor processes if existing!
        for tor_pid in $(ps aux | grep -E "tor -f /etc/tor/torrc.*" | grep -v "grep" | awk '{print $2}'); do
           kill $tor_pid &> /dev/null && echo Kill TOR-PID: $tor_pid
        done

        echo Done stopped all Tor instances!
        echo
        echo "Unload currently used iptables.rules!"
        reset_iptables
        iptables-restore /etc/iptables/iptables.rules & > /dev/null && echo "Restarted iptables with default system firewall rules!"
        echo "Change DNS service to use Google DNS service!"
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo
        #echo "Set default network device UP!"
        #ip link set dev $default_ifname up 1> /dev/null
        #echo
        echo "Done!"
        shift ;;

      -r|--runtime-check)
        if [[ "$#" -gt 1 ]]; then
          echo "To much parameters are given!"
          exit 9
        fi

        fail=false
        if [[ $(ps aux | grep -E "tor -f /etc/tor/torrc." | grep -v "grep"| wc -l) -gt 0 ]]; then
          echoinfo "found $(ps aux | grep -E 'tor -f /etc/tor/torrc.' | grep -v 'grep'| wc -l) running tor clients!"
          if [[ $(ps aux | grep -E "redsocks" | grep -v "grep"	| wc -l) -gt 0 ]]; then
            echoinfo "redsocks runs!"
          else
            echowarn "redsocks not running!"
            fail=true
          fi
          if [[ $(ps aux | grep -E "go-dispatcher" | grep -v "grep"| wc -l) -gt 0 ]]; then
            echoinfo "go-dispatcher loadbalancer running!"
          else
            echowarn "go-dispatche loadbalancer not running!"
            fail=true
          fi
          #####
          if $fail; then
            echo
            echowarn "firevigeo runtime dependencies are not running!"
          else
            echoinfo "firevigeo is running!"
          fi
        else
          echoerr "firevigeo is not running correct!"
        fi
        shift ;;

      -s|--start)
        param_num_check $1 $start $end
        start_tor_servers $start $end
        shift ;;

      *)
        echoerr Invalid Option!
        exit 1
    esac
  fi
}


__main__ "${@}"
