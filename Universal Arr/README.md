# Universal *arr Scripts

This folder contains scripts that work across all *arr applications for media automation.

## universal_arr_recovery.sh

### Description

This universal script helps with recovering SQLite databases across all popular *arr applications. It automatically detects which application you're working with and provides targeted recovery for corrupted databases. Common error you see in the logs is "Database disk image is malformed".

**Supported Applications:**
- 🎵 **Lidarr** (Music Management)
- 🎬 **Radarr** (Movie Management) 
- 📚 **Readarr** (Book Management)
- 📺 **Sonarr** (TV Show Management)
- 🎥 **Whisparr** (Adult Video Management)

### Key Features

- **🔍 Auto-Detection**: Automatically identifies which *arr database(s) are present
- **🎯 Application-Aware**: Provides specific guidance and handling for each application
- **⚡ High Performance**: Optimized for speed with multi-core processing and memory utilization
- **🛡️ Smart Recovery**: Intelligently handles corrupted tables with fallback methods
- **📊 Progress Tracking**: Real-time progress bar and detailed status updates
- **📝 Comprehensive Logging**: Creates detailed logs for troubleshooting
- **🎨 User-Friendly Interface**: Color-coded output and contextual information

### How to Use It

#### One-Liner Installation (Recommended)

You can run the `universal_arr_recovery.sh` script directly from the repository by navigating to the directory where your database file is located (e.g., "radarr.db", "sonarr.db", etc.) and use the following command:

```bash
curl -L https://raw.githubusercontent.com/itmunky/ScriptStash/main/Universal-arr/universal_arr_recovery.sh | bash
```

#### Manual Installation

1. Save the script to a file:
    ```bash
    wget https://raw.githubusercontent.com/itmunky/ScriptStash/main/Universal-arr/universal_arr_recovery.sh
    ```

2. Make it executable:
    ```bash
    chmod +x universal_arr_recovery.sh
    ```

3. **Stop your *arr application completely** (this is crucial!)

4. Navigate to the directory containing your database file:
    ```bash
    # Examples of common database locations:
    cd ~/.config/radarr/     # Radarr
    cd ~/.config/sonarr/     # Sonarr  
    cd ~/.config/lidarr/     # Lidarr
    cd ~/.config/readarr/    # Readarr
    cd ~/.config/whisparr/   # Whisparr
    ```

5. Run the script:
    ```bash
    ./universal_arr_recovery.sh
    ```

### What the Script Does

1. **Detection Phase**: Scans for *arr database files and identifies the application(s)
2. **Selection Phase**: If multiple databases are found, prompts you to choose which to recover
3. **Analysis Phase**: Examines the database structure and identifies recoverable tables
4. **Recovery Phase**: Systematically rebuilds the database table by table with optimization
5. **Finalization Phase**: Creates backups, installs the recovered database, and provides post-recovery guidance

### Performance Improvements

The script includes several performance optimizations:

- **Multi-Core Processing**: Utilizes available CPU cores for faster processing
- **Memory Optimization**: Uses RAM for temporary storage and caching
- **I/O Priority**: Sets high I/O priority for database operations
- **SQLite Tuning**: Applies performance-oriented database settings
- **Large Table Handling**: Special optimizations for tables with many records

**Performance Results**: Recovery times have been reduced from hours to minutes in most cases (e.g., a large Radarr database that previously took 2 hours now completes in ~6 minutes).

### Application-Specific Features

#### 🎵 Lidarr (Music)
- Prioritizes Artists, Albums, Tracks, and TrackFiles tables
- Handles music metadata and release information
- Provides music library-specific recovery tips

#### 🎬 Radarr (Movies) 
- Focuses on Movies, MovieFiles, and Collections tables
- Preserves movie metadata and alternative titles
- Offers movie library-specific guidance

#### 📚 Readarr (Books)
- Emphasizes Books, Authors, and BookFiles tables
- Maintains series and edition information
- Provides book library-specific advice

#### 📺 Sonarr (TV Shows)
- Prioritizes Series, Episodes, and EpisodeFiles tables
- Handles season and episode metadata
- Offers TV library-specific recommendations

#### 🎥 Whisparr (Adult Videos)
- Manages Movies, MovieFiles, and Collections tables
- Preserves video metadata and collections
- Provides video library-specific guidance

### Safety Features

- **Automatic Backups**: Creates `.old` backup of original database before replacement
- **Non-Critical Table Skipping**: Safely skips problematic non-essential tables
- **Rollback Instructions**: Provides clear instructions to restore original database if needed
- **Comprehensive Logging**: Creates detailed logs for review and troubleshooting

### Troubleshooting

If you encounter issues:

1. **Check the log file**: The script creates a timestamped log file with detailed information
2. **Verify application is stopped**: Ensure your *arr application is completely shut down
3. **Check disk space**: Ensure sufficient space for temporary files and database copies
4. **Review failed tables**: Non-critical table failures usually don't affect core functionality

To restore your original database if needed:
```bash
mv ./your-app.db.old ./your-app.db
```

### System Requirements

- **Operating System**: Linux, macOS, or Windows with WSL
- **Dependencies**: `sqlite3`, `bash` (version 4.0+)
- **Disk Space**: At least 2x the size of your database file
- **Memory**: Recommended 1GB+ RAM for optimal performance

### Acknowledgments

This universal script is built upon the excellent foundation created by [rhinot](https://gist.githubusercontent.com/rhinot/a0d81818250eaad0e39ce930f4cd04c4). The original Radarr-specific version was enhanced and expanded to support all *arr applications with significant performance improvements and user experience enhancements.

Special thanks to the *arr community for feedback and testing that helped make this universal solution possible!

### Contributing

Found a bug or have a suggestion? Please open an issue or submit a pull request. This script benefits from community input and real-world testing across different *arr setups.

### License

This script is provided as-is under the same license terms as the original work. Use at your own risk and always maintain backups of your data.