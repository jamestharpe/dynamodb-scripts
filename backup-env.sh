#!/usr/bin/env bash
set -e

#
# Backs up all dynamodb tables with names containing the specified value
#
# Example:
#   ./backup-env.sh production us-east-1 myprofile
#

scripts_path=$(dirname $0)

contains=$1
aws_region=$2
aws_profile=$3
wait=$4

echo "Creating backups of $contains tables"
for src_tbl_name in $("$scripts_path"/list-tables.sh $contains $aws_region $aws_profile); do 
  src_tbl_name=$(echo $src_tbl_name | xargs) # Trim whitespace
  echo "  Backing up $src_tbl_name as part of $contains backup"
  "$scripts_path"/backup-table.sh $src_tbl_name $aws_region $aws_profile $wait \
  | sed 's/^/  /' # Indent output
done

if [ "$wait" == "wait" ]; then
  echo "Backups of $contains tables completed"
else
  echo "Backups of $contains tables initiated"
fi