#!//bin/bash

# Directory of script (why is this so hard?)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Make logs directory if it doesn't exist
mkdir -p $DIR/logs

# Run forever as daemon, keeping logs
forever start -a -l $DIR/logs/forever.log -o $DIR/logs/out.log -e $DIR/logs/error.log --minUptime=10000 --spinSleepTime=10000 -c coffee $DIR/runProduction.coffee
