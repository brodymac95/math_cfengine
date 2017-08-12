#!/usr/bin/env bash
# Author: Ben Roose <ben.roose@wichita.edu>
# Original Prototype Author: Nick Anderson <nick@cmdln.org>
# Brief: Generate unique password hashes for each Incoming host in CFEngine
#        lastseen database
# Description: Uses cf-key to generate hashed root passwords for hosts
#              and store in /var/cfengine/host_by_key subdirectories
#              CFEngine can access hashed passwords using server side
#              expansion of the connection.key variable.

## NOT PRODUCTION VERSION!! NEED TO CHANGE DEFAULT_PASSWORD_FILE VAR

## PARAMETERS ##

HASHED_OUTPUT_DIR="/var/cfengine/host_by_key/"
HASHED_OUTPUT_FILENAME="root.hash"

STORE_PLAINTEXT=false
PLAINTEXT_OUTPUT_DIR="${HASHED_OUTPUT_DIR}"
PLAINTEXT_OUTPUT_FILENAME="root.plaintext"

DEFAULT_PASSWORD_FILE="[DELETED FOR SECURITY]"
REQUIRED_FILE_PERMS=400

# hashing algorithms: 1=MD5, 2 = Blowfish, 5 = SHA-256, 6 = SHA512
DEFAULT_HASHING_ALGORITHM=6

## FUNCTIONS

stored_file_mode() {
    # WARNING: storing passwords in plaintext file is dangerous, ensure secure permissions on file!

    _file="$DEFAULT_PASSWORD_FILE"

    if [ -e "$_file" ] ; then
	if [ $(stat -c %a "$_file") == $REQUIRED_FILE_PERMS ] ; then	
	    while IFS='' read -r _line || [[ -n "$_line" ]]; do
		PASSWORD="$_line"
	    done <"$_file"

	    _algo=$DEFAULT_HASHING_ALGORITHM
	    export _algo=$_algo
	    
	    unset _line

	else
	    echo "$_file does not have correct permissions of $REQUIRED_FILE_PERMS"
	    exit 1
	fi
    else
	echo "$_file not found"
	exit 1
    fi
}


user_interactive_mode() {
    # Turn off echo in POSIX compliant way so we don't see the password as typed in
    unset PASSWORD
    unset CHARCOUNT

    echo -n "Enter password: "

    stty -echo

    CHARCOUNT=0
    while IFS= read -p "$PROMPT" -r -s -n 1 CHAR
    do
	# Enter - accept password
	if [[ $CHAR == $'\0' ]] ; then
	    break
	fi
	# Backspace
	if [[ $CHAR == $'\177' ]] ; then
	    if [ $CHARCOUNT -gt 0 ] ; then
		CHARCOUNT=$((CHARCOUNT-1))
		PROMPT=$'\b \b'
		PASSWORD="${PASSWORD%?}"
	    else
		PROMPT=''
	    fi
	else
	    CHARCOUNT=$((CHARCOUNT+1))
	    PROMPT='*'
	    PASSWORD+="$CHAR"
	fi
    done

    stty echo

    # What hashing algorithm do I support?
    # for EL5 consider `authconfig --passalgo=sha512 --update`
    #HASHING_ALGORITHM=$(authconfig --test | awk '/hashing/ { print $NF } ')
    #echo $HASHING_ALGORITHM

    printf "
1. MD5 (Default RHEL 5)
2. Blowfish
5. SHA-256
6. SHA-512

Please choose a valid password hasing algorithm [1|2|5|6]"
    while [[ ! ${_algo} =~ ^[1256]+$ ]]; do
	echo "Please enter a valid selection: "
	read _algo
    done
    export _algo=$_algo

}

#########################################################################################################

build_host_list() {
    # Host identifiers to generate host list from unique cfe connection keys
    # Data could also be sourced from a simple file or API call to CFEngine Enterprise Mission Portal

    # By ppkey sha/md5
    HOSTS=$(cf-key -s | awk '/Incoming/ { print $NF }')

    # Simple: Unqualified host name $(sys.uqhost)
    # HOSTS=(host001 host002 host003)

}

#########################################################################################################

generate_hashes() {
    #HOST_COUNT=${#HOSTS[@]} : This does not work, counts only 1 line. Alternative counting using wc below
    HOST_COUNT=$(wc -w <<< "$HOSTS")

    echo "Generating unique password hashes for all 'Incoming' hosts that are present in the lastseen database"
    echo "Note: By default hosts not seen within 7 days are purged from the lastseen database."

    echo "Host Count: $HOST_COUNT"
    echo "$HOSTS"
    COUNT=1
    for each in $HOSTS; do
	echo "Generating Unique Hash for $each"

	mkdir -p $HASHED_OUTPUT_DIR/$each &> /dev/null
	export _salt=$(openssl rand 1000 | strings | grep -io [0-9A-Za-z\.\/] | head -n 16 | tr -d '\n' )
	export _password=$PASSWORD

	echo $(perl -e 'print crypt("$ENV{'_password'}","\$$ENV{'_algo'}\$"."$ENV{'_salt'}"."\$")') > ${HASHED_OUTPUT_DIR}/${each}/$HASHED_OUTPUT_FILENAME && echo Wrote hash for ${each} to ${HASHED_OUTPUT_DIR}/${each}/${HASHED_OUTPUT_FILENAME} && COUNT=$((COUNT+1))
	# Useful if you want to store the plaintext version for reference

	if [ "${STORE_PLAINTEXT}" = true ]; then
	    echo "$PASSWORD" > ${PLAINTEXT_OUTPUT_DIR}/${each}/${PLAINTEXT_OUTPUT_FILENAME}
	fi
    done

    # clean up variables after generating all hashes
    unset _password
    unset PASSWORD
    unset _salt

    echo "Generated $COUNT unique password hashes in $HASHED_OUTPUT_DIR of $HOST_COUNT hosts seen in lastseen database."
}

#########################################################################################################

# MAIN: DEFINE USE CASES TO CALL FUNCTIONS
case "${1}" in
    file)
	stored_file_mode
	build_host_list
	generate_hashes
	;;

    interactive)
	user_interactive_mode
	build_host_list
	generate_hashes
	;;

    *)
        echo "Please specify:
file = use default file for hashing password: $DEFAULT_PASSWORD_FILE with perms $REQUIRED_FILE_PERMS
interactive = CLI prompt for password and hashing algorithm"
	exit 1
	;;
esac

#########################################################################################################
