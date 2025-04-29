# Radarr Scripts

This folder contains scripts related to Radarr.

## improved_radarr_recovery.sh

### Description

This script helps with recovering a the SQLite Database. Error you see in the logs is "Database disk image is malformed"

### How to Use It

1. Save this script to a file (e.g., `improved_radarr_recovery.sh`).
2. Make it executable:
    ```bash
    chmod +x improved_radarr_recovery.sh
    ```
3. Make sure Radarr is completely stopped.
4. Run it in the directory where your `radarr.db` file is located:
    ```bash
    ./improved_radarr_recovery.sh
    ```
