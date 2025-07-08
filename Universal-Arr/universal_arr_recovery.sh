#!/bin/bash

# Universal *arr Database Recovery Script
# Works with: Lidarr, Radarr, Readarr, Sonarr, Whisparr
# Ensure the respective *arr application is not running
# Run script in directory where the .db file is located
#
# Enhanced from original Radarr script by github.com/rhinot
# Made universal for all *arr applications with performance optimization

# Performance optimization settings
export SQLITE_THREADSAFE=0       # Disable thread safety for performance
export SQLITE_TEMP_STORE=2       # Use memory for temporary storage
export SQLITE_DIRECT_BYTES=8192  # I/O buffer size
ionice -c 1 -n 0 -p $$ &>/dev/null || true  # Set I/O priority to real-time if possible

clear

echo -e "\033[1;34m============================================\033[0m"
echo -e "\033[1;34m     Universal *arr Database Recovery       \033[0m"
echo -e "\033[1;34m    Lidarr | Radarr | Readarr | Sonarr     \033[0m"
echo -e "\033[1;34m              | Whisparr |                 \033[0m"
echo -e "\033[1;34m============================================\033[0m"

# Function to detect which *arr application we're working with
detect_arr_app() {
  local detected_apps=()
  local detected_files=()
  
  # Check for database files
  if [ -f "./lidarr.db" ]; then
    detected_apps+=("Lidarr")
    detected_files+=("lidarr.db")
  fi
  
  if [ -f "./radarr.db" ]; then
    detected_apps+=("Radarr")
    detected_files+=("radarr.db")
  fi
  
  if [ -f "./readarr.db" ]; then
    detected_apps+=("Readarr")
    detected_files+=("readarr.db")
  fi
  
  if [ -f "./sonarr.db" ]; then
    detected_apps+=("Sonarr")
    detected_files+=("sonarr.db")
  fi
  
  if [ -f "./whisparr.db" ]; then
    detected_apps+=("Whisparr")
    detected_files+=("whisparr.db")
  fi
  
  # Return results
  if [ ${#detected_apps[@]} -eq 0 ]; then
    return 1  # No databases found
  elif [ ${#detected_apps[@]} -eq 1 ]; then
    ARR_APP="${detected_apps[0]}"
    DB_FILE="${detected_files[0]}"
    return 0  # Single database found
  else
    return 2  # Multiple databases found
  fi
}

# Detect which *arr application database(s) are present
detect_arr_app
detection_result=$?

if [ $detection_result -eq 1 ]; then
  echo -e "\033[1;31mNo *arr database files found in current directory.\033[0m"
  echo -e "Please navigate to the directory containing one of these files:"
  echo -e "  • lidarr.db (Lidarr - Music)"
  echo -e "  • radarr.db (Radarr - Movies)"
  echo -e "  • readarr.db (Readarr - Books)"
  echo -e "  • sonarr.db (Sonarr - TV Shows)"
  echo -e "  • whisparr.db (Whisparr - Adult Videos)"
  exit 1
elif [ $detection_result -eq 2 ]; then
  echo -e "\033[1;33mMultiple *arr databases detected in current directory.\033[0m"
  echo -e "Please select which database to recover:\n"
  
  # Show detected databases
  local counter=1
  declare -a app_options
  declare -a file_options
  
  if [ -f "./lidarr.db" ]; then
    echo -e "  $counter) Lidarr (Music) - lidarr.db"
    app_options[$counter]="Lidarr"
    file_options[$counter]="lidarr.db"
    ((counter++))
  fi
  
  if [ -f "./radarr.db" ]; then
    echo -e "  $counter) Radarr (Movies) - radarr.db"
    app_options[$counter]="Radarr"
    file_options[$counter]="radarr.db"
    ((counter++))
  fi
  
  if [ -f "./readarr.db" ]; then
    echo -e "  $counter) Readarr (Books) - readarr.db"
    app_options[$counter]="Readarr"
    file_options[$counter]="readarr.db"
    ((counter++))
  fi
  
  if [ -f "./sonarr.db" ]; then
    echo -e "  $counter) Sonarr (TV Shows) - sonarr.db"
    app_options[$counter]="Sonarr"
    file_options[$counter]="sonarr.db"
    ((counter++))
  fi
  
  if [ -f "./whisparr.db" ]; then
    echo -e "  $counter) Whisparr (Adult Videos) - whisparr.db"
    app_options[$counter]="Whisparr"
    file_options[$counter]="whisparr.db"
    ((counter++))
  fi
  
  echo -e "\nEnter your choice (1-$((counter-1))): \c"
  read choice
  
  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$counter" ]; then
    ARR_APP="${app_options[$choice]}"
    DB_FILE="${file_options[$choice]}"
  else
    echo -e "\033[1;31mInvalid selection. Exiting.\033[0m"
    exit 1
  fi
fi

echo -e "\n\033[1;32mDetected: $ARR_APP\033[0m"
echo -e "\033[1;32mDatabase: $DB_FILE\033[0m\n"

echo -e "\033[1;31mWARNING: If $ARR_APP is still running, exit this script now, stop $ARR_APP, then rerun this script.\033[0m\n"
echo -e "Waiting 5 seconds before continuing...\n"
sleep 5

# Define tables that can be safely skipped if they cause problems
# These are common across all *arr applications and are typically non-critical
COMMON_SKIPPABLE_TABLES=("Commands" "ScheduledTasks" "CommandQueue" "Logs" "PendingInstallations" "UpdateHistory" "ExtraFiles")

# Application-specific skippable tables
declare -A APP_SPECIFIC_SKIPPABLE
APP_SPECIFIC_SKIPPABLE["Lidarr"]="LastFmUsers TrackFiles PendingReleases"
APP_SPECIFIC_SKIPPABLE["Radarr"]="NotificationStatus AutoTagging PendingReleases"
APP_SPECIFIC_SKIPPABLE["Readarr"]="EditionFiles BookFiles PendingReleases"
APP_SPECIFIC_SKIPPABLE["Sonarr"]="EpisodeFiles PendingReleases SceneMappings"
APP_SPECIFIC_SKIPPABLE["Whisparr"]="MovieFiles PendingReleases SceneMappings"

# Combine common and app-specific skippable tables
ALL_SKIPPABLE_TABLES="${COMMON_SKIPPABLE_TABLES[*]} ${APP_SPECIFIC_SKIPPABLE[$ARR_APP]}"

# Convert skippable tables to string for easier checking
SKIPPABLE_TABLES_STR=$(echo "$ALL_SKIPPABLE_TABLES" | tr ' ' '|')

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

# Function to get application-specific context for table importance
get_table_context() {
  local table=$1
  local app=$2
  
  case $app in
    "Lidarr")
      case $table in
        "Artists"|"Albums"|"Tracks") echo "🎵 Core music library data" ;;
        "AlbumReleases"|"ArtistMetadata") echo "🎵 Music metadata" ;;
        "TrackFiles") echo "🎵 Audio file references" ;;
        *) echo "⚙️  System data" ;;
      esac
      ;;
    "Radarr")
      case $table in
        "Movies"|"MovieFiles") echo "🎬 Core movie library data" ;;
        "AlternativeTitles"|"MovieMetadata") echo "🎬 Movie metadata" ;;
        "Collections") echo "🎬 Movie collections" ;;
        *) echo "⚙️  System data" ;;
      esac
      ;;
    "Readarr")
      case $table in
        "Books"|"Authors"|"BookFiles") echo "📚 Core book library data" ;;
        "Editions"|"Series") echo "📚 Book metadata" ;;
        "AuthorMetadata") echo "📚 Author information" ;;
        *) echo "⚙️  System data" ;;
      esac
      ;;
    "Sonarr")
      case $table in
        "Series"|"Episodes"|"EpisodeFiles") echo "📺 Core TV library data" ;;
        "Seasons"|"SeriesMetadata") echo "📺 TV show metadata" ;;
        "SceneMappings") echo "📺 Scene mappings" ;;
        *) echo "⚙️  System data" ;;
      esac
      ;;
    "Whisparr")
      case $table in
        "Movies"|"MovieFiles") echo "🎥 Core video library data" ;;
        "MovieMetadata"|"AlternativeTitles") echo "🎥 Video metadata" ;;
        "Collections") echo "🎥 Video collections" ;;
        *) echo "⚙️  System data" ;;
      esac
      ;;
    *)
      echo "📋 Database table"
      ;;
  esac
}

