#!/bin/bash

# per the following $0 doesn't work reliably when the script is sourced:
# https://stackoverflow.com/questions/35006457/choosing-between-0-and-bash-source.  But 
# in some cases I've found BASH_SOURCE hasn't been set correctly.
declare SCRIPT=$0
if [[ "$SCRIPT" == "/bin/bash" ]]; then
    SCRIPT="${BASH_SOURCE}"
fi

if [[ -z "${SCRIPT}" ]]; then
    echo "BASH_SOURCE: ${BASH_SOURCE}, 0 is: $0"
    echo "Failed to find the running name of the script, you need to set DEMO_HOME manually"
fi

export DEMO_HOME=$( cd "$(dirname "${SCRIPT}")/.." ; pwd -P )

echo "Welcome to kubernetes tutorial"