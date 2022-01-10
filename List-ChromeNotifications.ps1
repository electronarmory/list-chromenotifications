<#
  .SYNOPSIS
  Returns list of allowed Chrome notifications.
  .DESCRIPTION
  The List-ChromeNotifications.ps1 script searches each user and Chrome profile,
  enumerates the allowed notifications from each Preferences file and outputs a list.
  .PARAMETER output
  Specifies the output format. Options are json and table. 
  Default is table.
  .INPUTS
  None. You cannot pipe objects to List-ChromeNotifications.ps1.
  .OUTPUTS
  A table with the list of allowed Chrome notifications.
  .EXAMPLE
  PS> .\List-ChromeNotifications.ps1
  .EXAMPLE
  PS> .\List-ChromeNotifications.ps1 -output json
#>

param(
    [string]$output = "table"
)

$userdir = "$env:SystemDrive\Users\"
$users = Get-ChildItem $userdir
$cpuname = $env:COMPUTERNAME
$notificationlist = @()

Foreach($user in $users){
    $username_string = $user.Name
    $BaseDir = "$userdir$user\AppData\Local\Google\Chrome\User Data"
    #Write-Output "Analyzing user $user"

    try{
        # Find files named Preferences inside \AppData\Local\Google\Chrome\User Data for each user. This works for multiple Chrome profiles. 
        $preferencefiles = Get-ChildItem $BaseDir -Recurse -Depth 2 -ErrorAction Stop | Where-Object { $_.Name.Equals("Preferences") }
        foreach($pref in $preferencefiles){
            # For each Preferences file, should be one for every active Chrome profile (Default, Profile 1, Profile 2, etc) for each user
            try{
                #Write-Output "Attempting to open Preferences file " + $pref.FullName
                $prefjson = (Get-Content $pref.FullName -Raw) | ConvertFrom-Json
                
                # Grab the JSON for the notifications and parse looking for allowed notifications (setting=1)   
                # Sample: https://testnotificationsite.com,*=@{expiration=0; last_modified=13285405629693768; model=0; setting=1}             
                Foreach($note in @($prefjson.profile.content_settings.exceptions.notifications.psobject.properties)){                 
                    # Iterate through notification properties looking for "setting" to determine if notification is allowed 
                    foreach($child in @($note.Value.psobject.properties | where-object {$_.MemberType -eq "NoteProperty"})){
                        if($child.Name.ToString() -eq "setting"){
                            if($child.Value -eq 1){
                                # Notification is enabled, add it to list
                                $tempnotification = New-Object System.Object
                                $cleanedurl = $note.Name -replace '[,*]',''   # Removes ,* at end of URLs
                                $tempnotification | Add-Member -MemberType NoteProperty -Name Computer -Value $cpuname
                                $tempnotification | Add-Member -MemberType NoteProperty -Name Username -Value $username_string
                                $tempnotification | Add-Member -MemberType NoteProperty -Name Profile -Value $pref.FullName.Split('\')[8]
                                $tempnotification | Add-Member -MemberType NoteProperty -Name "Notification Site" -Value $cleanedurl;
                                $tempnotification | Add-Member -MemberType NoteProperty -Name Setting -Value "Allowed";
                                $notificationlist += $tempnotification
                            }
                            #elseif($child.Value -eq 2){
                            #    $tempnotification | Add-Member -MemberType NoteProperty -Name Setting -Value "Not Allowed";
                            #}
                        }
                        #elseif($child.Name.ToString() -eq "last_modified"){
                        #    $tempnotification | Add-Member -MemberType NoteProperty -Name last_modified -Value $child.Value;
                        #    Can't find a Powershell command that converts Chrome's Webkit times to something readable
                        #}
                        
                    }
                }
            }
            catch{
                #Write-Error "Failed to open Preferences file."
                Write-Output $_
            }
        }
    }
    catch{}
}

# Output notifications
if($notificationlist.Length -gt 0){
    if($output -like "json"){
        $notificationlist | ConvertTo-Json | Out-String
    }
    else{
        $notificationlist | ft
    }
}
else{
        Write-Output "No allowed Chrome Notifications found."
}
