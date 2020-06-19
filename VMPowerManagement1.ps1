## GLOBALS ##

$PMConfigFile = "./config.json"
$ProgramLocation = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\')
$ProgramFileName = $MyInvocation.MyCommand.Name
$LogFileName = "Log.txt"
$BaseConfig =@"
{
                    "PMCatalogs": {

                                  },
                    "GlobalIdleThreshold":60                      
}   
"@

$SleepWait = 30 ## Amount of time (in Seconds) to wait for Graceful User Log Off during the PowerOffMachines Cycle. 

### SCHEDULED TASK GLOBALS ###
### Scheduled Task Names
$MaintModeTaskName = "S@W VM Power Management - Set Global Maintenance Mode"
$IntialPowerOffTaskName = "S@W VM Power Management - Global Power OFF Machines"
$SecondaryPowerOffTaskName = "S@W VM Power Management - Global Secondary Power Off Machines"
$PowerOnTaskName = "S@W VM Power Management - Global Power ON Machines"
## Scheduled Task Scripts  
$MaintModeScript = @"
Import-Module $ProgramLocation\$ProgramFileName
Set-MaintenanceMode
Write-Log "Set Machines into Maintenence Mode."
"@
$IntialPowerOffMachinesScript = @"
Import-Module $ProgramLocation\$ProgramFileName
PowerOffMachines
Write-Log "Ran Intial Power Off Machines Script"
"@
$SecondaryPowerOffMachinesScript = @"
Import-Module $ProgramLocation\$ProgramFileName
Write-Log "Attempting to Power Off Machines a second time..."
PowerOffMachines
Write-Log "Ran Secondary Power Off Cycle"
"@
$PowerOnMachinesScript = @"
Import-Module $ProgramLocation\$ProgramFileName
PowerOnMachines
Write-Log "Ran Power On Machines Scheduled Task."
"@

### Scheduled Task Descriptions
$MaintModeTaskDescription = "Task Created by VMPowerManagement.Ps1. This task puts machines that are configured with S@W VM Power Management into Maintenance Mode." 
$IntialPowerOffTaskDescription = "Task Created by VMPowerManagement.Ps1. This task Powers Off Machine that are configured with S@W VM Power Management."
$SecondaryPowerOffDescription = "Task Created by VMPowerManagement.ps1 This task tries a second time to Power Off Machines that may have been skipped the 1st try because a session was below IdleThreshold."
$PowerOnTaskDescription = "Task Created by VMPowerManagement.Ps1. This task Powers ON Machines configured by S@W VM Power Management."

### Scheduled Task Script File Paths/FileNames
$MaintModeScriptFilePath = "$ProgramLocation\TASK-SCRIPT-Set-GlobalMainteanceMode.ps1"
$IntialPowerOffScriptFilePath= "$ProgramLocation\TASK-SCRIPT-GlobalIntialPowerOffMachines.ps1"
$SecondaryPowerOffScriptFilePath = "$ProgramLocation\TASK-SCRIPT-GlobalSecondaryPowerOffMachines.ps1"
$PowerOnSCriptFilePath= "$ProgramLocation\TASK-SCRIPT-GlobalPowerOnMachines.ps1"


## END SCHEDULED TASK GLOBALS 
## END GLOBALS



## LOGGING CONFIGURATION
function Get-TimeStamp {
    
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    
}
Function Write-Log {
    param(
        [Parameter(Mandatory=$true)][String]$msg
    )
    $LogFile = "$ProgramLocation\$LogFileName"
    if (!(Test-Path $LogFile)){
        New-Item -Name $LogFile}
    Write-Output "$(Get-TimeStamp) $msg" | Out-file $LogFile -append
}

## END LOGGING CONFIGURATINON 

## PM CONFIGURATION FUNCTIONS
function Get-PMCurrentConfig{
    if (!(Test-Path $PMConfigFile)){ # If $ConfigFile Doesn't Exist... 
        New-Item -Name $PMConfigFile  # Create One..
        $config = $BaseConfig | ConvertFrom-Json  ## Create JSON Skeleton from $BaseConfig "Here Script" found in Globals...
        $config | ConvertTo-Json -depth 10 | Out-File ./config.json  # Write it to File
        return $config 
    }
    $config = Get-Content -raw -path $PMConfigFile | convertfrom-json  # Config File was Found. Load it. 
    if(!($config.PMCatalogs)){ # Check to see if at least the $Baseconfig Sekelton Exists... 
        $config = $BaseConfig | ConvertFrom-Json ## It didn't. Load JSON Skelton from $Base Config Here Script 
        $config | ConvertTo-Json -depth 10 | Out-File ./config.json ## WRite it File
        $config = Get-Content -raw -path $PMConfigFile | convertfrom-json # Get Current Config
        return $config
        }
    $config = Get-Content -raw -path $PMConfigFile | convertfrom-json ## Get Config From File
    return $config # Config File was found, It was correct, Return it. 
}

