#!/bin/bash

# Check if all tools are installed
for tool in gau; do
    if ! command -v $tool &> /dev/null; then
        echo "$tool is not installed. Please install it to proceed." >&2
        exit 1
    fi
done

# Input domain
read -p "Enter the domain to fetch URLs: " domain

# Create a directory to store results
mkdir -p "$domain"_results
results_path="${domain}_results"

# Using Waybackmachine
echo "Fetching Waybackmachine URLs..."
curl -sX GET "http://web.archive.org/cdx/search/cdx?url=*.$domain/*&output=text&fl=original&collapse=urlkey" | tee $results_path/waybackurls-$domain.txt

# Using GAU
echo "Fetching GAU URLs..."
gau --subs $domain | tee $results_path/gau-$domain.txt

# Aggregating results   
echo "Aggregating results into one file..."
cat $results_path/*-$domain.txt > $results_path/urls.txt

# Cleanup: Removing individual results files
rm $results_path/*-$domain.txt

echo "Done fetching $domain URLs. Check urls.txt in the '$results_path' directory for aggregated results"