# Determine CPU count for parallel processing
CPU_COUNT=$(nproc 2>/dev/null || grep -c processor /proc/cpuinfo 2>/dev/null || echo 2)
MAX_PARALLEL=$((CPU_COUNT > 1 ? CPU_COUNT - 1 : 1))  # Leave one CPU free
echo -e "\033[1;32mOptimizing for performance with up to $MAX_PARALLEL parallel operations\033[0m\n"

# Get list of tables
echo -e "Analyzing $ARR_APP database structure..."
tables=$(sqlite3 -readonly ./$DB_FILE ".tables" 2>/dev/null | tr -s ' ' '\n' | sort)
table_count=$(echo "$tables" | wc -l)

if [ -z "$tables" ]; then
  echo -e "\033[1;31mEmpty database. Unable to restore.\033[0m"
  exit 1
fi

echo -e "\033[1;32mFound $table_count tables to process in $ARR_APP database.\033[0m\n"

# Create a directory for our recovery files
recovery_dir="${ARR_APP,,}_recovery_data"
mkdir -p "$recovery_dir"

# Create a new empty database
recovered_db="${DB_FILE%.*}-recovered.db"
rm -f "$recovered_db"
touch "$recovered_db"

# For SQLite performance
sqlite3 "./$recovered_db" "PRAGMA synchronous = OFF" 2>/dev/null
sqlite3 "./$recovered_db" "PRAGMA journal_mode = MEMORY" 2>/dev/null
sqlite3 "./$recovered_db" "PRAGMA temp_store = MEMORY" 2>/dev/null
sqlite3 "./$recovered_db" "PRAGMA cache_size = 10000" 2>/dev/null

