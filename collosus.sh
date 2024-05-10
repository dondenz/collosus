#!/bin/bash
set -e

# Check if all tools are installed
required_tools=("assetfinder" "dig" "findomain" "httpx" "knockpy" "subfinder" "xsubfind3r" "whatweb")
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
touch subdomains.txt
subfinder -silent -d $TARGET_DOMAIN | tee -a subdomains.txt
assetfinder --subs-only $TARGET_DOMAIN | tee -a subdomains.txt
findomain -t $TARGET_DOMAIN | tee -a subdomains.txt
xsubfind3r -d $TARGET_DOMAIN | tee -a subdomains.txt
touch tmp.txt
curl --silent --insecure --tcp-fastopen --tcp-nodelay "https://rapiddns.io/subdomain/$TARGET_DOMAIN?full=1#result" | grep "<td><a" | cut -d '"' -f 2 | grep http | cut -d '/' -f3 | sed 's/#results//g' | sort -u >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay "http://web.archive.org/cdx/search/cdx?url=*.$TARGET_DOMAIN/*&output=text&fl=original&collapse=urlkey" | sed -e 's_https*://__' -e "s/\/.*//" | sort -u >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://crt.sh/?q=%.$TARGET_DOMAIN&group=none  | grep -oP "\<TD\>\K.*\.$TARGET_DOMAIN" | sed -e 's/\<BR\>/\n/g' | grep -oP "\K.*\.$TARGET_DOMAIN" | sed -e 's/[\<|\>]//g' | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN"  >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://crt.sh/?q=%.%.$TARGET_DOMAIN | grep -oP "\<TD\>\K.*\.$TARGET_DOMAIN" | sed -e 's/\<BR\>/\n/g' | sed -e 's/[\<|\>]//g' | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://crt.sh/?q=%.%.%.$TARGET_DOMAIN | grep "$TARGET_DOMAIN" | cut -d '>' -f2 | cut -d '<' -f1 | grep -v " " | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" | sort -u >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://crt.sh/?q=%.%.%.%.$TARGET_DOMAIN | grep "$TARGET_DOMAIN" | cut -d '>' -f2 | cut -d '<' -f1 | grep -v " " | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" |  sort -u >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://otx.alienvault.com/api/v1/indicators/domain/$TARGET_DOMAIN/passive_dns | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://www.threatcrowd.org/searchApi/v2/domain/report/?domain=$TARGET_DOMAIN | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://api.hackertarget.com/hostsearch/?q=$TARGET_DOMAIN | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://certspotter.com/api/v0/certs?domain=$TARGET_DOMAIN | grep  -o '\[\".*\"\]' | sed -e 's/\[//g' | sed -e 's/\"//g' | sed -e 's/\]//g' | sed -e 's/\,/\n/g' | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://spyse.com/target/domain/$TARGET_DOMAIN | grep -E -o "button.*>.*\.$TARGET_DOMAIN\/button>" |  grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://tls.bufferover.run/dns?q=$TARGET_DOMAIN | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://dns.bufferover.run/dns?q=.$TARGET_DOMAIN | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://urlscan.io/api/v1/search/?q=$TARGET_DOMAIN | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay -X POST https://synapsint.com/report.php -d "name=http%3A%2F%2F$TARGET_DOMAIN" | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://jldc.me/anubis/subdomains/$TARGET_DOMAIN | grep -Po "((http|https):\/\/)?(([\w.-]*)\.([\w]*)\.([A-z]))\w+" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://sonar.omnisint.io/subdomains/$TARGET_DOMAIN | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://riddler.io/search/exportcsv?q=pld:$TARGET_DOMAIN | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay -X POST https://suip.biz/?act=amass -d "url=$TARGET_DOMAIN&Submit1=Submit"  | grep $TARGET_DOMAIN | cut -d ">" -f 2 | awk 'NF' >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay -X POST https://suip.biz/?act=subfinder -d "url=$TARGET_DOMAIN&Submit1=Submit"  | grep $TARGET_DOMAIN | cut -d ">" -f 2 | awk 'NF' >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay "https://securitytrails.com/list/apex_domain/$TARGET_DOMAIN" | grep -Po "((http|https):\/\/)?(([\w.-]*)\.([\w]*)\.([A-z]))\w+" | grep ".$TARGET_DOMAIN" | sort -u >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://certificatedetails.com/$TARGET_DOMAIN | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" | sed -e 's/^.//g' | sort -u >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://columbus.elmasy.com/report/$TARGET_DOMAIN | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" | sort -u >> tmp.txt &
curl --silent --insecure --tcp-fastopen --tcp-nodelay https://webscout.io/lookup/$TARGET_DOMAIN | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" | sort -u >> tmp.txt &
wait
cat tmp.txt | sed -e "s/\*\.$TARGET_DOMAIN//g" | sed -e "s/^\..*//g" | grep -o -E "[a-zA-Z0-9._-]+\.$TARGET_DOMAIN" | sort -u | tee -a subdomains.txt
rm -f tmp.txt
cp subdomains.txt knockpy.txt
knockpy --file knockpy.txt --recon | tee -a subdomains.txt
rm -f knockpy.txt

# HTTPX Filtering
cat subdomains.txt | httpx -fc 200,400,401,403,500,501 | tee -a alive.txt
cat alive.txt | sort -u | tee -a sorted_subdomains.txt
rm -f alive.txt
rm -f subdomains.txt

# Web scanning
whatweb -i "sorted_subdomains.txt" --log-json="whatweb.json"

# DNS reconnaissance
dig $TARGET_DOMAIN any +short | tee -a dns.txt
nslookup -type=any $TARGET_DOMAIN | tee -a dns.txt
host -t any $TARGET_DOMAIN | tee -a dns.txt

# Whois
whois $TARGET_DOMAIN | tee -a whois.txt

echo "Recon completed! Results saved in $output_dir. Work in progress. Press CTRL+C to exit"  