#!/bin/bash
set -e

# Check if all tools are installed
required_tools=("assetfinder" "subfinder" "httprobe" "nuclei" "xsubfind3r" "findomain" "amass" "whatweb" "ffuf" "gobuster" "knockpy")
missing_tools=()
for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        missing_tools+=("$tool")
    fi
done

if [ ${#missing_tools[@]} -gt 0 ]; then
    echo "The following tools are missing: ${missing_tools[*]}"
    echo "Please install them to proceed."
    exit 1
fi

# Validate user input
read -p "Enter the target domain: " TARGET_DOMAIN

while true; do
  if [[ $TARGET_DOMAIN =~ ^https?:// ]]; then
    echo "Please enter only the domain name without http(s)://"
    read -p "Enter the target domain: " TARGET_DOMAIN
  else
    break
  fi
done

# Output directory
read -p "Enter output directory (press Enter for default): " output_dir
output_dir=${output_dir:-"${domain}_results"}

# Create output directory
mkdir -p "$output_dir"
cd "$output_dir"

# Subdomain enumeration
subfinder -silent -d $TARGET_DOMAIN | tee -a subdomains.txt
assetfinder --subs-only $TARGET_DOMAIN | tee -a subdomains.txt
findomain -t $TARGET_DOMAIN | tee -a subdomains.txt
amass enum -d $TARGET_DOMAIN -timeout 1 | tee -a subdomains.txt

#amass enum -active -d $TARGET_DOMAIN -ip | tee -a amass_ips.txt | awk '{print $1}' | tee -a subdomains.txt
xsubfind3r -d $TARGET_DOMAIN | tee -a subdomains.txt

#jsubfinder search -u $TARGET_DOMAIN -c | tee -a subdomains.txt
gobuster dns -d $TARGET_DOMAIN -w "../wordlists/w.txt" --wildcard | tee -a subdomains.txt

# Knockpy
cp subdomains.txt op.txt
knockpy --file op.txt --recon | tee -a subdomains.txt
rm op.txt

# HTTProbe
cat subdomains.txt | httprobe | tee -a alive.txt
cat alive.txt | sort -u | tee -a sorted_subdomains.txt
rm alive.txt

# DNS reconnaissance
dig $TARGET_DOMAIN any +short | tee -a dns.txt
nslookup -type=any $TARGET_DOMAIN | tee -a dns.txt
host -t any $TARGET_DOMAIN | tee -a dns.txt
curl -s https://certspotter.com/api/v0/certs?domain=$TARGET_DOMAIN 2>/dev/null | jq '.[].dns_names[]' | sed 's/\"//g' | sed 's/\*\.//g' | sort -u | grep -i $TARGET_DOMAIN > certspotter.txt
curl -ss https://dns.bufferover.run/dns?q=$TARGET_DOMAIN | jq '.FDNS_A[]' | sed 's/^\".*.,//g' | sed 's/\"$//g' | sort -u | grep -i $TARGET_DOMAIN > bufferover.txt
curl -s https://crt.sh/\?q\=\%.$TARGET_DOMAIN\&output\=json | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u > ~crt.txt
nuclei -l sorted_subdomains.txt -t "../templates/dns" -c 60 | tee -a dns.txt

# Whois
whois $TARGET_DOMAIN | tee -a whois.txt

# Webpage scanning
nmap -sV -oA nmap-web $TARGET_DOMAIN
whatweb -i "sorted_subdomains.txt" --log-json="whatweb.json"

echo "Recon completed. Results saved in $output_dir. Work in progress. Press CTRL+C to exit"