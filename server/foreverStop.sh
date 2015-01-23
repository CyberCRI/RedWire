#!//bin/bash

# Directory of script (why is this so hard?)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

pushd .
cd $DIR

forever stop runProduction.coffee

popd 
