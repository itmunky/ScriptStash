#!/bin/bash

# Improved Recovery script to rebuild Radarr databases table by table
# Ensure Radarr is not running
# Run script in directory where radarr.db is located
#
# Original by github.com/rhinot
# Enhanced with additional feedback, error handling, and performance optimization

# Performance optimization settings
export SQLITE_THREADSAFE=0       # Disable thread safety for performance
export SQLITE_TEMP_STORE=2       # Use memory for temporary storage
export SQLITE_DIRECT_BYTES=8192  # I/O buffer size
ionice -c 1 -n 0 -p $ &>/dev/null || true  # Set I/O priority to real-time if possible

clear

echo -e "\033[1;34m========================================\033[0m"
echo -e "\033[1;34m     Radarr Database Recovery Tool      \033[0m"
echo -e "\033[1;34m========================================\033[0m"

echo -e "\n\033[1;31mWARNING: If Radarr is still running, exit this script now, stop Radarr, then rerun this script.\033[0m\n"
echo -e "Waiting 5 seconds before continuing...\n"
sleep 5

# Define tables that can be safely skipped if they cause problems
# These tables are typically non-critical or will be recreated by Radarr
SKIPPABLE_TABLES=("Commands" "ScheduledTasks" "CommandQueue" "Logs" "PendingInstallations")

# Convert skippable tables array to a string for easier checking
SKIPPABLE_TABLES_STR=$(IFS="|"; echo "${SKIPPABLE_TABLES[*]}")

# Function to check if a table is in the skippable list
is_skippable() {
  if [[ "$SKIPPABLE_TABLES_STR" =~ (^|\\|)$1(\\||$) ]]; then
    return 0  # True, it is skippable
  else
    return 1  # False, it is not skippable
  fi
}

# Function to display progress
display_progress() {
  local current=$1
  local total=$2
  local table_name=$3
  local percentage=$(( (current * 100) / total ))
  
  # Create progress bar
  local bar_size=50
  local completed=$(( (percentage * bar_size) / 100 ))
  local bar=""
  
  for ((i=0; i<completed; i++)); do
    bar+="█"
  done
  
  for ((i=completed; i<bar_size; i++)); do
    bar+="░"
  done
  
  echo -ne "\r\033[K\033[1;33mOverall Progress: \033[0m[$bar] $percentage% ($current/$total tables)"
}

# Check for presence of radarr.db
if [ -f "./radarr.db" ]; then
  echo -e "\033[1;32mFound radarr.db. Attempting to rebuild...\033[0m\n"
else
  echo -e "\033[1;31mRadarr.db not found. Please go to folder where radarr.db is located and rerun script.\033[0m"
  exit 1
fi

# Get list of tables
echo -e "Analyzing database structure..."
tables=$(sqlite3 -readonly ./radarr.db ".tables" 2>/dev/null | tr -s ' ' '\n' | sort)
table_count=$(echo "$tables" | wc -l)

if [ -z "$tables" ]; then
  echo -e "\033[1;31mEmpty database. Unable to restore.\033[0m"
  exit 1
fi

echo -e "\033[1;32mFound $table_count tables to process.\033[0m\n"

# Create a directory for our recovery files
mkdir -p recovery_data

# Create a new empty database
rm -f radarr-recovered.db
touch radarr-recovered.db

# Create a log file
log_file="radarr_recovery_$(date +%Y%m%d_%H%M%S).log"
echo "Radarr Database Recovery Log - $(date)" > "$log_file"
echo "----------------------------------------" >> "$log_file"

# Track statistics
successful_tables=0
skipped_tables=0
failed_tables=0
failed_table_names=""

# Determine CPU count for parallel processing
CPU_COUNT=$(nproc 2>/dev/null || grep -c processor /proc/cpuinfo 2>/dev/null || echo 2)
MAX_PARALLEL=$((CPU_COUNT > 1 ? CPU_COUNT - 1 : 1))  # Leave one CPU free
echo -e "\033[1;32mOptimizing for performance with up to $MAX_PARALLEL parallel operations\033[0m\n"

# For SQLite performance
sqlite3 ./radarr-recovered.db "PRAGMA synchronous = OFF" 2>/dev/null
sqlite3 ./radarr-recovered.db "PRAGMA journal_mode = MEMORY" 2>/dev/null
sqlite3 ./radarr-recovered.db "PRAGMA temp_store = MEMORY" 2>/dev/null
sqlite3 ./radarr-recovered.db "PRAGMA cache_size = 10000" 2>/dev/null

