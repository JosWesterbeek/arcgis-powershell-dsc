<#
    .SYNOPSIS
        Enables or disables the services directory for ArcGIS Server
    .PARAMETER Enabled
        - $true ensures the services directory is enabled.
        - $false ensures the services directory is disabled.
    .PARAMETER SiteName
        Site Name or Default Context of Server.
    .PARAMETER SiteAdministrator
        A MSFT_Credential Object - Primary Site Adminstrator
#>

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
        $SiteName,

        [parameter(Mandatory = $false)]
        [System.Boolean]
        $Enabled = $true,

		[System.Management.Automation.PSCredential]
		$SiteAdministrator
	)

    Import-Module $PSScriptRoot\..\..\ArcGISUtility.psm1 -Verbose:$false

	$null # TODO
}

function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
        $SiteName,

        [parameter(Mandatory = $false)]
        [System.Boolean]
        $Enabled = $true,

		[System.Management.Automation.PSCredential]
		$SiteAdministrator
	)

    Import-Module $PSScriptRoot\..\..\ArcGISUtility.psm1 -Verbose:$false

	$FQDN = Get-FQDN $env:COMPUTERNAME
    $ServerUrl = "http://$($FQDN):6080"
    Wait-ForUrl -Url "$($ServerUrl)/$SiteName/admin/" -MaxWaitTimeInSeconds 60 -HttpMethod 'GET'
    $Referer = $ServerUrl

    $token = Get-ServerToken -ServerEndPoint $ServerUrl -ServerSiteName $SiteName -Credential $SiteAdministrator -Referer $Referer

    if($Enabled -eq $true){$dirEnabled = 'true'}
    else{$dirEnabled = 'false'}

    $servicesdirectory = Get-AdminSettings -ServerUrl $ServerUrl -SettingUrl "$SiteName/admin/system/handlers/rest/servicesdirectory" -Token $token.token -Referer $Referer
    Write-Verbose "Services Directory Enabled: $($servicesdirectory.enabled)"
    $servicesdirectory.enabled = $dirEnabled
    $servicesdirectory = ConvertTo-Json $servicesdirectory
    Set-AdminSettings -ServerUrl $ServerUrl -SettingUrl "$SiteName/admin/system/handlers/rest/servicesdirectory/edit" -Token $token.token -Properties $servicesdirectory -Referer $Referer
}

function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
        $SiteName,

        [parameter(Mandatory = $false)]
        [System.Boolean]
        $Enabled = $true,

		[System.Management.Automation.PSCredential]
		$SiteAdministrator
	)

    Import-Module $PSScriptRoot\..\..\ArcGISUtility.psm1 -Verbose:$false

    [System.Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
    $result = $false

    $FQDN = Get-FQDN $env:COMPUTERNAME
    $ServerUrl = "http://$($FQDN):6080"

    Wait-ForUrl -Url "$($ServerUrl)/$SiteName/admin/" -MaxWaitTimeInSeconds 60 -HttpMethod 'GET'

    $Referer = $ServerUrl
    $token = Get-ServerToken -ServerEndPoint $ServerUrl -ServerSiteName $SiteName -Credential $SiteAdministrator -Referer $Referer
  
    if(-not($token.token)){
        throw "Unable to retrieve token for Site Administrator"
    }

    $servicesdirectory = Get-AdminSettings -ServerUrl $ServerUrl -SettingUrl "$SiteName/admin/system/handlers/rest/servicesdirectory" -Token $token.token -Referer $Referer

    if($Enabled -ieq $true -and $($servicesdirectory.enabled) -eq 'true') {
        $result = $true
    }
    elseif($Enabled -ieq $false -and $($servicesdirectory.enabled) -eq 'false') {
        $result = $true
    }

    Write-Verbose "Services Directory Enabled: $($servicesdirectory.enabled)"
    Write-Verbose "Returning $result from Test-TargetResource"
    $result
}

function Get-AdminSettings
{
    [CmdletBinding()]
    Param
    (
        [System.String]
        $ServerUrl,

        [System.String]
        $SettingUrl,

        [System.String]
        $Token,

        [System.String]
        $Referer
    )

    $RequestUrl  = $ServerUrl.TrimEnd("/") + "/" + $SettingUrl.TrimStart("/")
    $props = @{ f= 'json'; token = $Token; }
    $cmdBody = To-HttpBody $props
    $headers = @{'Content-type'='application/x-www-form-urlencoded'
                'Content-Length' = $cmdBody.Length
                'Accept' = 'text/plain'
                'Referer' = $Referer
                }

    $res = Invoke-WebRequest -Uri $RequestUrl -Body $cmdBody -Method POST -Headers $headers -UseDefaultCredentials -DisableKeepAlive -UseBasicParsing
    $response = $res.Content | ConvertFrom-Json
    Write-Verbose "Response from Get-AdminSettings ($RequestUrl):- $($res.Content)"
    Check-ResponseStatus $response
    $response
}

function Set-AdminSettings
{
    [CmdletBinding()]
    Param
    (
        [System.String]
        $ServerUrl,

        [System.String]
        $SettingUrl,

        [System.String]
        $Token,

        [System.String]
        $Referer,

        [System.String]
        $Properties
    )

    $COProperties = $Properties | ConvertFrom-Json
    $RequestUrl  = $ServerUrl.TrimEnd("/") + "/" + $SettingUrl.TrimStart("/")
    $props = @{ f= 'json'; token = $Token; }
    $COProperties.psobject.properties | Foreach { $props[$_.Name] = $_.Value }
    if ($props['enabled'])
    {
        $props['servicesDirEnabled'] = $props['enabled']
    }
    $cmdBody = To-HttpBody $props
    $headers = @{'Content-type'='application/x-www-form-urlencoded'
                'Content-Length' = $cmdBody.Length
                'Accept' = 'text/plain'
                'Referer' = $Referer
                }
    $res = Invoke-WebRequest -Uri $RequestUrl -Body $cmdBody -Method POST -Headers $headers -UseDefaultCredentials -DisableKeepAlive -UseBasicParsing
    $response = $res.Content | ConvertFrom-Json
    Write-Verbose "Response from Set-AdminSettings ($RequestUrl):- $($res.Content)"
    Check-ResponseStatus $response
    $response
}

Export-ModuleMember -Function *-TargetResource