function Show-PMConfig{
    $config = Get-PMCurrentConfig
    $PMCatalogNames = $config.PMCatalogs.PSObject.Properties.Name
    Write-Output "----- Current Configuration ------ "
    Write-Output ""
    Write-Output "Global Idle Threshold: $($config.GlobalIdleThreshold)"
    Write-Output ""
    Write-Output "---- Currently Scheduled Tasks ----"
    Write-Output ""
    $MaintModeTaskInfo = Get-PMScheduledTaskInfo -TaskName $MaintModeTaskName
    $IntialPowerOffTaskInfo = Get-PMScheduledTaskInfo -TaskName $IntialPowerOffTaskName
    $SecondaryPowerOffTaskInfo = Get-PMScheduledTaskInfo -TaskName $SecondaryPowerOffTaskName
    $PowerOnTaskInfo = Get-PMScheduledTaskInfo -TaskName $PowerOnTaskName
    Write-Output "Task Name: $MaintModeTaskName"
    Write-Output "Task Time: Runs Daily At: $($MaintModeTaskInfo.Time)"
    Write-Output "Last Run: $($MaintModeTaskInfo.LastRunTime)"
    Write-Output ""
    Write-Output "Task Name: $IntialPowerOffTaskName"
    Write-Output "Task Time: Runs Daily At: $($IntialPowerOffTaskInfo.Time)"
    Write-Output "Last Run: $($IntialPowerOffTaskInfo.LastRunTime)"
    Write-Output ""
    Write-Output "Task Name: $SecondaryPowerOffTaskName"
    Write-Output "Task Time: Runs Daily At: $($SecondaryPowerOffTaskInfo.Time)"
    Write-Output "Last Run: $($SecondaryPowerOffTaskInfo.LastRunTime)"
    Write-Output ""
    Write-Output "Task Name: $PowerOnTaskName"
    Write-Output "Task Time: Runs Daily At: $($PowerOnTaskInfo.Time)"
    Write-Output "Last Run: $($PowerONTaskInfo.LastRunTime)"
    Write-Output ""
    Write-Output "----- Power Managed Machine Catalogs -----"
    foreach($PMCatalog in $PMcatalogNames){
        Write-Output "PM Catalog Name: $PMCatalog"
        Write-Output "Excluded Machines: $($config.PMCatalogs.$PMCatalog.ExcludedMachines)"
        if ($config.PMCatalogs.$PMCatalog.IdleThreshold){
            Write-Output "Custom Idle Threshold: $($config.PMCatalogs.$PMCatalog.IdleThreshold)"
            Write-Output ""
        }
        Write-Output "Custom Idle Threshold: Not Set"
        Write-Output ""
    }
}
#Test-MachineCatalog Checks to See if the Machine Catalog Exists in the config.json. It returns a Boolean. 
function Test-PMCatalog{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Name
        )
    $config = Get-PMCurrentConfig # Load Config 
    if ($config.PMCatalogs.PSObject.Properties.Name -contains $Name){ #If the PMCatalog Exists..
        return $True # Return True
    }
    return $False
}

