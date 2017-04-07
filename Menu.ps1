Clear-Host
$Host.UI.RawUI.WindowTitle = "Mike's PowerShell Tools"

function loadMainMenu()
{
    [bool]$loopMainMenu = $true
    while ($loopMainMenu)
    {
    Clear-Host  # Clear the screen.
    Write-Host -BackgroundColor Black -ForegroundColor White  "`n`t`tPowerShell Tools`t`n"
    Write-Host -BackgroundColor Black -ForegroundColor White  "`t`tMain Menu`t`t`n"
    Write-Host "`t`t`t1 - Microsoft Tools"
    Write-Host "`t`t`t2 - NetApp Tools"
    Write-Host "`t`t`t3 - vCloud Tools"
    Write-Host "`t`t`t4 - vCenter/vSphere Tools"
    Write-Host "`t`t`tQ --- Quit And Exit`n"
    Write-Host -BackgroundColor DarkCyan -ForegroundColor Yellow "`NOTICE:`t"
    Write-Host -BackgroundColor DarkCyan -ForegroundColor White  "`Use at your own risk. You have been warned.`t`n"
    $mainMenu = Read-Host "`t`tEnter Sub-Menu Option Number" # Get user's entry.
    switch ($mainMenu)
        {
        1{MSTools}
        2{NATools}
        3{VCTools}
        4{VITools}
        "q" {
                $loopMainMenu = $false
                Clear-Host
                Write-Host -BackgroundColor DarkCyan -ForegroundColor Yellow "`t`t`t`t`t"
                Write-Host -BackgroundColor DarkCyan -ForegroundColor Yellow "`tGoodbye!`t`t`t"
                Write-Host -BackgroundColor DarkCyan -ForegroundColor Yellow "`t`t`t`t`t"
                sleep -Seconds 1
                $Host.UI.RawUI.WindowTitle = "Windows PowerShell" # Set back to standard.
                Clear-Host
                Exit-PSSession
            }
        default {
            Write-Host -BackgroundColor Red -ForegroundColor White "You did not enter a valid sub-menu selection. Please enter a valid selection."
            sleep -Seconds 1
                }
        }
    }
return
}

function MSTools()
# This section is used for Loading Main Menu Option 1, .
{
    [bool]$loopSubMenu = $true
    while ($loopSubMenu)
    {
    $Host.UI.RawUI.WindowTitle = "Microsoft Tools Menu"
    Clear-Host  # Clear the screen.
    Write-Host -BackgroundColor Black -ForegroundColor White  "`n`t`tPowerShell Tools`t`n"
    Write-Host -BackgroundColor Black -ForegroundColor White  "`t`tMicrosoft Tools Menu`t`t`n"
    Write-Host "`t`t`t1 - Sub Menu 1 - Option 1"
    Write-Host "`t`t`t2 - Sub Menu 2 - Option 2"
    Write-Host "`t`t`t3 - Sub Menu 3 - Option 3"
    Write-Host "`t`t`tQ --- Quit And Return To Main Menu`n"
    $subMenu = Read-Host "`t`tEnter Sub-Menu 1 Option Number"
        switch ($subMenu)
        {
        1
            {
            loadSubMenu1Option1
            }
        2
            {
            #loadSubMenu2
            }
        3
            {
            #loadSubMenu3
            }
        q
            {
                $loopSubMenu = $false
            }
    default
            {
            Write-Host -BackgroundColor Red -ForegroundColor White "You did not enter a valid sub-menu selection. Please enter a valid selection."
            sleep -Seconds 1
            }
        }
    }
}

function NATools()
# This section is used for Loading Main Menu Option 2, .
{
    [bool]$loopSubMenu = $true
    while ($loopSubMenu)
    {
    $Host.UI.RawUI.WindowTitle = "NetApp Tools Menu"
    Clear-Host  # Clear the screen.
    Write-Host -BackgroundColor Black -ForegroundColor White  "`n`t`tPowerShell Tools`t`n"
    Write-Host -BackgroundColor Black -ForegroundColor White  "`t`NetApp Tools Menu`t`t`n"
    Write-Host "`t`t`tnadoc - Create NetApp Documentation"
    Write-Host "`t`t`t2 - Sub Menu 2 - Option 2"
    Write-Host "`t`t`t3 - Sub Menu 3 - Option 3"
    Write-Host "`t`t`tQ --- Quit And Return To Main Menu`n"
    $subMenu = Read-Host "`t`tEnter Sub-Menu 1 Option Number"
        switch ($subMenu)
        {
        nadoc {
          if (((!(Get-Module -Name netappdocs -ErrorAction SilentlyContinue)) -and  (Get-Module -Name netappdocs -listavailable -ErrorAction SilentlyContinue)) -or (Get-Module -Name netappdocs -ErrorAction SilentlyContinue)) {
            import-module netappdocs
            }
          else {
            Clear-Host
            Write-Host -BackgroundColor Red -ForegroundColor White "`n`n`nNetApp Docs is not installed or is an old version, please install/upgrade!`n`n"
            pause
            $loopSubMenu = $false
          }
          if (!$NACredential) {
            Write-Host "Please enter your NetApp credentials"
            $NACredential = Get-Credential
          }

          $CNAs = (read-host "Enter a comma-separated list of NetApp cDOT Arrays:") -split ","
          $7NAs = (read-host "Enter a comma-separated list of NetApp 7-Mode Arrays:") -split ","

          if ($CNAs) {
            foreach ($CNA in $CNAs) {
              Write-Host "Starting $CNA"
              Get-NtapClusterData -Name $CNA -credential $NACredential -verbose | Format-NtapClusterData | Out-NtapDocument -WordFile c:\"$CNA".docx -ExcelFile c:\"$CNA".xlsx
            }
          }

          if ($7NAs) {
            foreach ($7NA in $7NAs) {
              Write-Host "Starting $7NA"
              Get-NtapClusterData -Name $7NA -credential $NACredential -verbose | Format-NtapClusterData | Out-NtapDocument -WordFile c:\"$7NA".docx -ExcelFile c:\"$7NA".xlsx
            }
          }
          pause
          }
        2 {

          }
        3 {
            #loadSubMenu3
          }
        q {
                $loopSubMenu = $false
          }
    default
          {
            Write-Host -BackgroundColor Red -ForegroundColor White "You did not enter a valid sub-menu selection. Please enter a valid selection."
            sleep -Seconds 1
          }
        }
    }
}

