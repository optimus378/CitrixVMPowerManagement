# CitrixVMPowerManagement (PM)
Need to edit this document for readablity. Sorry, haven't the time to do this now. 

Powershell Module for handling the stopping and starting of VMs on a schedule in Citrix Studio


Overview of How PM Works  
 
High Level: 
1 You include Machine Catalogs in the PM configuration. If the Machine Catalog is not in the configuration it will not be touched by PM 
2 Within the Machine Catalogs in PM. You exclude machines that you would like to be omitted from the PM Cycle: 
                 - They’re called ‘Excluded Machines’  
                 - By Default 1 machine will be included  
                 - You cannot add Machine Catalogs that have only 1 Machine. (You’ll be told)  
                 - You cannot Exclude All Machines in the Machine Catalog  
3. You set a Global Idle Threshold. (Default 60Mins) It’s explained below. In Short, If someone is disconnected on the machine or Active and Idle on the machine for a under a set time, the machine is skipped from the Power Off Cycle 
4. You set a Power Management Schedule:  
           For ONLY Machine Catalogs Included in the PM Config and Only Machines Not Excluded in the PM Config 
          - A time is set to place machines in Maintenance Mode.  
          - A Time is set to power Off Machines.  
          - A Time is set to Power On Machines.  

5. Every Action is logged. Every time you make a change to the config, every time a task is run. It is logged.  

Other functions are provided to adjust the config, so you can add/remove Machine Catalogs, Add/Remove Excluded Machines within any catalog. Etc.  
It is required that you be on a machine that has the Citrix PowerShell modules and knows how to contact and connect to the Citrix Delivery Controllers 
 


Doing it  

-  Create a folder where you want to run it from and paste the script in it. This is now considered your ‘Working Directory’ 
- You load up a PowerShell console and navigate to the Working Directory.  
-  All Functions below will run in a Non-Admin PowerShell console besides The Task Scheduling function. (If you try and run that without admin, it’ll just tell you that you’re a wrong person and to do it right) 
-  The script includes PowerShell functions that are intended to run via PowerShell command line. (Do not be directly editing the config)   

Import the Module.  

Command: ‘Import-Module VMPowerManagement.ps1’ – Or whatever the script got renamed to , it doesn’t really matter)  
This will create two files in the Working Directory 
config.json  -- That’s where the configuration stuff goes when you run the modules.  
log.txt  

Now that the module is imported you gotta do things.  
1. Add Machine Catalog(s) to be included in the PM Power Cycle Schedule. 
2. Exclude Extra Machines from the Machine Catalog. These Machines will not be touched by PM Power Cycle Schedule  
3. Adjust/Set The Global Idle Threshold. (Talked about more in Detail Later)  
4. Override the Global Idle threshold for Specific Machine Catalogs if Need Be.  
5. Schedule the Power Management Cycle  
     - What time are machines being placed in Maintenance Mode?  
     - When will they be powered Off?  
     - When will they be powered back on?  

 

You do all this with a few commands…  

PM Commands: 

Show the Current Configuration: 

Command: Show-PMConfig  

- This command will display The Machine Catalogs Currently in PM config.  
- The Excluded Machines under Each Machine Catalog that will be excluded from PM Processing  
- If There Is Idle Threshold Override set on the Machine Catalog (More On this Later)  
- The Current PM Scheduled Tasks, The Time They Run, The Last Time they Ran  
- The Current Global Idle Threshold set in the PM Config  

Add Machine Catalog to PM: 

Command: Add-PMCatalog -PMCatalogName <CatalogName>  
Example: Add-PMCatalog -PMCatalogName AZ-CTX999-MC     
 
Logic:  
	- If the Machine Catalog you provided Doesn’t Exist in the Citrix Machine Catalogs, It won’t add it.  
	- If the Machine Catalog you provided Already Exists in the Power Management Config, It won’t add it.  
	- If the Machine Catalog you provided has 1 or less machines in the Citrix Machine Catalog it won’t add it.  
	- It will Automatically Added 1 Excluded Machine providing that there are more than 1 machine in the Citrix Machine Catalog 

Remove Machine Catalog from Power Management: 

Remove-PMCatalog -PM CatalogName
	- If Machine Catalog does not exist in the PM config it will tell you.  

Add More “Excluded Machines” to Power Managed Machine Catalog: 

Command:  Add-PMExcludedMachine -PMCatalogName -Machine 
Ex: Add-PMExcludedMachine -PMCatalogName AZ-CTX999-MC -Machine AZ-CTX999-01.saw.loc  < -- DNS Name 
 
Logic:  
-If Machine Catalog you provided doesn’t exist, It won’t add the Machine to it.  
-If the Machine you provided doesn’t exist in the Citrix Machine Catalog, it won’t add it, and will show you a list of machines in the Citrix Machine Catalog.  
-If by Adding the Machine you provided to the Citrix Machine Catalog, it would be adding all available machines, it will not add it. It then directs you to just remove the Catalog. 

Remove Excluded Machine from Power Managed Catalog:  

Command: Remove-PMExcludedMacine -PMCatalogName -Machine  

Ex: Remove-PMExcludedMachine -PMCatalogName AZ-CTX999-MC -Machine AZ-CTX999-01.saw.loc  

Logic: 
-If Machine Catalog you provided does not exist, it will not remove the Excluded Machine you provided 
-If the Machine you provided does not exist, it will not remove it. It will then offer a list of Excluded Machines currently in Power Management 