# Add-PMCatalog- Adds a new Machine Catalog. And Automatically Adds 1 Excluded Machine to PMCatalogs.$PMCatalog.ExcludedMachines for Safety Reasons. 
function Add-PMCatalog{
    [CmdletBinding(SupportsShouldProcess=$True)]
    param (
        [Parameter(Mandatory)]
        [string]
        $PMCatalogName

    )
    $config = Get-PMCurrentConfig # Get Current Configuration.. 
        if (Test-PMCatalog($PMCatalogName)){ ## If PMCatalog Exists, Don't Add.
        write-output "$PMCatalogName Already Exists!"
        Write-Log "Tried to add Local Machine Catalog $PMCatalogName to config.json, but it already exists" 
        Return
        }
    try{ $CitrixMachineCatalogs = Get-BrokerCatalog | Select-Object -property Name #Gets A List of All Machine Catalogs from Citrix Machine Catalogs
    }
    catch{Write-Output "Can't Access Citrix PowerShell Modules. Make sure you're on a machine with access to Citrix PowerShell Modules"
            Return
        }
    if ($PMCatalogName -notin $CitrixMachineCatalogs.name){ # If The PMCatalog Name you provided doesn't exist in the Citrix Machine Catalogs, Don't Add. 
        Write-Output "$PMCatalogName is not Found in Citrix Machine Catalogs"
        Write-Log "Tried to add $PMCatalogName to Power Managed Catalogs, but it doesn't exist in Citrix Machine Catalogs"
        Return
    }
    $CitrixMachinesInCatalog = Get-CitrixMachinesInCatalog -PMCatalogName $PMCatalogName # Gets a List of Machines IN the Citrix Machine Catalog you provided. 
    if ($CitrixMachinesInCatalog.count -lt 2){ # If only 1 Machine Exists in the Citrix Machine Catalog. For saftey Reasons, Don't add. We're not Power Mananaging Machine Catalogs with Single Machines for Now. 
        write-output "There must be at least 2 machines in the Citrix Machine Catalog to be included in Power Management."
        Return
    }
    $Value = @{}
    $config.PMCatalogs | Add-Member -Name $PMCatalogName -Value $Value -MemberType NoteProperty -Force  ## Made it through all the "Ifs: Add the Catalog to PM Config
    $config | ConvertTo-Json -depth 10 | Out-File ./config.json ## Write it To Config. 
    $config = Get-PMCurrentConfig ## Get Config AGain...
    $config.PMCatalogs.$PMCatalogName | Add-Member -Name PMCatalogName -Value $PMCatalogName -MemberType NoteProperty -Force ## Add PSCatalog Name to PSCatalog Object 
    $config | ConvertTo-Json -depth 10 | Out-File ./config.json # Write it again.. for some reason. 
    $AutoExcludedMachine = $CitrixMachinesInCatalog[0] # Get The First Machine in the Citrix Machine Catalog. 
    Add-PMExcludedMachine -PMCatalogName $PMCatalogName -Machine $AutoExcludedMachine ## Add it to ExcludedMachines for the PMCatalog you Just added. 
    Write-Output "Added $PMCatalogName to PowerManagement with 1 Excluded Machine $AutoExcludedMachine"
    Write-Log "Modfied Congfiguration: - Added PMCatalog: $PMCatalogName to Power Management"
    Write-Log "Auto Added $AutoExcludedMAchine to Machine $PMCatalogName in Power Management"
}

