#!/bin/bash

progname=`basename $0`

command_line_error()
{

    if [ $# -gt 0 ]
    then
        echo "$progname: $@"
    fi
    echo "run $progname with no arguments for usage"
    return

} # end command_line_error()

if [ $# -eq 0 ]
then
    echo
    echo "usage: $progname ..."
    echo
    echo "XNAT curl helper"
    echo
    echo "url prefixed by XNAT_URI if given"
    echo
    echo "authentication (in order of priority):"
    echo
    echo "    command line -u"
    echo "    session"
    echo "    XNAT_USER, XNAT_PASSWORD/prompt"
    echo "    prompt"
    echo
    echo "xc options:"
    echo
    echo "    --xc-start-session"
    echo "    --xcss"
    echo "    --xc-end-session"
    echo "    --xces"
    echo
    exit 1
fi

credentials=
session_command=
declare -a curl_args
declare -a cred_args
jsessionid=`cat ~/.xcrc 2> /dev/null`

getopt_results=`/opt/local/bin/getopt -n $progname -o ku:X: -l xc-start-session -l xcss -l xc-end-session -l xces -- "$@"`
if [ $? -ne 0 ] ; then command_line_error ; exit 1 ; fi
eval set -- "$getopt_results"

while [ "$1" ]
do
    if [ "$1" == "-k" ]
    then
        curl_args[${#curl_args[@]}]="$1"
    fi
    if [ "$1" == "-u" ]
    then
        shift
        credentials="$1"
    fi
    if [ "$1" == "-X" ]
    then
        curl_args[${#curl_args[@]}]="$1"
        shift
        curl_args[${#curl_args[@]}]="$1"
    fi
    if [ "$1" == "--xc-start-session" -o "$1" = "--xcss" ]
    then
        session_command=start
    fi
    if [ "$1" == "--xc-end-session" -o "$1" = "--xces" ]
    then
        session_command=end
    fi
    if [ "$1" == "--" ]
    then
        shift
        break
    fi
    shift
done

if [ $# -eq 0 ]
then
    if [ -z "$XNAT_URI" ]
    then
        command_line_error "no URI specified"
        exit 1
    fi
    uri="$XNAT_URI"
elif [ $# -eq 1 ]
then
    if [ -n "$XNAT_URI" ]
    then
        uri="$XNAT_URI/$1"
    else
        uri="$1"
    fi
else
    command_line_error "too many non-option arguments"
    exit 1
fi

if [ -n "$credentials" ]
then
    cred_args[0]=-u
    cred_args[1]="$credentials"
elif [ -n "$jsessionid" ]
then
    cred_args[0]=--cookie
    cred_args[1]="JSESSIONID=$jsessionid"
else
    if [ -z "$XNAT_USER" ]
    then
        read -p "User name: " XNAT_USER
    fi
    if [ -z "$XNAT_PASSWORD" ]
    then
        stty -echo
        read -p "Password: " XNAT_PASSWORD
        echo
        stty echo
    fi
    cred_args[0]=-u
    cred_args[1]="$XNAT_USER:$XNAT_PASSWORD"
fi

if [ "$session_command" = "start" ]
then
    jsessionid=`curl -s -S "${curl_args[@]}" "${cred_args[@]}" $uri/data/JSESSION` || exit 1
    echo $jsessionid > ~/.xcrc
    echo session started
elif [ "$session_command" = "end" ]
then
    curl -X DELETE "${curl_args[@]}" "${cred_args[@]}" $uri/data/JSESSION || exit 1
    rm ~/.xcrc
    echo session ended
else
    curl "${curl_args[@]}" "${cred_args[@]}" $uri || exit 1
fi

exit 0

# eof