function VCTools()
# This section is used for Loading Main Menu Option 3, .
{
    [bool]$loopSubMenu = $true

    #Load the VMWare modules if not already loaded
      if (((!(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) -and  (Get-Module -Name VMware.VimAutomation.Core -listavailable -ErrorAction SilentlyContinue)) -or (Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
        Invoke-Expression "& '$PSScriptRoot\Initialize-PowerCLIEnvironment.ps1'"
        }
      else {
        Clear-Host
        Write-Host -BackgroundColor Red -ForegroundColor White "`n`n`nPowerCLI not installed or is an old version, please install/upgrade!`n`n"
        pause
        $loopSubMenu = $false
      }

  while ($loopSubMenu)
    {
    $Host.UI.RawUI.WindowTitle = "vCloud Tools Menu"
    Clear-Host  # Clear the screen.
    Write-Host -BackgroundColor Black -ForegroundColor White  "`n`t`tPowerShell Tools`t`n"
    Write-Host -BackgroundColor Black -ForegroundColor White  "`t`VMWare Tools Menu`t`t`n"
    Write-Host "`t`t`t1 - Sub Menu 1 - Option 1"
    Write-Host "`t`t`t2 - Sub Menu 2 - Option 2"
    Write-Host "`t`t`t3 - Sub Menu 3 - Option 3"
    Write-Host "`t`t`tQ --- Quit And Return To Main Menu`n"
    $subMenu = Read-Host "`t`tEnter Sub-Menu 1 Option Number"
        switch ($subMenu)
        {
        1
            {
            loadSubMenu1Option1
            }
        2
            {
              #loadSubMenu2
            }
        3
            {
            #loadSubMenu3
            }
        q
            {
                $loopSubMenu = $false
            }
    default
            {
            Write-Host -BackgroundColor Red -ForegroundColor White "You did not enter a valid sub-menu selection. Please enter a valid selection."
            sleep -Seconds 1
            }
        }
    }
}


function VITools() {
# This section is used for Loading Main Menu Option 4, .

    [bool]$loopSubMenu = $true

    #Load the VMWare modules if not already loaded
      if (((!(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) -and  (Get-Module -Name VMware.VimAutomation.Core -listavailable -ErrorAction SilentlyContinue)) -or (Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
        Invoke-Expression "& '$PSScriptRoot\Initialize-PowerCLIEnvironment.ps1'"
        }
      else {
        Clear-Host
        Write-Host -BackgroundColor Red -ForegroundColor White "`n`n`nPowerCLI not installed or is an old version, please install/upgrade!`n`n"
        pause
        $loopSubMenu = $false
      }

  while ($loopSubMenu) {
    $Host.UI.RawUI.WindowTitle = "vCenter/vSphere Tools Menu"
    Clear-Host  # Clear the screen.
    Write-Host -BackgroundColor Black -ForegroundColor White  "`n`t`tPowerShell Tools`t`n"
    Write-Host -BackgroundColor Black -ForegroundColor White  "`t`VMWare Tools Menu`t`t`n"
    Write-Host "`t`t`t1 - Sub Menu 1 - Option 1"
    Write-Host "`t`t`t2 - Change a VM(s) UUID"
    Write-Host "`t`t`t3 - Check Hosts for the NetApp VAAI Plugin"
    Write-Host "`t`t`t4 - Count CPU Cores for all ESXi Hosts"
    Write-Host "`t`t`tQ --- Quit And Return To Main Menu`n"
    $subMenu = Read-Host "`t`tEnter Sub-Menu 1 Option Number"
        switch ($subMenu)
        {
        1 {
            loadSubMenu1Option1
            }
        2 {
            Clear-Host
            Invoke-Expression "& '$PSScriptRoot\VMWare\vSphere_GenerateNewUUID.ps1'"
            Pause
            }
        3 {
            Clear-Host
            Invoke-Expression "& '$PSScriptRoot\VMWare\vSphere_Check_NA-VAAI.ps1'"
            Pause
            }
        4 {
            Clear-Host
            Invoke-Expression "& '$PSScriptRoot\VMWare\vSphere_Cores-Per_Host.ps1'"
            Pause
            }
        q {
            $loopSubMenu = $false
            }
    default
            {
            Write-Host -BackgroundColor Red -ForegroundColor White "You did not enter a valid sub-menu selection. Please enter a valid selection."
            sleep -Seconds 1
            }
        }
    }
}

# Start the Menu once loaded:
loadMainMenu

# Extras:
if ($clearHost) {Clear-Host}
if ($exitSession) {Exit-PSSession};
