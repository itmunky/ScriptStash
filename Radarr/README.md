# Radarr Scripts

This folder contains scripts related to Radarr.

## improved_radarr_recovery.sh

### Description

This script helps with recovering a the SQLite Database. Error you see in the logs is "Database disk image is malformed"

### How to Use It

You can run the `improved_radarr_recovery.sh` script directly from the repository by navigating to the directory where the "radarr.db" is located and use the following one-liner command:

```bash
curl -L https://raw.githubusercontent.com/itmunky/ScriptStash/main/Radarr/improved_radarr_recovery.sh | bash
```
Or Manually with the below

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

This process will take some time - Mine ran for just shy of 2 hours, But at the end i started Radarr and no more error messages. 
![image](https://github.com/user-attachments/assets/dc4bde95-474d-48fa-bfed-6077a3d02a44)


### Acknowledgments

This script is built on top of the original work by [rhinot](https://gist.githubusercontent.com/rhinot/a0d81818250eaad0e39ce930f4cd04c4/raw). Many thanks for their valuable contribution! 