#Remove-MachineCatalog Removes Specified Machine Catalog from config.json
function Remove-PMCatalog($PMCatalogName){
    $config = Get-PMCurrentConfig #Get Current PM Config 
    if (Test-PMCatalog($PMCatalogName)){ # Test to make sure the Catalog you are trying to remove exists in PMCatalogs. 
        $config.PMCatalogs.PSObject.Properties.Remove($PMCatalogName) # Remove it and all sub Objects.
        $config | ConvertTo-Json -depth 10 | Out-File ./config.json #Write it 
        Write-Log "Modfied Confguration: -  Removed Local Machine Catalog $PMCatalogName."
        Write-Output "Removed $PMCatalogName"
    }else{
        Write-Output "$PMCatalogName does not Exist in config.json!"
        Write-Log  "Tried to Remove Local Machine Catalog $PMCatalogName from config.json, but it did not exist."
    }
}
#Add-PMEExcludedMachine  Adds Another Machine to ExcludedMachines list for Existing PMCatalog.  
function Add-PMExcludedMachine{
    [CmdletBinding()]
    param (
        [Alias("Name")]
        [Parameter(Mandatory)]
        [string]
        $PMCatalogName,
        [Parameter(Mandatory)]
        [string[]]
        $Machine
    )
    $config = Get-PMCurrentConfig ## Get PM Config
    if (Test-PMCatalog($PMCatalogName)){ ## If Catalog Name Exists...
        $CitrixMachinesInCatalog = Get-CitrixMachinesInCatalog -PMCatalogName $PMCatalogName ## Get A list of Machines in Machine Catalog from Citrix. 
        if ($Machine -notin $CitrixMachinesinCatalog){ ##Checks to make sure that the Machine Exists in the Citrix Machine Catalog. 
            Write-Output "The DnsName '$Machine' does Not Exist in Citrix Machine Catalog '$PMCatalogName'"
            Write-Output "You must Add Machines by their DNSName"
            Write-Output "Here's a List of Current Machines in the Citrix Machine Catalog '$PMCatalogName':"
            $CitrixMachinesInCatalog ## Returns a List of Current Machines in the Citrix Machine Catalog so you can see them. 
            Return 
        }
        if($config.PMCatalogs.$PMCatalogName.ExcludedMachines -contains $Machine){ ## If Machine you're trying to add exists in $PMCatalog.ExcludedMachines, Abort with Message.
            Write-Log "$PMCatalogName already contains $Machine"
            Write-Output "$PMCatalogName already contains $Machine"
        }
        if (($config.PMCatalogs.$PMCatalogName.ExcludedMachines.count +1) -eq $CitrixMachinesInCatalog.count ){ ## If The Machine you're adding is the last of the machines in the Citrix Machines Catalogs NOT Excluded, Prevent from Adding. 
            write-output "This would Add All Avaiable Machines in the Citrix Machine Catalog to Excluded Machines. Aborting. Maybe Remove the Catalog from Power Management all together? Remove-PMCatalog"
            Return
        }
        if (!($config.PMCatalogs.$PMCatalogName.ExcludedMachines)){ ## If there are no Excluded Machines in the Catalog, just add it. 
            $Machines = @($Machine)
            $config.PMCatalogs.$PMCatalogName | Add-Member -Name ExcludedMachines -Value $Machines -MemberType Noteproperty
            $config | ConvertTo-Json -depth 10 | Out-File ./config.json
        }        
        ## Made it Through all the "Ifs".. 
        $UpdatedExcludedMachines = $config.PMCatalogs.$PMCatalogName.ExcludedMachines + $machine | Select-Object -unique ## Creates $UpdatedExcluded Machines Variable. Which is. A new List with $Current ExcludedMAchines Plus the Machine you're adding (Powershell is weird about Arrays, You can't just add to them) 
        $config.PMCatalogs.$PMCatalogName | Add-Member -Name ExcludedMachines -Value $UpdatedExcludedMachines -Membertype NoteProperty -Force ## Add The Excluded Machine to the ExcludedMachines Object under $PMCatalog
        $config | ConvertTo-Json -depth 10 | Out-File ./config.json ## Write it to File.
        Write-Output "Modfied Configuration: - Added $Machine to Excluded Machines in Local Machine Catalog: $PMCatalogName"
        Write-Log "Modfied Configuration: - Added $Machine to Excluded Machines in Local Machine Catalog: $PMCatalogName"
    }else{ ## The $PMCatalog didn't, so you can't add a machine to it. 
    Write-Log "$PMCatalogName Does not Exist in Power Management Config, so I can't Exclude a Machine. Try Add-PMCatalog -PMCatalogName?"  
    }
}
# Remove-ExcludedMachine - Removes a Machine from $PMCatalog.ExcludedMachines. 
function Remove-PMExcludedMachine{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $PMCatalogName,
        [Parameter(Mandatory)]
        [string]
        $Machine
    )
    $config = Get-PMCurrentConfig # Get Config
    if (Test-PMCatalog($PMCatalogName)){ #IF $PMCatalog Exists....
        $CurrentExcludedMachines = @($config.PMCatalogs.$PMCatalogName.ExcludedMachines) ## Get List of Current Exlcluded Machines in $PMCatalog
        if ($Machine -notin $CurrentExcludedMachines){ ## If the Machine you're trying to remove is not in the Catalog..
            Write-Output " '$Machine' does not exist in Machine Catalog: $PMCatalogName" ## State That it doesn't Exist. 
            Write-Output "Here's a list Excluded Machines in '$PMCatalogName':" # Show a list of Excluded Machines in $PMCatalog that Do Exist. 
            $CurrentExcludedMachines
            Return
        }
        if (($CurrentExcludedMachines.Count -1) -eq 0){ ## IF by Removing your machine, it would bring the ExcludedMachines Count to 0 in $PMCatalog, ABort. 
            Write-Log "Cannot Remove Machine. You must have at least 1 Excluded Machine"
            Write-Output "Cannot Remove Machine. You must have at least 1 Excluded Machine"
            Return 
        }
        ## Made it Through all the "ifs" 
        $UpdatedExcludedMachines = $CurrentExcludedMachines| Where-Object {$_ -notcontains $machine} # Create a new array with the current Excluded Machines and the New Machine
        $config.PMCatalogs.$PMCatalogName | Add-Member -Name ExcludedMachines -Value $UpdatedExcludedMachines -Membertype NoteProperty -Force ## Add it to the Config
        $config | ConvertTo-Json -depth 10 | Out-File ./config.json ## Write the Config. 
        Write-Log "Modified Local Machine Catalog: $PMCatalogName.  Action: Removed $Machine from Excluded Machines"
        Write-Output "Modified Local Machine Catalog: $PMCatalogName.  Action: Removed $Machine from Excluded Machines"
    }
    Write-Output "Cannot Remove Machine from Catalog that Does not Exist."
    Write-Log "Tried to Remove $Machine from $PMCatalogName, but $PMCatalogNAme does not Exist."
}
# Set-Global Idle Threshold. Configures the IdleThreshold. Which is a set time in which to test against ACtive/Idle SEssions on a particular MAchine during the PowerOffMachines Function. 

