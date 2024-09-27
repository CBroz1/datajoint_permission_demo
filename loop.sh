#!/bin/bash

# Paths to the files
OPTIONS_FILE="options.cnf"
MYSQL_CONF="mysqld.cnf"
TEMP_FILE="temp_options.cnf"

# Ensure options.cnf exists and is not empty
if [[ ! -s $OPTIONS_FILE ]]; then
    echo "The options.cnf file is empty or does not exist. Exiting..."
    exit 1
fi

# Loop through each line in options.cnf
while true; do
    # Read the first line from options.cnf
    first_line=$(head -n 1 "$OPTIONS_FILE")

    # Check if the first line is empty (end of file)
    if [[ -z "$first_line" ]]; then
        echo "No more lines in options.cnf. Exiting loop."
        break
    fi

    # Append the first line to mysqld.cnf
    echo "$first_line" >> "$MYSQL_CONF"
    echo -ne "Appended    $first_line                                        \r"

    # Run the script
    ./run.sh
    exit_code=$?

    # Check exit code
    if [[ $exit_code -eq 0 ]]; then
        echo "RUN success $first_line                                          "
    else
        echo "RUN FAIL    $first_line                                          "
        # Comment out the newly added line in mysqld.cnf
        sed -i '' -e "\$s/^/# /" "$MYSQL_CONF" 2> /dev/null || true
    fi

    # Remove the first line from options.cnf (update options.cnf for the next iteration)
    tail -n +2 "$OPTIONS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$OPTIONS_FILE"
done


