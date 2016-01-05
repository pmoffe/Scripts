<#
.SYNOPSIS
   Produces menu for performing Snapmirror tasks using the Data ONTAP PowerShell Toolkit.
.DESCRIPTION
   This script creates a console-based menu giving the user a set of options to choose in
   order to perform basic Snapmirror tasks: update, quiesce, break, resume, resync, and status.
.NOTES
   Author: David Maldonado
   Date: 12/11/2013
.PARAMETER DestController
   The destination Data ONTAP storage controller.
.EXAMPLE
   netapp-snapmirror-menu -DestController ControllerA1
#>
 
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true,
        HelpMessage='Name of destination Data ONTAP storage controller'
    )]
    [String]
    $DestController
) 
 
Import-Module DataONTAP
 
Write-Host "..status..connecting" -foregroundcolor "yellow"
Connect-NaController $DestController -Credential (Get-Credential)
 
Write-Host "..status..connected" -foregroundcolor "yellow"
 
function Read-Choice {
    Param(
        [System.String]$Message,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]$Choices,
        [System.Int32]$DefaultChoice = 1,
        [System.String]$Title = [string]::Empty
    )
    [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices | ForEach-Object {
        New-Object System.Management.Automation.Host.ChoiceDescription "&$($_)", "Sets $_ as an answer."
    }
    $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice )
}
 
    Write-Output "`nController $DestController contains the following snapmirror pairs:`n"
    $Targetdest = Get-NaSnapmirror | Select Destination #| Where {$_.Destination -like "$DestController*"}
    $Targetdest | ForEach-Object { $Id = 0 } { Write-Host "$Id : $_"; $ID++ }
    $Mychoice = $Targetdest[(Read-Choice -Message "`nChoose Snapmirror Destination " `
        -Choices (0..($ID - 1)))]
    Write-Host "You selected $Mychoice"
 
    $Snapmirrorpair = Get-NaSnapmirror | Where {$_.Destination -like $Mychoice.destination}
 
    Do {
        $Title = "SnapMirror Menu"
        $Message = "What do you want to do?"
 
        $Update = New-Object System.Management.Automation.Host.ChoiceDescription "&Update", `
        "Starts a transfer over the network for a specific destination."
 
        $Quiesce = New-Object System.Management.Automation.Host.ChoiceDescription "&Quiesce", `
        "Pauses transfers to the destination."
 
        $Break = New-Object System.Management.Automation.Host.ChoiceDescription "&Break", `
        "Breaks a snapmirrored relationship."
 
        $Resume = New-Object System.Management.Automation.Host.ChoiceDescription "&Resume", `
        "Resumes transfers to the destination that were quiesced."
 
        $Resync = New-Object System.Management.Automation.Host.ChoiceDescription "&Pair Resync", `
        "Kicks off a resync of a broken snapmirrored pair."
 
        $Status = New-Object System.Management.Automation.Host.ChoiceDescription "&Status", `
        "Returns the SnapMirror status."
 
        $Exit = New-Object System.Management.Automation.Host.ChoiceDescription "&Exit", `
        "Exits the menu."
 
        $Options = [System.Management.Automation.Host.ChoiceDescription[]]($Update, $Quiesce, $Break,
        $Resume, $Resync, $Status, $Exit)
 
        $Result = $Host.ui.PromptForChoice($Title, $Message, $Options, 6) 
 
        switch ($Result)
        {
            0 {"You selected Update."
                Write-Host "..updating snapmirror pair" -foregroundcolor "yellow"
                $Snapmirrorpair | Invoke-NaSnapmirrorUpdate
            }
            1 {"You selected Quiesce."
                Write-Host "..quiescing snapmirror pair" -foregroundcolor "yellow"
                $Snapmirrorpair | Invoke-NaSnapmirrorQuiesce
            }
            2 {"You selected Break."
                Write-Host "..breaking snapmirror pair" -foregroundcolor "yellow"
                $Snapmirrorpair | Invoke-NaSnapmirrorBreak
            }
            3 {"You selected Resume."
                Write-Host "..resuming snapmirror pair" -foregroundcolor "yellow"
                $Snapmirrorpair | Invoke-NaSnapmirrorResume
            }
            4 {"You selected Resync."
                Write-Host "..resyncing snapmirror pair" -foregroundcolor "yellow"
                $Snapmirrorpair | Invoke-NaSnapmirrorResync
            }
            5 {"You selected Status."
                Write-Host "..returning snapmirror status" -foregroundcolor "yellow"
                $Snapmirrorpair
            }
            6 {"You selected Exit."
                Write-Host "..exiting" -foregroundcolor "yellow"
                exit
            }
        }
 
    }
    Until ($result -eq 6)