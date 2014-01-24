#!//bin/bash

# Directory of script (why is this so hard?)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

forever stop $DIR/runProduction.coffee
