#!/bin/bash

# Check if a file is provided as an argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <file_with_numbers>"
    exit 1
fi

file="${1}"

# Check if the file exists
if [ ! -f "${file}" ] || [ ! -r "${file}" ]; then
    echo "File not found!"
    exit 1
fi

# Extract the leading digits, count their occurrences, and sort
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
done < "$file"

# Expected frequencies for Benford's Law
declare -A benford_frequencies=( ["1"]=30.1 ["2"]=17.6 ["3"]=12.5 ["4"]=9.7 ["5"]=7.9 ["6"]=6.7 ["7"]=5.8 ["8"]=5.1 ["9"]=4.6 )

# Output the observed frequencies, expected frequencies, and compute the Chi-Square statistic
echo -e "Digit\tObserved(%)\tExpected(%)\tChi-Square"

chi_square=0

# Temporary file for gnuplot data
plot_data=$(mktemp)

for digit in {1..9}; do
    observed_count=${digit_counts[$digit]:-0}
    observed_percentage=$(awk "BEGIN { printf \"%.2f\", ($observed_count / $total_numbers) * 100 }")
    expected_percentage=${benford_frequencies[$digit]}
    
    # Calculate the expected count based on Benford's Law
    expected_count=$(awk "BEGIN { printf \"%.2f\", ($expected_percentage / 100) * $total_numbers }")
    
    # Calculate the Chi-Square component for this digit
    if (( $(echo "$expected_count > 0" | bc -l) )); then
        chi_square_component=$(awk "BEGIN { printf \"%.4f\", (($observed_count - $expected_count) ^ 2) / $expected_count }")
        chi_square=$(awk "BEGIN { printf \"%.4f\", $chi_square + $chi_square_component }")
    else
        chi_square_component="N/A"
    fi
    
    echo -e "$digit\t$observed_percentage\t\t$expected_percentage\t\t$chi_square_component"
    
    # Store data for gnuplot (digit observed expected)
    echo -e "$digit $observed_percentage $expected_percentage" >> "$plot_data"
done

# Output the total Chi-Square statistic
echo -e "\nChi-Square Statistic: $chi_square"

# Provide a basic interpretation (degrees of freedom = 9 - 1 = 8 for Benford's Law test)
critical_value=15.51 # Chi-square critical value at 8 degrees of freedom, 0.05 significance level
if (( $(echo "$chi_square < $critical_value" | bc -l) )); then
    echo "The dataset follows Benford's Law (Chi-Square <$critical_value)."
else
    echo "The dataset does NOT follow Benford's Law (Chi-Square >=$critical_value)."
fi

# Gnuplot command to generate a dumb terminal graph
gnuplot -persist <<-EOF
    set terminal dumb size 120,40
    set title "Benford's Law Distribution"
    set key left top
    set xlabel "Digit"
    set ylabel "Percentage"
    set yrange [0:*]
    set style data histograms
    set style histogram clustered gap 1
    set style fill solid 0.5 border -1
    set boxwidth 0.9
    plot "$plot_data" using 2:xtic(1) title "Observed" linecolor rgb "blue", \
         '' using 3 title "Expected" linecolor rgb "red"
EOF

# Clean up the temporary file
/bin/rm "$plot_data"