## Set-Time -- This Function is Deprecated. No longer need to convert IdleThresholds pulled from Citrix as I found a way to pull the time directly into Minutes. 
## Converts IdleThreshold times pulled from Citrix into Minutes.  

function Set-Time{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $IdleDurationTime
    )
    $TimeSpan = $timespan = [TimeSpan]::Parse($IdleDurationTime)
    $TotalMinutes = $TimeSpan.TotalMinutes
    return $TotalMinutes
}

function Set-PMGlobalIdleThreshold{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int] ## -- TO DO: ADD A STring Validator REgex - No Letters, Only len 6 000000
        $GlobalIdleThreshold
    )
    $config = Get-PMCurrentConfig ## Get the Config. 
    $CurrentThreshold = $config.GlobalIdleThreshold # Get The Current IdleThreshold. 
    $config | Add-Member -Name GlobalIdleThreshold -Value $GlobalIdleThreshold -MemberType NoteProperty -Force ## Add The New Idle Threshold to Config
    $config | ConvertTo-Json -depth 10 | Out-File ./config.json  #Write Config. 
    Write-Log "Modified Config: Changed Global Threshold from $CurrentThreshold to $GlobalIdleThreshold"
    Write-Output "Changed Global Idle Threshold to $GlobalIdleThreshold"
}

# Set-IdleThresholdOverride. Gives you that ability to configure a different IdleThreshold for a specific $PMCatalog
function Set-PMIdleThresholdOverride{
    [CmdletBinding()]
    param (
        [Alias('Name')]
        [Parameter(Mandatory)]
        [string]
        $PMCatalogName,
        [Parameter(Mandatory)]
        [int] ## -- TO DO: ADD A STring Validator REgex - No Letters, Only len 6 000000
        $IdleThreshold
    )
    $config = Get-PMCurrentConfig # Get Current Config
    $CurrentThreshold = $config.PMCatalogs.$PMCatalogName.CustomIdleThreshold ## Gets the Current Idle Threshold from $PMCatalog
    $config.PMCatalogs.$PMCatalogName | Add-Member -Name CustomIdleThreshold -Value $IdleThreshold -MemberType NoteProperty -Force # Adds the new IdleThreshold to $PMConfig
    $config | ConvertTo-Json -depth 10 | Out-File ./config.json  # Write it to File. 
    if (!($CurrentThreshold)){ # If There's not a Current Idle Threshold Set for $PMCatalog, Write a different Message.  
        Write-Log "Modified Config: Set a Custom Idle Threshold for Machine Catalog: $PMCatalogName to $IdleThreshold"
        Write-Output "Modified Config: Set a Custom Idle Threshold for Machine Catalog: $PMCatalogName to $IdleThreshold"
    }else{ # There was an IdleThreshold already set. Write A different Message. 
        Write-Log "Modifed Config: Changed Custom Idle Threshold for Machines Catalog $PMCatalogName from $CurrentIdleThreshold to $IdleThreshold"
        Write-Output "Modifed Config: Changed Custom Idle Threshold for Machines Catalog $PMCatalogName from $CurrentIdleThreshold to $IdleThreshold"
    }
}

## END CONFIGURATION FUNCTIONS

# GEt-CitrixMachinesInCatalog Gets a list of all Machines in a Single Citrix Machine Catalog. 
function Get-CitrixMachinesInCatalog{
    [CmdletBinding()]
    param (
        [Alias("name")]
        [Parameter(Mandatory)]
        [string]
        $PMCatalogName
    )
    $Machines = Get-BrokerDesktop -Filter {CatalogName -eq $PMCatalogName} | Select-Object -Property DNSName
    Return $Machines.DNSName
}
# Get-CitrixMachineStats - Gets Stats from a Single Machine in a Citrix Machine Catalog. The Powerstate, Whether it's current in Maintenance Mode, And the Session Count.  (PowerState And SEssion Count will be used in a future itearion of this script. )
function Get-CitrixMachineStats{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Machine
        )
    $MachineStats = Get-BrokerMachine -Filter {DNSNAme -eq $Machine} | Select-object -Property PowerState, InMaintenanceMode, SessionCount ## Gets Stats from Specific Machine. 
    return $MachineStats
}

