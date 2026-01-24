#!/bin/bash
infile="${1:-/tmp/domainlist.txt}"
outfile="${2:-/tmp/domainlist_mx.csv}"

# Validate input file and required tools.
if [[ ! -r "$infile" ]]; then
  echo "Error: cannot read input file: $infile" >&2
  exit 1
fi
if ! command -v dig >/dev/null 2>&1; then
  echo "Error: dig is not available in PATH." >&2
  exit 1
fi
if command -v timeout >/dev/null 2>&1; then
  use_timeout=1
else
  use_timeout=0
fi

# Ensure the output directory exists and is writable.
out_dir="$(dirname "$outfile")"
if [[ ! -d "$out_dir" || ! -w "$out_dir" ]]; then
  echo "Error: output directory is not writable: $out_dir" >&2
  exit 1
fi

# Accumulate CSV rows and track the maximum number of columns.
rows=()
max_fields=1
while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip empty or whitespace-only lines.
  [[ -z "${line//[[:space:]]/}" ]] && continue
  # Skip comment lines (allowing leading whitespace).
  line="${line#"${line%%[![:space:]]*}"}"
  [[ "${line:0:1}" == "#" ]] && continue

  # Use the first field as the domain token and trim a trailing dot.
  read -r domain _ <<< "$line"
  domain="${domain%.}"
  [[ -z "$domain" ]] && continue

  # Query MX records with an optional timeout.
  if (( use_timeout )); then
    mx_output="$(timeout 10 dig "$domain" MX +noall +answer 2>/dev/null)"
  else
    mx_output="$(dig "$domain" MX +noall +answer 2>/dev/null)"
  fi

  # Parse unique MX targets for the requested domain.
  mapfile -t mx_records < <(
    printf '%s\n' "$mx_output" |
      awk -v d="$domain" '$4=="MX" && $1 ~ ("^" d "\\.?$") {print $NF}' |
      sed 's/\.$//' |
      sort -u
  )

  # Build the CSV row and update the maximum field count.
  row="$domain"
  if (( ${#mx_records[@]} > 0 )); then
    for mx in "${mx_records[@]}"; do
      row+=",${mx}"
    done
  fi
  rows+=("$row")
  field_count=$(( ${#mx_records[@]} + 1 ))
  if (( field_count > max_fields )); then
    max_fields=$field_count
  fi
done < "$infile"

# Emit the CSV header and all rows, then write to stdout and file.
header="DOMAIN"
for ((i=1; i<max_fields; i++)); do
  header+=",MX_RECORD_${i}"
done
{
  printf '%s\n' "$header"
  printf '%s\n' "${rows[@]}"
} | tee "$outfile"
