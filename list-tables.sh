#!/usr/bin/env bash

#
# Lists all DynamoDB tables in the specified environment
#
# Example use: 
#   $ ./list-tables.sh contains region profile
#
# You can pass "." as the contains arg to return all tables


set -e

contains=$1
aws_region=$2
aws_profile=$3

# Default to listing all tables
if [ "$contains" != "." ] && [ "$contains" != "" ]; then
  contains_arg=' | contains("'$contains'.")'
fi

# Default to us-east-1 region
if [ "$aws_region" == "" ]; then
  aws_region="us-east-1"
fi

# Set profile arg, if specified
if [ "$aws_profile" != "" ]; then
  aws_profile_arg="--profile $aws_profile"
fi

aws dynamodb list-tables --region=$aws_region $aws_profile_arg \
| jq '.TableNames | .[] | select(.'"$contains_arg"')' -r