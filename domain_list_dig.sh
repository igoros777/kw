#!/bin/bash
list="${1:-}"

# Validate input and required tooling.
if [[ -z "$list" ]]; then
  echo "Usage: $0 <domain_list_file>" >&2
  exit 2
fi
if [[ ! -r "$list" ]]; then
  echo "Error: cannot read input file: $list" >&2
  exit 1
fi
if ! command -v dig >/dev/null 2>&1; then
  echo "Error: dig is not available in PATH." >&2
  exit 1
fi

# Normalize a domain token by trimming a trailing dot.
normalize_domain() {
  local domain="$1"
  printf '%s' "${domain%.}"
}

# Get the base domain (last two labels) used for grouping.
get_base_domain() {
  local domain="$1"
  local -a parts=()
  local count=0
  IFS='.' read -r -a parts <<< "$domain"
  count=${#parts[@]}
  if (( count >= 2 )); then
    printf '%s.%s' "${parts[count-2]}" "${parts[count-1]}"
  else
    printf '%s' "$domain"
  fi
}

# Build suffix labels (TLD, SLD, 3LD, 4LD) for CSV output.
build_suffixes() {
  local domain="$1"
  local -a parts=()
  local -a suffixes=()
  local suffix=""
  IFS='.' read -r -a parts <<< "$domain"
  for ((idx=${#parts[@]}-1; idx>=0 && ${#suffixes[@]}<4; idx--)); do
    if [[ -z "$suffix" ]]; then
      suffix="${parts[idx]}"
    else
      suffix="${parts[idx]}.${suffix}"
    fi
    suffixes+=("$suffix")
  done
  s1ld="${suffixes[0]:-}"
  s2ld="${suffixes[1]:-}"
  s3ld="${suffixes[2]:-}"
  s4ld="${suffixes[3]:-}"
}

# Load domains and group them by base domain to avoid rescanning the file.
declare -A base_to_domains=()
while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip empty or whitespace-only lines.
  [[ -z "${line//[[:space:]]/}" ]] && continue
  # Use the first field as the domain token.
  read -r domain _ <<< "$line"
  # Skip comment lines.
  [[ "${domain:0:1}" == "#" ]] && continue
  domain="$(normalize_domain "$domain")"
  [[ -z "$domain" ]] && continue
  base="$(get_base_domain "$domain")"
  base_to_domains["$base"]+="${domain}"$'\n'
done < "$list"

# Emit CSV header before any records.
echo "Record,TLD,SLD,3LD,4LD,Type,TTL,Value"

# Process each base domain in sorted order.
mapfile -t base_domains < <(printf '%s\n' "${!base_to_domains[@]}" | sort -u)
for base in "${base_domains[@]}"; do
  # Deduplicate domains within the base domain group.
  mapfile -t domains < <(printf '%s' "${base_to_domains[$base]}" | sort -u)
  for domain in "${domains[@]}"; do
    [[ -z "$domain" ]] && continue

    # Compute suffix labels for output columns.
    build_suffixes "$domain"

    # Resolve a nameserver for the domain, falling back to default resolver.
    ns_server="$(dig ns "$domain" +noall +answer 2>/dev/null | awk 'NR==1 {print $NF}' | sed 's/\.$//')"
    if [[ -n "$ns_server" ]]; then
      dig_target=("@$ns_server")
    else
      dig_target=()
    fi

    # Query records and emit CSV rows for each answer.
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      t=$(awk '{print $4}' <<< "$line")
      r=$(awk '{print $1}' <<< "$line")
      ttl=$(awk '{print $2}' <<< "$line")
      v=$(awk '{print $NF}' <<< "$line" | sed 's/\.$//')
      echo "${domain:-none},${s1ld:-none},${s2ld:-none},${s3ld:-none},${s4ld:-none},${t:-none},${ttl:-none},${v:-none}"
    done < <(dig "${dig_target[@]}" "$domain" -t any +noall +answer 2>/dev/null)
  done
done
