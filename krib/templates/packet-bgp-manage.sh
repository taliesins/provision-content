#!/bin/bash

###
#  Get/Set/Delete BGP peering stats on a Device in Packet
###

# set defaults
__T=$( [[ -r $HOME/.packet_token ]] && cat $HOME/.packet_token )
__M=""    # the Machine/Device UUID to set the custom data on, can be comma
          # separated list with no spaces of UUIDs
__4="no"  # enable BGP on Device for IPv4 learning
__6="no"  # enable BGP on Device for IPv6 learning
__S="no"  # start with Set mode no
__G="no"  # start with Get mode no
__D="no"  # start with Delete mode no

# POST by default, if we do Delete, issue a DELETE later
API_URL="https://api.packet.net"

# output our usage statement
function usage() {
cat <<EOF
Submit an API request to set a custom data field on a Machine in Packet.

USAGE:  $0  [ -s | -g | -d ] [ -t token ] [ -m machine_uuid(s) ] [ -4 | -6 ]
   OR:  TOKEN=token MACHINES=uuid,uuid,... $0 [-s]
   OR:  $0 -u

WHERE:  -t token            set API security Token to 'token'
        -d                  Disable all BGP learning on given Machine/Device
        -g                  Get the BGP session status information (JSON output)
        -s                  Set the BGP session to enabled for Machines
        -m machine_uuid(s)  the Machine UUID to set the custom data on
        -4                  enable the IPv4 BGP learning on given Machine/Device
        -6                  enable the IPv6 BGP learning on given Machine/Device
        -u                  this usage statement

EXAMPLES: Use one of -s, -g, -d combined with -4 and/or -6, for given Machines

          "TOKEN" is the API Key to use that has authorization to modify the
          Machines you specify.

          get (-g) will ignore '-4' and '-6' flags

          The followin Environment Variables can be specified in place of
          -t and -m options, as follows:
            - MACHINES
            - TOKEN
EOF
}

function xiterr() { [[ $1 =~ ^[0-9]+$ ]] && { XIT=$1; shift; } || XIT=1; printf "FATAL: $*\n"; exit $XIT; }

while getopts ":t:m:46dgsu" CmdLineOpts
do
  case $CmdLineOpts in
    t) TOKEN=${OPTARG}    ;;
    m) MACHINES=${OPTARG} ;;
    4) __4="yes"          ;;
    6) __6="yes"          ;;
    s) __S="yes"          ;;
    d) __D="yes"          ;;
    g) __G="yes"          ;;
    u) usage; exit 0      ;;
    \?)
      echo "Incorrect usage.  Invalid flag '${OPTARG}'."
      usage
      exit 1
      ;;
  esac
done

# set our variables, use Cmd Line settings, or flags if set,
# otherwise default values, env vars override flags
TOKEN=${TOKEN:-"$__T"}
MACHINES=${MACHINES:-"$__F"}

# convert commas to spaces
MACHINES=$(echo $MACHINES | sed 's/,/ /g')
[[ -z "$MACHINES" ]] && xiterr 1 "MACHINES not specified."

# Set or Get machine BGP peering status in the Packet API
function bgp() {
  local _machine _url_part _proto _result _session_id
  local _op=$1
  shift 1
  local _machines=$*
  [[ -z "$_machines" ]] && xiterr 1 "_machine not passed to us in bgp()"

  for TYPE in $PROTOS
  do
    for _machine in $_machines
    do
      _url_part="devices/${_machine}/bgp/sessions"

      case $_op in
        get)    METHOD="GET"
                JSON="{}"
          ;;
        set)    METHOD="POST"
                JSON="{ \"address_family\": \"$TYPE\" }"
          ;;
        delete) METHOD="GET"
                JSON="{}"
                _session_id=$(bgp get $_machine | jq -r ".bgp_sessions[] | select(.address_family == \"$TYPE\") | .id")
                METHOD="DELETE"
                _url_part="bgp/sessions/$_session_id"
          ;;
        *) xiterr 1 "unsupported operation ('$_op') passedin to bgp() function"
      esac

      _result=$(                                      \
      curl --silent --insecure --request $METHOD      \
        --header "Content-Type: application/json"     \
        --header "Accept: application/json"           \
        --header "X-Auth-Token: $TOKEN"               \
        --data "$JSON"                                \
        "${API_URL}/${_url_part}")

      if [[ "$_op" == "delete" && -z "$_result" ]]
      then
        echo "Delete appears successful:"
        echo "           address_family:  $TYPE"
        echo "                  machine:  $_machine"
        echo "                  session:  $_session_id"
      else
        echo "$_result" | jq '.'
      fi
    done
  done
}

function msg() { [[ -z "${__S}" ]] && echo "$*" || return; }

function check_status() {
case $STATUS in
  204)  msg "available"
        exit 0
    ;;
  503)  msg "unavailable"
        exit 1
    ;;
  401)  msg "unauthorized"
        exit 97
    ;;
  422)  msg "unprocessable entity"
        exit 98
    ;;
  *)    msg "unknown http code ('$STATUS')"
        exit 99
    ;;
esac
}

function usage_err() {
  echo "ERROR:  Options '$*' are mutually exclussive."
  echo "        Consider checking the Usage statemeint ('-u')."
  exit 1
}

# set and delete are exclussive
[[ "$__S" == "yes" && "$__D" == "yes" ]] && usage_err -s -d
# get and delete are exclussive
[[ "$__G" == "yes" && "$__D" == "yes" ]] && usage_err -g -d
# get and delete are exclussive
[[ "$__G" == "yes" && "$__S" == "yes" ]] && usage_err -g -s

# if get specified, zero out 4 and 6
[[ "$__G" == "yes" ]] && { __4="no"; __6="no"; }

# build our PROTOS to operate on
[[ "$__4" == "yes" ]] && PROTOS="ipv4"
[[ "$__6" == "yes" ]] && PROTOS="$PROTOS ipv6"

# run the set operations
[[ "$__S" == "yes" ]] && bgp set $MACHINES

# delete sessions
[[ "$__D" == "yes" ]] && bgp delete $MACHINES

# get sessions
[[ "$__G" == "yes" ]] && { PROTOS="get"; bgp get $MACHINES; }
