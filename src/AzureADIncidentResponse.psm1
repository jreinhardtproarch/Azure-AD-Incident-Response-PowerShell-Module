# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
#############################################################################################################
#############################################################################################################
<#
    #############################################
    AZURE AD INCIDENT RESPONSE POWERSHELL MODULE
    #############################################

    Included functions:

    1) CONNECTIVITY
        * Connect-AzureADIR
        * Get-AzureADIRApiToken
        * Get-AzureADIRTenantId
        * Get-AzureADIRHeader
        * Invoke-AzureADIRDoWhile
        * Invoke-AzureADIRWebRequest

    2) DOMAINS
        * Get-AzureADIRDomainRegistrationDetail

    3) APPLICATIONS
        * Get-AzureADIRPermission

    4) ACTIVITY
        * Get-AzureADIRSignInDetail
        * Get-AzureADIRAuditActivity
        * Get-AzureADIRDismissedUserRisk
        * Get-AzureADIRSsprUsageHistory
        * Get-AzureADIRUserLastSignInActivity

    5) PRIVILEGE
        * Get-AzureADIRPrivilegedRoleAssignment
        * Get-AzureADIRPrivilegedUserOnPremCorrelation
        * Get-AzureADIRPimPrivilegedRoleAssignment
        * Get-AzureADIRPimPrivilegedRoleAssignmentRequest

    6) SECURITY CREDENTIALS
        * Get-AzureADIRMfaAuthMethodAnalysis
        * Get-AzureADIRMfaPhoneToLocationCheck

    7) POLICIES
        * Get-AzureADIRConditionalAccessPolicy

    8) MISC
        * Get-AzureADIRObjectIdToDisplayName
        * Get-AzureADIRDisplayNameToObjectId


    Least privilege:

        * Run the module as GLOBAL READER in Azure AD roles


    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service. 
    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
    implied warranties including, without limitation, any implied warranties of merchantability
    or of fitness for a particular purpose. The entire risk arising out of the use or performance
    of the sample and documentation remains with you. In no event shall Microsoft, its authors,
    or anyone else involved in the creation, production, or delivery of the script be liable for 
    any damages whatsoever (including, without limitation, damages for loss of business profits, 
    business interruption, loss of business information, or other pecuniary loss) arising out of 
    the use of or inability to use the sample or documentation, even if Microsoft has been advised 
    of the possibility of such damages, rising out of the use of or inability to use the sample script, 
    even if Microsoft has been advised of the possibility of such damages. 

#>
#############################################################################################################


#Author: Ian Farr (PoSh Chap)
#(c) 2020 Microsoft. All rights reserved.

$VerbosePreference = "Continue"


#############################################################################################################


#################################
#################################
#region 1) CONNECTIVITY


###############################
#FUNCTION: Connect-AzureADIR
###############################

function Connect-AzureADIR {

    ############################################################################

    <#
    .SYNOPSIS

        Autheticate to the Microsoft Graph API and Azure AD Graph API. 
        
        Use the obtained tokens to authenticate to the Azure AD PowerShell 
        and the MSOnline modules.


    .DESCRIPTION

        Performs the following in order:
        
        1) Obtains tokens for MS Graph API / Azure AD Graph API

        2) Connect to the Azure AD PowerShell module

        3) Connect to MSOnline PowerShell module.


    .EXAMPLE

        Connect-AzureADIR -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f

        Connect to the tenant ID - b446a536-cb76-4360-a8bb-6593cf4d9c7f for:
        
            1) MS Graph API / Azure AD Graph API
            2) Azure AD PowerShell
            3) MSOnline PowerShell


    .EXAMPLE

        Connect-AzureADIR -TenantId (Get-AzureADIRTenantId -DomainName test.info)

        Use the Get-AzureADIRTenantId cmdlet to obtain a tenant ID for
        test.info. Then connects to the supplied tenant ID.


    .EXAMPLE

        Connect-AzureADIR -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -UserUpn Bob@contoso.com

        Connect to the tenant ID - b446a536-cb76-4360-a8bb-6593cf4d9c7f as user Bob@contoso.com for:

            1) MS Graph API / Azur AD Graph API
            2) Azure AD PowerShell
            3) MSOnline PowerShell


    #>

    ############################################################################

    [CmdletBinding()]
    param(

        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #A login hint
        [Parameter(Position=1)]
        [string]$UserUpn

        )


    ############################################################################


    ########################
    ##Microsoft Graph Token
    if ($UserUpn) {
        
        Write-Verbose -Message "$(Get-Date -f T) - Obtaining MS Graph access token..."
        $MsGraphResponse = Get-AzureADIRApiToken -TenantId $TenantId -LoginHint $UserUpn

        if ($MsGraphResponse) {

            Write-Verbose -Message "$(Get-Date -f T) - Obtaining Azure AD Graph access token..."
            $AadGraphResponse = Get-AzureADIRApiToken -TenantId $TenantId -LoginHint $UserUpn -AadGraph

        }

    }
    else {

        Write-Verbose -Message "$(Get-Date -f T) - Obtaining MS Graph access token..."
        $MSGraphResponse = Get-AzureADIRApiToken -TenantId $TenantId

        if ($MsGraphResponse) {

            Write-Verbose -Message "$(Get-Date -f T) - Obtaining Azure AD Graph access token..."
            $AadGraphResponse = Get-AzureADIRApiToken -TenantId $TenantId -AadGraph

        }

    }

    ############################
    ##Azure AD PowerShell module

    if ($AadGraphResponse -and $MsGraphResponse) {
    
        #Get tenant details to test that Connect-AzureADIR has been called
        try {$TenantInfo = Get-AzureADTenantDetail -ErrorAction SilentlyContinue}
        catch {}

        if ($TenantInfo) {

            Write-Verbose -Message "$(Get-Date -f T) - A connection for Azure AD Powershell module is already established"
            $InitialDomain = ($TenantInfo.VerifiedDomains | Where-Object {$_.Initial}).Name
            Write-Verbose -Message "$(Get-Date -f T) - Target tenant ID initial domain name - $InitialDomain"

            if ($TenantInfo.ObjectId -eq $TenantId) {

                Write-Verbose -Message "$(Get-Date -f T) - Retrieved tenant ($(($TenantInfo).ObjectId)) matches supplied target tenant ID ($TenantId)"
                $InitialDomain = ($TenantInfo.VerifiedDomains | Where-Object {$_.Initial}).Name
                Write-Verbose -Message "$(Get-Date -f T) - Target tenant ID initial domain name - $InitialDomain"

            }
            else {

                Write-Verbose -Message "$(Get-Date -f T) - Retrieved tenant ($(($TenantInfo).ObjectId)) does not match supplied target tenant ID ($TenantId)"
                Write-Verbose -Message "$(Get-Date -f T) - Disconnecting from $(($TenantInfo).ObjectId) for Azure AD PowerShell module..."

                try {Disconnect-AzureAD -ErrorAction SilentlyContinue}
                catch {}

                #Check if we've disconnected
                if ($?) {
                
                    Write-Verbose -Message "$(Get-Date -f T) - $(($TenantInfo).ObjectId) disconnected"

                    Write-Verbose -Message "$(Get-Date -f T) - Connecting to $TenantId for Azure AD PowerShell module..."

                    if ($UserUpn) {

                        #Silently connect
                        try {Connect-AzureAD -TenantId $TenantId -AccountID $UserUpn -AadAccessToken $AadGraphResponse.AccessToken `
                                                                 -MsAccessToken $MsGraphResponse.AccessToken `
                                                                 -ErrorAction SilentlyContinue | Out-Null}
                        catch {}

                    }
                    else {

                        #Silently connect
                        try {Connect-AzureAD -TenantId $TenantId -AccountId $MsGraphResponse.Account.UserName -AadAccessToken $AadGraphResponse.AccessToken `
                                                                 -MsAccessToken $MsGraphResponse.AccessToken `
                                                                 -ErrorAction SilentlyContinue | Out-Null}
                        catch {}

                    }
            
                    #Check if if Connect-AzureAD works
                    if ($?) {
                
                        Write-Verbose -Message "$(Get-Date -f T) - Connection to $TenantId for Azure AD PowerShell module established"

                        try {$TenantInfo = Get-AzureADTenantDetail -ErrorAction SilentlyContinue}
                        catch {}

                        $InitialDomain = ($TenantInfo.VerifiedDomains | Where-Object {$_.Initial}).Name
                        Write-Verbose -Message "$(Get-Date -f T) - Target tenant ID initial domain name - $InitialDomain"
                    
                    }
                    else {

                        Write-Warning -Message "$(Get-Date -f T) - Connection to $TenantId for Azure AD PowerShell module could not be established"
                        $TenantInfo = $false

                    }

                }
                else {

                    Write-Warning -Message "$(Get-Date -f T) - Could not disconnect from $(($TenantInfo).ObjectId) for Azure AD PowerShell module"
                    $TenantInfo = $false

                }

            }
         }
        else {

            Write-Verbose -Message "$(Get-Date -f T) - Connecting to $TenantId for Azure AD PowerShell module..."

            #Silently connect
            if ($UserUpn) {

                #Silently connect
                try {Connect-AzureAD -TenantId $TenantId -AccountID $UserUpn -AadAccessToken $AadGraphResponse.AccessToken `
                                                            -MsAccessToken $MsGraphResponse.AccessToken `
                                                            -ErrorAction SilentlyContinue | Out-Null}
                catch {}

            }
            else {

                #Silently connect
                try {Connect-AzureAD -TenantId $TenantId -AccountId $MsGraphResponse.Account.UserName -AadAccessToken $AadGraphResponse.AccessToken `
                                                         -MsAccessToken $MsGraphResponse.AccessToken `
                                                          -ErrorAction SilentlyContinue | Out-Null}
                catch {}

                }
            
            #Check if if Connect-AzureAD works
            if ($?) {
                
                Write-Verbose -Message "$(Get-Date -f T) - Connection to $TenantId for Azure AD PowerShell module established"

                try {$TenantInfo = Get-AzureADTenantDetail -ErrorAction SilentlyContinue}
                catch {}

                $InitialDomain = ($TenantInfo.VerifiedDomains | Where-Object {$_.Initial}).Name
                Write-Verbose -Message "$(Get-Date -f T) - Target tenant ID initial domain name - $InitialDomain"
                    
            }
            else {

                Write-Warning -Message "$(Get-Date -f T) - Connection to $TenantId for Azure AD PowerShell module could not be established"
                $TenantInfo = $false

            }

        } 


        #############################
        ##MSOnline PowerShell module

        #Try and connect to the MS Online PowerShell module
        try {$DomainInfo = Get-MsolDomain -TenantId $TenantId -ErrorAction SilentlyContinue}
        catch {}

        if ($DomainInfo) {

            Write-Verbose -Message "$(Get-Date -f T) - Connection to $TenantId for MSOnline PowerShell module established"

        }
        else {

            #Present connection pop-up
            Write-Verbose -Message "$(Get-Date -f T) - Calling Connect-MsolService cmdlet"
            Connect-MsolService -AdGraphAccesstoken $AadGraphResponse.AccessToken -MsGraphAccessToken $MsGraphResponse.AccessToken -ErrorAction SilentlyContinue
            
            #Populate the DomainInfo variable if Connect-MsolService works
            if ($?) {
                
                Write-Verbose -Message "$(Get-Date -f T) - Connection to $TenantId for MSOnline PowerShell module established"
                $DomainInfo = $true
            }
            else {

                Write-Verbose "$(Get-Date -f T) - Connection to $TenantId for MSOnline PowerShell module could not be established"

            }

        }

    }

}   #end function



##################################
#FUNCTION: Get-AzureADIRApiToken
##################################

function Get-AzureADIRApiToken {

    ############################################################################

    <#
    .SYNOPSIS

        Get an access token for use with the API cmdlets.


    .DESCRIPTION

        Uses MSAL.ps to obtain an access token. Has an option to refresh an existing token.


    .EXAMPLE

        Get-AzureADIRApiToken -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f

        Gets or refreshes an access token for making API calls for the tenant ID
        b446a536-cb76-4360-a8bb-6593cf4d9c7f.


    .EXAMPLE

        Get-AzureADIRApiToken -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -ForceRefresh

        Refreshes an access token for making API calls for the tenant ID
        b446a536-cb76-4360-a8bb-6593cf4d9c7f.


    .EXAMPLE

        Get-AzureADIRApiToken -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -LoginHint Bob@Contoso.com

        Gets or refreshes an access token for making API calls for the tenant ID
        b446a536-cb76-4360-a8bb-6593cf4d9c7f and user Bob@Contoso.com.


    .EXAMPLE

        Get-AzureADIRApiToken -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -InterActive

        Gets or refreshes an access token for making API calls for the tenant ID
        b446a536-cb76-4360-a8bb-6593cf4d9c7f. Ensures a pop-up box appears.

    #>

    ############################################################################

    [CmdletBinding(DefaultParameterSetName="InterActive")]
    param(

        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #Force a token refresh
        [Parameter(Position=1,ParameterSetName="ForceRefresh")]
        [switch]$ForceRefresh,

        #The user's upn used for the login hint
        [Parameter(Position=2,ParameterSetName="InterActive")]
        [string]$LoginHint,

        #Force a pop-up box
        [Parameter(Position=3,ParameterSetName="InterActive")]
        [switch]$InterActive,

        #get an Azure AD Graph token
        [Parameter(Position=4)]
        [switch]$AadGraph

    )


    ############################################################################


    #Get an access token using the PowerShell client ID
    $ClientId = "1b730954-1685-4b74-9bfd-dac224a7b894" 
    #$RedirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $Authority = "https://login.microsoftonline.com/$TenantId"

    if ($AadGraph) {

        $Scopes = "https://graph.windows.net/.default"

    }
    else {
    
        $Scopes = "https://graph.microsoft.com/.default"

    }
    

    if ($ForceRefresh) {

        Write-Verbose -Message "$(Get-Date -f T) - Attempting to refresh an existing access token"

        #Attempt to refresh access token
        try {

            $Response = Get-MsalToken -ClientId $ClientId -RedirectUri $RedirectUri -Authority $Authority -Scopes $Scopes -ForceRefresh
        }
        catch {}

        #Error handling for token acquisition
        if ($Response) {

            Write-Verbose -Message "$(Get-Date -f T) - API Access Token refreshed - new expiry: $(($Response).ExpiresOn.UtcDateTime)"

            return $Response

        }
        else {
            
            Write-Warning -Message "$(Get-Date -f T) - Failed to refresh Access Token - try re-running the cmdlet again"

        }

    }
    elseif ($LoginHint) {

        Write-Verbose -Message "$(Get-Date -f T) - Checking token cache with -LoginHint for $LoginHint"

        #Run this to obtain an access token - should prompt on first run to select the account used for future operations
        try {

            if ($InterActive) {

                $Response = Get-MsalToken -ClientId $ClientId -RedirectUri $RedirectUri -Authority $Authority -LoginHint $LoginHint -Scopes $Scopes -Interactive

            } 
            else {

                $Response = Get-MsalToken -ClientId $ClientId -RedirectUri $RedirectUri -Authority $Authority -LoginHint $LoginHint -Scopes $Scopes 

            }
        }
        catch {}

        #Error handling for token acquisition
        if ($Response) {

            Write-Verbose -Message "$(Get-Date -f T) - API Access Token obtained for: $(($Response).Account.Username) ($(($Response).Account.HomeAccountId.ObjectId))"
            #Write-Verbose -Message "$(Get-Date -f T) - API Access Token scopes: $(($Response).Scopes)"

            return $Response

        }
        else {

            Write-Warning -Message "$(Get-Date -f T) - Failed to obtain an Access Token - try re-running the cmdlet again"
            Write-Warning -Message "$(Get-Date -f T) - If the problem persists, use `$Error[0] for more detail on the error or start a new PowerShell session"

        }

    }
    else {

        Write-Verbose -Message "$(Get-Date -f T) - Checking token cache with -Prompt"

        #Run this to obtain an access token - should prompt on first run to select the account used for future operations
        try {

            if ($InterActive) {

                $Response = Get-MsalToken -ClientId $ClientId -RedirectUri $RedirectUri -Authority $Authority -Prompt SelectAccount -Interactive -Scopes $Scopes 

            }
            else {

                $Response = Get-MsalToken -ClientId $ClientId -RedirectUri $RedirectUri -Authority $Authority -Prompt SelectAccount -Scopes $Scopes 

            }

        }
        catch {}

        #Error handling for token acquisition
        if ($Response) {

            Write-Verbose -Message "$(Get-Date -f T) - API Access Token obtained for: $(($Response).Account.Username) ($(($Response).Account.HomeAccountId.ObjectId))"
            #Write-Verbose -Message "$(Get-Date -f T) - API Access Token scopes: $(($Response).Scopes)"

            return $Response

        }
        else {

            Write-Warning -Message "$(Get-Date -f T) - Failed to obtain an Access Token - try re-running the cmdlet again"
            Write-Warning -Message "$(Get-Date -f T) - If the problem persists, run Connect-AzureADIR with the -UserUpn parameter"

        }

    }


}   #end function


###################################
#FUNCTION: Get-AzureADIRTenantId
###################################

function Get-AzureADIRTenantId {

    ############################################################################

    <#
    .SYNOPSIS

        Retrieves the tenant ID for a supplied domain name.


    .DESCRIPTION

        Retrieves the tenant ID for a supplied domain name by querying the 
        \well-known\openid-configuration end point.
       

    .EXAMPLE

        Get-AzureADIRTenantId -DomainName test.info

        Retrives the tenant ID for the domain name test.info.


    .NOTES

        Thanks to Ramiro Calderon!

    #>

    ############################################################################

    [CmdletBinding()]
    param(

        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [string]$DomainName

        )


    ############################################################################

    
    try {
     
        Write-Verbose -Message "$(Get-Date -f T) - Obtaining tenant ID for $DomainName"

        $RawResult = Invoke-WebRequest "https://login.microsoftonline.com/$DomainName/v2.0/.well-known/openid-configuration" -ErrorAction SilentlyContinue -Verbose:$false
        $ObjectResult = $RawResult | ConvertFrom-Json 
        $Endpoint = $ObjectResult.authorization_endpoint 
        $EndpointUri = [Uri]$Endpoint 
 
        Write-Verbose -Message "$(Get-Date -f T) - Target tenant ID - $($EndpointUri.Segments[1].Trim('/'))"
        Write-Output $EndpointUri.Segments[1].Trim('/')


    } 
    catch { 

        Write-Warning -Message "$(Get-Date -f T) - Domain not found" 

    } 


}   #end function


#################################
#FUNCTION: Get-AzureADIRHeader
#################################

function Get-AzureADIRHeader {

    ############################################################################

    <#
    .SYNOPSIS

        Uses a supplied Access Token to construct a header for a an API call.


    .DESCRIPTION

        Uses a supplied Access Token to construct a header for a an API call with 
        Invoke-WebRequest.

        Can supply the ConsistencyLevel = Eventual parameter for performing Count
        activities.


    .EXAMPLE

        Get-AzureADIRHeader -Token $Token

        Constructs a header with an obtained token for using with Invoke-WebRequest.


    .EXAMPLE

        Get-AzureADIRHeader -Token $Token -ConsistencyLevelEventual

        Constructs a header with an obtained token for using with Invoke-WebRequest.

        Uses the optional -ConsistencyLevelEventual switch for use in conjunction with
        the count call.

    #>

    ############################################################################
    
    [CmdletBinding()]
    param(

        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [string]$Token,

        #Switch to include ConsistencyLevel = Eventual for $count operations
        [Parameter(Position=1)]
        [switch]$ConsistencyLevelEventual

        )

    ############################################################################

    if ($ConsistencyLevelEventual) {

        return @{

            "Authorization" = ("Bearer {0}" -f $Token);
            "Content-Type" = "application/json";
             "ConsistencyLevel" = "eventual";

        }

    }
    else {

        return @{

            "Authorization" = ("Bearer {0}" -f $Token);
            "Content-Type" = "application/json";

        }

    }

}   #end function


##################################
#FUNCTION: Get-AzureADIRDoWhile
##################################

function Invoke-AzureADIRDoWhile {

    ############################################################################

    <#
    .SYNOPSIS

        Performs the API pagination loop.


    .DESCRIPTION

        Calls the Invoke-AzureADIRWebRequest to obtain target information with 
        a supplied query URL and authentication header.

        Handles pagination with @odata.nextLink.

        Adds the returned content for each call to an array that is ultimately 
        returned by the function.


    .EXAMPLE

        Invoke-AzureADIRDoWhile -Header $Header -Url $Url

        Calls the Invoke-AzureADIRWebRequest to obtain target information with 
        a supplied query URL and authentication header.


    #>

    ############################################################################

    [CmdletBinding()]
    param(

        #The header for the API call
        [Parameter(Mandatory,Position=0)]
        $Header,

        #the query Url 
        [Parameter(Mandatory,Position=1)]
        [string]$Url

        )

    ############################################################################

    
    ######################################
    ##Do while the fetch URL is populated
    do {

        Write-Verbose -Message "$(Get-Date -f T) - Invoking web request for $Url"

        $MyReport = Invoke-AzureADIRWebRequest -Header $Header -Url $Url


        ###############################
        #Convert the content from JSON
        $ConvertedReport = ($MyReport.Content | ConvertFrom-Json).value

        #Add to concatenated findings
        [array]$TotalReport += $ConvertedReport

        #Update the fetch url to include the paging element
        $Url = ($myReport.Content | ConvertFrom-Json).'@odata.nextLink'

        #Update the access token on the second iteration
        if ($OneSuccessfulFetch) {
                
            $Token = (Get-AzureADIRApiToken -TenantId $TenantId -ForceRefresh).AccessToken
            $Header = Get-AzureADIRHeader -Token $Token

        }

        #Update count and show for this cycle
        $Count = $Count + $ConvertedReport.Count
        Write-Verbose -Message "$(Get-Date -f T) - Total records fetched: $count"

        #Update tracking variables
        $OneSuccessfulFetch = $true


    } while ($Url) #end do / while

    return $TotalReport

}   #end function


#######################################
#FUNCTION: Invoke-AzureADIRWebRequest
#######################################