#Set-MaintenanceMode. Sets All MAchines not in $PMCatalog.ExcludedMAchines into Maintenance Mode. This is a pre-function that's run before PowerOffMachines. The purpose is to no longer allow logons to the Machines, so they can be powered Off. 
# To Do. Get List of MCs and Machines that were affected by this function with date. 
function Set-MaintenanceMode{
    $config = Get-PMCurrentConfig ## Get Current PMConfig
    $PMCatalogs = $config.PMCatalogs.PSObject.Properties.Name ## Get all the $PMCatalogs by Name
    foreach ($PMCatalog in $PMCatalogs){ ## Loop Through Each $PMCatalog
        $AllMachines = Get-CitrixMachinesInCatalog -PMCatalogName $PMCatalog  ## Get All the machines in the Citrix Machine Catalog ($PMCatalog)
        if ($AllMachines -le 1){
            Write-Log "$PMCatalog only has 1 Active Machine in the Machine Catalog, Skipping Catalog."
            continue
        }
        $ExcludedMachines = $config.PMCatalogs.$PMCatalog.ExcludedMachines
        $CitrixMachinesinCatalog = Get-CitrixMachinesInCatalog($PMCatalog)   ## Get a List of Excluded Machines for $PMCatalog
        $IncludedMachines = $CitrixMachinesinCatalog | Where-Object {$ExcludedMachines -notcontains $_} ## Get the List Machines to be Included by getting a list of All the Machines in the Citrix MAchines Catalog and subtracting the $PMCatalog.ExcludedMAchines
        Write-Log "Skipping $ExcludedMachines in Excluded Machines List for Local Machine Catalog $PMCatalog."   ## Logs the Machines that will be Excluded to the Log. 
        foreach ($Machine in $IncludedMachines){ ## Loops Through Each Machine in $IncludedMachines
                $MachineInstance = Get-BrokerMachine -DNSName $Machine
                Set-BrokerMachineMaintenanceMode -InputObject $MachineInstance $true   ## Sets $Machine into Maintenance Mode
                Write-Log "Set $Machine in Machine Catalog $PMCatalog into Maintenance Mode."
        }
    }
    
}

function PowerOffMachines{
    $config = Get-PMCurrentConfig ## Get Current Config
    $PMCatalogs = $config.PMCatalogs.PSObject.Properties.Name ## Get the Names of $PMCatalogs
    foreach ($PMCatalog in $PMCatalogs){  ##For aach $PMCatalog..
        $AllMachines = Get-CitrixMachinesInCatalog -PMCatalogName $PMCatalog  ## Get All the machines in the Citrix Machine Catalog ($PMCatalog)
        if ($AllMachines -le 1){
            Write-Log "$PMCatalog only has 1 Active Machine in the Machine Catalog, Skipping Catalog."
            continue
        }
        $IdleThreshold = $config.GlobalIdleThreshold -as [int]  ## Gets GlobaIdleThreshold and converts it to Integer
        if ($config.PMCatalogs.$PMCatalog.CustomIdleThreshold){ ## If the $PMCatalog contains an entry for a Custom Idle Threshold...
            $IdleThreshold = $config.PMCatalogs.$PMCatalog.CustomIdleThreshold -as [int]  ## Reset The $IdleThreshold variable and Use that.      
        }
        $ExcludedMachines = $config.PMCatalogs.$PMCatalog.ExcludedMachines ## Get the Excluded MAchines from $PMCatalog.ExcludedMachines
        $IncludedMachines = $AllMachines | Where-Object {$ExcludedMachines -notcontains $_} ### Filter out the Excluded Machines from The Citrix Machines and Set That Variable. These are the machines that may be powered off
        foreach ($Machine in $IncludedMachines){ ## For each of the the machines that may be powered off...
            Write-Log "Starting Power OFF Cycle For $Machine..."
            $MachineStats = Get-CitrixMachineStats -Machine $Machine ## Get the Stats of the machines. In this case, we're checking the status of Maintenance Mode
            if($Machinestats.Powerstate -eq "Off"){
                Write-Log "$Machine is already powered off, skipping. This is either because it was manually shutdown, or it was powered off in the intial power off cycle."
                continue
            }
            if(!($MachineStats.InMaintenanceMode)){ ## If the Machine is not in Maintenance Mode, We're Skipping. 
                write-output "$Machine is not In MaintenanceMode... Skipping"
                Write-Log "$Machine is not in Maintenance Mode... Will not Continue with Power Off"
                Continue
            } 
            Write-Log "$Machine is not already powered off and is in Maintenance Mode, Continuing.."
            $MachineIdleDurationTimes = Get-BrokerSession | Where-Object {$_.DNSName -eq $Machine} | select-object -property Idleduration ## Get Active and Disconnected Sessions' Idle Duration Times 
            $MachineDurationTimesinMins= $MachineIdleDurationTimes.IdleDuration.TotalMinutes
            if($MachineDurationTimesinMins.count -gt 0){ ## If There are Idle Duration Times...Check to see if they are above the IdleThreshold
                foreach($time in $MachineDurationTimesinMins -as [int]){
                    if ($time -as [int] -le $IdleThreshold){  
                        Write-Log "$Machine was skipped because there's an Active Session below the IdleThreshold" 
                        Write-Output "$Machine was skipped because there's an Active Session below the IdleThreshold" 
                        Write-Log "$Machine : Idle Threshold Times in Mins: $MachineDurationTimesinMins"
                        Write-Log "$Machine : Idle Duration Times in Citrix: $MachineIdleDurationTimes"                 
                        Continue ## IdleDuration time is less than Threshold - Continue returns program flow to the inner most loop.
                    }
                }

            }
            Write-Log "$Machine has no sessions below IdleThreshold of $IdleThreshold, Continuing With Power OFF..."
            Get-BrokerSession | Where-Object DNSName -eq $Machine | Stop-Brokersession
            Write-Output "GraceFully Logging Off Sessions on $Machine. Waiting $SleepWait Seconds..."
            Start-Sleep $SleepWait
            Write-Log "Done! Finished Logging Off Users!"
            $MachineInstance = Get-BrokerMachine -DNSName $Machine                          
            New-BrokerHostingPowerAction -Action 'TurnOff' -MachineName $MachineInstance.MachineName
            Write-Log "POWERED OFF $Machine" 
            Write-OutPut "POWERED OFF $Machine"
        }

                        
    }
           
}

