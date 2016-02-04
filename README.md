# Scripts
A collection of Scripts I've created to help automate some day-to-day 'Sys Admin' duties. Any configuration that is not likely to change between script runs is defined in the NetApp.config file.  Configuration that is more likely to change is defined via user input when the script is run.

- NetApp
  - 7m_Check_Snapmirror
    * This script will connect to any 7Mode controller(s) defined in the NetApp.config file `sm7mfilers`, create a report of any mirrors lagging > `smlag` in seconds and email a report to everyone using the SMTP configuration.  All variables are defined in the NetApp.config file.
  - cDOT_New_Snapmirror.csv
    * This is where new SnapMirror relationship details are stored for the cDOT_New_SnapMirror script.
    * If creating SnapMirror relationships between multiple SVMs, they could be run independently as the script isn't able to handle multiple sources and destinations.
  - cDOT_New_SnapMirror
    * This script will create new cDOT SnapMirror relationship(s) using the .csv file in conjunction with user input when the script is run.  It's currently limited to 1 source and 1 destination SVM per run.
    * It will likely need to be tweaked to match your naming convention.
  - cDOT_New_SVM
    * This script will create a new cDOT SVM based on the variables that are set at the top of the script.  If a variable is omitted the script will skip over that configuration section.
    * It will likely need to be tweaked to match your naming convention
  - NetApp_Functions
    * This is a functions file that is required for most if not all of my scripts.  Common processes have been consolidated into functions that can be called from multiple scripts.
  - NetApp.config
    * Configuration file that gets called from most if not all of my scripts.  Common configuration items are stored here.
- Sandbox
  - Just a bunch of random scripts that I've saved as reference.
- VMware
  - vCenter_AddAllVMsfromDatastore
    * 
