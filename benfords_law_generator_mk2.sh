#!/bin/bash

# Parse input arguments
low_end=$1
top_end=$2
decimal_places=$3
num_output=$4

# Check if the correct number of arguments are provided
if [ $# -ne 4 ]; then
    echo "Usage: $0 <low_end> <top_end> <decimal_places> <num_output>"
    exit 1
fi

# Ensure low_end and top_end are positive numbers
if ! [[ $low_end =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! [[ $top_end =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$low_end <= 0" | bc -l) )) || (( $(echo "$top_end <= 0" | bc -l) )); then
    echo "Error: low_end and top_end must be positive numbers."
    exit 1
fi

# Ensure decimal_places and num_output are positive integers
if ! [[ $decimal_places =~ ^[0-9]+$ ]] || ! [[ $num_output =~ ^[0-9]+$ ]]; then
    echo "Error: decimal_places and num_output must be positive integers."
    exit 1
fi

# Temporary file to store generated numbers
temp_file=$(mktemp)

# Calculate logarithmic bounds
min_log=$(echo "l($low_end)" | bc -l 2>/dev/null)
max_log=$(echo "l($top_end)" | bc -l 2>/dev/null)

export min_log max_log decimal_places

# Ensure logarithmic bounds are computed successfully
if [ -z "$min_log" ] || [ -z "$max_log" ]; then
    echo "Error: Failed to compute logarithmic bounds. Check input values."
    exit 1
fi

# Function to generate a Benford-distributed number
generate_benford_number() {
    local min_log="$1"
    local max_log="$2"
    local decimal_places="$3"
    local top_end="$4"
    local low_end="$5"

    # Generate a random logarithmic value that follows Benford's Law
    rand_fraction=$(echo "scale=10; $RANDOM / 32767" | bc -l)
    rand_log=$(echo "scale=10; $min_log + ($max_log - $min_log) * $rand_fraction" | bc -l)

    # Convert the logarithmic value back to a number
    benford_number=$(echo "scale=10; e($rand_log)" | bc -l)

    # Ensure the number stays within bounds (this should rarely trigger)
    if (( $(echo "$benford_number < $low_end" | bc -l) )); then
        benford_number=$low_end
    elif (( $(echo "$benford_number > $top_end" | bc -l) )); then
        benford_number=$top_end
    fi

    # Format the number to the specified number of decimal places
    printf "%.*f\n" "$decimal_places" "$benford_number"
}

export -f generate_benford_number

# Function to generate numbers
generate_numbers() {
    # Use parallel processing to speed up the number generation, and save output to the temp file
    seq 1 "$num_output" | xargs -n 1 -P "$(nproc)" bash -c 'generate_benford_number "$@"' _ "$min_log" "$max_log" "$decimal_places" "$top_end" "$low_end" > "$temp_file"
}

# Function to validate numbers against Benford's Law
validate_numbers() {
    # Reset digit counts
    declare -A digit_counts
    total_numbers=0

    # Read through the file line by line
    while read -r number; do
        # Extract the first non-zero digit
        first_digit=$(echo "$number" | grep -o '[1-9]' | head -n 1)
        if [ -n "$first_digit" ]; then
            digit_counts[$first_digit]=$((digit_counts[$first_digit] + 1))
            total_numbers=$((total_numbers + 1))
        fi
    done < "$temp_file"

    # Expected frequencies for Benford's Law
    declare -A benford_frequencies=( ["1"]=30.1 ["2"]=17.6 ["3"]=12.5 ["4"]=9.7 ["5"]=7.9 ["6"]=6.7 ["7"]=5.8 ["8"]=5.1 ["9"]=4.6 )

    # Compute the Chi-Square statistic
    chi_square=0
    for digit in {1..9}; do
        observed_count=${digit_counts[$digit]:-0}
        expected_percentage=${benford_frequencies[$digit]}
        
        # Calculate the expected count based on Benford's Law
        expected_count=$(awk "BEGIN { printf \"%.2f\", ($expected_percentage / 100) * $total_numbers }")
        
        # Calculate the Chi-Square component for this digit
        if (( $(echo "$expected_count > 0" | bc -l) )); then
            chi_square_component=$(awk "BEGIN { printf \"%.4f\", (($observed_count - $expected_count) ^ 2) / $expected_count }")
            chi_square=$(awk "BEGIN { printf \"%.4f\", $chi_square + $chi_square_component }")
        fi
    done

    # Check if the dataset follows Benford's Law
    critical_value=15.51 # Chi-square critical value at 8 degrees of freedom, 0.05 significance level
    if (( $(echo "$chi_square < $critical_value" | bc -l) )); then
        return 0 # Success
    else
        return 1 # Failure
    fi
}

# Loop until numbers follow Benford's Law
while true; do
    generate_numbers   # Generate numbers and store in $temp_file
    if validate_numbers; then  # Validate the numbers from $temp_file
        cat "$temp_file"  # Output the valid numbers
        break
    fi
done

# Clean up
/bin/rm "$temp_file"