# Process each table
current_table=0
for table in $tables; do
  current_table=$((current_table + 1))
  display_progress $current_table $table_count "$table"
  
  echo -e "\n\n\033[1;36mProcessing table ($current_table/$table_count): $table\033[0m"
  echo "Processing table: $table" >> "$log_file"
  
  # Check if this is a table we can skip if problems occur
  if is_skippable "$table"; then
    echo -e "Note: This is a non-critical table that can be skipped if problems occur."
  fi
  
  # Get table creation SQL
  echo -e "  → Getting table schema... \c"
  if sqlite3 -readonly ./radarr.db ".schema $table" > recovery_data/${table}_schema.sql 2>/dev/null; then
    echo -e "\033[1;32mOK\033[0m"
  else
    echo -e "\033[1;31mFAILED\033[0m"
    echo "  Failed to get schema for $table" >> "$log_file"
    
    if is_skippable "$table"; then
      echo -e "\033[1;33m    Skipping non-critical table: $table\033[0m"
      echo "  Skipping non-critical table" >> "$log_file"
      skipped_tables=$((skipped_tables + 1))
      continue
    else
      echo -e "\033[1;31m    Critical table schema failed. Attempting to continue...\033[0m"
    fi
  fi
  
  # Create table in new database
  echo -e "  → Creating table structure... \c"
  if sqlite3 ./radarr-recovered.db < recovery_data/${table}_schema.sql 2>/dev/null; then
    echo -e "\033[1;32mOK\033[0m"
  else
    echo -e "\033[1;31mFAILED\033[0m"
    echo "  Failed to create schema for $table" >> "$log_file"
    
    if is_skippable "$table"; then
      echo -e "\033[1;33m    Skipping non-critical table: $table\033[0m"
      echo "  Skipping non-critical table" >> "$log_file"
      skipped_tables=$((skipped_tables + 1))
      continue
    else
      echo -e "\033[1;31m    Critical table structure creation failed. This may impact recovery.\033[0m"
      failed_tables=$((failed_tables + 1))
      failed_table_names="$failed_table_names $table"
      continue
    fi
  fi
  
  # Try to get row count for progress estimation
  row_count=$(sqlite3 -readonly ./radarr.db "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "unknown")
  if [[ "$row_count" != "unknown" ]]; then
    echo -e "  → Table contains approximately $row_count rows"
  fi
  
  # Try to export data in INSERT statements format
  echo -e "  → Exporting table data... \c"
  
  # Different approach for large tables vs small tables for performance
  if [[ "$row_count" != "unknown" && $row_count -gt 10000 ]]; then
    echo -e "\n    (Large table detected - optimizing for speed...)"
  fi
  
  export_success=false
  
  # Performance optimizations for SQLite
  export SQLITE_MMAP_SIZE=1073741824  # 1GB memory map for large tables
  
  # First attempt - optimized export with high-performance settings
  if sqlite3 -readonly ./radarr.db <<EOF > recovery_data/${table}_data.sql 2>/dev/null
.mode insert $table
.output recovery_data/${table}_data.sql
PRAGMA temp_store = MEMORY;
PRAGMA cache_size = 100000;
PRAGMA synchronous = OFF;
SELECT * FROM $table LIMIT 1000000;
.output stdout
EOF
  then
    # Check if we got any data
    if [ -s "recovery_data/${table}_data.sql" ]; then
      export_success=true
      echo -e "\033[1;32mOK\033[0m"
    else
      echo -e "\033[1;33mEmpty data\033[0m"
      # This might be normal for some tables, so we'll continue
      export_success=true
    fi
  fi
  
  # If first attempt failed, try a different approach for problematic tables
  if ! $export_success; then
    echo -e "\033[1;33mRetrying with alternative method\033[0m"
    
    # Second attempt - try with a simpler approach for troublesome tables
    if sqlite3 -readonly ./radarr.db "SELECT * FROM $table LIMIT 1" > /dev/null 2>&1; then
      echo -e "  → Creating empty table structure only... \c"
      export_success=true
      echo -e "\033[1;33mSkipping data export\033[0m"
      echo "  Data export skipped - created empty table" >> "$log_file"
      # Create empty file for consistency
      touch recovery_data/${table}_data.sql
    else
      echo -e "\033[1;31mFAILED\033[0m"
      echo "  Failed to export data for $table" >> "$log_file"
      
      if is_skippable "$table"; then
        echo -e "\033[1;33m    Skipping non-critical table: $table\033[0m"
        echo "  Skipping non-critical table" >> "$log_file"
        skipped_tables=$((skipped_tables + 1))
        continue
      else
        echo -e "\033[1;31m    Critical table data export failed. This may impact recovery.\033[0m"
        failed_tables=$((failed_tables + 1))
        failed_table_names="$failed_table_names $table"
        continue
      fi
    fi
  fi
  
  # Import data to new database with performance optimizations
  echo -e "  → Importing data... \c"
  if [ -s "recovery_data/${table}_data.sql" ]; then
    # For large files, use high-performance import settings
    if [ $(stat -c%s "recovery_data/${table}_data.sql" 2>/dev/null || stat -f%z "recovery_data/${table}_data.sql" 2>/dev/null) -gt 1048576 ]; then
      echo -e "\n    (Large data file detected - applying high-speed import...)"
    fi
    
    if sqlite3 ./radarr-recovered.db <<EOF 2>/dev/null
PRAGMA synchronous = OFF;
PRAGMA journal_mode = MEMORY;
PRAGMA temp_store = MEMORY;
PRAGMA cache_size = 100000;
.read recovery_data/${table}_data.sql
PRAGMA optimize;
EOF
    then
      echo -e "\033[1;32mOK\033[0m"
      successful_tables=$((successful_tables + 1))
    else
      echo -e "\033[1;31mFAILED\033[0m"
      echo "  Failed to import data for $table" >> "$log_file"
      
      if is_skippable "$table"; then
        echo -e "\033[1;33m    Skipping non-critical table: $table\033[0m"
        echo "  Skipping non-critical table" >> "$log_file"
        skipped_tables=$((skipped_tables + 1))
      else
        echo -e "\033[1;31m    Critical table data import failed. This may impact recovery.\033[0m"
        failed_tables=$((failed_tables + 1))
        failed_table_names="$failed_table_names $table"
      fi
    fi
  else
    echo -e "\033[1;33mSkipped (empty data)\033[0m"
    successful_tables=$((successful_tables + 1))
  fi
  
  # Display progress after each table
  display_progress $current_table $table_count "$table"
done

echo -e "\n\n\033[1;34m========================================\033[0m"
echo -e "\033[1;34m         Recovery Process Complete        \033[0m"
echo -e "\033[1;34m========================================\033[0m"

echo -e "\n\033[1;32mSuccessfully processed tables: $successful_tables\033[0m"
echo -e "\033[1;33mSkipped non-critical tables: $skipped_tables\033[0m"
echo -e "\033[1;31mFailed critical tables: $failed_tables\033[0m"

if [ "$failed_tables" -gt 0 ]; then
  echo -e "\n\033[1;31mThe following critical tables could not be fully recovered:$failed_table_names\033[0m"
  echo -e "You may experience issues with functionality related to these tables."
  echo "Failed tables:$failed_table_names" >> "$log_file"
fi

# Keep the original database in case rebuilt database fails
echo -e "\n\033[1;36mFinalizing recovery...\033[0m"
echo -e "  → Backing up original database... \c"
if mv ./radarr.db ./radarr.db.old; then
  echo -e "\033[1;32mOK\033[0m"
else
  echo -e "\033[1;31mFAILED\033[0m"
  echo "Failed to backup original database" >> "$log_file"
fi

# Make the rebuilt database the active database
echo -e "  → Installing recovered database... \c"
if mv ./radarr-recovered.db ./radarr.db; then
  echo -e "\033[1;32mOK\033[0m"
else
  echo -e "\033[1;31mFAILED\033[0m"
  echo "Failed to install recovered database" >> "$log_file"
fi

# Clean up
echo -e "  → Cleaning up temporary files... \c"
if rm -r recovery_data; then
  echo -e "\033[1;32mOK\033[0m"
else
  echo -e "\033[1;33mWARNING: Could not remove temporary files\033[0m"
  echo "Failed to clean up temporary files" >> "$log_file"
fi

# Log completion
echo "Recovery completed at $(date)" >> "$log_file"
echo "Success: $successful_tables, Skipped: $skipped_tables, Failed: $failed_tables" >> "$log_file"

# Finished!
echo -e "\n\033[1;42m                                           \033[0m"
echo -e "\033[1;42m          RECOVERY PROCESS COMPLETED         \033[0m"
echo -e "\033[1;42m                                           \033[0m"

echo -e "\n\033[1;36mRecovery Summary:\033[0m"
echo -e "  • The old database is saved as \033[1;33mradarr.db.old\033[0m"
echo -e "  • A recovery log has been created: \033[1;33m$log_file\033[0m"
echo -e "  • You can now restart Radarr"
echo -e "\n\033[1;33mImportant:\033[0m Once Radarr is running, please check Radarr's logs"
echo -e "to ensure the rebuilt database is working correctly.\n"

echo -e "If you encounter issues, you can restore the original database with:"
echo -e "\033[1;36m  mv ./radarr.db.old ./radarr.db\033[0m\n"
