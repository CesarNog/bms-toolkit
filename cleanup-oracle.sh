#!/bin/bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



GETOPT_MANDATORY="ora-version:,yes-i-am-sure"
GETOPT_OPTIONAL="ora-role-separation:,inventory-file:,help"
GETOPT_LONG="${GETOPT_MANDATORY},${GETOPT_OPTIONAL}"
GETOPT_SHORT="yh"

YESIAMSURE=0
VALIDATE=0
INVENTORY_FILE=inventory

ORA_VERSION="${ORA_VERSION}"
ORA_VERSION_PARAM='^(19\.3\.0\.0\.0|18\.0\.0\.0\.0|12\.2\.0\.1\.0|12\.1\.0\.2\.0|11\.2\.0\.4\.0|ALL)$'

ORA_ROLE_SEPARATION="${ORA_ROLE_SEPARATION:-TRUE}"
ORA_ROLE_SEPARATION_PARAM="^(TRUE|FALSE)$"

options=$(getopt --longoptions "$GETOPT_LONG" --options "$GETOPT_SHORT" -- "$@")

[ $? -eq 0 ] || {
       echo "Invalid options provided: $*"
       exit 1
}

eval set -- "$options"

while true; do
    case "$1" in
    --yes-i-am-sure|-y)
        YESIAMSURE=1
        ;;
    --ora-version)
        ORA_VERSION="$2"
        if [[ ${ORA_VERSION} = "19" ]]   ; then ORA_VERSION="19.3.0.0.0"; fi
        if [[ ${ORA_VERSION} = "18" ]]   ; then ORA_VERSION="18.0.0.0.0"; fi
        if [[ ${ORA_VERSION} = "12" ]]   ; then ORA_VERSION="12.2.0.1.0"; fi
        if [[ ${ORA_VERSION} = "12.2" ]] ; then ORA_VERSION="12.2.0.1.0"; fi
        if [[ ${ORA_VERSION} = "12.1" ]] ; then ORA_VERSION="12.1.0.2.0"; fi
        if [[ ${ORA_VERSION} = "11" ]]   ; then ORA_VERSION="11.2.0.4.0"; fi
        shift;
        ;;
    --inventory-file)
	INVENTORY_FILE="$2"
        shift;
	;;
    --ora-role-separation)
        ORA_ROLE_SEPARATION="$2"
        shift;
        ;;
    --help|-h)
        echo -e "\tUsage: `basename $0` "
        echo $GETOPT_MANDATORY|sed 's/,/\n/g'|sed 's/:/ <value>/'|sed 's/\(.\+\)/\t  --\1/'
        echo $GETOPT_OPTIONAL |sed 's/,/\n/g'|sed 's/:/ <value>/'|sed 's/\(.\+\)/\t  [ --\1 ]/'
        exit 2
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

shopt -s nocasematch

# Mandatory options
if [ "${ORA_VERSION}" = "" ]; then
    echo "Please specify the oracle release with --ora-version"
    exit 2
fi

if [ $YESIAMSURE -eq 0 ]; then
    echo "Parameter --yes-i-am-sure needs to be specified for cleanup to run"
    exit 2
fi

[[ ! "$ORA_VERSION" =~ $ORA_VERSION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-version: $ORA_VERSION"
    exit 1
}
[[ ! "$ORA_ROLE_SEPARATION" =~ $ORA_ROLE_SEPARATION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-role-separation: $ORA_ROLE_SEPARATION"
    exit 1
}

export ORA_ROLE_SEPARATION
export ORA_VERSION

echo -e "Running with parameters from command line or environment variables:\n"
set | egrep '^(ORA_|INVENTORY_)' | grep -v '_PARAM='
echo

ANSIBLE_PARAMS="-i ${INVENTORY_FILE}"
ANSIBLE_EXTRA_PARAMS="${*}"


echo "Ansible params: ${ANSIBLE_EXTRA_PARAMS}"

if [ $VALIDATE -eq 1 ]; then
    echo "Exiting because of --validate"
    exit;
fi

export ANSIBLE_NOCOWS=1

ANSIBLE_PLAYBOOK=`which ansible-playbook 2> /dev/null`
if [ $? -ne 0 ]; then
    echo "Ansible executable not found in path"
    exit 3
else
    echo "Found Ansible at $ANSIBLE_PLAYBOOK"
fi

# exit on any error from the following scripts
set -e

for PLAYBOOK in brute-cleanup.yml ; do
    ANSIBLE_COMMAND="${ANSIBLE_PLAYBOOK} ${ANSIBLE_PARAMS} ${ANSIBLE_EXTRA_PARAMS} ${PLAYBOOK}"
    echo
    echo "Running Ansible playbook: ${ANSIBLE_COMMAND}"
    eval ${ANSIBLE_COMMAND}
done

exit 0;