The Global Idle Threshold: 
   -  Affects all Machine Catalogs that are not Overridden/Specifically Configured with their own Idle Thresholds (See Next Section)  
    - Is the amount of time that a single Active or Disconnected Session is allowed to remain idle.  
    - Comes into play when machines are going through the Scheduled Power Off Cycle.  
 
The Power off Function gets all the current Idle thresholds from the machine… 
If any of the Current Idle Thresholds on the Machine are LESS THAN Global Idle Threshold, The Machine is skipped from the Power Off Cycle.   
The Global Idle Threshold is set to 60 Minutes by Default. 

Setting the Global Idle Threshold:  

Command: Set-PMGlobalIdleThreshold Time in Minutes”  
Example: Set-PMGlobalIdleThreshold -IdleThreshold 60  

 
Overriding the Global Idle Threshold for a Particular Machine Catalog 

If there is a need to set a specific/different Idle Threshold for a Machine Catalog, you can override the Global Idle Threshold for that Machine Catalog.  
This essentially sets a parameter in the Power Management Configuration. If that Parameter exists for that machine catalog, during the Power Off Cycle, it is used instead of the Global Idle Threshold.  
 

Command: Set-PMIdleThresholdOverride -PMCatalogName  <MachineCatalogName> -IdleThreshold <Time in Minutes> 
Example: Set-PMIdleThresholdOverride -PMCatalogName  AZ-CTX999-MC -IdleThreshold 120 

 

Overview of The Power Management Schedule  

Every Machine Catalog and every machine within that catalog, except for ‘Excluded Machines’ in the PM configuration will be included in the Power Management Schedule.  
The Power Management Schedule consists of 3 Windows Scheduled Tasks that run DAILY at a time that you configured.  
The Tasks themselves are configured via PM. If using PM DO NOT set or adjust these Tasks yourself. Use PM.  
It is also very important that these scripts be configured to be run in ORDER. There is not logic currently configured in the code to prevent an out of order run times.  
In short, that means.  
Set Maintenance Mode 
Power Off Machines   
Power On Machines.  
The Scheduled Tasks should run in this order:  
 

Task One:  “S@W VM Power Management - Set Global Maintenance Mode” 
This script runs at (x) time daily. 
The purpose is to place machines that are included in the PM config  into Maintenance mode.  
 

Logic:  
When the Script is RUN at the configured time…  
For each Machine Catalog included in the PM Configuration …  
      For Each Machine in Each Machine Catalog…  
             If the Machine is not configured as an Excluded Machine in the PM configuration…  
                     The Machine will be placed into Maintenance Mode.  
 
Task Two:  "S@W VM Power Management - Global Power OFF Machines" 
The purpose of this script is to power off Machines included in the PM configuration providing some important conditions are met.  
 
Logic:  
When the Script is run at the configured time…  
     For Each Machine Catalog included in the PM configuration…  
            If an Idle Threshold Override is set, use that, if not use Global Idle Threshold  
                  For each Machine in Each Machine Catalog….  
                        If the Machine is NOT an Excluded Machine…  
                               If the Machine is IN Maintenance Mode…  
                                     If the Machine does NOT have Active/Disconnected Sessions below the Global Idle Threshold or the IdleThreshold Override (If Set)  
                                             Power Off Machine.  

If any of those conditions are not met… The Machine is Skipped.  
                   
Task Three: S@W VM Power Management- Global Power ON Machines 

The Purpose of this script is Power On All Machines in all Machine Catalogs that are configured in PM.  
 
Logic:  
When the Script is run at the configured time…  
       For Each Machine Catalog included in the PM Configuration…  
            For Each Machine in the Machine Catalog….  
                 If the Machine is not configured as an Excluded Machine in the PM config…  
                      Take the Machine out of Maintenance Mode 
                      Power on Machine.  

 

Setting the Power Management Schedule 
The purpose of this command it to Set the PM Schedule. 
 
Command: Set-PMGlobalScheduledTasks -MaintModeTime <Time in AM PM> -PowerOffTime <Time in AM PM>  -PowerOnTime <Time in AM PM>  
Example Set-PMGlobalScheduledTasks -MaintModeTime 5PM -PowerOffTime 7PM -PowerOnTime 4AM 

Logic:  
Automatically creates 3 Windows Scheduled Tasks at the times you specify.  (The Tasks themselves and what they do are described in detail in the previous section.)  
Once again there is not logic to ensure the time order of the scheduled tasks (Yet) So don’t be scheduling things out of order.  

How it works:  
When the command is run,  

It creates 3 Separate Scripts in the Folder that PM resides.  

Those are: 
TASK-SCRIPT-Set-GlobalMaintenanceMode.ps1 
TASK-SCRIPT-GlobalPowerOffMachines.ps1 
TASK-SCRIPT-GlobalPowerOnMachines.ps1 

Three Separate Windows Scheduled Tasks are created running the Powershell scripts when triggered at the time specified.  

 

Removing All Scheduled Tasks  
Running this command deletes all of the Tasks That were Scheduled with PM 
Run this command if don’t want PM running any tasks on the machine.  
command: Remove-AllPMScheduledTasks 
----- 
 

Future Features 

Eventually, I’d like to add more features to this.  
1. Being able to set custom schedules per machine catalog  
2.  Smarter Power off Cycle. Ex: If there were users still on the machine when the power off Scheduled Task Ran, Take note of that and try again in an Hour. --  
3. Even Smarter. Cycle Machines all the time based on Load Index Metrics. 
4. Church up the Log Out Put a little more.  
5. Some Minor Error Handling 
