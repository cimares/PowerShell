 Param
	(
	[Parameter(Mandatory=$True, HelpMessage="You must provide a platform suffix so the script can find the paramter file!")]
	[string]$Platform
	)

# this script will start the service instances for sharepoint. simples.
# as we are doing things for learning purposes, this script is slightly unusual!
# follow the comments to make sense of things :)

# let's clean the error variable as we are not starting a fresh session
$Error.Clear()

# setup the parameter file
$parameterfile = "r:\powershell\xml\spconfig-"+$Platform+".xml"

# below we are using regions to show the technique. makes the script foldable in an ISE and easier to read
#REGION load snapins and assemblies
# check for the sharepoint snap-in. this is from Ed Wilson.
$snapinsToCheck = @("Microsoft.SharePoint.PowerShell") #you can add more snapins to this array to load more
$currentSnapins = Get-PSSnapin
$snapinsToCheck | ForEach-Object `
    {$snapin = $_;
        if(($CurrentSnapins | Where-Object {$_.Name -eq "$snapin"}) -eq $null)
        {
            Write-Host "$snapin snapin not found, loading it"
            Add-PSSnapin $snapin
            Write-Host "$snapin snapin loaded"
        }
    }
#ENDREGION

#REGION variables
# get the variables from the parameter file
Try {
	# here we are turning a non-terminating error into a terminating error if the file does not exist, this is so we can catch it
	[xml]$configdata = Get-Content $parameterfile -ErrorAction Stop
}
Catch {
	Write-Warning "There is no parameter file called $parameterfile!"
	Break
}
#ENDREGION

#REGION Function Declaration
# in this region we are showing the declaration of a function that will be called later in the script.
# this example is very simple as it is not necessary to pass parameters to the function due to how it is called
# most functions would accept parameterised input of some type under normal cirumstances.
# I'm also being slightly naughty not showing how to correctly construct the beginning of a function to include information
# about the funtion that can be invoked from the command line such as a description, examples or notes.

Function Start-SPFarmServiceInstances {
	# here we are showing the use of Trap.  
	# Although clunky, Trap has its uses as it runs at the scope of its execution.
	# in this case as the trap is contained within the function, even if an error is trapped, the script can continue beyond the function 
	# and report that the service instance start failed
	Trap {"Starting the Service Instance $($serviceinstance.typename) on server $($serviceinstance.server) failed!"; break;}
	$serviceinstances = Get-SPServiceInstance | Where-Object {($_.typename -eq $serviceinstancetoenable) -and ($($_.server.name) -eq $($server.name))}
	foreach ($serviceinstance in $serviceinstances) {
		$instanceidentity = $serviceinstance.id
		$instancename = $serviceinstance.typename
		$serveridentity = $serviceinstance.Server
		$instanceenabled = $serviceinstance.Status
		if ($instanceenabled -eq "Disabled") {
			Start-SPServiceInstance $instanceidentity | Out-Null
			Write-Host "INFO: Starting $serviceinstancetoenable on $($serveridentity.name), please wait." -NoNewline -ForegroundColor Yellow
			# here we are using a do...while loop to periodically test for a condition (in this case the service instance being started)
			# in essence the loop continues looping until the condition (the instance is online) is $TRUE
			do 	{
				sleep -Seconds 3
				$instancestarted = Get-SPServiceInstance -Identity $instanceidentity
				$instancestartedcheck = $instancestarted.Status
				Write-Host "." -NoNewline 
			} 
			while ($instancestartedcheck -ne "Online")
			Write-Host "Done!" -BackgroundColor DarkGreen
			Write-Host ""
		}
	}
}
#ENDREGION

# As we are using a function the actual work is not started until we get to this point
# Loop through the parameter file to spin up the service instances by calling the function to start the service instances
# The nested foreach loop through each required service instance for each server
Write-Host
foreach ($server in $configdata.farm.servers.ChildNodes) {
	foreach ($serviceinstancetoenable in $server.serviceinstances.instance) {
		Start-SPFarmServiceInstances
	}
}

Write-Host
# just to be different, we are reporting success/failure and dumping the output file in a slightly different way
if (!$error) {
	Write-Host "SUCCESS: Service instances now started." -BackgroundColor DarkGreen
	Out-File $env:USERPROFILE\desktop\$(($MyInvocation).mycommand.name)' completed'.txt
}
if ($Error) {
	Write-Warning 'Some service instances may not have started correctly, please review!'
	start-process "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\BIN\psconfigui.exe" -argumentlist "-cmd showcentraladmin"
	Out-File $env:USERPROFILE\desktop\$(($MyInvocation).mycommand.name)' failed'.txt
	}
Write-Host

#    The PowerShell Tutorial for SharePoint 2016
#    Copyright (C) 2015 Seb Matthews
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.