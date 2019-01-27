#!/usr/bin/env bash

#
# Copies all records from the specified source table to the specified destination table
#
# Example usage:
#   $ ./copy-table-rows tasks.production tasks.staging us-east-1 myprofile

set -e

src_tbl_name=$1
dst_tbl_name=$2
aws_region=$3
aws_profile=$4

if [ "$src_tbl_name" == "" ]; then
  echo "Source table argument missing"
  exit 1
fi

if [ "$dst_tbl_name" == "" ]; then
  echo "Destination table argument missing"
  exit 1
fi

if [ "$src_tbl_name" == "$dst_tbl_name" ]; then
  echo "Source and destination tables cannot be the same"
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

page_size=25
page=1

echo "Copying all rows from $src_tbl_name to $dst_tbl_name, $page_size rows at a time"
while : ; do
    # Pagination docs: https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-pagination.html
    echo "  Scanning page $page, up to $page_size records in $src_tbl_name"
    scan_result=$(aws dynamodb scan $aws_profile_arg --region=$aws_region \
        --table-name $src_tbl_name \
        --page-size $page_size \
        --max-items $page_size \
        $starting_token)

    put_req_json=$(echo $scan_result | jq '[.Items | .[] | { PutRequest: { Item: . } }]')
    rec_count=$(echo $put_req_json | jq 'length')
    next_token=$(echo "$scan_result" | jq '.NextToken' -r)
    starting_token="--starting-token $next_token"

    echo "  Writing $rec_count records to temporary file"
    tmp_file_name="${dst_tbl_name}.$page.json"
    echo '{
        "'${dst_tbl_name}'": '"${put_req_json}"'
    }' > "${dst_tbl_name}.$page.json"

    echo "  Writing $rec_count to $dst_tbl_name"
    aws dynamodb batch-write-item \
        --region=us-east-1 \
        --profile hvh \
        --request-items file://"$tmp_file_name" \
    | sed 's/^/  /' # Indent output

    echo "  Deleting temporary file"
    rm "$tmp_file_name"

    [[ "$next_token" != "null" ]] || break
    ((page++))
done

echo "Copied all rows from $src_tbl_name to $dst_tbl_name"