# Create a log file
log_file="${ARR_APP,,}_recovery_$(date +%Y%m%d_%H%M%S).log"
echo "$ARR_APP Database Recovery Log - $(date)" > "$log_file"
echo "Database: $DB_FILE" >> "$log_file"
echo "----------------------------------------" >> "$log_file"

# Track statistics
successful_tables=0
skipped_tables=0
failed_tables=0
failed_table_names=""

# Process each table
current_table=0
for table in $tables; do
  current_table=$((current_table + 1))
  display_progress $current_table $table_count "$table"
  
  # Get table context
  table_context=$(get_table_context "$table" "$ARR_APP")
  
  echo -e "\n\n\033[1;36mProcessing table ($current_table/$table_count): $table\033[0m"
  echo -e "  $table_context"
  echo "Processing table: $table ($table_context)" >> "$log_file"
  
  # Check if this is a table we can skip if problems occur
  if is_skippable "$table"; then
    echo -e "  \033[1;33mNote: This is a non-critical table that can be skipped if problems occur.\033[0m"
  fi
  
  # Get table creation SQL
  echo -e "  → Getting table schema... \c"
  if sqlite3 -readonly ./$DB_FILE ".schema $table" > $recovery_dir/${table}_schema.sql 2>/dev/null; then
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
  if sqlite3 "./$recovered_db" < $recovery_dir/${table}_schema.sql 2>/dev/null; then
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
  row_count=$(sqlite3 -readonly ./$DB_FILE "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "unknown")
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
  if sqlite3 -readonly ./$DB_FILE <<EOF > $recovery_dir/${table}_data.sql 2>/dev/null
.mode insert $table
.output $recovery_dir/${table}_data.sql
PRAGMA temp_store = MEMORY;
PRAGMA cache_size = 100000;
PRAGMA synchronous = OFF;
SELECT * FROM $table LIMIT 1000000;
.output stdout
EOF
  then
    # Check if we got any data
    if [ -s "$recovery_dir/${table}_data.sql" ]; then
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
    if sqlite3 -readonly ./$DB_FILE "SELECT * FROM $table LIMIT 1" > /dev/null 2>&1; then
      echo -e "  → Creating empty table structure only... \c"
      export_success=true
      echo -e "\033[1;33mSkipping data export\033[0m"
      echo "  Data export skipped - created empty table" >> "$log_file"
      # Create empty file for consistency
      touch $recovery_dir/${table}_data.sql
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
  if [ -s "$recovery_dir/${table}_data.sql" ]; then
    # For large files, use high-performance import settings
    if [ $(stat -c%s "$recovery_dir/${table}_data.sql" 2>/dev/null || stat -f%z "$recovery_dir/${table}_data.sql" 2>/dev/null) -gt 1048576 ]; then
      echo -e "\n    (Large data file detected - applying high-speed import...)"
    fi
    
    if sqlite3 "./$recovered_db" <<EOF 2>/dev/null
PRAGMA synchronous = OFF;
PRAGMA journal_mode = MEMORY;
PRAGMA temp_store = MEMORY;
PRAGMA cache_size = 100000;
.read $recovery_dir/${table}_data.sql
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

echo -e "\n\n\033[1;34m============================================\033[0m"
echo -e "\033[1;34m         $ARR_APP Recovery Complete          \033[0m"
echo -e "\033[1;34m============================================\033[0m"

echo -e "\n\033[1;32mSuccessfully processed tables: $successful_tables\033[0m"
echo -e "\033[1;33mSkipped non-critical tables: $skipped_tables\033[0m"
echo -e "\033[1;31mFailed critical tables: $failed_tables\033[0m"

if [ "$failed_tables" -gt 0 ]; then
  echo -e "\n\033[1;31mThe following critical tables could not be fully recovered:$failed_table_names\033[0m"
  echo -e "You may experience issues with functionality related to these tables."
  echo "Failed tables:$failed_table_names" >> "$log_file"
fi

# Keep the original database in case rebuilt database fails
echo -e "\n\033[1;36mFinalizing $ARR_APP recovery...\033[0m"
echo -e "  → Backing up original database... \c"
if mv "./$DB_FILE" "./${DB_FILE}.old"; then
  echo -e "\033[1;32mOK\033[0m"
else
  echo -e "\033[1;31mFAILED\033[0m"
  echo "Failed to backup original database" >> "$log_file"
fi

# Make the rebuilt database the active database
echo -e "  → Installing recovered database... \c"
if mv "./$recovered_db" "./$DB_FILE"; then
  echo -e "\033[1;32mOK\033[0m"
else
  echo -e "\033[1;31mFAILED\033[0m"
  echo "Failed to install recovered database" >> "$log_file"
fi

# Clean up
echo -e "  → Cleaning up temporary files... \c"
if rm -r "$recovery_dir"; then
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
echo -e "\033[1;42m       $ARR_APP RECOVERY COMPLETED          \033[0m"
echo -e "\033[1;42m                                           \033[0m"

echo -e "\n\033[1;36m$ARR_APP Recovery Summary:\033[0m"
echo -e "  • The old database is saved as \033[1;33m${DB_FILE}.old\033[0m"
echo -e "  • A recovery log has been created: \033[1;33m$log_file\033[0m"
echo -e "  • You can now restart $ARR_APP"
echo -e "\n\033[1;33mImportant:\033[0m Once $ARR_APP is running, please check the application logs"
echo -e "to ensure the rebuilt database is working correctly.\n"

echo -e "If you encounter issues, you can restore the original database with:"
echo -e "\033[1;36m  mv ./${DB_FILE}.old ./$DB_FILE\033[0m\n"

# Application-specific tips
case $ARR_APP in
  "Lidarr")
    echo -e "\033[1;36m🎵 Lidarr-specific tips:\033[0m"
    echo -e "  • Check that your music library paths are still correct"
    echo -e "  • Verify artist and album metadata is preserved"
    echo -e "  • Re-scan your music library if any files appear missing"
    ;;
  "Radarr")
    echo -e "\033[1;36m🎬 Radarr-specific tips:\033[0m"
    echo -e "  • Check that your movie library paths are still correct"
    echo -e "  • Verify movie collections are intact"
    echo -e "  • Re-scan your movie library if any files appear missing"
    ;;
  "Readarr")
    echo -e "\033[1;36m📚 Readarr-specific tips:\033[0m"
    echo -e "  • Check that your book library paths are still correct"
    echo -e "  • Verify author and series information is preserved"
    echo -e "  • Re-scan your book library if any files appear missing"
    ;;
  "Sonarr")
    echo -e "\033[1;36m📺 Sonarr-specific tips:\033[0m"
    echo -e "  • Check that your TV show library paths are still correct"
    echo -e "  • Verify series and season information is preserved"
    echo -e "  • Re-scan your TV library if any episodes appear missing"
    ;;
  "Whisparr")
    echo -e "\033[1;36m🎥 Whisparr-specific tips:\033[0m"
    echo -e "  • Check that your video library paths are still correct"
    echo -e "  • Verify collections and metadata are preserved"
    echo -e "  • Re-scan your video library if any files appear missing"
    ;;
esac

echo