function Invoke-AzureADIRWebRequest {

    ############################################################################

    <#
    .SYNOPSIS

        Perform Invoke-WebRequest with additional error handling.


    .DESCRIPTION

        Perform Invoke-WebRequest with additional error handling for supplied
        query URL and authentication header.

        Has retry logic.

    .EXAMPLE

        Invoke-AzureADIRWebRequest -Header $Header -Url $Url

        Calls Invoke-Webrequest with the supplied authentication header and query
        URL with error checking and retry logic.


    #>

    ############################################################################

    [CmdletBinding()]
    param(

        #The header for the API call
        [Parameter(Mandatory,Position=0)]
        $Header,

        #the query Url 
        [Parameter(Mandatory,Position=1)]
        [string]$Url

        )

    ############################################################################
    
    $RetryCount = 0


    ##################################
    #Do our stuff with error handling
    try {

        #Invoke the web request
        $MyReport = (Invoke-WebRequest -UseBasicParsing -Headers $Header -Uri $Url -Verbose:$false)

    }
    catch [System.Net.WebException] {
        
        $StatusCode = [int]$_.Exception.Response.StatusCode
        Write-Warning -Message "$(Get-Date -f T) - $($_.Exception.Message)"

        #Check what's gone wrong
        if (($StatusCode -eq 401) -and ($OneSuccessfulFetch)) {

            #Token might have expired; renew token and try again
            $Token = (Get-AzureADIRApiToken -TenantId $TenantId -InterActive).AccessToken
            $Header = Get-AzureADIRHeader -Token $Token
            $OneSuccessfulFetch = $False

        }
        elseif (($StatusCode -eq 429) -or ($StatusCode -eq 504) -or ($StatusCode -eq 503)) {

            #Throttled request or a temporary issue, wait for a few seconds and retry
            Start-Sleep -Seconds 5

        }
        elseif (($StatusCode -eq 403) -or ($StatusCode -eq 401)) {

            Write-Warning -Message "$(Get-Date -f T) - Please check the permissions of the user"
            break

        }
        elseif ($StatusCode -eq 400) {

            Write-Warning -Message "$(Get-Date -f T) - Please check the query used"
            break

        }
        else {
            
            #Retry up to 5 times
            if ($RetryCount -lt 5) {
                
                write-output "Retrying..."
                $RetryCount++

            }
            else {
                
                #Write to host and exit loop
                Write-Warning -Message "$(Get-Date -f T) - Download request failed. Please try again in the future"
                break

            }

        }

    }
    catch {

        #Write error details to host
        Write-Warning -Message "$(Get-Date -f T) - $($_.Exception)"


        #Retry up to 5 times    
        if ($RetryCount -lt 5) {

            write-output "Retrying..."
            $RetryCount++

        }
        else {

            #Write to host and exit loop
            Write-Warning -Message "$(Get-Date -f T) - Download request failed - please try again in the future"
            break

        }

    } # end try / catch


    return $MyReport


}   #end function



#endregion
 


#################################
#################################
#region 2) DOMAINS


###################################################
#FUNCTION: Get-AzureADIRDomainRegistrationDetail
###################################################

function Get-AzureADIRDomainRegistrationDetail {

    ############################################################################

    <#
    .SYNOPSIS

        Generates a list of domains from Azure AD and then checks whois 
        information to display Name Servers, Admin and Registrant.


    .DESCRIPTION

        Generates a list of domains and uses whois to get additional information.

        Flags if the domain is verified in Azure AD and if its whois information is
        available. Will attempt to retrieve name server, admin and registrant
        information from the whois output.

        Writes all of the raw whois information to a txt file per domain and then
        zips the results.

        Can create date and time stamped CSV output.


    .EXAMPLE

        Get-AzureADIRDomainRegistrationDetail -TenantId 98cfcac2-9255-41a9-b206-a8cfad3998cc -CsvOutput

        Creates a CSV file containing domains listed in Azure AD, containing 
        name server, admin and registrant information where available from whois.

        Also creates a zip file containing the raw who is output.


    .EXAMPLE

        Get-AzureADIRDomainRegistrationDetail -TenantId 98cfcac2-9255-41a9-b206-a8cfad3998cc

        Displays a list of domains from Azure AD, containing name server, 
        admin and registrant information where available from whois.

    #>

    ############################################################################

    [CmdletBinding()]
    param(
    
        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #Use this switch to create a date and time stamped CSV file
        [Parameter(Position=1)]
        [switch]$CsvOutput

    )


    ############################################################################

    #Get tenant details to test that Connect-AzureADIR has been called
    try {

        $TenantInfo = Get-AzureADTenantDetail

    } 
    catch {

        Write-Warning -Message "$(Get-Date -f T) - You must call Connect-AzureADIR to run this function"
        Write-Verbose "$(Get-Date -f T) - Calling Connect AzureADIR"
        
        Connect-AzureADIR -TenantId $TenantId
    
    }

    if ($TenantInfo) {

        $InitialDomain = ($TenantInfo.VerifiedDomains | Where-Object {$_.Initial}).Name
        Write-Verbose -Message "$(Get-Date -f T) - Target tenant ID initial domain name - $InitialDomain"


        #Define module base and whois location
        $ModuleBase = (Get-Module -Name AzureADIncidentResponse).ModuleBase
        $WhoIsBase = "$ModuleBase\Components\Whois"
        $WhoIsExe = "$WhoIsBase\WhoIs.exe"

        if (!(Test-Path $WhoIsExe)) {

            Write-Warning -Message "$(Get-Date -f T) - Unable to locate Whois.exe. Attempting to download..."

            $WhoIsDlUrl = "https://download.sysinternals.com/files/WhoIs.zip"
            $Tempfile = [System.IO.Path]::GetTempFileName()
            $TempFolder = [System.IO.Path]::GetDirectoryName($TempFile)

            $WebClient = New-Object System.Net.WebClient

            while ($WebClient.DownloadFile($WhoIsDlUrl,$TempFile)) {

                Start-Sleep -Seconds 1

            }

            if ($?) {

                Write-Verbose -Message "$(Get-Date -f T) - Successfully downloaded WhoIs.zip to $TempFolder\$Tempfile"

                Rename-Item -Path $TempFile -NewName "WhoIs.zip" -Force -ErrorAction SilentlyContinue

                if ($?) {

                    Write-Verbose -Message "$(Get-Date -f T) - Renamed $TempFile to WhoIs.zip"

                    $WhoIsPath = "$($TempFolder)\WhoIs.zip"

                    Copy-Item $WhoIsPath -Destination $WhoIsBase -Force

                    if ($?) {

                        Write-Verbose -Message "$(Get-Date -f T) - Copied $($TempFolder)\WhoIs.zip to $WhoIsBase"

                        Expand-Archive -Path "$WhoIsBase\WhoIs.zip" -DestinationPath "$WhoIsBase\" -Force -ErrorAction SilentlyContinue

                        if ($?) {

                            Write-Verbose -Message "$(Get-Date -f T) - $WhoIsBase\WhoIs.zip archive expanded"

                        }
                        else {

                            Write-Warning -Message "$(Get-Date -f T) - Failed to expand archive $WhoIsBase\WhoIs.zip"
                            
                        }

                    }
                    else {

                       Write-Warning -Message "$(Get-Date -f T) - Failed to copy zip file from $TempFolder to $WhoIsBase"
                        
                    }

                }
                else {

                    Write-Warning -Message "$(Get-Date -f T) - Failed to rename temp file - $Tempfile"

                }

            }
            else {

                Write-Warning -Message "$(Get-Date -f T) - Failed to download WhoIs.zip to $TempFolder\$Tempfile"

            }

        }


        if (Test-Path $WhoIsExe) {

            Write-Verbose -Message "$(Get-Date -f T) - WhoIs.exe located in $WhoIsExe"

            #Output files
            $now = "{0:yyyyMMdd_hhmmss}" -f (Get-Date)
            $DomainRegistrations = "DomainRegistrations_$now.csv"
            $DomainZip = "DomainRegistrations_$now.zip"


            #Get a list of domains

            Write-Verbose -Message "$(Get-Date -f T) - Attempting to get domains"

            try {$Domains = Get-AzureADDomain -ErrorAction SilentlyContinue | Where-Object {$_.Name -notlike "*.onmicrosoft.com"}}
            catch {}

            if ($Domains) {

                Write-Verbose -Message "$(Get-Date -f T) - $(($Domains).Count) domains found"

                #Loop through the domains and check whois information
                foreach ($Domain in $Domains) {

                    #Blank variables
                    $NameServerDetails = $null

                    #Get whois information

                    Write-Verbose -Message "$(Get-Date -f T) - Attempting to get whois information for $(($Domain).Name)" 

                    $WhoIsCmd = cmd /c $WhoIsExe /v $Domain.Name /accepteula /nobanner
                    $WhoIs = $WhoIsCmd
                
                    #Check we have whois info and parse
                    if (($LASTEXITCODE -eq 0) -and ($WhoIs)) {

                        $DomainRaw = "DomainRaw_$(($Domain).Name)_$now.txt"

                        Write-Verbose -Message "$(Get-Date -f T) - Saving whois raw information for $(($Domain).Name) to $DomainRaw" 

                        $WhoIs > $DomainRaw

                        Write-Verbose -Message "$(Get-Date -f T) - Parsing whois information for $(($Domain).Name)" 
                    

                        #Is there a message saying we can't match a registrant?

                        $NotMatchRegistrant =  $WhoIs | Select-String -Pattern "as not able to match the registrant's name"

                        if ($NotMatchRegistrant) {

                            $WhoIsRegistrant = "UNKNOWN"

                            $NameSeverLine = ($WhoIs | Select-String -Pattern "Name Servers:").LineNumber

                            $NameServerDetails = "$(($WhoIs[$NameSeverLine + 1]).Trim())`n$(($WhoIs[$NameSeverLine + 3]).Trim())`n$(($WhoIs[$NameSeverLine + 5]).Trim())`n$(($WhoIs[$NameSeverLine + 7]).Trim())"

                        }
                        else {

                            #Grab some details
                            $WhoIsRegistrant = "Known"

                            [string]$AdminDetails = ($WhoIs | Select-String -Pattern "^Admin ") -join "`n"

                            [string]$RegistrantDetails = ($WhoIs | Select-String -Pattern "^Registrant ") -join "`n"

                            $NameServerDetails = $WhoIs | Select-String -Pattern "Name Server:"
                            $NameServerDetails = ($NameServerDetails | ForEach-Object {($_ -split ":")[1]} | Sort-Object -Unique).Trim() -join "`n"


                        }


                        #Create PS Custom Object with domain detais
                        $WhoIsDetails = [pscustomobject]@{

                            DomainName = $Domain.Name
                            AzureADVerified = $Domain.IsVerified
                            WhoIsRegistrant = $WhoIsRegistrant
                            NameServers = $NameServerDetails
                            AdminDetails = $AdminDetails
                            Registrantdetails = $RegistrantDetails
                            RawFile = $DomainRaw

                        }

                
                    }
                    else {
                
                        Write-Warning -Message "$(Get-Date -f T) - Unable to get whois information for $(($Domain).Name)"
                
                    }  

                    #Zip up files
                    Compress-Archive -Path .\*.txt -DestinationPath $DomainZip -Update -ErrorAction SilentlyContinue

                    if ($?) {

                        Write-Verbose -Message "$(Get-Date -f T) - Raw whois domain files zipped to $(Get-Location)\$DomainZip" 

                        Remove-Item -Path .\*.txt -Force -ErrorAction SilentlyContinue

                        if ($?) {

                            Write-Verbose -Message "$(Get-Date -f T) - Removed raw domain txt files from $(Get-Location)" 

                        }
                        else {

                            Write-Warning -Message "$(Get-Date -f T) - Failed to remove raw domain txt files from $(Get-Location)" 

                        }

                    }
                    else {


                        Write-Warning -Message "$(Get-Date -f T) - Failed to zip raw whois domain files - txt files still available" 


                    }

                    #Add PS Custom Object to array
                    [array]$TotalObjects += $WhoIsDetails

                }

            }
            else {

                Write-Warning -Message "$(Get-Date -f T) - No domains found"

            }

            #See if we need to write to CSV
            if ($CsvOutput) {

                Write-Verbose -Message "$(Get-Date -f T) - Generating a CSV for domain ownership"

                $TotalObjects | Export-Csv -Path $DomainRegistrations -NoTypeInformation

                Write-Verbose -Message "$(Get-Date -f T) - Domain ownership CSV written to $(Get-Location)\$DomainRegistrations"

            }
            else {

                $TotalObjects

            }

        }
        else {

            Write-Warning -Message "$(Get-Date -f T) - Unable to locate Whois.exe."

        }

    }

}   #end function



#endregion



#################################
#################################
#region 3) APPLICATIONS


######################################
#FUNCTION: Get-AzureADIRPermission
######################################

