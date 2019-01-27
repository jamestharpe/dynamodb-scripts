#!/usr/bin/env bash
set -e

#
# Creates a backup of the specified DynamoDB table
#
# Example usage:
#   $ ./backup-table table.name us-east-1 myprofile wait

src_tbl_name=$1
aws_region=$2
aws_profile=$3
wait=$4

if [ "$src_tbl_name" == "" ]; then
  echo "Source table argument missing"
  exit 1
fi

# Default to us-east-1 region
if [ "$aws_region" == "" ]; then
  aws_region="us-east-1"
fi

# Set profile arg, if specified
if [ "$aws_profile" != "" ]; then
  aws_profile_arg="--profile $aws_profile"
fi

# Create the backup
echo "Creating backup of $src_tbl_name table"
backup_arn=$(aws dynamodb create-backup \
  $aws_profile_arg \
  --region=$aws_region \
  --table-name $src_tbl_name \
  --backup-name $src_tbl_name-$(date '+%Y%m%d_%H%M%S') \
| jq '.BackupDetails.BackupArn' -r)

if [ "$backup_arn" == "" ]; then
  echo "No backup ARN retrieved, backup failed"
  exit 1
fi

if [ "$wait" == "wait" ]; then
  echo "Monitoring backup status of $backup_arn"
  backup_status="CREATING"
  while [ "$backup_status" = "CREATING" ] # CREATING, AVAILABLE, DELETED
  do
    echo "... Waiting for backup of $src_tbl_name to complete, backup_status="$backup_status
    backup_status=$(aws dynamodb describe-backup \
      --backup-arn $backup_arn \
      --region=$aws_region \
      $aws_profile_arg \
    | jq '.BackupDescription.BackupDetails.BackupStatus' -r)

    sleep 2
  done

  if [ "$backup_status" != "AVAILABLE" ]; then
    echo "Backup failure! Backup status is not equal to AVAILABLE: "$backup_status
    exit 1
  fi

  echo "Backup is now available at $backup_arn"
else
  echo "Backup initiated. Check status by running: "
  echo "  aws dynamodb describe-backup --backup-arn $backup_arn --region=$aws_region $aws_profile_arg"
fi

echo $backup_arn