## Powers On all Eligible Maachines listed in Power Management.              
function PowerOnMachines{
    $config = Get-PMCurrentConfig ## Get Current Config
    $PMCatalogs = $config.PMCatalogs.PSObject.Properties.Name ## Get $PMCatalog Names
    foreach ($PMCatalog in $PMCatalogs){ ## Loop Through Each $PMCatalog
        $AllMachines = Get-CitrixMachinesInCatalog -PMCatalogName $PMCatalog  ## Get All the machines in the Citrix Machine Catalog ($PMCatalog)
        if ($AllMachines -le 1){
            Write-Log "$PMCatalog only has 1 Active Machine in the Machine Catalog, Skipping Catalog."
            continue
        }
        $AllMachines = Get-CitrixMachinesInCatalog -PMCatalogName $PMCatalog ## Get a list of AllMachines in Citrix Machine Catlog
        $ExcludedMachines = $config.PMCatalogs.$PMCatalog.ExcludedMachines ## GEt List of Excluded Machines from $PMCatalog.ExcludedMachines
        $IncludedMachines = $AllMachines | Where-Object {$ExcludedMachines -notcontains $_} ## Get List of Machines to be included in PowerOnCycle by removing Excluded Machines
                    foreach ($Machine in $IncludedMachines){ # Loop Through $IncludedMachines
                    Write-Log "Powering On $Machine in $PMCatalog"
                    $MachineInstance = Get-BrokerMachine -DNSName $Machine
                    Set-BrokerMachineMaintenanceMode -InputObject $MachineInstance $false ## Turn Off MaintenanceMode on $Machine
                    New-BrokerHostingPowerAction -Action 'TurnON' -MachineName $MachineInstance.MachineName ## Power Power On $Machine
                    Write-Log "Set Maintenance mode to 'Off' and Powered On $Machine"
            }
    }
}