function Get-AzureADIRPermission {

    ############################################################################

    <#
    .SYNOPSIS

        Produces CSV reports of app permissions. Can also list all permissions.


    .DESCRIPTION

        Produces two date and time stamped CSV reports with the -CsvOutput switch:

            * one for delegated permissions (OAuth2PermissionGrants)
            * one for application permissions (AppRoleAssignments)

        Can also list all permissions to the host without the -CsvOutput switch.


    .EXAMPLE

        Get-AzureADIRPermission -TenantId 98cfcac2-9255-41a9-b206-a8cfad3998cc -CsvOutput

        Creates two date and time stamped CSV files of tenant permissions, one for
        delegated permissions, one for application permissions and svaes them to the
        execution directory.


    .EXAMPLE

        Get-AzureADIRPermission -TenantId 98cfcac2-9255-41a9-b206-a8cfad3998cc

        Displays a list of tenant permissions to the host.


    .NOTES

        Thanks to Philippe Signoret for Get-AzureADPSPermission.

    #>

    ############################################################################

    [CmdletBinding()]
    param(
    
        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #Use this switch to create a date and time stamped CSV file
        [Parameter(Position=1)]
        [switch]$CsvOutput

    )


    ############################################################################

    function Get-AzureADPSPermission {

        <#
        .SYNOPSIS
            Lists delegated permissions (OAuth2PermissionGrants) and application permissions (AppRoleAssignments).

        .PARAMETER DelegatedPermissions
            If set, will return delegated permissions. If neither this switch nor the ApplicationPermissions switch is set,
            both application and delegated permissions will be returned.

        .PARAMETER ApplicationPermissions
            If set, will return application permissions. If neither this switch nor the DelegatedPermissions switch is set,
            both application and delegated permissions will be returned.

        .PARAMETER UserProperties
            The list of properties of user objects to include in the output. Defaults to DisplayName only.

        .PARAMETER ServicePrincipalProperties
            The list of properties of service principals (i.e. apps) to include in the output. Defaults to DisplayName only.

        .PARAMETER ShowProgress
            Whether or not to display a progress bar when retrieving application permissions (which could take some time).

        .PARAMETER PrecacheSize
            The number of users to pre-load into a cache. For tenants with over a thousand users,
            increasing this may improve performance of the script.

        .EXAMPLE
            PS C:\> .\Get-AzureADPSPermission.ps1 | Export-Csv -Path "permissions.csv" -NoTypeInformation
            Generates a CSV report of all permissions granted to all apps.

        .EXAMPLE
            PS C:\> .\Get-AzureADPSPermission.ps1 -ApplicationPermissions -ShowProgress | Where-Object { $_.Permission -eq "Directory.Read.All" }
            Get all apps which have application permissions for Directory.Read.All.

        .EXAMPLE
            PS C:\> .\Get-AzureADPSPermission.ps1 -UserProperties @("DisplayName", "UserPrincipalName", "Mail") -ServicePrincipalProperties @("DisplayName", "AppId")
            Gets all permissions granted to all apps and includes additional properties for users and service principals.

        .NOTES
            Taken from https://gist.github.com/psignoret/41793f8c6211d2df5051d77ca3728c09

        #>

        [CmdletBinding()]
        param(
            [switch] $DelegatedPermissions,

            [switch] $ApplicationPermissions,

            [string[]] $UserProperties = @("DisplayName"),

            [string[]] $ServicePrincipalProperties = @("DisplayName"),

            [switch] $ShowProgress,

            [int] $PrecacheSize = 999
        )

        # Get tenant details to test that Connect-AzureADIR has been called
        try {

            $tenant_details = Get-AzureADTenantDetail

        } catch {

            Write-Warning -Message  "$(Get-Date -f T) - You must call Connect-AzureADIR to run this function"
            Write-Verbose "$(Get-Date -f T) - Calling Connect AzureADIR"
            Connect-AzureADIR -TenantId $TenantId

        }

        Write-Verbose -Message ("$(Get-Date -f T) - TenantId - {0}, InitialDomain - {1}" -f `
                        $tenant_details.ObjectId, `
                        ($tenant_details.VerifiedDomains | Where-Object { $_.Initial }).Name)


        # An in-memory cache of objects by {object ID} andy by {object class, object ID}
        $script:ObjectByObjectId = @{}
        $script:ObjectByObjectClassId = @{}

        # Function to add an object to the cache
        function CacheObject ($Object) {
            if ($Object) {
                if (-not $script:ObjectByObjectClassId.ContainsKey($Object.ObjectType)) {
                    $script:ObjectByObjectClassId[$Object.ObjectType] = @{}
                }
                $script:ObjectByObjectClassId[$Object.ObjectType][$Object.ObjectId] = $Object
                $script:ObjectByObjectId[$Object.ObjectId] = $Object
            }
        }

        # Function to retrieve an object from the cache (if it's there), or from Azure AD (if not).
        function GetObjectByObjectId ($ObjectId) {
            if (-not $script:ObjectByObjectId.ContainsKey($ObjectId)) {
                Write-Verbose -Message ("$(Get-Date -f T) - Querying Azure AD for object '{0}'" -f $ObjectId)
                try {
                    $object = Get-AzureADObjectByObjectId -ObjectIds $ObjectId
                    CacheObject -Object $object
                } catch {
                    Write-Verbose -Message "$(Get-Date -f T) - Object not found."
                }
            }
            return $script:ObjectByObjectId[$ObjectId]
        }

        # Function to retrieve all OAuth2PermissionGrants, either by directly listing them (-FastMode)
        # or by iterating over all ServicePrincipal objects. The latter is required if there are more than
        # 999 OAuth2PermissionGrants in the tenant, due to a bug in Azure AD.
        function GetOAuth2PermissionGrants ([switch]$FastMode) {
            if ($FastMode) {
                Get-AzureADOAuth2PermissionGrant -All $true
            } else {
                $i = 0
                $script:ObjectByObjectClassId['ServicePrincipal'].GetEnumerator() | ForEach-Object {

                    if ($ShowProgress) {
                        Write-Progress -Activity "Retrieving delegated permissions..." `
                                       -Status ("Checked {0}/{1} apps" -f $i++, $servicePrincipalCount) `
                                       -PercentComplete (($i / $servicePrincipalCount) * 100)
                    }

                    $client = $_.Value
                    Get-AzureADServicePrincipalOAuth2PermissionGrant -ObjectId $client.ObjectId
                }
            }
        }

        $empty = @{} # Used later to avoid null checks

        # Get all ServicePrincipal objects and add to the cache
        Write-Verbose -Message "$(Get-Date -f T) - Retrieving all ServicePrincipal objects..."
        Get-AzureADServicePrincipal -All $true | ForEach-Object {
            CacheObject -Object $_
        }
        $servicePrincipalCount = $script:ObjectByObjectClassId['ServicePrincipal'].Count

        if ($DelegatedPermissions -or (-not ($DelegatedPermissions -or $ApplicationPermissions))) {

            # Get one page of User objects and add to the cache
            Write-Verbose -Message ("$(Get-Date -f T) - Retrieving up to {0} User objects..." -f $PrecacheSize)
            Get-AzureADUser -Top $PrecacheSize | Where-Object {
                CacheObject -Object $_
            }

            Write-Verbose -Message "$(Get-Date -f T) - Testing for OAuth2PermissionGrants bug before querying..."
            $fastQueryMode = $false
            try {
                # There's a bug in Azure AD Graph which does not allow for directly listing
                # oauth2PermissionGrants if there are more than 999 of them. The following line will
                # trigger this bug (if it still exists) and throw an exception.
                $null = Get-AzureADOAuth2PermissionGrant -Top 999
                $fastQueryMode = $true
            } catch {
                if ($_.Exception.Message -and $_.Exception.Message.StartsWith("Unexpected end when deserializing array.")) {
                    Write-Verbose -Message ("$(Get-Date -f T) - Fast query for delegated permissions failed, using slow method...")
                } else {
                    throw $_
                }
            }

            # Get all existing OAuth2 permission grants, get the client, resource and scope details
            Write-Verbose -Message "$(Get-Date -f T) - Retrieving OAuth2PermissionGrants..."
            GetOAuth2PermissionGrants -FastMode:$fastQueryMode | ForEach-Object {
                $grant = $_
                if ($grant.Scope) {
                    $grant.Scope.Split(" ") | Where-Object { $_ } | ForEach-Object {

                        $scope = $_

                        $grantDetails =  [ordered]@{
                            "PermissionType" = "Delegated"
                            "ClientObjectId" = $grant.ClientId
                            "ResourceObjectId" = $grant.ResourceId
                            "Permission" = $scope
                            "ConsentType" = $grant.ConsentType
                            "PrincipalObjectId" = $grant.PrincipalId
                        }

                        # Add properties for client and resource service principals
                        if ($ServicePrincipalProperties.Count -gt 0) {

                            $client = GetObjectByObjectId -ObjectId $grant.ClientId
                            $resource = GetObjectByObjectId -ObjectId $grant.ResourceId

                            $insertAtClient = 2
                            $insertAtResource = 3
                            foreach ($propertyName in $ServicePrincipalProperties) {
                                $grantDetails.Insert($insertAtClient++, "Client$propertyName", $client.$propertyName)
                                $insertAtResource++
                                $grantDetails.Insert($insertAtResource, "Resource$propertyName", $resource.$propertyName)
                                $insertAtResource ++
                            }
                        }

                        # Add properties for principal (will all be null if there's no principal)
                        if ($UserProperties.Count -gt 0) {

                            $principal = $empty
                            if ($grant.PrincipalId) {
                                $principal = GetObjectByObjectId -ObjectId $grant.PrincipalId
                            }

                            foreach ($propertyName in $UserProperties) {
                                $grantDetails["Principal$propertyName"] = $principal.$propertyName
                            }
                        }

                        New-Object PSObject -Property $grantDetails
                    }
                }
            }
        }

        if ($ApplicationPermissions -or (-not ($DelegatedPermissions -or $ApplicationPermissions))) {

            # Iterate over all ServicePrincipal objects and get app permissions
            Write-Verbose -Message "$(Get-Date -f T) - Retrieving AppRoleAssignments..."
            $i = 0
            $script:ObjectByObjectClassId['ServicePrincipal'].GetEnumerator() | ForEach-Object {
                
                if ($ShowProgress) {
                    Write-Progress -Activity "Retrieving application permissions..." `
                                -Status ("Checked {0}/{1} apps" -f $i++, $servicePrincipalCount) `
                                -PercentComplete (($i / $servicePrincipalCount) * 100)
                }

                $sp = $_.Value

                Get-AzureADServiceAppRoleAssignedTo -ObjectId $sp.ObjectId -All $true `
                | Where-Object { $_.PrincipalType -eq "ServicePrincipal" } | ForEach-Object {
                    $assignment = $_

                    $resource = GetObjectByObjectId -ObjectId $assignment.ResourceId
                    $appRole = $resource.AppRoles | Where-Object { $_.Id -eq $assignment.Id }

                    $grantDetails = [ordered]@{
                        "PermissionType" = "Application"
                        "ClientObjectId" = $assignment.PrincipalId
                        "ResourceObjectId" = $assignment.ResourceId
                        "Permission" = $appRole.Value
                    }

                    # Add properties for client and resource service principals
                    if ($ServicePrincipalProperties.Count -gt 0) {

                        $client = GetObjectByObjectId -ObjectId $assignment.PrincipalId

                        $insertAtClient = 2
                        $insertAtResource = 3
                        foreach ($propertyName in $ServicePrincipalProperties) {
                            $grantDetails.Insert($insertAtClient++, "Client$propertyName", $client.$propertyName)
                            $insertAtResource++
                            $grantDetails.Insert($insertAtResource, "Resource$propertyName", $resource.$propertyName)
                            $insertAtResource ++
                        }
                    }

                    New-Object PSObject -Property $grantDetails
                }
            }
        }
    }


    ############################################################################

    #Check if we need to produce CSV files
    if ($CsvOutput) {

        #Output files
        $now = "{0:yyyyMMdd_hhmmss}" -f (Get-Date)
        $DelegatedPermissions = "DelegatedPermissions_$now.csv"
        $ApplicationPermissions = "ApplicationPermissions_$now.csv"

        #Call Philippe's script and output to CSV
        Write-Verbose -Message "$(Get-Date -f T) - Generating a CSV for delegated permissions"

        Get-AzureADPSPermission -DelegatedPermissions -ServicePrincipalProperties @("DisplayName","AppId","AppOwnerTenantId") `
        -UserProperties @("DisplayName","UserPrincipalName") -ShowProgress |
        Export-Csv -Path $DelegatedPermissions -NoTypeInformation

        Write-Verbose -Message "$(Get-Date -f T) - CSV written to $(Get-Location)\$DelegatedPermissions"
        Write-Verbose -Message "$(Get-Date -f T) - Generating a CSV for application permissions"

        Get-AzureADPSPermission -ApplicationPermissions -ServicePrincipalProperties @("DisplayName","AppId","AppOwnerTenantId") `
        -UserProperties @("DisplayName","UserPrincipalName") -ShowProgress |
        Export-Csv -Path $ApplicationPermissions -NoTypeInformation

        Write-Verbose -Message "$(Get-Date -f T) - CSV written to $(Get-Location)\$ApplicationPermissions"

    }
    else {

        Get-AzureADPSPermission -ServicePrincipalProperties @("DisplayName","AppId","AppOwnerTenantId") `
        -UserProperties @("DisplayName","UserPrincipalName") -ShowProgress 

    }

}   #end function



#endregion



#################################
#################################
#region 4) ACTIVITY


#######################################
#FUNCTION: Get-AzureADIRSignInDetail
#######################################

function Get-AzureADIRSignInDetail {

    ############################################################################

    <#
    .SYNOPSIS

        Gets Sign-In log details for target users, clients or resources.


    .DESCRIPTION

        Produces filtered output for the sign-in log. Can target specific users,
        client applications, resources or IP addresses. Also has an option to
        specify a date range.

        Can send the filtered logs to Out-GridView for detailed examination. 
        For more information run:

            Get-Help Out-GridView -Full | More


    .EXAMPLE

        Get-AzureADIRSignInDetail -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -UserId 8a734f47-0641-4b6d-ac10-3f47b55ab270

        Gets all sign-in log events for the target user (by Object ID) for the specified tenant. 
        
        Outputs retrieved events to screen.


    .EXAMPLE

        Get-AzureADIRSignInDetail -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f 
        -UserId 8a734f47-0641-4b6d-ac10-3f47b55ab270,729d870c-337b-432e-8e3a-2b4a4c87506e
        -OutGridView

        Gets all sign-in log events for the target users (by Object ID) for the specified tenant. 
        
        Outputs the events to Out-GridView for detailed examination. 


    .EXAMPLE

        Get-AzureADIRSignInDetail -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f 
        -ClientId 1b730954-1685-4b74-9bfd-dac224a7b894,c44b4083-3bb0-49c1-b47d-974e53cbdf3c
        -OutGridView

        Gets all sign-in log events for the target client apps (by Object ID) for the specified tenant. The target apps are:
        
            * 1b730954-1685-4b74-9bfd-dac224a7b894 (Azure Active Directory PowerShell)
            * c44b4083-3bb0-49c1-b47d-974e53cbdf3c (Azure Portal)
        
        Outputs the events to Out-GridView for detailed examination. 
      
                
    .EXAMPLE

        Get-AzureADIRSignInDetail -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f 
        -ResourceId 00000003-0000-0000-c000-000000000000,797f4846-ba00-4fd7-ba43-dac1f8f63013
        | Export-Csv .\Sign-Ins-By_ResourceId.csv -NoTypeInformation

        Gets all sign-in log events for the target client apps (by Object ID) for the specified tenant. The target apps are:
        
            * 00000003-0000-0000-c000-000000000000 (Microsoft Graph)
            * 797f4846-ba00-4fd7-ba43-dac1f8f63013 (Windows Azure Service Management API)
        
       Exports the events to a CSV file called Sign-Ins-By_ResourceId.csv without the type information header.


    .EXAMPLE

        Get-AzureADIRSignInDetail -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -IpAddress 212.100.128.76

        Gets all sign-in log events for the target IP Address for the specified tenant. 
        
        Outputs retrieved events to screen.


    .EXAMPLE

        Get-AzureADIRSignInDetail -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f 
        -CorrelationId 6b8fb7d2-3461-43d6-9a7a-296e105b713c

        Gets all sign-in log events for the target correlation ID for the specified tenant.


    #>

    ############################################################################

    [CmdletBinding(DefaultParameterSetName="User")]
    param(

        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #The target user ID on which to filter
        [Parameter(Mandatory,Position=1,ParameterSetName="User")]
        [array]$UserId,

        #The target client ID on which to filter
        [Parameter(Mandatory,Position=2,ParameterSetName="Client")]
        [array]$ClientId,

        #The target client ID on which to filter
        [Parameter(Mandatory,Position=3,ParameterSetName="Resource")]
        [array]$ResourceId,

        #The target IP address on which to filter
        [Parameter(Mandatory,Position=4,ParameterSetName="IpAddress")]  
        [ValidateScript({$_ -match [IPAddress]$_ })]  
        [String]$IpAddress,

        #The target IP address on which to filter
        [Parameter(Mandatory,Position=4,ParameterSetName="Correlation")]  
        [array]$CorrelationId,

        #The number of days ago after which events are retrieved, i.e. get events older than this point in time
        [Parameter(Position=5)]
        [ValidateRange(1,29)]
        [int32]$RangeFromDaysAgo,

        #The number of days ago before which events are retrieved, i.e. get events previous to this point in time
        [Parameter(Position=6)]
        [ValidateRange(2,30)]
        [int32]$RangeToDaysAgo,

        #Use this switch to output to the Grid View
        [Parameter(Position=7)]
        [switch]$OutGridView

    )


    ############################################################################

    #Deal with different search criterea
    if ($UserId) {

        $Target = "UserId"

        $Objects = $UserId

         Write-Verbose -Message "$(Get-Date -f T) - User mode selected"

    }
    elseif ($ClientId) {

        $Target = "AppId"

        $Objects = $ClientId

        Write-Verbose -Message "$(Get-Date -f T) - Client mode selected"

    }
    elseif ($ResourceId) {

        $Target = "ResourceId"

        $Objects = $ResourceId

        Write-Verbose -Message "$(Get-Date -f T) - Resource mode selected"

    }
    elseif ($IpAddress) {

        $Target = "ipAddress"

        $Objects = $IpAddress

        Write-Verbose -Message "$(Get-Date -f T) - IpAddress mode selected"

    }
   elseif ($CorrelationId) {

        $Target = "correlationId"

        $Objects = $CorrelationId

        Write-Verbose -Message "$(Get-Date -f T) - CorrelationId mode selected"

    }

    #Deal with different date criterea
    if ($RangeFromDaysAgo -and $RangeToDaysAgo){

        Write-Verbose -Message "$(Get-Date -f T) - RangeFrom and RangeTo selected"
        
        if ($RangeFromDaysAgo -lt $RangeToDaysAgo) {
        
            Write-Verbose -Message "$(Get-Date -f T) - RangeFrom is less than RangeTo"

        }
        else {

            Write-Warning -Message "$(Get-Date -f T) - RangeFrom is greater than or equal to RangeTo"
            Write-Warning -Message "$(Get-Date -f T) - Setting RangeTo to $($RangeFromDaysAgo + 1)"

            $RangeToDaysAgo = $RangeFromDaysAgo +1

        }

        #Create the datetime values
        $RangeFrom = (Get-Date (Get-Date).AddDays(-$RangeFromDaysAgo) -Format s) + "Z"
        $RangeTo = (Get-Date (Get-Date).AddDays(-$RangeToDaysAgo) -Format s) + "Z"

        Write-Verbose -Message "$(Get-Date -f T) - Getting events from $RangeFrom to $RangeTo"

        $DateFilter = "and createdDateTime le $RangeFrom and createdDateTime ge $RangeTo"

    }
    elseif ($RangeFromDaysAgo) {

        $RangeFrom = (Get-Date (Get-Date).AddDays(-$RangeFromDaysAgo) -Format s) + "Z"

        Write-Verbose -Message "$(Get-Date -f T) - Getting events from $RangeFrom"

        $DateFilter = "and createdDateTime le $RangeFrom"

    }
    elseif ($RangeToDaysAgo) {

        $RangeTo = (Get-Date (Get-Date).AddDays(-$RangeToDaysAgo) -Format s) + "Z"

        Write-Verbose -Message "$(Get-Date -f T) - Getting events to $RangeTo"

        $DateFilter = "and createdDateTime ge $RangeTo"

    }
    else {

        $DateFilter = ""

    }       
        

    #Get / refresh an access token
    $Token = (Get-AzureADIRApiToken -TenantId $TenantId).AccessToken

    if ($Token) {

        #Construct header with access token
        $Header = Get-AzureADIRHeader -Token $Token

        #Tracking variables
        $TotalReport = $null

        #Loop through the supplied users
        foreach ($Object in $Objects) {

            ###########################################
            #Filter
            $Filter = "?`$filter=$Target eq '$Object'"

            #API endpoint
            $Url = "https://graph.microsoft.com/beta/auditLogs/signIns$Filter$DateFilter"
            ###########################################

            #Call the API query loop
            $TotalReport = Invoke-AzureADIRDoWhile -Header $Header -Url $Url


        }   #end foreach


        #See if we need to write to CSV
        if ($OutGridView) {


            Write-Verbose -Message "$(Get-Date -f T) - Sending to Out-GridView"

            $TotalReport | Out-GridView -Title "Azure AD Incident Response Sign-In Detail - $Target"

        }
        else {

            #Return stuff
            $TotalReport

        }


    }   #end if ($Token)


}   #end function


########################################
#FUNCTION: Get-AzureADIRAuditActivity
########################################

function Get-AzureADIRAuditActivity {

    ############################################################################

    <#
    .SYNOPSIS

        Gets Audit log details for target Users, Service Principals, Event Categories 
        or services logging the events.


    .DESCRIPTION

        Produces filtered output for the Audit log. Can target specific users, 
        Service Principals, Audit Categories, Logging Services or Activity Display
        Names. Can specifiy a date range for a more targeted retrieval.

        Use this to reference Audit Categories and Activity Display Names:

        https://docs.microsoft.com/en-us/azure/active-directory/reports-monitoring/reference-audit-activities


        Can send the filtered logs to Out-GridView for detailed examination. 
        For more information run:

            Get-Help Out-GridView -Full | More
            

    .EXAMPLE

        Get-AzureADIRAuditActivity -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f
        -InitiatedByUser "3bdd577c-716f-4d6d-ba83-6daf8c439cdb","eed48f42-72c6-4c0f-b405-701f0558e07d"
        
        Retrieves audit events for actions initiated by the two user object IDs: 

            * 3bdd577c-716f-4d6d-ba83-6daf8c439cdb
            * eed48f42-72c6-4c0f-b405-701f0558e07d


    .EXAMPLE

        Get-AzureADIRAuditActivity -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f 
        -InitiatedByServicePrincipal "Microsoft.Azure.SyncFabric" -OutGridView
                                                     
        Retrives audit events for actions intiated by the "Microsoft.Azure.SyncFabric" (case sensitive) 
        Service Princiapl. 
        
        Here we have to use the Display Name as supplying the Object ID is disallowed.

        Sends to Out-Gridview for examination.


    .EXAMPLE

        Get-AzureADIRAuditActivity -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f 
        -Category "UserManagement","DirectoryManagement","ApplicationManagment" -OutGridView
                                                     
        Retrives audit events for the following categories (case sensitive):
        
            * UserManagement
            * DirectoryManagement
            * ApplicationManagment

        Sends to Out-Gridview for examination.


    .EXAMPLE

        Get-AzureADIRAuditActivity -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f 
        -LoggedByService "Core Directory" | Export-Csv .\Audits_By_ResourceId.csv -NoTypeInformation

        Retrieves events logged by the "Core Directory" (case sensitive) service.
        
        Exports the events to a CSV file called Audits_By_ResourceId.csv without the type information header.
 

     .EXAMPLE

        Get-AzureADIRAuditActivity -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f 
        -ActivityDisplayName "Consent to application" 

        Retrieves events that relate to the "Consent to application" (case sensitive) activity.
        
 
      .EXAMPLE

        Get-AzureADIRAuditActivity -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f 
        -CorrelationId 7f0ecc65-27c6-4486-984d-073b843b5161,62992a74-5474-4910-b935-2f3156c351ea

        Retrieves events that relate to the correlation IDs 7f0ecc65-27c6-4486-984d-073b843b5161 and 62992a74-5474-4910-b935-2f3156c351ea
           
    #>

    ############################################################################

    [CmdletBinding(DefaultParameterSetName="User")]
    param(

        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #The user or users initiating the action by Object ID
        [Parameter(Mandatory,Position=1,ParameterSetName="User")]
        [array]$InitiatedByUser,

        #The service principal or principals initiating the action by Display Name on which to filter
        [Parameter(Mandatory,Position=2,ParameterSetName="ServicePrincipal")]
        [array]$InitiatedByServicePrincipal,

        #The audit event category or categories on which to filter
        [Parameter(Mandatory,Position=3,ParameterSetName="Category")]
        [array]$Category,

        #The service or services logging the event on which to filter
        [Parameter(Mandatory,Position=4,ParameterSetName="Service")]
        [array]$LoggedByService,

        #The activity display name on which to filter
        [Parameter(Mandatory,Position=5,ParameterSetName="Activity")]
        [array]$ActivityDisplayName,

        #The correlation ID on which to filter
        [Parameter(Mandatory,Position=6,ParameterSetName="Correlation")]
        [array]$CorrelationId,

        #The number of days ago after which events are retrieved, i.e. get events older than this point in time
        [Parameter(Position=7)]
        [ValidateRange(1,29)]
        [int32]$RangeFromDaysAgo,

        #The number of days ago before which events are retrieved, i.e. get events previous to this point in time
        [Parameter(Position=8)]
        [ValidateRange(2,30)]
        [int32]$RangeToDaysAgo,

        #Use this switch to output to the Grid View
        [Parameter(Position=9)]
        [switch]$OutGridView

    )


    ############################################################################


    #Deal with different search criterea
    if ($InitiatedByUser) {

        $Target = "initiatedBy/user/id"

        $Objects = $InitiatedByUser

         Write-Verbose -Message "$(Get-Date -f T) - InitiatedByUser mode selected"

    }
    elseif ($InitiatedByServicePrincipal) {

        $Target = "initiatedBy/app/displayName"

        $Objects = $InitiatedByServicePrincipal

        Write-Verbose -Message "$(Get-Date -f T) - InitiatedByServicePrincipal mode selected"

    }
    elseif ($Category) {

        $Target = "category"

        $Objects = $Category

        Write-Verbose -Message "$(Get-Date -f T) - Category mode selected"

    }
    elseif ($LoggedByService) {

        $Target = "LoggedByService"

        $Objects = $LoggedByService

        Write-Verbose -Message "$(Get-Date -f T) - LoggedByService mode selected"

    }
    elseif ($ActivityDisplayName) {

        $Target = "ActivityDisplayName"

        $Objects = $ActivityDisplayName

        Write-Verbose -Message "$(Get-Date -f T) - ActivityDisplayName mode selected"

    }
    elseif ($CorrelationId) {

        $Target = "correlationId"

        $Objects = $CorrelationId

        Write-Verbose -Message "$(Get-Date -f T) - Correlation ID mode selected"

    }


    #Deal with different date criterea
    if ($RangeFromDaysAgo -and $RangeToDaysAgo){

        Write-Verbose -Message "$(Get-Date -f T) - RangeFrom and RangeTo selected"
        
        if ($RangeFromDaysAgo -lt $RangeToDaysAgo) {
        
            Write-Verbose -Message "$(Get-Date -f T) - RangeFrom is less than RangeTo"

        }
        else {

            Write-Warning -Message "$(Get-Date -f T) - RangeFrom is greater than or equal to RangeTo"
            Write-Warning -Message "$(Get-Date -f T) - Setting RangeTo to $($RangeFromDaysAgo + 1)"

            $RangeToDaysAgo = $RangeFromDaysAgo +1

        }

        #Create the datetime values
        $RangeFrom = (Get-Date (Get-Date).AddDays(-$RangeFromDaysAgo) -Format s) + "Z"
        $RangeTo = (Get-Date (Get-Date).AddDays(-$RangeToDaysAgo) -Format s) + "Z"

        Write-Verbose -Message "$(Get-Date -f T) - Getting events from $RangeFrom to $RangeTo"

        $DateFilter = "and activityDateTime le $RangeFrom and activityDateTime ge $RangeTo"

    }
    elseif ($RangeFromDaysAgo) {

        $RangeFrom = (Get-Date (Get-Date).AddDays(-$RangeFromDaysAgo) -Format s) + "Z"

        Write-Verbose -Message "$(Get-Date -f T) - Getting events from $RangeFrom"

        $DateFilter = "and activityDateTime le $RangeFrom"

    }
    elseif ($RangeToDaysAgo) {

        $RangeTo = (Get-Date (Get-Date).AddDays(-$RangeToDaysAgo) -Format s) + "Z"

        Write-Verbose -Message "$(Get-Date -f T) - Getting events to $RangeTo"

        $DateFilter = "and activityDateTime ge $RangeTo"

    }
    else {

        $DateFilter = ""

    }
              

    #Get / refresh an access token
    $Token = (Get-AzureADIRApiToken -TenantId $TenantId).AccessToken

    if ($Token) {

        #Construct header with access token
        $Header = Get-AzureADIRHeader -Token $Token

        #Tracking variables
        $TotalReport = $null

        #Loop throughthe supplied users
        foreach ($Object in $Objects) {

            ###########################################
            #Filter
            $Filter = "?`$filter=$Target eq '$Object'"

            #API endpoint
            $Url = "https://graph.microsoft.com/beta/auditLogs/directoryAudits$Filter$DateFilter"
            ###########################################

            #Call the API query loop
            $TotalReport = Invoke-AzureADIRDoWhile -Header $Header -Url $Url


        }   #end foreach


        #See if we need to write to CSV
        if ($OutGridView) {


            Write-Verbose -Message "$(Get-Date -f T) - Sending to Out-GridView"

            $TotalReport | Out-GridView -Title "Azure AD Incident Response Audit Detail - $Target"

        }
        else {

            #Return stuff
            $TotalReport

        }


    }   #end if ($Token)


}   #end function


############################################
#FUNCTION: Get-AzureADIRDismissedUserRisk
############################################

function Get-AzureADIRDismissedUserRisk {

    ############################################################################

    <#
    .SYNOPSIS

        Gets all Identity Protection User Risk dismissals.


    .DESCRIPTION

        Gets User Risk dismissals showing target user details, with last sign-in activity,
        and the initiating object details, app or user, also with last sign-in activity
        where that information is available.

        Also produces optional date and time stamped CSV output.


    .EXAMPLE

        Get-AzureADIRDismissedUserRisk -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f

        Gets user risk dismissals for the target tenant with additional details to the event,
        i.e. user information.


    .EXAMPLE

        Get-AzureADIRDismissedUserRisk -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -CsvOutput

        Gets user risk dismissals for the target tenant with additional details to the event,
        i.e. user information.

        Writes found events to a date and time stamped CSV file in the executing directory.

    #>

    ############################################################################

    [CmdletBinding()]
    param(

        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #Use this switch to create a date and time stamped CSV file
        [Parameter(Position=1)]
        [switch]$CsvOutput

    )


    ############################################################################

    #Filter(s)
    $Filter = "?`$filter=(activityDisplayName eq 'DismissUser')"

    ############################################################################
    
    #API endpoint
    $Url = "https://graph.microsoft.com/beta/auditLogs/directoryAudits$Filter"

    ############################################################################

    #Get / refresh an access token
    $Token = (Get-AzureADIRApiToken -TenantId $TenantId).AccessToken

    if ($Token) {

        #Construct header with access token
        $Header = Get-AzureADIRHeader -Token $Token

        #Tracking variables
        $Count = 0
        $OneSuccessfulFetch = $false
        $TotalReport = $null


        #Do while the fetch URL is populated
        do {

            Write-Verbose -Message "$(Get-Date -f T) - Invoking web request for $Url"

            $MyReport = Invoke-AzureADIRWebRequest -Header $Header -Url $Url


            ###############################
            #Convert the content from JSON
            $ConvertedReport = ($MyReport.Content | ConvertFrom-Json).value


            #Create / null objects array
            $TotalObjects = @()

            foreach ($Event in $ConvertedReport) {

                Write-Verbose -Message "$(Get-Date -f T) - Looking up target ObjectId - $(($Event).TargetResources.id)"

                $TargetUser = $null
                $InitiatingObject = $null
                $InitiatingObjectName = $null
                $InitiatngObjectId = $null

                #Get some user details
                $UserUrl = "https://graph.microsoft.com/beta/users?`$filter=ID eq '$(($Event).TargetResources.id)'&`$select=displayName,userPrincipalName,Id,signInActivity"

                try {

                    $TargetUser = (Invoke-WebRequest -UseBasicParsing -Headers $Header -Uri $UserUrl -Verbose:$false)
                
                }
                catch {}

                if ($TargetUser) {

                    Write-Verbose -Message "$(Get-Date -f T) - Target object found"

                    $TargetUser = ($TargetUser.Content | ConvertFrom-Json).Value

                }
                else {

                    Write-Warning -Message "$(Get-Date -f T) - Target object not found"

                }


                #Check for app or user
                if ($Event.InitiatedBy.user) {

                    $InitiatngObjectId = $Event.InitiatedBy.user.id

                    Write-Verbose -Message "$(Get-Date -f T) - Looking up initiating ObjectId - $(($Event).InitiatedBy.user.id)"

                    #Get some user details
                    $ObjectUrl = "https://graph.microsoft.com/beta/users?`$filter=ID eq '$(($Event).InitiatedBy.user.id)'&`$select=displayName,userPrincipalName,signInActivity"

                    try {

                        $InitiatingObject = (Invoke-WebRequest -UseBasicParsing -Headers $Header -Uri $ObjectUrl -Verbose:$false)
                
                    }
                    catch {}

                    if ($InitiatingObject) {

                        Write-Verbose -Message "$(Get-Date -f T) - Object found"

                        $InitiatingObject = ($InitiatingObject.Content | ConvertFrom-Json).Value
                        $InitiatingObjectName = $InitiatingObject.DisplayName

                    }
                    else {

                        Write-Warning -Message "$(Get-Date -f T) - Object not found"

                    }

                }
                elseif ($Event.InitiatedBy.app.displayName) {

                    Write-Verbose -Message "$(Get-Date -f T) - Capturing intitiating app details"

                    $InitiatingObjectName = $Event.InitiatedBy.app.displayName

                }


                #Construct a custom object
                $Properties = [PSCustomObject]@{

                    LoggingService = $Event.loggedByService
                    ActivityStatus = $Event.result
                    ActivityType = $Event.activityDisplayName
                    EventTime = $Event.activityDateTime
                    CorrelationId = $Event.correlationId
                    TargetObjectDisplayName = $TargetUser.DisplayName
                    TargetObjectId = $TargetUser.Id
                    TargetObjectUpn = $TargetUser.userPrincipalName
                    TargetObjectLastSignIn = $TargetUser.signInActivity.lastSignInDateTime
                    InitiatingObjectDisplayName = $InitiatingObjectName
                    InitiatingObjectId = $InitiatngObjectId
                    InitiatingObjectUpn = $InitiatingObject.userPrincipalName
                    InitiatingtObjectLastSignIn = $InitiatingObject.signInActivity.lastSignInDateTime

                } 
            
                $TotalObjects += $Properties

            }


            #Add to concatenated findings
            [array]$TotalReport += $TotalObjects

            #Update the fetch url to include the paging element
            $Url = ($myReport.Content | ConvertFrom-Json).'@odata.nextLink'

            #Update the access token on the second iteration
            if ($OneSuccessfulFetch) {
                
                $Token = (Get-AzureADIRApiToken -TenantId $TenantId).AccessToken
                $Header = Get-AzureADIRHeader -Token $Token

                }

            #Update count and show for this cycle
            $Count = $Count + $ConvertedReport.Count
            Write-Verbose -Message "$(Get-Date -f T) - Total records fetched: $count"

            #Update tracking variables
            $OneSuccessfulFetch = $true


        } while ($Url) #end do / while


        #See if we need to write to CSV
        if ($CsvOutput) {

            #Output file
            $now = "{0:yyyyMMdd_hhmmss}" -f (Get-Date)
            $DismissedUserRiskEvents = "DismissedUserRiskEvents_$now.csv"

            Write-Verbose -Message "$(Get-Date -f T) - Generating a CSV for dismissed user risk events"

            $TotalReport | Export-Csv -Path $DismissedUserRiskEvents -NoTypeInformation

            Write-Verbose -Message "$(Get-Date -f T) - Dismissed user risk events written to $(Get-Location)\$DismissedUserRiskEvents"

        }
        else {

            #Return stuff
            $TotalReport

        }

    }


}   #end function


##########################################
#FUNCTION: Get-AzureADIRSsprUsageHistory
##########################################

function Get-AzureADIRSsprUsageHistory {

    ############################################################################

    <#
    .SYNOPSIS

        Gets SSPR usage history.

    .DESCRIPTION

        Gets SSPR usage history, i.e. reset related events in the tenant. 
        
        Can retrieve just successful or just failure events.

        Can also produce a date and time stamped CSV file as output.


    .EXAMPLE

        Get-AzureADIRSsprUsageHistory -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f 

        Gets all SSPR usage history for the target tenant.


    .EXAMPLE

        Get-AzureADIRSsprUsageHistory -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -CsvOutput

        Gets all SSPR usage history for the target tenant. 

        Writes the output to a date and time stamped CSV file in the execution directory.


    .EXAMPLE

        Get-AzureADIRSsprUsageHistory -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -Status Success -CsvOutput

        Gets all successful SSPR usage events for the target tenant. 

        Writes the output to a date and time stamped CSV file in the execution directory.


    .EXAMPLE

        Get-AzureADIRSsprUsageHistory -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -Status Failure

        Gets all failed SSPR usage events for the target tenant. 

    #>

    ############################################################################

    [CmdletBinding()]
    param(

        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #Filter on success or failure events
        [Parameter(Position=1)]
        [ValidateSet('Success','Failure')] 
        [string]$Status,

        #Use this switch to create a date and time stamped CSV file
        [Parameter(Position=2)]
        [switch]$CsvOutput

    )


    ############################################################################

    #Deal with different search criterea
    if ($Status -eq 'Success') {

        $Filter = "&`$filter=(isSuccess eq true)"

        Write-Verbose -Message "$(Get-Date -f T) - Successful SSPR events selected"

    }
    elseif ($Status -eq 'Failure') {

        $Filter = "&`$filter=(isSuccess eq false)"

        Write-Verbose -Message "$(Get-Date -f T) - failed SSPR events selected"

    }


    ############################################################################
    
    #API endpoint
    $Url = "https://graph.microsoft.com/beta/reports/userCredentialUsageDetails?`$orderby=userDisplayName asc$Filter"


    ############################################################################

    #Get / refresh an access token
    $Token = (Get-AzureADIRApiToken -TenantId $TenantId).AccessToken

    if ($Token) {

        #Construct header with access token
        $Header = Get-AzureADIRHeader -Token $Token

        #Tracking variables
        $TotalReport = $null


        #Call the API query loop
        $TotalReport = Invoke-AzureADIRDoWhile -Header $Header -Url $Url


    }

    #See if we need to write to CSV
    if ($CsvOutput) {

        #Output file
        $now = "{0:yyyyMMdd_hhmmss}" -f (Get-Date)
        $CsvName = "SsprUsageHistory_$now.csv"

        Write-Verbose -Message "$(Get-Date -f T) - Generating a CSV for SSPR usage history"

        $TotalReport | Export-Csv -Path $CsvName -NoTypeInformation

        Write-Verbose -Message "$(Get-Date -f T) - SSPR usage history written to $(Get-Location)\$CsvName"

    }
    else {

        #Return stuff
        $TotalReport

    }

}   #end function


#################################################
#FUNCTION: Get-AzureADIRUserLastSignInActivity
#################################################

function Get-AzureADIRUserLastSignInActivity {

    ############################################################################

    <#
    .SYNOPSIS

        Gets Azure Active Directory user last interactive sign-in activity details.


    .DESCRIPTION

        Gets Azure Active Directory user last interactive sign-in activity details
        using the signInActivity.lastSignInDateTime attribute.

            Use -All to get details for all users in the target tenant.

            Use -UserObjectId to target a single user or groups of users.

            Use -StaleThreshold to see details of users whose sign-in activity is before
            a certain datetime threshold.

            Use -GuestInfo to include additional information specific to guest accounts

        Can also produce a date and time stamped CSV file as output.


    .EXAMPLE

        Get-AzureADIRUserLastSignInActivity -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -All

        Gets the last interactive sign-in activity for all users on the tenant.


    .EXAMPLE

        Get-AzureADIRUserLastSignInActivity -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f 
        -UserObjectId 69447235-0974-4af6-bfa3-d0e922a92048 -CsvOutput

        Gets the last interactive sign-in activity for the user, targeted by their object ID.

        Writes the output to a date and time stamped CSV file in the execution directory.


    .EXAMPLE

        Get-AzureADIRUserLastSignInActivity -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f
        -StaleThreshold 60 -GuestInfo -CsvOutput

        Gets all users whose last interactive sign-in activity is before the stale threshold of 60 days. 

        Writes the output to a date and time stamped CSV file in the execution directory.

        Includes additional attributes for guest user insight.


    .EXAMPLE

        Get-AzureADIRUserLastSignInActivity -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f
        -StaleThreshold 30

        Gets all users whose last interactive sign-in activity is before the stale threshold of 30 days. 


    .EXAMPLE

        Get-AzureADIRUserLastSignInActivity -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f
        -StaleThreshold 30 -GuestInfo

        Gets all users whose last interactive sign-in activity is before the stale threshold of 30 days. 

        Includes additional attributes for guest user insight.


    #>

    ############################################################################

    [CmdletBinding(DefaultParameterSetName="All")]
    param(

        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #Get sign-in activity for all users in the tenant
        [Parameter(Mandatory,Position=1,ParameterSetName="All")]
        [switch]$All,

        #Get the sign-in activity for a single user by object ID
        [Parameter(Mandatory,Position=2,ParameterSetName="UserObjectId")]
        [string]$UserObjectId,

        #The number of days before which accounts are considered stale
        [Parameter(Mandatory,Position=3,ParameterSetName="Threshold")]
        [ValidateSet(30,60,90)] 
        [int32]$StaleThreshold,

        #Include additio al information for guest accounts
        [Parameter(Position=4)]
        [switch]$GuestInfo,

        #Use this switch to create a date and time stamped CSV file
        [Parameter(Position=5)]
        [switch]$CsvOutput

    )


    ############################################################################

    #Deal with different search criterea
    if ($All) {

        #API endpoint
        $Filter = "?`$select=displayName,userPrincipalName,Id,signInActivity,userType,externalUserState,creationType,createdDateTime"

        Write-Verbose -Message "$(Get-Date -f T) - All user mode selected"

    }
    elseif ($UserObjectId) {

        #API endpoint
        $Filter = "?`$filter=ID eq '$UserObjectId'&`$select=displayName,userPrincipalName,Id,signInActivity,userType,externalUserState,creationType,createdDateTime"

        Write-Verbose -Message "$(Get-Date -f T) - Single user mode selected"

    }
    elseif ($StaleThreshold) {

        Write-Verbose -Message "$(Get-Date -f T) - Stale mode selected"

        #Obtain a datetime object before which accounts are considered stale
        $DaysAgo = (Get-Date (Get-Date).AddDays(-$StaleThreshold) -Format s) + "Z"

        Write-Verbose -Message "$(Get-Date -f T) - Stale threshold set to $DaysAgo"

        #API endpoint
        $Select = "&`$select=displayName,userPrincipalName,Id,signInActivity,userType,externalUserState,creationType,createdDateTime"
        $Filter = "?`$filter=signInActivity/lastSignInDateTime le $DaysAgo$Select"

    }


    ############################################################################
    
    $Url = "https://graph.microsoft.com/beta/users$Filter"


    ############################################################################

    #Get / refresh an access token
    $Token = (Get-AzureADIRApiToken -TenantId $TenantId).AccessToken

    if ($Token) {

        if ($All) {

            #Construct header with access token and ConsistencyLevel = Eventual
            $Header = Get-AzureADIRHeader -Token $Token -ConsistencyLevelEventual

            $CountUrl = "https://graph.microsoft.com/beta/users/`$count"

            Write-Verbose -Message "$(Get-Date -f T) - Invoking web request for $CountUrl"

            #Now make a call to get the number of users
            try {
                 
                $UserCount = (Invoke-WebRequest -Headers $Header -Uri $CountUrl -Verbose:$false)

            }
            catch {}

            if ($UserCount) {

                Write-Verbose -Message "$(Get-Date -f T) - $UserCount users found in tenant"

                #Estimate execution time
                if ($CsvOutput) {

                    $ExTime = (0.03 * $UserCount.Content)

                }
                else {

                    $ExTime = (0.035 * $UserCount.Content)

                }


                $ExTimeSpan = [timespan]::FromSeconds($ExTime)

                Write-Verbose -Message "$(Get-Date -f T) - Estimated function execution time is $($ExTimeSpan.Hours) hours, $($ExTimeSpan.Minutes) minutes, $($ExTimeSpan.Seconds) seconds"
                    

                #Light up the progress bar in the later loop
                $ShowProgress = $true


            }
            else {

                Write-Warning -Message "$(Get-Date -f T) - User count unobtainable - unable to estimate function execution time"
            }

        }
        else {

            #Construct header with access token
            $Header = Get-AzureADIRHeader -Token $Token

        }

        #Tracking variables
        $Count = 0
        $OneSuccessfulFetch = $false
        $TotalReport = $null
        $i = 1


        #Do while the fetch URL is populated
        do {

            Write-Verbose -Message "$(Get-Date -f T) - Invoking web request for $Url"

            $MyReport = Invoke-AzureADIRWebRequest -Header $Header -Url $Url


            ###############################
            #Convert the content from JSON
            $ConvertedReport = ($MyReport.Content | ConvertFrom-Json).value

            $TotalObjects = @()

            foreach ($User in $ConvertedReport) {

                if ($GuestInfo) {

                    #Construct a custom object
                    $Properties = [PSCustomObject]@{

                        displayName = $User.displayName
                        userPrincipalName = $User.userPrincipalName
                        objectId = $User.Id
                        lastSignInDateTime = $User.signInActivity.lastSignInDateTime
                        lastSignInRequestId = $User.signInActivity.lastSignInRequestId
                        userType = $User.userType
                        createdDateTime = $User.createdDateTime
                        externalUserState = $User.externalUserState
                        creationType = $User.creationType

                    }
            
                }
                else {

                    #Construct a custom object
                    $Properties = [PSCustomObject]@{

                        displayName = $User.displayName
                        userPrincipalName = $User.userPrincipalName
                        objectId = $User.Id
                        lastSignInDateTime = $User.signInActivity.lastSignInDateTime
                        lastSignInRequestId = $User.signInActivity.lastSignInRequestId

                    }

                }

                $TotalObjects += $Properties

                #Progress bar when targeting all users
                if ($ShowProgress) {

                    Write-Progress -Activity "Processing..." `
                                -Status ("Checked {0}/{1} user accounts" -f $i++, $UserCount.Content) `
                                -PercentComplete ((($i -1)  / $UserCount.Content) * 100)

                }


            }


            #Add to concatenated findings
            [array]$TotalReport += $TotalObjects

            #Update the fetch url to include the paging element
            $Url = ($myReport.Content | ConvertFrom-Json).'@odata.nextLink'

            #Update the access tokenon the second iteration
            if ($OneSuccessfulFetch) {
                
                $Token = (Get-AzureADIRApiToken -TenantId $TenantId).AccessToken
                $Header = Get-AzureADIRHeader -Token $Token

            }

            #Update count and show for this cycle
            $Count = $Count + $ConvertedReport.Count
            Write-Verbose -Message "$(Get-Date -f T) - Total records fetched: $count"

            #Update tracking variables
            $OneSuccessfulFetch = $true


        } while ($Url) #end do / while


    }

    #See if we need to write to CSV
    if ($CsvOutput) {

        #Output file
        $now = "{0:yyyyMMdd_hhmmss}" -f (Get-Date)
        $CsvName = "UserLastSignInDetails_$now.csv"

        Write-Verbose -Message "$(Get-Date -f T) - Generating a CSV for last user Sign-In details"

        $TotalReport | Export-Csv -Path $CsvName -NoTypeInformation

        Write-Verbose -Message "$(Get-Date -f T) - Last user sign-in details written to $(Get-Location)\$CsvName"

    }
    else {

        #Return stuff
        $TotalReport

    }

}   #end function


#endregion



#################################
#################################
#region 5) PRIVILEGE


####################################################
#FUNCTION: Get-AzureADIRPrivilegedRoleAssignment
####################################################

function Get-AzureADIRPrivilegedRoleAssignment {

    ############################################################################

    <#
    .SYNOPSIS

        Gets a list of directory roles and members.


    .DESCRIPTION

        Gets the currently populated directory roles and finds their members.
        
        Can write the results to a time and date-stamped CSV.


    .EXAMPLE

        Get-AzureADIRPrivilegedRoleAssignment -TenantId 98cfcac2-9255-41a9-b206-a8cfad3998cc -CsVOutput

        Gets a list of directory roles and members and saves then to a date and time stamped
        CSV file in the execution directory.


    .EXAMPLE

        Get-AzureADIRPrivilegedRoleAssignment -TenantId 98cfcac2-9255-41a9-b206-a8cfad3998cc

        Gets a list of directory roles and members and displays them to the host.


    .EXAMPLE

        Get-AzureADIRPrivilegedRoleAssignment -UserObjectId 704bb78b-103f-4e22-807f-4312c68af4c1

        Gets a list of directory roles that the target user is a member of.


    #>

    ############################################################################

    [CmdletBinding()]
    param(
        
        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #User objectID to target
        [Parameter(Position=1)]
        [string]$UserObjectId,

        #Use this switch to create a date and time stamped CSV file
        [Parameter(Position=2)]
        [switch]$CsvOutput

    )


    ############################################################################


    #Get tenant details to test that Connect-AzureADIR has been called
    try {

        $TenantDetails = Get-AzureADTenantDetail

    } 
    catch {

        Write-Warning -Message  "$(Get-Date -f T) - You must call Connect-AzureADIR to run this function"
        Write-Verbose "$(Get-Date -f T) - Calling Connect AzureADIR"
        Connect-AzureADIR -TenantId $TenantId

    }


    $InitialDomain = ($TenantInfo.VerifiedDomains | Where-Object {$_.Initial}).Name
    Write-Verbose -Message "$(Get-Date -f T) - Target tenant ID initial domain name - $InitialDomain"


    #Get a list of directory roles

    Write-Verbose -Message "$(Get-Date -f T) - Attempting to get directory roles"

    try {$Roles = Get-AzureADDirectoryRole -ErrorAction SilentlyContinue}
    catch {}

    if ($Roles) {

        Write-Verbose -Message "$(Get-Date -f T) - $(($Roles).Count) directory roles found"

        #Loop through the roles, get members and add as a ps cutome object to an array
        foreach ($Role in $Roles) {

            #Make Company Admin show as Global Admin
            if ($Role.DisplayName -eq "Company Administrator") {

                $DirectoryRole = "Global Administrator"

            }
            else {

                $DirectoryRole = $Role.DisplayName

            }

            #Get role members

            Write-Verbose -Message "$(Get-Date -f T) - Attempting to get role members for $DirectoryRole" 

            try {$RoleMembers = Get-AzureADDirectoryRoleMember -ObjectId $Role.ObjectId -ErrorAction SilentlyContinue}
            catch {}

            if ($RoleMembers) {

                Write-Verbose -Message "$(Get-Date -f T) - $(($RoleMembers).Count) members found for $DirectoryRole"
                Write-Verbose -Message "$(Get-Date -f T) - Looping through role members"

                foreach ($RoleMember in $RoleMembers) {

                    $AlternateEmail = $RoleMember.OtherMails -join ";"

                    $Properties = [PSCustomObject]@{

                        DirectoryRole = $DirectoryRole
                        DirectoryRoleObjectId =$Role.ObjectId 
                        RoleMemberName = $RoleMember.DisplayName
                        RoleMemberObjectType = $RoleMember.ObjectType
                        RoleMemberUPN = $RoleMember.UserPrincipalName
                        RoleMemberObjectId = $RoleMember.ObjectId
                        RoleMemberEnabled = $RoleMember.AccountEnabled
                        RoleMemberMail = $RoleMember.Mail
                        RoleMemberAlternateEmail = $AlternateEmail
                        RoleMemberOnPremDn = $RoleMember.ExtensionProperty.onPremisesDistinguishedName

                    } 
            
                    [array]$TotalObjects += $Properties

                }
                
            }
            else {

                Write-Warning -Message "$(Get-Date -f T) - No role memberships obtained for $DirectoryRole"

            }

        }

    }
    else {

        Write-Warning -Message "$(Get-Date -f T) - No directory roles obtained"

    }

    #Filter for target user object ID
    if ($UserObjectId) {

        $TotalObjects = $TotalObjects | Where-Object {$_.RoleMemberObjectId -eq $UserObjectId}

    }

    #See if we need to write to CSV
    if ($CsvOutput) {

        #Output file
        $now = "{0:yyyyMMdd_hhmmss}" -f (Get-Date)
        $PrivilegedRoleAssignments = "PrivilegedRoleAssignments_$now.csv"

        Write-Verbose -Message "$(Get-Date -f T) - Generating a CSV for privileged role assignments"

        $TotalObjects | Export-Csv -Path $PrivilegedRoleAssignments -NoTypeInformation

        Write-Verbose -Message "$(Get-Date -f T) - Privileged role assignments CSV written to $(Get-Location)\$PrivilegedRoleAssignments"

    }
    else {

        $TotalObjects

    }


}   #end function


#########################################################
#FUNCTION: Get-AzureADIRPrivilegedUserOnPremCorrelation
#########################################################

function Get-AzureADIRPrivilegedUserOnPremCorrelation {

    ############################################################################

    <#
    .SYNOPSIS

        Gets a list of directory roles, members and any associated on-premises
        privileged groups.        


    .DESCRIPTION

        Gets the currently populated directory roles, finds their members, checks to
        see if the member has an on-premises Distinsguished Name and checks for 
        on-premises privilege. If privilege exists, enumerates the users on-premises 
        groups and checks the groups privilege status.
        
        Can write the results to a time and date-stamped CSV.

        NB - requires the Active Directory PowerShell module and line of siight of
        a domain controller in the target domain.


    .EXAMPLE

        Get-AzureADIRPrivilegedUserOnPremCorrelation -TenandId 98cfcac2-9255-41a9-b206-a8cfad3998cc -OnPremDomain "Consoto.local" -CsVOutput

        Gets a list of directory roles and members that have a privileged status
        in the on-premises domain contoso.com. 
        
        Writes the output to a date and time stamped CSV file in the execution directory.


    .EXAMPLE

        Get-AzureADIRPrivilegedUserOnPremCorrelation -TenandId 98cfcac2-9255-41a9-b206-a8cfad3998cc -OnPremDomain "Consoto.local"

        Gets a list of directory roles and members that have a privileged status
        in the on-premises domain contoso.local.

    #>

    ############################################################################

    [CmdletBinding()]
    param(
    
        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #The target Windows Server Active Directory domain in which to find the linked accounts
        [Parameter(Mandatory,Position=1)] 
        [string]$OnPremDomain,

        #Use this switch to create a date and time stamped CSV file
        [Parameter(Position=2)]
        [switch]$CsvOutput

    )


    ############################################################################

    #Check to see if we have the on-prem Active Directory powershell module
    $ActiveDirectory = Get-Module -ListAvailable ActiveDirectory -Verbose:$false -ErrorAction SilentlyContinue

    if ($ActiveDirectory) {

        Write-Verbose -Message "$(Get-Date -f T) - ActiveDirectory PowerShell module installed"

        try {$RetrieveObject = Get-ADDomain -Server $OnPremDomain}
        catch {}

        if ($RetrieveObject) {

            Write-Verbose -Message "$(Get-Date -f T) - Active Directory domain - $OnPremDomain - contacted"

            #Get tenant details to test that Connect-AzureADIR has been called
            try {

                $TenantInfo = Get-AzureADTenantDetail

            } 
            catch {

                Write-Warning -Message  "$(Get-Date -f T) - You must call Connect-AzureADIR to run this function"
                Write-Verbose "$(Get-Date -f T) - Calling Connect AzureADIR"
                Connect-AzureADIR -TenantId $TenantId
    
            }

        }
        else {

            Write-Error -Message "Please ensure you have line of site to a domain controller for the target domain - $OnPremDomain" `
            -ErrorAction Stop

        }
                
    }
    else {


        Write-Error -Message "Please install the Windows Server Active Directory PowerShell module" `
        -ErrorAction Stop

    }   

    #Display Azure AD Domain
    $InitialDomain = ($TenantInfo.VerifiedDomains | Where-Object {$_.Initial}).Name
    Write-Verbose -Message "$(Get-Date -f T) - Target tenant ID initial domain name - $InitialDomain"

    #Display Windows Server AD Domain
    Write-Verbose -Message "$(Get-Date -f T) - Target Active Directory domain - $(($RetrieveObject).DistinguishedName)"


    #Call the Get-AzureADIRPrivilegedRoleAssignment function
    Write-Verbose -Message "$(Get-Date -f T) - Calling Get-AzureADIRPrivilegedRoleAssignment..."


    $RoleAssigments = Get-AzureADIRPrivilegedRoleAssignment | Where-Object {$_.RoleMemberOnPremDn}


    Write-Verbose -Message "$(Get-Date -f T) - $($RoleAssigments.Count) users with an on-prem Distinguished Name"
    Write-Verbose -Message "$(Get-Date -f T) - Looping through users to check for on-prem privileges"


    #Loop through the users with an on-prem DN and see if they're privileged
    foreach ($RoleAssigment in $RoleAssigments) {

        #Nullify variables
        $PrivGroups = $null

        try {$AdUser = Get-ADUser -Server $OnPremDomain -Identity $RoleAssigment.RoleMemberOnPremDn -Properties adminCount,memberOf -ErrorAction SilentlyCOntinue}
        catch {}

        if ($AdUser) {

            Write-Verbose -Message "$(Get-Date -f T) - Windows Server AD user object found for $(($RoleAssigment).RoleMemberOnPremDn)"

            if ($AdUser.adminCount) {

                Write-Verbose -Message "$(Get-Date -f T) - User is currently or has been a member of a privileged group"
                Write-Verbose -Message "$(Get-Date -f T) - Checking user's groups for privileged status"

                #Update PS Custom Object
                $RoleAssigment | Add-Member -MemberType NoteProperty -Name 'OnPremPrivilegedStatus' -Value $true


                foreach ($GroupDn in $AdUser.memberof) {
                
                    try {$AdGroup = Get-ADGroup -Server $OnPremDomain -Identity $GroupDn -Properties adminCount -ErrorAction SilentlyCOntinue}
                    catch {}

                    if ($AdGroup) {

                       Write-Verbose -Message "$(Get-Date -f T) - Windows Server AD group object found for $GroupDn" 

                       if ($AdGroup.adminCount) {

                            Write-Verbose -Message "$(Get-Date -f T) - Group is currently privileged or has been privileged"

                            if ($CsvOutput) {

                                [string]$PrivGroups += ";'$GroupDn'"

                            }
                            else {

                                [array]$PrivGroups += $GroupDn

                            }

                       }

                    }
                    else {

                        Write-Warnimg -Message "$(Get-Date -f T) - Windows Server AD group object not found for $GroupDn"

                    }
                
                }
                
                #Update PS Custom Object
                if ($CsvOutput) {

                    $RoleAssigment | Add-Member -MemberType NoteProperty -Name 'OnPremPrivilegedGroups' -Value $PrivGroups.TrimStart(";")

                }
                else {

                    $RoleAssigment | Add-Member -MemberType NoteProperty -Name 'OnPremPrivilegedGroups' -Value $PrivGroups

                }

                #Add to total array
                [array]$TotalObjects += $RoleAssigment

            }


        }
        else {

            Write-Warnimg -Message "$(Get-Date -f T) - Windows Server AD user object not found for $(($RoleAssigment).RoleMemberOnPremDn)"


        }

    }

    #See if we need to write to CSV
    if ($CsvOutput) {

        #Output files
        $now = "{0:yyyyMMdd_hhmmss}" -f (Get-Date)
        $PrivilegedRoleAssignments = "PrivilegedRolesOnPremCorrelations_$now.csv"

        Write-Verbose -Message "$(Get-Date -f T) - Generating a CSV for privileged role assignments and on-prem correlations"

        $TotalObjects | Export-Csv -Path $PrivilegedRoleAssignments -NoTypeInformation

        Write-Verbose -Message "$(Get-Date -f T) - Privileged role assignments and on-prem correlations CSV written to $(Get-Location)\$PrivilegedRoleAssignments"

    }
    else {

        $TotalObjects

    }


}   #end function


#######################################################
#FUNCTION: Get-AzureADIRPimPrivilegedRoleAssignment
#######################################################

function Get-AzureADIRPimPrivilegedRoleAssignment {

    ############################################################################

    <#
    .SYNOPSIS

        Gets PIM privileged roles assignments.

    .DESCRIPTION

        Gets PIM privileged roles assignments with additional role and user details.

        Can produce CSV output.

    .EXAMPLE

        Get-AzureADIRPimPrivilegedRoleAssignment -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -All

        Gets PIM privileged role assignments for the target tenant.


    .EXAMPLE

        Get-AzureADIRPimPrivilegedRoleAssignment -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -ActiveOnly

        Gets PIM privileged role assignments for the target tenant. Only returns active users.


    .EXAMPLE

        Get-AzureADIRPimPrivilegedRoleAssignment -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -UserObjectId 704bb78b-103f-4e22-807f-4312c68af4c1

        Gets PIM privileged role assignments for the target user in the target tenant.


    .EXAMPLE

        Get-AzureADIRPimPrivilegedRoleAssignment -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -All -CsvOutput

        Gets PIM privileged role assignments for the target tenant.

        Writes the output to a date and time stamped CSV file in the target directory.


    #>

    ############################################################################

    [CmdletBinding()]
    param(

        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #Get sign-in activity for all users in the tenant
        [Parameter(Mandatory,Position=1,ParameterSetName="All")]
        [switch]$All,

        #Use this switch to list active assignments (includes permanent assignments)
        [Parameter(Mandatory,Position=2,ParameterSetName="Active")]
        [switch]$ActiveOnly,

        #Use this parameter to target a specific user
        [Parameter(Mandatory,Position=3,ParameterSetName="User")]
        [string]$UserObjectId,

        #Use this switch to create a date and time stamped CSV file
        [Parameter(Position=4)]
        [switch]$CsvOutput

    )


    ############################################################################

    #API endpoint
    if ($ActiveOnly) {

        $Url = "https://graph.microsoft.com/beta/privilegedAccess/aadroles/resources/$TenantId/roleAssignments?`$filter=assignmentState eq 'Active'"

    }
    elseif ($UserObjectId) {

        $Url = "https://graph.microsoft.com/beta/privilegedAccess/aadroles/resources/$TenantId/roleAssignments?`$filter=subjectId eq '$UserObjectId'"

    }
    else {

        $Url = "https://graph.microsoft.com/beta/privilegedAccess/aadroles/resources/$TenantId/roleAssignments"

    }
    

    ############################################################################

    #Get / refresh an access token
    $Token = (Get-AzureADIRApiToken -TenantId $TenantId).AccessToken

    if ($Token) {

        #Construct header with access token
        $Header = Get-AzureADIRHeader -Token $Token

        #Tracking variables
        $Count = 0
        $OneSuccessfulFetch = $false
        $TotalReport = $null


        #Do while the fetch URL is populated
        do {

            Write-Verbose -Message "$(Get-Date -f T) - Invoking web request for $Url"

            $MyReport = Invoke-AzureADIRWebRequest -Header $Header -Url $Url


            ###############################
            #Convert the content from JSON
            $ConvertedReport = ($MyReport.Content | ConvertFrom-Json).value

            #Create / null objects array
            $TotalObjects = @()

            foreach ($Event in $ConvertedReport) {

                #Get some role details
                Write-Verbose -Message "$(Get-Date -f T) - Looking up role definition details - $(($Event).roleDefinitionId)"

                $TargetRole = $null

                $RoleUrl = "https://graph.microsoft.com/beta/privilegedAccess/aadroles/resources/$TenantId/roleDefinitions?`$filter=(id eq '$(($Event).roleDefinitionId)')&`$Select=displayName,Type"


                try {

                    $TargetRole = (Invoke-WebRequest -UseBasicParsing -Headers $Header -Uri $RoleUrl -Verbose:$false)
                
                }
                catch {}

                if ($TargetRole) {

                    Write-Verbose -Message "$(Get-Date -f T) - Target role found"

                    $TargetRole = ($TargetRole.Content | ConvertFrom-Json).Value

                }
                else {

                    Write-Warning -Message "$(Get-Date -f T) - Target role not found"

                }


                #Get some user details
                Write-Verbose -Message "$(Get-Date -f T) - Looking up assigned user details - $(($Event).subjectId)"

                $TargetUser = $null

                $UserUrl = "https://graph.microsoft.com/beta/users?`$filter=ID eq '$(($Event).subjectId)'&`$select=displayName,userPrincipalName,Id,signInActivity"

                try {

                    $TargetUser = (Invoke-WebRequest -UseBasicParsing -Headers $Header -Uri $UserUrl -Verbose:$false)
                
                }
                catch {}

                if ($TargetUser) {

                    Write-Verbose -Message "$(Get-Date -f T) - Target user found"

                    $TargetUser = ($TargetUser.Content | ConvertFrom-Json).Value

                }
                else {

                    Write-Warning -Message "$(Get-Date -f T) - Target user not found"

                }


                #Construct a custom object
                $Properties = [PSCustomObject]@{

                    RoleName = $TargetRole.displayName
                    RoleType = $TargetRole.Type
                    RoleId = $Event.roleDefinitionId
                    UserDisplayName = $TargetUser.DisplayName
                    UserId = $TargetUser.Id
                    UserUpn = $TargetUser.userPrincipalName
                    UserLastSignIn = $TargetUser.signInActivity.lastSignInDateTime
                    AssignmentType = $Event.memberType
                    AssignmentState = $Event.assignmentState
                    AssignmentStatus = $Event.status
                    AssignmentStart = $Event.startDateTime
                    AssignmentEnd = $Event.endDateTime

                } 
            
                $TotalObjects += $Properties

            }


            #Add to concatenated findings
            [array]$TotalReport += $TotalObjects

            #Update the fetch url to include the paging element
            $Url = ($myReport.Content | ConvertFrom-Json).'@odata.nextLink'

            #Update the access token on the second iteration
            if ($OneSuccessfulFetch) {
                
                $Token = (Get-AzureADIRApiToken -TenantId $TenantId).AccessToken
                $Header = Get-AzureADIRHeader -Token $Token

            }

            #Update count and show for this cycle
            $Count = $Count + $ConvertedReport.Count
            Write-Verbose -Message "$(Get-Date -f T) - Total records fetched: $count"

            #Update tracking variables
            $OneSuccessfulFetch = $true


        } while ($Url) #end do / while


        #See if we need to write to CSV
        if ($CsvOutput) {

            #Output file
            $now = "{0:yyyyMMdd_hhmmss}" -f (Get-Date)
            $CsvName = "PimPrivilegedRoleAssignments_$now.csv"

            Write-Verbose -Message "$(Get-Date -f T) - Generating a CSV for PIM role assignments"

            $TotalReport | Export-Csv -Path $CsvName -NoTypeInformation

            Write-Verbose -Message "$(Get-Date -f T) - PIM role assignment details written to $(Get-Location)\$CsvName"

        }
        else {

            #Return stuff
            $TotalReport

        }


    }


}   #end function


#############################################################
#FUNCTION: Get-AzureADIRPimPrivilegedRoleAssignmentRequest
#############################################################

function Get-AzureADIRPimPrivilegedRoleAssignmentRequest {

    ############################################################################

    <#
    .SYNOPSIS

        Gets PIM assignment related activity.


    .DESCRIPTION

        Gets all PIM assignment related events from the target tenant.

        Can produce a time and date stamped CSV file.


    .EXAMPLE

        Get-AzureADIRPimPrivilegedRoleAssignmentRequest -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f

        Gets all PIM assignment related events from the target tenant.


    .EXAMPLE

        Get-AzureADIRPimPrivilegedRoleAssignmentRequest -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -CsvOutput

        Gets all PIM assignment related events from the target tenant.

        Produces a time and date stamped CSV file.

    #>

    ############################################################################

    [CmdletBinding()]
    param(

        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #Use this switch to create a date and time stamped CSV file
        [Parameter(Position=1)]
        [switch]$CsvOutput

    )


    ############################################################################
    
    #API endpoint
    $Url = "https://graph.microsoft.com/beta/privilegedAccess/aadroles/resources/$TenantId/roleAssignmentRequests"
    

    ############################################################################

    #Get / refresh an access token
    $Token = (Get-AzureADIRApiToken -TenantId $TenantId).AccessToken

    if ($Token) {

        #Construct header with access token
        $Header = Get-AzureADIRHeader -Token $Token

        #Tracking variables
        $Count = 0
        $OneSuccessfulFetch = $false
        $TotalReport = $null


        #Do while the fetch URL is populated
        do {

            Write-Verbose -Message "$(Get-Date -f T) - Invoking web request for $Url"

            $MyReport = Invoke-AzureADIRWebRequest -Header $Header -Url $Url


            ###############################
            #Convert the content from JSON
            $ConvertedReport = ($MyReport.Content | ConvertFrom-Json).value

            #Create / null objects array
            $TotalObjects = @()

            foreach ($Event in $ConvertedReport) {

                #Get some role details
                Write-Verbose -Message "$(Get-Date -f T) - Looking up role definition details - $(($Event).roleDefinitionId)"

                $TargetRole = $null

                $RoleUrl = "https://graph.microsoft.com/beta/privilegedAccess/aadroles/resources/$TenantId/roleDefinitions?`$filter=(id eq '$(($Event).roleDefinitionId)')&`$Select=displayName,Type"


                try {

                    $TargetRole = (Invoke-WebRequest -UseBasicParsing -Headers $Header -Uri $RoleUrl -Verbose:$false)
                
                }
                catch {}

                if ($TargetRole) {

                    Write-Verbose -Message "$(Get-Date -f T) - Target role found"

                    $TargetRole = ($TargetRole.Content | ConvertFrom-Json).Value

                }
                else {

                    Write-Warning -Message "$(Get-Date -f T) - Target role not found"

                }


                #Get some user details
                Write-Verbose -Message "$(Get-Date -f T) - Looking up assigned user details - $(($Event).subjectId)"

                $TargetUser = $null

                $UserUrl = "https://graph.microsoft.com/beta/users?`$filter=ID eq '$(($Event).subjectId)'&`$select=displayName,userPrincipalName,Id,signInActivity"

                try {

                    $TargetUser = (Invoke-WebRequest -UseBasicParsing -Headers $Header -Uri $UserUrl -Verbose:$false)
                
                }
                catch {}

                if ($TargetUser) {

                    Write-Verbose -Message "$(Get-Date -f T) - Target user found"

                    $TargetUser = ($TargetUser.Content | ConvertFrom-Json).Value

                }
                else {

                    Write-Warning -Message "$(Get-Date -f T) - Target user not found"

                }


                #Construct a custom object
                $Properties = [PSCustomObject]@{

                    RequestedRoleName = $TargetRole.displayName
                    RequestedRoleType = $TargetRole.Type
                    RequestedRoleId = $Event.roleDefinitionId
                    RequestingUserDisplayName = $TargetUser.DisplayName
                    RequestingUserId = $TargetUser.Id
                    RequestingUserUpn = $TargetUser.userPrincipalName
                    RequestingUserLastSignIn = $TargetUser.signInActivity.lastSignInDateTime
                    AssignmentRequestType = $Event.type
                    AssignmentRequestState = $Event.assignmentState
                    AssignmentRequestStatus = $Event.status.status
                    AssignmentRequestDate = $Event.requestedDateTime
                    AssignmentRequestId = $Event.id

                } 
            
                $TotalObjects += $Properties

            }


            #Add to concatenated findings
            [array]$TotalReport += $TotalObjects

            #Update the fetch url to include the paging element
            $Url = ($myReport.Content | ConvertFrom-Json).'@odata.nextLink'

            #Update the access token on the second iteration
            if ($OneSuccessfulFetch) {
                
                $Token = (Get-AzureADIRApiToken -TenantId $TenantId).AccessToken
                $Header = Get-AzureADIRHeader -Token $Token

            }

            #Update count and show for this cycle
            $Count = $Count + $ConvertedReport.Count
            Write-Verbose -Message "$(Get-Date -f T) - Total records fetched: $count"

            #Update tracking variables
            $OneSuccessfulFetch = $true


        } while ($Url) #end do / while


        #See if we need to write to CSV
        if ($CsvOutput) {

            #Output file
            $now = "{0:yyyyMMdd_hhmmss}" -f (Get-Date)
            $CsvName = "PimPrivilegedRoleAssignments_$now.csv"

            Write-Verbose -Message "$(Get-Date -f T) - Generating a CSV for PIM assignment requests"

            $TotalReport | Export-Csv -Path $CsvName -NoTypeInformation

            Write-Verbose -Message "$(Get-Date -f T) - PIM assignment request details written to $(Get-Location)\$CsvName"

        }
        else {

            #Return stuff
            $TotalReport

        }


    }


}   #end function


#endregion



#################################
#################################
#region 6) SECURITY CREDENTIALS


################################################
#FUNCTION: Get-AzureADIRMfaAuthMethodAnalysis
###############################################

function Get-AzureADIRMfaAuthMethodAnalysis {

    ##########################################################################################################
    ##########################################################################################################

    <#
    .SYNOPSIS

        Analyses Azure AD users to make recommendations on how to improve their MFA stance.


    .DESCRIPTION

        Analyses Azure AD users to make recommendations on how to improve each user's MFA configuration. 

        Can target a group by ObjectId or analyse all users in a tenant.

        Can add user-specific location information: UPN domain, usage location and country.

        Can produce a date and time stamped CSV report of per user recommendations.

        IMPORTANT:

        * You can not use a guest (B2B) account to run this script against the target tenant. This is a 
          limitation of the MSOnline PowerShell module. The script will execute in the guest's home tenant,
          not the target tenant.

        * Ensure you run the script with an account that can enumerate user properties. For least privilege
          use the User Administrator role


    .EXAMPLE

        Get-AzureADIRMfaAuthMethodAnalysis -TenantId 9959f32b-837b-41db-b6e5-32277e344292

        Creates per user recommendations for all users in the target tenant and displays the results to screen.


    .EXAMPLE

        Get-AzureADIRMfaAuthMethodAnalysis -TenantId 9959f32b-837b-41db-b6e5-32277e344292 -TargetGroup 6424cd24-ee16-472f-bad6-85427c9febc2

        Creates per user recommendations for each user in the target group and displays the results to screen.


    .EXAMPLE

        Get-AzureADIRMfaAuthMethodAnalysis -TenantId 9959f32b-837b-41db-b6e5-32277e344292 -CsvOutput -Verbose

        Creates a date and time stamped CSV file in the scripts execution directory with per user recommendations 
        for all users in the tenant. Has verbose notation to screen.


    .EXAMPLE

        Get-AzureADIRMfaAuthMethodAnalysis -TenantId 9959f32b-837b-41db-b6e5-32277e344292 -LocationInfo -CsvOutput

        Creates a date and time stamped CSV file in the scripts execution directory with per user recommendations 
        for all users in the tenant. Includeds location information: UPN domain, usage location and country.


    .EXAMPLE

        Get-AzureADIRMfaAuthMethodAnalysis -TenantId 9959f32b-837b-41db-b6e5-32277e344292 -TargetUser b24c24ac-5671-444b-ba58-0305c1c72cb0

        Creates a user recommendation for the target user b24c24ac-5671-444b-ba58-0305c1c72cb0.

 
     .EXAMPLE

        Get-Content .\User_ObjectIDs.txt | ForEach-Object {
        
            Get-AzureADIRMfaAuthMethodAnalysis -TenantId 9959f32b-837b-41db-b6e5-32277e344292 -TargetUser $_

        }

        Gets the contents of user_objectIDs.txt. Takes each user object ID from the file and runs it against the
        function to return a per user analysis to screen.


    #>

    ##########################################################################################################

    ################################
    #Define and validate Parameters
    ################################

    [CmdletBinding()]
    param(

        #The unique ID of the tenant to target for analysis
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #The unique ID of the group to analyse
        [Parameter(Position=1)]
        [string]$TargetGroup,

        #The unique ID of the group to analyse
        [Parameter(Position=2)]
        [string]$TargetUser,

        #Use this switch to include user-specific location information
        [Parameter(Position=3)]
        [switch]$LocationInfo,

        #Use this switch to create a date and time stamped CSV file
        [Parameter(Position=4)]
        [switch]$CsvOutput

        )

    ##########################################################################################################

    ##################
    #region Functions
    ##################

    #############################################
    function Measure-MsolUserStrongAuthMethod {

        [CmdletBinding()]
        param(

            #A user object to process
            [Parameter(ValueFromPipeline,Position=0)]
            [Microsoft.Online.Administration.User]$User

        )

        #Set user properties
        $UserPrincipalName = $_.UserPrincipalName
        $DisplayName = $_.DisplayName
        [string]$ObjectId = $_.ObjectId

        if ($LocationInfo) {

            $UpnDomain = ($_.UserPrincipalName).Split("@")[1]
            $UsageLocation = $_.UsageLocation
            $Country = $_.Country

        }

        $MfaAuthMethodCount = $_.StrongAuthenticationMethods.Count

    
        #Count number of methods
        if ($MfaAuthMethodCount -eq 0) {

            [array]$Recommendations = "'Register for MFA, preferably with the Microsoft Authenticator mobile app and also with a phone number, used for SMS or Voice.'"

        }
        else {

            #Do some analysis
            switch ($_.StrongAuthenticationMethods) {
            
                #Check default method
                {$_.IsDefault -eq $true} {
         
                    $DefaultMethod = $_.MethodType
            
                    if ($_.MethodType -ne "PhoneAppNotification") {

                        [array]$Recommendations += "'Consider setting the Microsoft Authenticator mobile app as the default method.'"

                    }

                }

                #Check for method type - PhoneAppNotification
                {$_.MethodType -eq "PhoneAppNotification"} {
             
                    $AppNotification = "Yes"

                    if ($MfaAuthMethodCount -eq 1) {

                        [array]$Recommendations += "'Register at least another authentication method, preferably a verification code from the mobile app or hardware OATH token. A user can have up to five hardware OATH tokens or mobile apps registered. Phone number can also be used for Voice or SMS.'"

                    }
            
            
                } 

                #Check for method type - PhoneAppOTP
                {$_.MethodType -eq "PhoneAppOTP"} {
            
                    $OathTotp = "Yes"

                    if ($MfaAuthMethodCount -eq 1) {

                        [array]$Recommendations += "'Register at least another authentication method, preferably the Microsoft Authenticator mobile app. A user can have up to five hardware OATH tokens or mobile apps registered.'"

                    }
            
                } 

                #Check for method type - OneWaySMS
                {$_.MethodType -eq "OneWaySMS"} {
            
                    $SMS = "Yes"
            
                }

                #Check for method type - TwoWayVoiceMobile
                {$_.MethodType -eq "TwoWayVoiceMobile"} {

                    $Phone = "Yes"        
            
                }

                #Check for method type - OneWaySMS
                {$_.MethodType -eq "TwoWayVoiceAlternateMobile"} {
            
                    $AltPhone = "Yes"     
            
                }

            }

        }


        #More recommendations - phone options only
        if ((($SMS) -and ($Phone)) -and ((!$OathTotp) -and (!$AppNotification))) {

            [array]$Recommendations += "'Register at least another authentication method, preferably the Microsoft Authenticator mobile app or hardware OATH token. A user can have up to five hardware OATH tokens or mobile apps registered.'"      

        }


        #More recommendations - Notification and OATH OTP, no phone nubers
        if (((!$SMS) -and (!$Phone) -and (!$AltPhone)) -and (($OathTotp) -and ($AppNotification))) {

            [array]$Recommendations += "'Register a phone number to be used for SMS and Voice.'"       

        }


        #More recommendations - if no Alternative phone number
        if (!$AltPhone) {

            [array]$Recommendations += "'Consider adding an alternative phone number for additional resilience.'"       

        }


        if ($LocationInfo) {

            $AnalysedUser = [pscustomobject]@{

                UserPrincipalName = $UserPrincipalName
                DisplayName = $DisplayName
                ObjectId = $ObjectId
                UpnDomain = $UpnDomain
                UsageLocation = $UsageLocation
                Country = $Country
                MfaAuthMethodCount = $MfaAuthMethodCount
                DefaultMethod = $DefaultMethod
                AppNotification = $AppNotification
                OathTotp = $OathTotp
                Sms = $Sms
                Phone = $Phone
                AltPhone = $AltPhone
                Recommendations = $Recommendations

            }

        }
        else {

            $AnalysedUser = [pscustomobject]@{

                UserPrincipalName = $UserPrincipalName
                DisplayName = $DisplayName
                ObjectId = $ObjectId
                MfaAuthMethodCount = $MfaAuthMethodCount
                DefaultMethod = $DefaultMethod
                AppNotification = $AppNotification
                OathTotp = $OathTotp
                Sms = $Sms
                Phone = $Phone
                AltPhone = $AltPhone
                Recommendations = $Recommendations

            }


        }

        Write-Verbose -Message "$(Get-Date -f T) - User anaylsis completed"

        return $AnalysedUser

    }   #end function


    #########################################################
    #Function to create a CSV friendly object for conversion
    function Expand-Recommendation {

        [cmdletbinding()]
        param (
            [parameter(ValueFromPipeline)]
            [psobject]$PsCustomObject
        )
    
        begin {

            #Mark that we don't have properties
            $SchemaObtained = $False

        }

        process {
        
            #If this is the first iteration get object properties
            if (!$SchemaObtained) {

                $OutputOrder = $PsCustomObject.psobject.properties.name
                $SchemaObtained = $true

            }

            #Loop thorugh the supplied object and process individually
            $PsCustomObject | ForEach-Object {

                #Capture each element
                $singleGraphObject = $_

                #New parent object for edited / expanded values
                $ExpandedObject = New-Object -TypeName PSObject

                #Loop through the properties
                $OutputOrder | ForEach-Object {

                    #Recommendations property has to have commas added
                    if ($_ -eq "Recommendations") {
                    
                        #Ensure we have a non-empty value if there's nothing in Recommendations
                        $CSVLine = " "

                        #Get variables from authMethods property
                        $Properties = $singleGraphObject.$($_)

                        #Loop through each property and add to a single string with a seperating comma (for CSV)
                        $Properties | ForEach-Object {

                            $CSVLine += "$_,"

                        }

                        #Add edited list of values for authmethods property to parent object
                        Add-Member -InputObject $ExpandedObject -MemberType NoteProperty -Name $_ -Value $CSVLine.TrimEnd(0,",").TrimStart()

                    }
                    else {

                        #Add single value property to parent object
                        Add-Member -InputObject $ExpandedObject -MemberType NoteProperty -Name $_ -Value $(($singleGraphObject.$($_) | Out-String).Trim())

                    }

                }

                #Return completed parent object
                $ExpandedObject

            }

        }

    }   #end function

    #endregion functions


    #############
    #region Main
    #############

    #Tracking variables
    $UsersProcessed = 0
    $ScriptStartTime = Get-Date

    #Verbose output
    Write-Verbose -Message "$(Get-Date -f T) - Function started..."
    if ($LocationInfo) {Write-Verbose -Message "$(Get-Date -f T) - User location information included"}
    if ($CsvOutput) {Write-Verbose -Message "$(Get-Date -f T) - CSV output selected"}


    #Some additional paramter validation outside of param()

    #Try and connect to Azure AD
    try {$DomainInfo = Get-MsolDomain -TenantId $TenantId -ErrorAction SilentlyContinue}
    catch {}

    if ($DomainInfo) {

        Write-Verbose -Message "$(Get-Date -f T) - Connection to $TenantId established"

    }
    else {

        #Present connection pop-up
        Write-Verbose -Message "$(Get-Date -f T) - Calling Connect-MsolService cmdlet"
        Connect-MsolService -ErrorAction SilentlyContinue
            
        #Populate the DomainInfo variable if Connect-MsolService works
        if ($?) {
                
            Write-Verbose -Message "$(Get-Date -f T) - Connection to $TenantId established"
            $DomainInfo = $true
        }
        else {

            Write-Verbose "$(Get-Date -f T) - Connection to $TenantId could not be established"

        }

    }

    #Check if we have a connection
    if ($DomainInfo) {

        #Check if we need to create a CSV file
        if ($CsvOutput) {

            #Output file
            $Now = "{0:yyyyMMdd_hhmmss}" -f (Get-Date)
            $OutputFile = "MfaAuthMethodAnalysis_$now.csv"

            Write-Verbose -Message "$(Get-Date -f T) - Creating CSV file - $OutputFile"

            #Create file with header
            if ($LocationInfo) {

                Add-Content -Value "UserPrincipalName,DisplayName,ObjectId,UpnDomain,UsageLocation,Country,MfaAuthMethodCount,DefaultMethod,AppNotification,OathTotp,Sms,Phone,AltPhone,Recommendations" `
                            -Path $OutputFile

            }
            else {

                Add-Content -Value "UserPrincipalName,DisplayName,ObjectId,MfaAuthMethodCount,DefaultMethod,AppNotification,OathTotp,Sms,Phone,AltPhone,Recommendations" `
                            -Path $OutputFile

            }

            if ($?) {

                Write-Verbose -Message "$(Get-Date -f T) - Header written to CSV file - $OutputFile"
            
            }
            else {

                Write-Warning -Message "$(Get-Date -f T) - Failed to write header to CSV file - $OutputFile"
                Write-Warning -Message "$(Get-Date -f T) - Reverting to non-CSV output mode"
            
                #Prevent further CSV processing
                $CsvOutput = $false

            }

        }

        #We have a connction so start doing stuff... let's check if we are targetting a group
        if ($TargetGroup) {
    
            Write-Verbose -Message "$(Get-Date -f T) - Checking for target group - $TargetGroup"

            #Ensure the group is valid 
            try {$GroupInfo = Get-MsolGroup -ObjectId $TargetGroup -ErrorAction SilentlyContinue}
            catch {}

            if ($GroupInfo) {

                Write-Verbose -Message "$(Get-Date -f T) - Group $TargetGroup confirmed as valid"
                Write-Verbose -Message "$(Get-Date -f T) - Group Display Name = $(($GroupInfo).Displayname); Group Type = $(($GroupInfo).GroupType)"
                Write-Verbose -Message "$(Get-Date -f T) - Enumerating users for $TargetGroup..."

                #We have he target group so let's enumerate the users
                try {$TargetUsers = Get-MsolGroupMember -GroupObjectId $TargetGroup -All}
                catch {}

                if ($TargetUsers) {

                    Write-Verbose -Message "$(Get-Date -f T) - $(($TargetUsers).Count) users found"

                    #Now we have users let's get an msol user object
                    $TargetUsers | ForEach-Object {

                        Get-MsolUser -ObjectId $_.objectID -ErrorAction SilentlyContinue | ForEach-Object {

                            Write-Verbose -Message "$(Get-Date -f T) - Processing $(($_).UserPrincipalName)"
                    
                            #Call the analysis function
                            $TargetUserDetail = Measure-MsolUserStrongAuthMethod -User $_

                            #Determine if we write to screen or file
                            if ($CsvOutput) {
                            
                                Write-Verbose -Message "$(Get-Date -f T) - Converting analysis to CSV format"

                                #Call property expansion function and pipe into a CSV format
                                $CsvFormat = $TargetUserDetail | Expand-Recommendation | ConvertTo-Csv -NoTypeInformation


                                Write-Verbose -Message "$(Get-Date -f T) - Writing conversion to CSV file"

                                #Write the pertinent CSV line
                                Add-Content -Value $CsvFormat[1] -Path $OutputFile

                                if ($?) {

                                    Write-Verbose -Message "$(Get-Date -f T) - Details successfully written to CSV file"

                                }
                                else {

                                    Write-Warning -Message "$(Get-Date -f T) - Failed to write details to CSV file"

                                }

                            }
                            else {

                                #Show user analysis in host
                                $TargetUserDetail

                            }

                            #Increment user count
                            $UsersProcessed++

                        }

                    }

                }
                else {

                    Write-Verbose -Message "$(Get-Date -f T) - $($error[0])"
                    Write-Warning -Message "$(Get-Date -f T) - Issue obtaining members for target group $TargetGroup"
                    Write-Warning -Message "$(Get-Date -f T) - Exiting script..."

                }

            }
            else {

                Write-Verbose -Message "$(Get-Date -f T) - $($error[0])"
                Write-Warning -Message "$(Get-Date -f T) - Issue obtaining the target group $TargetGroup"
                Write-Warning -Message "$(Get-Date -f T) - Exiting script..."

            }

        }
        elseif ($TargetUser) {

            Write-Verbose -Message "$(Get-Date -f T) - Checking for target user - $TargetUser"

            #Ensure the group is valid 
            try {$UserInfo = Get-MsolUser -ObjectId $TargetUser -ErrorAction SilentlyContinue}
            catch {}

            if ($UserInfo) {

                $UserInfo | ForEach-Object {

                    Write-Verbose -Message "$(Get-Date -f T) - User $TargetUser confirmed as valid"
                    Write-Verbose -Message "$(Get-Date -f T) - User Display Name = $(($UserInfo).Displayname)"

                    
                    #Call the analysis function
                    $TargetUserDetail = Measure-MsolUserStrongAuthMethod

                    #Determine if we write to screen or file
                    if ($CsvOutput) {
                            
                        Write-Verbose -Message "$(Get-Date -f T) - Converting analysis to CSV format"

                        #Call property expansion function and pipe into a CSV format
                        $CsvFormat = $TargetUserDetail | Expand-Recommendation | ConvertTo-Csv -NoTypeInformation


                        Write-Verbose -Message "$(Get-Date -f T) - Writing conversion to CSV file"

                        #Write the pertinent CSV line
                        Add-Content -Value $CsvFormat[1] -Path $OutputFile

                        if ($?) {

                            Write-Verbose -Message "$(Get-Date -f T) - Details successfully written to CSV file"

                        }
                        else {

                            Write-Warning -Message "$(Get-Date -f T) - Failed to write details to CSV file"

                        }

                    }
                    else {

                        #Show user analysis in host
                        $TargetUserDetail

                    }

                    #Increment user count
                    $UsersProcessed++

                }

            }
            else {

                Write-Verbose -Message "$(Get-Date -f T) - $($error[0])"
                Write-Warning -Message "$(Get-Date -f T) - Issue obtaining the target user $TargetUser"
                Write-Warning -Message "$(Get-Date -f T) - Exiting script..."

            }

        }
        else {
    
            Write-Verbose -Message "$(Get-Date -f T) - Targetting all users in $TenantId"

            #We're not tagtetting a group, so let's process all users
            Get-MsolUser -All -ErrorAction SilentlyContinue | ForEach-Object {
        
                Write-Verbose -Message "$(Get-Date -f T) - Processing $(($_).UserPrincipalName)"

                #Call the analysis function
                $TargetUserDetail = Measure-MsolUserStrongAuthMethod

                #Determine if we write to screen or file
                if ($CsvOutput) {
                            
                    Write-Verbose -Message "$(Get-Date -f T) - Converting analysis to CSV format"

                    #Call property expansion function and pipe into a CSV format
                    $CsvFormat = $TargetUserdetail | Expand-Recommendation | ConvertTo-Csv -NoTypeInformation


                    Write-Verbose -Message "$(Get-Date -f T) - Writing conversion to CSV file"

                    #Write the pertinent CSV line
                    Add-Content -Value $CsvFormat[1] -Path $OutputFile

                    if ($?) {

                        Write-Verbose -Message "$(Get-Date -f T) - Details successfully written to CSV file"

                    }
                    else {

                        Write-Warning -Message "$(Get-Date -f T) - Failed to write details to CSV file"

                    }

                }
                else {

                    #Show user analysis in host
                    $TargetUserDetail

                }

                #Increment user count
                $UsersProcessed++

            }

        } 
    
    }
    else {

        #We can't connect... say goodbye
        Write-Warning -Message "$(Get-Date -f T) - Exiting script..."

    } 

    #Tracking stuff
    $ScriptEndTime = Get-Date
    $TimeSpan = $ScriptEndTime - $ScriptStartTime
    $ProcessingTime = "{0:c}" -f $TimeSpan

    Write-Verbose -Message "$(Get-Date -f T) - Total users processed: $UsersProcessed"
    Write-Verbose -Message "$(Get-Date -f T) - Total processing time: $ProcessingTime"
    Write-Verbose -Message "$(Get-Date -f T) - Function finished!"

    #endregion main


}   #end function


###################################################
#FUNCTION: Get-AzureADIRMfaPhoneToLocationCheck
###################################################

function Get-AzureADIRMfaPhoneToLocationCheck {

    ##########################################################################################################
    ##########################################################################################################

    <#
    .SYNOPSIS

        Analyses Azure AD users to compare usage location to MFA / alternative phone number location.


    .DESCRIPTION

        Analyses Azure AD users to compare the ISO country code for populated usage location to the international
        dialling code for the registered MFA or alternative phone number.
        
        Displays any users whose MFA phone number or alternative phone number differs from their usage location. 

        Can target an individual user (by ObjectId), a group (by ObjectId) or analyse all users in a tenant.


        IMPORTANT:

        * You can not use a guest (B2B) account to run this script against the target tenant. This is a 
          limitation of the MSOnline PowerShell module. The script will execute in the guest's home tenant,
          not the target tenant.

        * Ensure you run the script with an account that can enumerate user properties. For least privilege
          use the User Administrator role.


    .EXAMPLE

        Get-AzureADIRMfaPhoneToLocationCheck -TenantId 9959f32b-837b-41db-b6e5-32277e344292

        Analyses the usage location information and MFA phone number on a per user basis, for all users in the tenant. Displays the results to screen.


    .EXAMPLE

        Get-AzureADIRMfaPhoneToLocationCheck -TenantId 9959f32b-837b-41db-b6e5-32277e344292 -TargetUser 6a9bcbeb-06e8-4af1-bcfa-37099d5127ee

        Analyses the usage location information and MFA phone number for the target user. Displays the results to screen.


    .EXAMPLE

        Get-AzureADIRMfaPhoneToLocationCheck -TenantId 9959f32b-837b-41db-b6e5-32277e344292 -CsvOutput -Verbose

        Creates a date and time stamped CSV file in the scripts execution directory with per user analysis of usage location and MFA phone number 
        for all users in the tenant. Has verbose notation to screen.


    #>

    ##########################################################################################################

    ################################
    #Define and validate Parameters
    ################################

    [CmdletBinding()]
    param(

        #The unique ID of the tenant to target for analysis
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #The unique ID of the user to analyse
        [Parameter(Position=1)]
        [string]$TargetUser,

        #Use this switch to create a date and time stamped CSV file
        [Parameter(Position=2)]
        [switch]$CsvOutput

        )

    ##########################################################################################################

    ##################
    #region Functions
    ##################

    #############################################
    function Measure-MsolMfaPhoneToLocationCorrelation {

        [CmdletBinding()]
        param(

            #A user object to process
            [Parameter(ValueFromPipeline,Position=0)]
            [Microsoft.Online.Administration.User]$User

        )

        #Set some variables
        $UserPrincipalName = $User.UserPrincipalName
        $DisplayName = $User.DisplayName
        [string]$ObjectId = $User.ObjectId
        $UsageLocation = $User.UsageLocation
        $MfaPhoneNumberPrefix = ($User.StrongAuthenticationUserDetails.PhoneNumber -split " ")[0]
        $AltPhoneNumberPrefix = ($User.StrongAuthenticationUserDetails.AlternativePhoneNumber -split " ")[0]


        if ($MfaPhoneNumberPrefix -or $AltPhoneNumberPrefix) {
        
            Write-Verbose -Message "$(Get-Date -f T) - User has usage location and phone number present - analysing $(($_).UserPrincipalName)"

            $TargetUsageCode = $CountryCodes | Where-Object {$_.IsoCode -eq $UsageLocation}
            $UsageCountry = $TargetUsageCode.Country

            $TargetMfaCode = $CountryCodes | Where-Object {$_.CountryCode -eq $MfaPhoneNumberPrefix}
            [array]$MfaPhoneNumberLocation = $TargetMfaCode.IsoCode
            [array]$MfaPhoneNumberCountry = $TargetMfaCode.Country

            $TargetAltCode = $CountryCodes | Where-Object {$_.CountryCode -eq $AltPhoneNumberPrefix}
            [array]$AltPhoneNumberLocation = $TargetAltCode.IsoCode
            [array]$AltPhoneNumberCountry = $TargetAltCode.Country
            

        }

        #Perform the analysis
        if (($MfaPhoneNumberPrefix -and ($MfaPhoneNumberLocation -notcontains $UsageLocation)) -or ($AltPhoneNumberPrefix -and ($AltPhoneNumberLocation -notcontains $UsageLocation))) {

            Write-Warning -Message "$(Get-Date -f T) - User has usage location and phone number mismatch - $(($_).UserPrincipalName)"

            $AnalysedUser = [pscustomobject]@{

                UserPrincipalName = $UserPrincipalName
                UserDisplayName = $DisplayName
                UserObjectId = $ObjectId
                UserUsageLocation = $UsageLocation
                UserUsageCountry = $UsageCountry
                MfaPhoneNumberPrefix = $MfaPhoneNumberPrefix
                MfaPhoneNumberLocation = $MfaPhoneNumberLocation -join ","
                MfaPhoneNumberCountry = $MfaPhoneNumberCountry -join ","
                AltPhoneNumberPrefix = $AltPhoneNumberPrefix
                AltPhoneNumberLocation = $AltPhoneNumberLocation -join ","
                AltPhoneNumberCountry = $AltPhoneNumberCountry -join ","

            }

            return $AnalysedUser

        }

    }

    #endregion Functions



    #############
    #region Main
    #############

    $JsonCodes = @"
    [
        {
            "Country":  "Afghanistan",
            "CountryCode":  "+93",
            "IsoCode":  "AF"
        },
        {
            "Country":  "Albania",
            "CountryCode":  "+355",
            "IsoCode":  "AL"
        },
        {
            "Country":  "Algeria",
            "CountryCode":  "+213",
            "IsoCode":  "DZ"
        },
        {
            "Country":  "American Samoa",
            "CountryCode":  "+1-684",
            "IsoCode":  "AS"
        },
        {
            "Country":  "Andorra",
            "CountryCode":  "+376",
            "IsoCode":  "AD"
        },
        {
            "Country":  "Angola",
            "CountryCode":  "+244",
            "IsoCode":  "AO"
        },
        {
            "Country":  "Anguilla",
            "CountryCode":  "+1-264",
            "IsoCode":  "AI"
        },
        {
            "Country":  "Antarctica",
            "CountryCode":  "+672",
            "IsoCode":  "AQ"
        },
        {
            "Country":  "Antigua and Barbuda",
            "CountryCode":  "+1-268",
            "IsoCode":  "AG"
        },
        {
            "Country":  "Argentina",
            "CountryCode":  "+54",
            "IsoCode":  "AR"
        },
        {
            "Country":  "Armenia",
            "CountryCode":  "+374",
            "IsoCode":  "AM"
        },
        {
            "Country":  "Aruba",
            "CountryCode":  "+297",
            "IsoCode":  "AW"
        },
        {
            "Country":  "Australia",
            "CountryCode":  "+61",
            "IsoCode":  "AU"
        },
        {
            "Country":  "Austria",
            "CountryCode":  "+43",
            "IsoCode":  "AT"
        },
        {
            "Country":  "Azerbaijan",
            "CountryCode":  "+994",
            "IsoCode":  "AZ"
        },
        {
            "Country":  "Bahamas",
            "CountryCode":  "+1-242",
            "IsoCode":  "BS"
        },
        {
            "Country":  "Bahrain",
            "CountryCode":  "+973",
            "IsoCode":  "BH"
        },
        {
            "Country":  "Bangladesh",
            "CountryCode":  "+880",
            "IsoCode":  "BD"
        },
        {
            "Country":  "Barbados",
            "CountryCode":  "+1-246",
            "IsoCode":  "BB"
        },
        {
            "Country":  "Belarus",
            "CountryCode":  "+375",
            "IsoCode":  "BY"
        },
        {
            "Country":  "Belgium",
            "CountryCode":  "+32",
            "IsoCode":  "BE"
        },
        {
            "Country":  "Belize",
            "CountryCode":  "+501",
            "IsoCode":  "BZ"
        },
        {
            "Country":  "Benin",
            "CountryCode":  "+229",
            "IsoCode":  "BJ"
        },
        {
            "Country":  "Bermuda",
            "CountryCode":  "+1-441",
            "IsoCode":  "BM"
        },
        {
            "Country":  "Bhutan",
            "CountryCode":  "+975",
            "IsoCode":  "BT"
        },
        {
            "Country":  "Bolivia",
            "CountryCode":  "+591",
            "IsoCode":  "BO"
        },
        {
            "Country":  "Bosnia and Herzegovina",
            "CountryCode":  "+387",
            "IsoCode":  "BA"
        },
        {
            "Country":  "Botswana",
            "CountryCode":  "+267",
            "IsoCode":  "BW"
        },
        {
            "Country":  "Brazil",
            "CountryCode":  "+55",
            "IsoCode":  "BR"
        },
        {
            "Country":  "British Indian Ocean Territory",
            "CountryCode":  "+246",
            "IsoCode":  "IO"
        },
        {
            "Country":  "British Virgin Islands",
            "CountryCode":  "+1-284",
            "IsoCode":  "VG"
        },
        {
            "Country":  "Brunei",
            "CountryCode":  "+673",
            "IsoCode":  "BN"
        },
        {
            "Country":  "Bulgaria",
            "CountryCode":  "+359",
            "IsoCode":  "BG"
        },
        {
            "Country":  "Burkina Faso",
            "CountryCode":  "+226",
            "IsoCode":  "BF"
        },
        {
            "Country":  "Myanmar",
            "CountryCode":  "+95",
            "IsoCode":  "MM"
        },
        {
            "Country":  "Burundi",
            "CountryCode":  "+257",
            "IsoCode":  "BI"
        },
        {
            "Country":  "Cambodia",
            "CountryCode":  "+855",
            "IsoCode":  "KH"
        },
        {
            "Country":  "Cameroon",
            "CountryCode":  "+237",
            "IsoCode":  "CM"
        },
        {
            "Country":  "Canada",
            "CountryCode":  "+1",
            "IsoCode":  "CA"
        },
        {
            "Country":  "Cape Verde",
            "CountryCode":  "+238",
            "IsoCode":  "CV"
        },
        {
            "Country":  "Cayman Islands",
            "CountryCode":  "+1-345",
            "IsoCode":  "KY"
        },
        {
            "Country":  "Central African Republic",
            "CountryCode":  "+236",
            "IsoCode":  "CF"
        },
        {
            "Country":  "Chad",
            "CountryCode":  "+235",
            "IsoCode":  "TD"
        },
        {
            "Country":  "Chile",
            "CountryCode":  "+56",
            "IsoCode":  "CL"
        },
        {
            "Country":  "China",
            "CountryCode":  "+86",
            "IsoCode":  "CN"
        },
        {
            "Country":  "Christmas Island",
            "CountryCode":  "+61",
            "IsoCode":  "CX"
        },
        {
            "Country":  "Cocos Islands",
            "CountryCode":  "+61",
            "IsoCode":  "CC"
        },
        {
            "Country":  "Colombia",
            "CountryCode":  "+57",
            "IsoCode":  "CO"
        },
        {
            "Country":  "Comoros",
            "CountryCode":  "+269",
            "IsoCode":  "KM"
        },
        {
            "Country":  "Republic of the Congo",
            "CountryCode":  "+242",
            "IsoCode":  "CG"
        },
        {
            "Country":  "Democratic Republic of the Congo",
            "CountryCode":  "+243",
            "IsoCode":  "CD"
        },
        {
            "Country":  "Cook Islands",
            "CountryCode":  "+682",
            "IsoCode":  "CK"
        },
        {
            "Country":  "Costa Rica",
            "CountryCode":  "+506",
            "IsoCode":  "CR"
        },
        {
            "Country":  "Croatia",
            "CountryCode":  "+385",
            "IsoCode":  "HR"
        },
        {
            "Country":  "Cuba",
            "CountryCode":  "+53",
            "IsoCode":  "CU"
        },
        {
            "Country":  "Curacao",
            "CountryCode":  "+599",
            "IsoCode":  "CW"
        },
        {
            "Country":  "Cyprus",
            "CountryCode":  "+357",
            "IsoCode":  "CY"
        },
        {
            "Country":  "Czech Republic",
            "CountryCode":  "+420",
            "IsoCode":  "CZ"
        },
        {
            "Country":  "Denmark",
            "CountryCode":  "+45",
            "IsoCode":  "DK"
        },
        {
            "Country":  "Djibouti",
            "CountryCode":  "+253",
            "IsoCode":  "DJ"
        },
        {
            "Country":  "Dominica",
            "CountryCode":  "+1-767",
            "IsoCode":  "DM"
        },
        {
            "Country":  "Dominican Republic",
            "CountryCode":  "+1-809, 1-829, 1-849",
            "IsoCode":  "DO"
        },
        {
            "Country":  "East Timor",
            "CountryCode":  "+670",
            "IsoCode":  "TL"
        },
        {
            "Country":  "Ecuador",
            "CountryCode":  "+593",
            "IsoCode":  "EC"
        },
        {
            "Country":  "Egypt",
            "CountryCode":  "+20",
            "IsoCode":  "EG"
        },
        {
            "Country":  "El Salvador",
            "CountryCode":  "+503",
            "IsoCode":  "SV"
        },
        {
            "Country":  "Equatorial Guinea",
            "CountryCode":  "+240",
            "IsoCode":  "GQ"
        },
        {
            "Country":  "Eritrea",
            "CountryCode":  "+291",
            "IsoCode":  "ER"
        },
        {
            "Country":  "Estonia",
            "CountryCode":  "+372",
            "IsoCode":  "EE"
        },
        {
            "Country":  "Ethiopia",
            "CountryCode":  "+251",
            "IsoCode":  "ET"
        },
        {
            "Country":  "Falkland Islands",
            "CountryCode":  "+500",
            "IsoCode":  "FK"
        },
        {
            "Country":  "Faroe Islands",
            "CountryCode":  "+298",
            "IsoCode":  "FO"
        },
        {
            "Country":  "Fiji",
            "CountryCode":  "+679",
            "IsoCode":  "FJ"
        },
        {
            "Country":  "Finland",
            "CountryCode":  "+358",
            "IsoCode":  "FI"
        },
        {
            "Country":  "France",
            "CountryCode":  "+33",
            "IsoCode":  "FR"
        },
        {
            "Country":  "French Polynesia",
            "CountryCode":  "+689",
            "IsoCode":  "PF"
        },
        {
            "Country":  "Gabon",
            "CountryCode":  "+241",
            "IsoCode":  "GA"
        },
        {
            "Country":  "Gambia",
            "CountryCode":  "+220",
            "IsoCode":  "GM"
        },
        {
            "Country":  "Georgia",
            "CountryCode":  "+995",
            "IsoCode":  "GE"
        },
        {
            "Country":  "Germany",
            "CountryCode":  "+49",
            "IsoCode":  "DE"
        },
        {
            "Country":  "Ghana",
            "CountryCode":  "+233",
            "IsoCode":  "GH"
        },
        {
            "Country":  "Gibraltar",
            "CountryCode":  "+350",
            "IsoCode":  "GI"
        },
        {
            "Country":  "Greece",
            "CountryCode":  "+30",
            "IsoCode":  "GR"
        },
        {
            "Country":  "Greenland",
            "CountryCode":  "+299",
            "IsoCode":  "GL"
        },
        {
            "Country":  "Grenada",
            "CountryCode":  "+1-473",
            "IsoCode":  "GD"
        },
        {
            "Country":  "Guam",
            "CountryCode":  "+1-671",
            "IsoCode":  "GU"
        },
        {
            "Country":  "Guatemala",
            "CountryCode":  "+502",
            "IsoCode":  "GT"
        },
        {
            "Country":  "Guernsey",
            "CountryCode":  "+44-1481",
            "IsoCode":  "GG"
        },
        {
            "Country":  "Guinea",
            "CountryCode":  "+224",
            "IsoCode":  "GN"
        },
        {
            "Country":  "Guinea-Bissau",
            "CountryCode":  "+245",
            "IsoCode":  "GW"
        },
        {
            "Country":  "Guyana",
            "CountryCode":  "+592",
            "IsoCode":  "GY"
        },
        {
            "Country":  "Haiti",
            "CountryCode":  "+509",
            "IsoCode":  "HT"
        },
        {
            "Country":  "Honduras",
            "CountryCode":  "+504",
            "IsoCode":  "HN"
        },
        {
            "Country":  "Hong Kong",
            "CountryCode":  "+852",
            "IsoCode":  "HK"
        },
        {
            "Country":  "Hungary",
            "CountryCode":  "+36",
            "IsoCode":  "HU"
        },
        {
            "Country":  "Iceland",
            "CountryCode":  "+354",
            "IsoCode":  "IS"
        },
        {
            "Country":  "India",
            "CountryCode":  "+91",
            "IsoCode":  "IN"
        },
        {
            "Country":  "Indonesia",
            "CountryCode":  "+62",
            "IsoCode":  "ID"
        },
        {
            "Country":  "Iran",
            "CountryCode":  "+98",
            "IsoCode":  "IR"
        },
        {
            "Country":  "Iraq",
            "CountryCode":  "+964",
            "IsoCode":  "IQ"
        },
        {
            "Country":  "Ireland",
            "CountryCode":  "+353",
            "IsoCode":  "IE"
        },
        {
            "Country":  "Isle of Man",
            "CountryCode":  "+44-1624",
            "IsoCode":  "IM"
        },
        {
            "Country":  "Israel",
            "CountryCode":  "+972",
            "IsoCode":  "IL"
        },
        {
            "Country":  "Italy",
            "CountryCode":  "+39",
            "IsoCode":  "IT"
        },
        {
            "Country":  "Ivory Coast",
            "CountryCode":  "+225",
            "IsoCode":  "CI"
        },
        {
            "Country":  "Jamaica",
            "CountryCode":  "+1-876",
            "IsoCode":  "JM"
        },
        {
            "Country":  "Japan",
            "CountryCode":  "+81",
            "IsoCode":  "JP"
        },
        {
            "Country":  "Jersey",
            "CountryCode":  "+44-1534",
            "IsoCode":  "JE"
        },
        {
            "Country":  "Jordan",
            "CountryCode":  "+962",
            "IsoCode":  "JO"
        },
        {
            "Country":  "Kazakhstan",
            "CountryCode":  "+7",
            "IsoCode":  "KZ"
        },
        {
            "Country":  "Kenya",
            "CountryCode":  "+254",
            "IsoCode":  "KE"
        },
        {
            "Country":  "Kiribati",
            "CountryCode":  "+686",
            "IsoCode":  "KI"
        },
        {
            "Country":  "Kosovo",
            "CountryCode":  "+383",
            "IsoCode":  "XK"
        },
        {
            "Country":  "Kuwait",
            "CountryCode":  "+965",
            "IsoCode":  "KW"
        },
        {
            "Country":  "Kyrgyzstan",
            "CountryCode":  "+996",
            "IsoCode":  "KG"
        },
        {
            "Country":  "Laos",
            "CountryCode":  "+856",
            "IsoCode":  "LA"
        },
        {
            "Country":  "Latvia",
            "CountryCode":  "+371",
            "IsoCode":  "LV"
        },
        {
            "Country":  "Lebanon",
            "CountryCode":  "+961",
            "IsoCode":  "LB"
        },
        {
            "Country":  "Lesotho",
            "CountryCode":  "+266",
            "IsoCode":  "LS"
        },
        {
            "Country":  "Liberia",
            "CountryCode":  "+231",
            "IsoCode":  "LR"
        },
        {
            "Country":  "Libya",
            "CountryCode":  "+218",
            "IsoCode":  "LY"
        },
        {
            "Country":  "Liechtenstein",
            "CountryCode":  "+423",
            "IsoCode":  "LI"
        },
        {
            "Country":  "Lithuania",
            "CountryCode":  "+370",
            "IsoCode":  "LT"
        },
        {
            "Country":  "Luxembourg",
            "CountryCode":  "+352",
            "IsoCode":  "LU"
        },
        {
            "Country":  "Macau",
            "CountryCode":  "+853",
            "IsoCode":  "MO"
        },
        {
            "Country":  "Macedonia",
            "CountryCode":  "+389",
            "IsoCode":  "MK"
        },
        {
            "Country":  "Madagascar",
            "CountryCode":  "+261",
            "IsoCode":  "MG"
        },
        {
            "Country":  "Malawi",
            "CountryCode":  "+265",
            "IsoCode":  "MW"
        },
        {
            "Country":  "Malaysia",
            "CountryCode":  "+60",
            "IsoCode":  "MY"
        },
        {
            "Country":  "Maldives",
            "CountryCode":  "+960",
            "IsoCode":  "MV"
        },
        {
            "Country":  "Mali",
            "CountryCode":  "+223",
            "IsoCode":  "ML"
        },
        {
            "Country":  "Malta",
            "CountryCode":  "+356",
            "IsoCode":  "MT"
        },
        {
            "Country":  "Marshall Islands",
            "CountryCode":  "+692",
            "IsoCode":  "MH"
        },
        {
            "Country":  "Mauritania",
            "CountryCode":  "+222",
            "IsoCode":  "MR"
        },
        {
            "Country":  "Mauritius",
            "CountryCode":  "+230",
            "IsoCode":  "MU"
        },
        {
            "Country":  "Mayotte",
            "CountryCode":  "+262",
            "IsoCode":  "YT"
        },
        {
            "Country":  "Mexico",
            "CountryCode":  "+52",
            "IsoCode":  "MX"
        },
        {
            "Country":  "Micronesia",
            "CountryCode":  "+691",
            "IsoCode":  "FM"
        },
        {
            "Country":  "Moldova",
            "CountryCode":  "+373",
            "IsoCode":  "MD"
        },
        {
            "Country":  "Monaco",
            "CountryCode":  "+377",
            "IsoCode":  "MC"
        },
        {
            "Country":  "Mongolia",
            "CountryCode":  "+976",
            "IsoCode":  "MN"
        },
        {
            "Country":  "Montenegro",
            "CountryCode":  "+382",
            "IsoCode":  "ME"
        },
        {
            "Country":  "Montserrat",
            "CountryCode":  "+1-664",
            "IsoCode":  "MS"
        },
        {
            "Country":  "Morocco",
            "CountryCode":  "+212",
            "IsoCode":  "MA"
        },
        {
            "Country":  "Mozambique",
            "CountryCode":  "+258",
            "IsoCode":  "MZ"
        },
        {
            "Country":  "Namibia",
            "CountryCode":  "+264",
            "IsoCode":  "NA"
        },
        {
            "Country":  "Nauru",
            "CountryCode":  "+674",
            "IsoCode":  "NR"
        },
        {
            "Country":  "Nepal",
            "CountryCode":  "+977",
            "IsoCode":  "NP"
        },
        {
            "Country":  "Netherlands",
            "CountryCode":  "+31",
            "IsoCode":  "NL"
        },
        {
            "Country":  "Netherlands Antilles",
            "CountryCode":  "+599",
            "IsoCode":  "AN"
        },
        {
            "Country":  "New Caledonia",
            "CountryCode":  "+687",
            "IsoCode":  "NC"
        },
        {
            "Country":  "New Zealand",
            "CountryCode":  "+64",
            "IsoCode":  "NZ"
        },
        {
            "Country":  "Nicaragua",
            "CountryCode":  "+505",
            "IsoCode":  "NI"
        },
        {
            "Country":  "Niger",
            "CountryCode":  "+227",
            "IsoCode":  "NE"
        },
        {
            "Country":  "Nigeria",
            "CountryCode":  "+234",
            "IsoCode":  "NG"
        },
        {
            "Country":  "Niue",
            "CountryCode":  "+683",
            "IsoCode":  "NU"
        },
        {
            "Country":  "Northern Mariana Islands",
            "CountryCode":  "+1-670",
            "IsoCode":  "MP"
        },
        {
            "Country":  "North Korea",
            "CountryCode":  "+850",
            "IsoCode":  "KP"
        },
        {
            "Country":  "Norway",
            "CountryCode":  "+47",
            "IsoCode":  "NO"
        },
        {
            "Country":  "Oman",
            "CountryCode":  "+968",
            "IsoCode":  "OM"
        },
        {
            "Country":  "Pakistan",
            "CountryCode":  "+92",
            "IsoCode":  "PK"
        },
        {
            "Country":  "Palau",
            "CountryCode":  "+680",
            "IsoCode":  "PW"
        },
        {
            "Country":  "Palestine",
            "CountryCode":  "+970",
            "IsoCode":  "PS"
        },
        {
            "Country":  "Panama",
            "CountryCode":  "+507",
            "IsoCode":  "PA"
        },
        {
            "Country":  "Papua New Guinea",
            "CountryCode":  "+675",
            "IsoCode":  "PG"
        },
        {
            "Country":  "Paraguay",
            "CountryCode":  "+595",
            "IsoCode":  "PY"
        },
        {
            "Country":  "Peru",
            "CountryCode":  "+51",
            "IsoCode":  "PE"
        },
        {
            "Country":  "Philippines",
            "CountryCode":  "+63",
            "IsoCode":  "PH"
        },
        {
            "Country":  "Pitcairn",
            "CountryCode":  "+64",
            "IsoCode":  "PN"
        },
        {
            "Country":  "Poland",
            "CountryCode":  "+48",
            "IsoCode":  "PL"
        },
        {
            "Country":  "Portugal",
            "CountryCode":  "+351",
            "IsoCode":  "PT"
        },
        {
            "Country":  "Puerto Rico",
            "CountryCode":  "+1-787, 1-939",
            "IsoCode":  "PR"
        },
        {
            "Country":  "Qatar",
            "CountryCode":  "+974",
            "IsoCode":  "QA"
        },
        {
            "Country":  "Reunion",
            "CountryCode":  "+262",
            "IsoCode":  "RE"
        },
        {
            "Country":  "Romania",
            "CountryCode":  "+40",
            "IsoCode":  "RO"
        },
        {
            "Country":  "Russia",
            "CountryCode":  "+7",
            "IsoCode":  "RU"
        },
        {
            "Country":  "Rwanda",
            "CountryCode":  "+250",
            "IsoCode":  "RW"
        },
        {
            "Country":  "Saint Barthelemy",
            "CountryCode":  "+590",
            "IsoCode":  "BL"
        },
        {
            "Country":  "Samoa",
            "CountryCode":  "+685",
            "IsoCode":  "WS"
        },
        {
            "Country":  "San Marino",
            "CountryCode":  "+378",
            "IsoCode":  "SM"
        },
        {
            "Country":  "Sao Tome and Principe",
            "CountryCode":  "+239",
            "IsoCode":  "ST"
        },
        {
            "Country":  "Saudi Arabia",
            "CountryCode":  "+966",
            "IsoCode":  "SA"
        },
        {
            "Country":  "Senegal",
            "CountryCode":  "+221",
            "IsoCode":  "SN"
        },
        {
            "Country":  "Serbia",
            "CountryCode":  "+381",
            "IsoCode":  "RS"
        },
        {
            "Country":  "Seychelles",
            "CountryCode":  "+248",
            "IsoCode":  "SC"
        },
        {
            "Country":  "Sierra Leone",
            "CountryCode":  "+232",
            "IsoCode":  "SL"
        },
        {
            "Country":  "Singapore",
            "CountryCode":  "+65",
            "IsoCode":  "SG"
        },
        {
            "Country":  "Sint Maarten",
            "CountryCode":  "+1-721",
            "IsoCode":  "SX"
        },
        {
            "Country":  "Slovakia",
            "CountryCode":  "+421",
            "IsoCode":  "SK"
        },
        {
            "Country":  "Slovenia",
            "CountryCode":  "+386",
            "IsoCode":  "SI"
        },
        {
            "Country":  "Solomon Islands",
            "CountryCode":  "+677",
            "IsoCode":  "SB"
        },
        {
            "Country":  "Somalia",
            "CountryCode":  "+252",
            "IsoCode":  "SO"
        },
        {
            "Country":  "South Africa",
            "CountryCode":  "+27",
            "IsoCode":  "ZA"
        },
        {
            "Country":  "South Korea",
            "CountryCode":  "+82",
            "IsoCode":  "KR"
        },
        {
            "Country":  "South Sudan",
            "CountryCode":  "+211",
            "IsoCode":  "SS"
        },
        {
            "Country":  "Spain",
            "CountryCode":  "+34",
            "IsoCode":  "ES"
        },
        {
            "Country":  "Sri Lanka",
            "CountryCode":  "+94",
            "IsoCode":  "LK"
        },
        {
            "Country":  "Saint Helena",
            "CountryCode":  "+290",
            "IsoCode":  "SH"
        },
        {
            "Country":  "Saint Kitts and Nevis",
            "CountryCode":  "+1-869",
            "IsoCode":  "KN"
        },
        {
            "Country":  "Saint Lucia",
            "CountryCode":  "+1-758",
            "IsoCode":  "LC"
        },
        {
            "Country":  "Saint Martin",
            "CountryCode":  "+590",
            "IsoCode":  "MF"
        },
        {
            "Country":  "Saint Pierre and Miquelon",
            "CountryCode":  "+508",
            "IsoCode":  "PM"
        },
        {
            "Country":  "Saint Vincent and the Grenadines",
            "CountryCode":  "+1-784",
            "IsoCode":  "VC"
        },
        {
            "Country":  "Sudan",
            "CountryCode":  "+249",
            "IsoCode":  "SD"
        },
        {
            "Country":  "Suriname",
            "CountryCode":  "+597",
            "IsoCode":  "SR"
        },
        {
            "Country":  "Svalbard and Jan Mayen",
            "CountryCode":  "+47",
            "IsoCode":  "SJ"
        },
        {
            "Country":  "Swaziland",
            "CountryCode":  "+268",
            "IsoCode":  "SZ"
        },
        {
            "Country":  "Sweden",
            "CountryCode":  "+46",
            "IsoCode":  "SE"
        },
        {
            "Country":  "Switzerland",
            "CountryCode":  "+41",
            "IsoCode":  "CH"
        },
        {
            "Country":  "Syria",
            "CountryCode":  "+963",
            "IsoCode":  "SY"
        },
        {
            "Country":  "Taiwan",
            "CountryCode":  "+886",
            "IsoCode":  "TW"
        },
        {
            "Country":  "Tajikistan",
            "CountryCode":  "+992",
            "IsoCode":  "TJ"
        },
        {
            "Country":  "Tanzania",
            "CountryCode":  "+255",
            "IsoCode":  "TZ"
        },
        {
            "Country":  "Thailand",
            "CountryCode":  "+66",
            "IsoCode":  "TH"
        },
        {
            "Country":  "Togo",
            "CountryCode":  "+228",
            "IsoCode":  "TG"
        },
        {
            "Country":  "Tokelau",
            "CountryCode":  "+690",
            "IsoCode":  "TK"
        },
        {
            "Country":  "Tonga",
            "CountryCode":  "+676",
            "IsoCode":  "TO"
        },
        {
            "Country":  "Trinidad and Tobago",
            "CountryCode":  "+1-868",
            "IsoCode":  "TT"
        },
        {
            "Country":  "Tunisia",
            "CountryCode":  "+216",
            "IsoCode":  "TN"
        },
        {
            "Country":  "Turkey",
            "CountryCode":  "+90",
            "IsoCode":  "TR"
        },
        {
            "Country":  "Turkmenistan",
            "CountryCode":  "+993",
            "IsoCode":  "TM"
        },
        {
            "Country":  "Turks and Caicos Islands",
            "CountryCode":  "+1-649",
            "IsoCode":  "TC"
        },
        {
            "Country":  "Tuvalu",
            "CountryCode":  "+688",
            "IsoCode":  "TV"
        },
        {
            "Country":  "United Arab Emirates",
            "CountryCode":  "+971",
            "IsoCode":  "AE"
        },
        {
            "Country":  "Uganda",
            "CountryCode":  "+256",
            "IsoCode":  "UG"
        },
        {
            "Country":  "United Kingdom",
            "CountryCode":  "+44",
            "IsoCode":  "GB"
        },
        {
            "Country":  "Ukraine",
            "CountryCode":  "+380",
            "IsoCode":  "UA"
        },
        {
            "Country":  "Uruguay",
            "CountryCode":  "+598",
            "IsoCode":  "UY"
        },
        {
            "Country":  "United States",
            "CountryCode":  "+1",
            "IsoCode":  "US"
        },
        {
            "Country":  "Uzbekistan",
            "CountryCode":  "+998",
            "IsoCode":  "UZ"
        },
        {
            "Country":  "Vanuatu",
            "CountryCode":  "+678",
            "IsoCode":  "VU"
        },
        {
            "Country":  "Vatican",
            "CountryCode":  "+379",
            "IsoCode":  "VA"
        },
        {
            "Country":  "Venezuela",
            "CountryCode":  "+58",
            "IsoCode":  "VE"
        },
        {
            "Country":  "Vietnam",
            "CountryCode":  "+84",
            "IsoCode":  "VN"
        },
        {
            "Country":  "U.S. Virgin Islands",
            "CountryCode":  "+1-340",
            "IsoCode":  "VI"
        },
        {
            "Country":  "Wallis and Futuna",
            "CountryCode":  "+681",
            "IsoCode":  "WF"
        },
        {
            "Country":  "Western Sahara",
            "CountryCode":  "+212",
            "IsoCode":  "EH"
        },
        {
            "Country":  "Yemen",
            "CountryCode":  "+967",
            "IsoCode":  "YE"
        },
        {
            "Country":  "Zambia",
            "CountryCode":  "+260",
            "IsoCode":  "ZM"
        },
        {
            "Country":  "Zimbabwe",
            "CountryCode":  "+263",
            "IsoCode":  "ZW"
        }
    ]
"@ 

    $CountryCodes = $JsonCodes | ConvertFrom-Json


    #Tracking variables
    $UsersProcessed = 0
    $ScriptStartTime = Get-Date

    #Verbose output
    Write-Verbose -Message "$(Get-Date -f T) - Function started..."
    if ($CsvOutput) {Write-Verbose -Message "$(Get-Date -f T) - CSV output selected"}


    #Some additional paramter validation outside of param()

    #Try and connect to Azure AD
    try {$DomainInfo = Get-MsolDomain -TenantId $TenantId -ErrorAction SilentlyContinue}
    catch {}

    if ($DomainInfo) {

        Write-Verbose -Message "$(Get-Date -f T) - Connection to $TenantId established"

    }
    else {

        #Present connection pop-up
        Write-Verbose -Message "$(Get-Date -f T) - Calling Connect-MsolService cmdlet"
        Connect-MsolService -ErrorAction SilentlyContinue
            
        #Populate the DomainInfo variable if Connect-MsolService works
        if ($?) {
                
            Write-Verbose -Message "$(Get-Date -f T) - Connection to $TenantId established"
            $DomainInfo = $true
        }
        else {

            Write-Verbose "$(Get-Date -f T) - Connection to $TenantId could not be established"

        }

    }

    #Check if we have a connection
    if ($DomainInfo) {

        #Check if we need to create a CSV file
        if ($CsvOutput) {

            #Output file
            $Now = "{0:yyyyMMdd_hhmmss}" -f (Get-Date)
            $OutputFile = "MfaPhoneToLocationCorrelation_$now.csv"

            Write-Verbose -Message "$(Get-Date -f T) - Creating CSV file - $OutputFile"


            Add-Content -Value "UserPrincipalName,UserDisplayName,UserObjectId,UserUsageLocation,UserUsageCountry,MfaPhoneNumberPrefix,MfaPhoneNumberLocation,MfaPhoneNumberCountry,AltPhoneNumberPrefix,AltPhoneNumberLocation,AltPhoneNumberCountry" `
                        -Path $OutputFile -ErrorAction SilentlyContinue

            if ($?) {

                Write-Verbose -Message "$(Get-Date -f T) - Header written to CSV file - $OutputFile"
            
            }
            else {

                Write-Warning -Message "$(Get-Date -f T) - Failed to write header to CSV file - $OutputFile"
                Write-Warning -Message "$(Get-Date -f T) - Reverting to non-CSV output mode"
            
                #Prevent further CSV processing
                $CsvOutput = $false

            }

        }

        #Check if we need to run for one user or the whole tenant
        if ($TargetUser) {

            Write-Verbose -Message "$(Get-Date -f T) - Checking for target user - $TargetUser"

            #Single user
            $ObtainedUser = Get-MsolUser -ObjectId $TargetUser -TenantId $TenantId -ErrorAction SilentlyContinue 
            
            if ($ObtainedUser) {

                Write-Verbose -Message "$(Get-Date -f T) - User $TargetUser confirmed as valid"
                Write-Verbose -Message "$(Get-Date -f T) - User Display Name = $(($ObtainedUser).Displayname)"

                if ($ObtainedUser.UsageLocation) {

                    $ObtainedUser | ForEach-Object {

                        #Analyse the user
                        $AnalysedUser = Measure-MsolMfaPhoneToLocationCorrelation -User $_

                        #Check for CSV output
                        if ($CsvOutput) {

                            Write-Verbose -Message "$(Get-Date -f T) - Converting analysis to CSV format"

                            #Call property expansion function and pipe into a CSV format
                            $CsvFormat = $AnalysedUser | ConvertTo-Csv -NoTypeInformation


                            Write-Verbose -Message "$(Get-Date -f T) - Writing conversion to CSV file"

                            #Write the pertinent CSV line
                            Add-Content -Value $CsvFormat[1] -Path $OutputFile

                            if ($?) {

                                Write-Verbose -Message "$(Get-Date -f T) - Details successfully written to CSV file"

                            }
                            else {

                                Write-Warning -Message "$(Get-Date -f T) - Failed to write details to CSV file"

                            }


                        }
                        else {


                            $AnalysedUser

                        }

                        #Increment user count
                        $UsersProcessed++


                    }

                }
                else {

                    Write-Warning -Message "$(Get-Date -f T) - The target user - $TargetUser - does not have usage location populated"
                    Write-Warning -Message "$(Get-Date -f T) - Exiting script..."               

                }


            }
            else {

                Write-Verbose -Message "$(Get-Date -f T) - $($error[0])"
                Write-Warning -Message "$(Get-Date -f T) - Issue obtaining the target user $TargetUser"
                Write-Warning -Message "$(Get-Date -f T) - Exiting script..."

            }


        }
        else {

            Write-Verbose -Message "$(Get-Date -f T) - Checking all users in the tenant"


            Get-MsolUser -All -TenantId $TenantId -ErrorAction SilentlyContinue  | ForEach-Object {

                if ($_.UsageLocation) {

                    #Analyse the user
                    $AnalysedUser = Measure-MsolMfaPhoneToLocationCorrelation -User $_

                    #We populate the UsageCountry if an MFA phone number or alternative phone number are found in the analysis
                    if ($AnalysedUser.UserUsageCountry) {

                        #Check for CSV output
                        if ($CsvOutput) {

                            Write-Verbose -Message "$(Get-Date -f T) - Converting analysis to CSV format"

                            #Call property expansion function and pipe into a CSV format
                            $CsvFormat = $AnalysedUser | ConvertTo-Csv -NoTypeInformation


                            Write-Verbose -Message "$(Get-Date -f T) - Writing conversion to CSV file"

                            #Write the pertinent CSV line
                            Add-Content -Value $CsvFormat[1] -Path $OutputFile

                            if ($?) {

                                Write-Verbose -Message "$(Get-Date -f T) - Details successfully written to CSV file"

                            }
                            else {

                                Write-Warning -Message "$(Get-Date -f T) - Failed to write details to CSV file"

                            }


                        }
                        else {

                            $AnalysedUser

                        }

                    }

                }


                #Increment user count
                $UsersProcessed++


            }

        }

    }
    else {

        #We can't connect... say goodbye
        Write-Warning -Message "$(Get-Date -f T) - Exiting script..."

    } 

    #Tracking stuff
    $ScriptEndTime = Get-Date
    $TimeSpan = $ScriptEndTime - $ScriptStartTime
    $ProcessingTime = "{0:c}" -f $TimeSpan

    Write-Verbose -Message "$(Get-Date -f T) - Total users processed: $UsersProcessed"
    Write-Verbose -Message "$(Get-Date -f T) - Total processing time: $ProcessingTime"
    Write-Verbose -Message "$(Get-Date -f T) - Function finished!"

    #endregion Main


}   #end function


#endregion



#################################
#################################
#region 7) POLICIES


##################################################
#FUNCTION: Get-AzureADIRConditionalAccessPolicy
##################################################

function Get-AzureADIRConditionalAccessPolicy {

    ############################################################################

    <#
    .SYNOPSIS

        Gets Azure Active Directory Conditional Access policies.


    .DESCRIPTION

        Gets Azure Active Directory Conditional Access policies for the target tenant.

            Use -All to get details for all policies.

            Use -PolicyDisplayName to target a single policy.

        Can also produce a date and time stamped XML file as output to capture multi-layered arrays.


    .EXAMPLE

        Get-AzureADIRConditionalAccessPolicy -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f -All

        Gets all Conditional Access policies for the tenant.


    .EXAMPLE

        Get-AzureADIRConditionalAccessPolicy -TenantId b446a536-cb76-4360-a8bb-6593cf4d9c7f 
        -PolicyDisplayName "Box Block" -XmlOutput

        Gets the details of the Conditional Access policy called "Box Block" 

        Writes the output to a date and time stamped XML file in the execution directory.


    #>

    ############################################################################

    [CmdletBinding()]
    param(

        #The tenant ID
        [Parameter(Mandatory,Position=0)]
        [guid]$TenantId,

        #Bring back all conditional access policies
        [Parameter(Mandatory,Position=1,ParameterSetName="All")]
        [switch]$All,

        #Bring back a specific policy by display name
        [Parameter(Mandatory,Position=2,ParameterSetName="PolicyDisplayName")]
        [string]$PolicyDisplayName,

        #Use this switch to create a date and time stamped XML file
        [Parameter(Position=3)]
        [switch]$XmlOutput

    )


    ############################################################################

    #Deal with different search criterea
    if ($All) {

        #API endpoint
        $Filter = ""

        Write-Verbose -Message "$(Get-Date -f T) - All policies mode selected"

    }
    elseif ($PolicyDisplayName) {

        #API endpoint
        $Filter = "?`$filter=displayName eq '$PolicyDisplayName'"

        Write-Verbose -Message "$(Get-Date -f T) - Single policy mode selected"

    }


    ############################################################################
    
    $Url = "https://graph.microsoft.com/beta/conditionalAccess/policies$Filter"


    ############################################################################

    #Get / refresh an access token
    $Token = (Get-AzureADIRApiToken -TenantId $TenantId).AccessToken

    if ($Token) {

        #Construct header with access token
        $Header = Get-AzureADIRHeader -Token $Token

        #Tracking variables
        $TotalReport = $null


        #Call the API query loop
        $TotalReport = Invoke-AzureADIRDoWhile -Header $Header -Url $Url


    }

    #See if we need to write to XML
    if ($XmlOutput) {

        #Output file
        $now = "{0:yyyyMMdd_hhmmss}" -f (Get-Date)
        $XmlName = "ConditionalAccess_$now.xml"

        Write-Verbose -Message "$(Get-Date -f T) - Generating a XML for Conditional Access details"

        $TotalReport | Export-Clixml -Path $XmlName

        Write-Verbose -Message "$(Get-Date -f T) - Conditional Access details written to $(Get-Location)\$XmlName"

    }
    else {

        #Return stuff
        $TotalReport

    }

}   #end function


#endregion



#################################
#################################
#region 8) MISC


###############################################
#FUNCTION: Get-AzureADIRObjectIdToDisplayName
###############################################

function Get-AzureADIRObjectIdToDisplayName {

    ############################################################################

    <#
    .SYNOPSIS

        Looks up an ObjectId and displays its human-friendly properties.


    .DESCRIPTION

        Looks up an ObjectId and shows its display name and other associated properties:
        
            * DisplayName
            * ObjectType
            * ObjectId 


    .EXAMPLE

        Get-AzureADIRObjectIdToDisplayName -ObjectId 69447235-0974-4af6-bfa3-d0e922a92048

        Gets the displayname for the supplied ObjectID - 69447235-0974-4af6-bfa3-d0e922a92048.


    .EXAMPLE

        Get-AzureADIRObjectIdToDisplayName -ObjectId 69447235-0974-4af6-bfa3-d0e922a92048,21fda713-d825-4a80-8e3a-7323b9dcd4b3

        Gets the displayname for the supplied ObjectIDs - 69447235-0974-4af6-bfa3-d0e922a92048, 21fda713-d825-4a80-8e3a-7323b9dcd4b3


    #>

    ############################################################################

    [CmdletBinding()]
    param(

        #The object IDs to look up a display name for
        [Parameter(Mandatory,Position=0)]
        [array]$ObjectIds

    )


    ############################################################################

 

    #Get tenant details to test that Connect-AzureADIR has been called
    try {

        $TenantInfo = Get-AzureADTenantDetail

    } 
    catch {

        throw "You must call Connect-AzureADIR to run this function"
    
    }


    $InitialDomain = ($TenantInfo.VerifiedDomains | Where-Object {$_.Initial}).Name
    Write-Verbose -Message "$(Get-Date -f T) - Target tenant ID initial domain name - $InitialDomain"


    #Get a list of directory roles

    Write-Verbose -Message "$(Get-Date -f T) - Attempting to get display name for $ObjectIds"

    try {$DisplayNames = Get-AzureADObjectByObjectId -ObjectIds $ObjectIds -ErrorAction SilentlyContinue}
    catch {}

    if ($DisplayNames) {

        Write-Verbose -Message "$(Get-Date -f T) - $(($DisplayNames).Count) objects found"

        $DisplayNames | ForEach-Object {


            $Properties = [PSCustomObject]@{

                ObjectId = $_.ObjectId
                DisplayName = $_.DisplayName
                ObjectType = "$($_.UserType)$($_.ObjectType)"

            } 
            
            [array]$TotalObjects += $Properties      

        }


        $TotalObjects

    }
    else {

        Write-Warning -Message "$(Get-Date -f T) - Issue with objectID list"

    }


}   #end function


###############################################
#FUNCTION: Get-AzureADIRDisplayNameToObjectId
###############################################

function Get-AzureADIRDisplayNameToObjectId {

    ############################################################################

    <#
    .SYNOPSIS

        Looks up a display name and shows its object ID.


    .DESCRIPTION

        Looks up a display name with a StartsWith filter. Shows its object ID and associated properties:

            * DisplayName
            * ObjectId
            * ObjectType

        Use with the -ObjectType parameter to target a specific object type. 


    .EXAMPLE

        Get-AzureADIRDisplayNameToObjectId -DisplayName "Ian Dreamer" -ObjectType User

        Gets the DisplayName, ObjectId and Object type for the supplied user display name - "Ian Dreamer".


    .EXAMPLE

        Get-AzureADIRDisplayNameToObjectId -DisplayNameStartsWith "All Sales" -ObjectType Group

        Gets the DisplayName, ObjectId and Object type for the supplied group display name - "All Sales".


    .EXAMPLE

        Get-AzureADIRDisplayNameToObjectId -DisplayNameStartsWith WinSrv -ObjectType Device

        Gets the DisplayName, ObjectId and Object type for the supplied device display name - WinSrv.


    .EXAMPLE

        Get-AzureADIRDisplayNameToObjectId -DisplayNameStartsWith Microsoft -ObjectType ServicePrincipal

        Gets the DisplayName, ObjectId and Object type for the supplied ServicePrincipal display name - Microsoft.


    .EXAMPLE

        Get-AzureADIRDisplayNameToObjectId -DisplayNameStartsWith Sales -ObjectType Application

        Gets the DisplayName, ObjectId and Object type for the supplied Application display name - Sales.


    #>

    ############################################################################

    [CmdletBinding()]
    param(

        #The display name to look up an object ID for
        [Parameter(Mandatory,Position=0)]
        [string]$DisplayNameStartsWith,

        #The object type to perform the look-up against
        [Parameter(Mandatory,Position=1)]
        [ValidateSet("User","Group","Device","ServicePrincipal","Application")] 
        [string]$ObjectType


    )


    ############################################################################

 
    #Get tenant details to test that Connect-AzureADIR has been called
    try {

        $TenantInfo = Get-AzureADTenantDetail

    } 
    catch {

        throw "You must call Connect-AzureADIR to run this function"
    
    }


    $InitialDomain = ($TenantInfo.VerifiedDomains | Where-Object {$_.Initial}).Name
    Write-Verbose -Message "$(Get-Date -f T) - Target tenant ID initial domain name - $InitialDomain"


    #Select look-up mode
    switch ($ObjectType) {


        "User" {

            Write-Verbose -Message "$(Get-Date -f T) - ObjectType is 'User'"
            try {$Objects = Get-AzureADUser -SearchString $DisplayNameStartsWith -ErrorAction SilentlyContinue}
            catch {}
            
        }

        "Group" {

            Write-Verbose -Message "$(Get-Date -f T) - ObjectType is 'Group'"
            try {$Objects = Get-AzureADGroup -SearchString $DisplayNameStartsWith -ErrorAction SilentlyContinue}
            catch {}

        }

        "Device" {

            Write-Verbose -Message "$(Get-Date -f T) - ObjectType is 'Device'"
            try {$Objects = Get-AzureADDevice -SearchString $DisplayNameStartsWith -ErrorAction SilentlyContinue}
            catch {}

        }

        "ServicePrincipal" {

            Write-Verbose -Message "$(Get-Date -f T) - ObjectType is 'ServicePrincipal'"
            try {$Objects = Get-AzureADServicePrincipal -SearchString $DisplayNameStartsWith -ErrorAction SilentlyContinue}
            catch {}

        }

        "Application" {

            Write-Verbose -Message "$(Get-Date -f T) - ObjectType is 'Application'"
            try {$Objects = Get-AzureADApplication -SearchString $DisplayNameStartsWith -ErrorAction SilentlyContinue}
            catch {}

        }


    }


    if ($Objects) {

        Write-Verbose -Message "$(Get-Date -f T) - Display name - `'$DisplayNameStartsWith`' - found"

        $Objects | ForEach-Object {


            $Properties = [PSCustomObject]@{

                DisplayName = $_.DisplayName
                ObjectId = $_.ObjectId
                ObjectType = "$($_.UserType)$($_.ObjectType)"

            } 
            
            [array]$TotalObjects += $Properties      

        }


        $TotalObjects

    }
    else {

        Write-Warning -Message "$(Get-Date -f T) - Issue with display name"

    }


}   #end function


#endregion


#############################################################################################################
#############################################################################################################