Write-host " _____ _   _           _                                              _                 "
Write-host "|_   _| | ( )         | |                                            | |                "
Write-host "  | | | |_|/ ___    __| | __ _ _ __   __ _  ___ _ __ ___  _   _ ___  | |_ ___           "
Write-host "  | | | __| / __|  / _' |/ _' | '_ \ / _' |/ _ \ '__/ _ \| | | / __| | __/ _ \          "
Write-host " _| |_| |_  \__ \ | (_| | (_| | | | | (_| |  __/ | | (_) | |_| \__ \ | || (_) |         "
Write-host "|_____|\__| |___/  \__,_|\__,_|_| |_|\__, |\___|_|__\___/ \__,_|___/  \__\___/  _       "
Write-host "                        | |           __/ || | |__   __|  | |        | | | |   (_)      "
Write-host "      __ _  ___     __ _| | ___  _ __|___/_| |    | | __ _| | _____  | |_| |__  _ ___   "
Write-host "     / _' |/ _ \   / _' | |/ _ \| '_ \ / _ \ |    | |/ _' | |/ / _ \ | __| '_ \| / __|  "
Write-host "    | (_| | (_) | | (_| | | (_) | | | |  __/_|    | | (_| |   <  __/ | |_| | | | \__ \  "
Write-host "     \__, |\___/   \__,_|_|\___/|_| |_|\___(_)    |_|\__,_|_|\_\___|  \__|_| |_|_|___(_)"
Write-host "      __/ |                                                                             "
Write-host "     |___/             ""You know a tool is great when it has an ascii-art header""     "
Write-host "                                                                                        "

function Get-WritableServicePaths {
    <#
    .SYNOPSIS
    It's dangerous to go alone! Take this.
    .DESCRIPTION
    A small tool to find ps1 scripts that can be manipulated.
    .PARAMETER All
    Lists all script executions found in the Windows PowerShell event log.
    .INPUTS
    None.
    .OUTPUTS
    Might return something useful, try poking it with a stick.
    .EXAMPLE
    PS> Get-WritablePSScripts
    .LINK
    https://github.com/robertteir
    #>

    param(
        [switch] $All
    )

    $results = @()

    $services = Get-WmiObject win32_service | select Name, DisplayName, State, PathName, StartName

    foreach ($service in $services | where-object { $_.PathName -ne $null })
    {
        if($service.PathName.Replace('"','') -match '^[A-Za-z]:\\.*\.exe\b') {
            $path = $Matches[0].SubString(0, $Matches[0].LastIndexOf('\'))
            $access = $null
            $owner = $null
            $can_read = $null
            $can_write = $null
            if($results.FilePath -notcontains $path) {
                $can_read = $true
                $can_write = $true
                if(Test-Path $path)
                {
                    $acl = Get-Acl $path
                    $access = $acl.AccessToString
                    $owner = $acl.Owner
                    Try {
			            $guid = [guid]::NewGuid().ToString()
                        [io.file]::Create($path + "\" + $guid).close()
			            [io.file]::Delete($path + "\" + $guid)
                    } Catch {
                        $can_write = $false
                    } 
                }
                else {
                    $can_read = $false
                    $can_write = $false
                }
            }
            ElseIf ($all) {
                $can_read = $null
                $can_write = $null
            }
            else {
                continue
            }
            $result = [PSCustomObject]@{
                FilePath = $path
                RunningAs = $service.StartName
                CanRead = $can_read
                CanWrite = $can_write
                Access  = $access
                Owner = $owner
            }
            $results += $result
        }
    }
    $defaultDisplaySet = 'RunningAs','FilePath','CanWrite'
    $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
    $results | Add-Member MemberSet PSStandardMembers $PSStandardMembers

    return $results
}

function Get-WritablePSScripts {
    <#
    .SYNOPSIS
    It's dangerous to go alone! Take this.
    .DESCRIPTION
    A small tool to find ps1 scripts that can be manipulated.
    .PARAMETER All
    Lists all script executions found in the Windows PowerShell event log.
    .INPUTS
    None.
    .OUTPUTS
    Might return something useful, try poking it with a stick.
    .EXAMPLE
    PS> Get-ExecutedPSScripts -all
    .LINK
    https://github.com/robertteir
    #>

    param(
        [switch] $All
    )

    $results = @()
    $events= Get-WinEvent -FilterHashTable @{ LogName = "Windows PowerShell"; ID = 400;} | Where-Object {$_.message -like "*.ps1*"}
    foreach($event in $events) {
        if($event.Message.ToString().replace("`t", '').Trim() -match '\b[A-Za-z]:\\.*\.ps1') {
            $values = [regex]::split($Matches[0], '(-.*[ ])')
            foreach ($value in $values) {
                if($value -match '[A-Za-z]:\\.*\.ps1') {
                    $file = $Matches[0]
                    $access = $null
                    $owner = $null
                    $can_read = $null
                    $can_write = $null
                    if($results.FilePath -notcontains $file) {
                        $can_read = $true
                        $can_write = $true
                        if(Test-Path $file)
                        {
                            $acl = Get-Acl $file
                            $access = $acl.AccessToString
                            $owner = $acl.Owner
                            Try {
                                [io.file]::OpenWrite($file).close() 
                            } Catch {
                                $can_write = $false
                            } 
                        }
                        else {
                            $can_read = $false
                            $can_write = $false
                        }
                    }
                    ElseIf ($all) {
                        $can_read = $null
                        $can_write = $null
                    }
                    else {
                        continue
                    }
                    $result = [PSCustomObject]@{
                        DateTime = $event.TimeCreated
                        FilePath = $file
                        CanRead = $can_read
                        CanWrite = $can_write
                        Access  = $access
                        Owner = $owner
                    }
                    $results += $result
                }   
            }
        }
    }
    $defaultDisplaySet = 'DateTime','FilePath','CanWrite'
    $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultDisplaySet)
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
    $results | Add-Member MemberSet PSStandardMembers $PSStandardMembers

    return $results
}