## Create-ScheduledTaskScripts -- Creates the SCripts needed for SCheduled Tasks and Drops them in the working directory. 
function Create-ScheduledTaskScripts{
    $MaintModeScript | Out-File $MaintModeScriptFilePath
    Write-Log "CREATED/MODFIED TASK SCRIPT $MaintModeScriptFilePath"
    Write-Output "CREATED/MODFIED TASK SCRIPT $MaintModeScriptFilePath"
    $IntialPowerOffMachinesScript| Out-File $IntialPowerOffScriptFilePath
    Write-Log "CREATED/MODFIED TASK SCRIPT $IntialPowerOffScriptFilePath"
    Write-Output "CREATED/MODFIED TASK SCRIPT $IntialPowerOffScriptFilePath"
    $SecondaryPowerOffMachinesScript| Out-File $SecondaryPowerOffScriptFilePath
    Write-Log "CREATED/MODFIED TASK SCRIPT $SecondaryPowerOffScriptFilePath"
    Write-Output "CREATED/MODFIED TASK SCRIPT $SecondaryPowerOffScriptFilePath"
    $PowerOnMachinesScript | Out-File $PowerONScriptFilePath
    Write-Log "CREATED/MODFIED TASK SCRIPT $PowerONScriptFilePath"
    Write-Output "CREATED/MODFIED TASK SCRIPT $PowerONScriptFilePath"

}
### Set-PMGlobalScheduledTasks - User Function: Creates the Scheduled Tasks 
function Set-PMGlobalScheduledTasks{
    param(
        [Parameter(Mandatory)]
        [string]
        $MaintModeTime,
        [Parameter(Mandatory)]
        [string]
        $IntialPowerOffTime,
        [Parameter(Mandatory)]
        [string]
        $SecondaryPowerOffTime,
        [Parameter(Mandatory)]
        [string]
        $PowerOnTime
    )
    
    Create-ScheduledTaskScripts
    Set-PMGLobalScheduledTask -TaskName $MaintModeTaskName -Description $MaintModeTaskDescription -ScriptFilePath $MaintModeScriptFilePath -Time $MaintModeTime -ErrorAction Stop
    Set-PMGLobalScheduledTask -TaskName $IntialPowerOffTaskName -Description $IntialPowerOffTaskDescription -ScriptFilePath $IntialPowerOffScriptFilePath -Time $PowerOffTime -ErrorAction Stop
    Set-PMGlobalScheduledTask -TaskName $SecondaryPowerOffTaskName -Description $SecondaryPowerOffDescription -ScriptFilePath $SecondaryPowerOffScriptFilePath $SecondaryPowerOffTime -ErrorAction Stop
    Set-PMGLobalScheduledTask -TaskName $PowerONTaskName -Description $PowerONTaskDescription -ScriptFilePath $PowerONScriptFilePath -Time $PowerONTime -ErrorAction Stop

}

function Set-PMGlobalScheduledTask{
    param(
    [Parameter(Mandatory)]
    [string]
    $TaskName,
    [Parameter(Mandatory)]
    [string]
    $Description,
    [Parameter(Mandatory)]
    [string]
    $ScriptFilePath,
    [Parameter(Mandatory)]
    [string]
    $Time
    )
    if (Get-ScheduledTask -TaskName $TaskName -EA SilentlyContinue){ ## If the Task Name Already Exists... 
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$False # Remove The Scheduled Task
    }
    ## Setting up Parameters 
    $STName = $TaskName  # Task NAme
    $STDescription = $Description
    $STAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $ScriptFilePath -WorkingDirectory $ProgramLocation ## Location of the Script 
    $STTrigger = New-ScheduledTaskTrigger -Daily -At $time -ErrorAction Stop 
    $STSettings = New-ScheduledTaskSettingsSet # Set up the "SEtting Up" of the Task
    Register-ScheduledTask -TaskName $STName -Description $STDescription -Action $STAction -Trigger $STTrigger -RunLevel Highest -Settings $STSettings
    Write-Log "Successfully Created Scheduled Task: $TaskName" 
    Write-Output "Successfully Created Scheduled Task: $TaskName" 

}


function Get-PMScheduledTaskInfo{
    param(
    [Parameter()]    
    [string]
    $TaskName
    )
        $Info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
        if($Info){
            $Time = $Info.NextRunTime | Get-Date -Format t
            $LastRunTime = $Info.LastrunTime
            Return @{Time = $time; LastRunTime = $LastRunTime}
        }
        $Info =  "Task Not Scheduled"
        return @{Time = $Info; LastRunTime = $Info}
}
## REmove-AllPMScheduledTasks -- Deletes All Scheduled Tasks from the Machine it was run. 
function Remove-AllPMScheduledTasks{ 
    Unregister-ScheduledTask -TaskName $MaintModeTaskName -Confirm:$False -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $IntialPowerOffTaskName -Confirm:$False -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $SecondaryPowerOnTaskName -Confirm:$False -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $PowerOnTaskName -Confirm:$False -ErrorAction SilentlyContinue
    Write-Log "Succesfully Removed All Scheduled Tasks. Power Management will no longer Run."

}
#Create $PMConfig if it doesn't Exist. 

if(!(Test-Path $PMConfigFile)){
    Get-PMCurrentConfig
}

function Get-Admin{
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
        Return $True
    }
    else{
        Return $False
    }
}
