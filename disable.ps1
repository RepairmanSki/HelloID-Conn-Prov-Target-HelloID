﻿$portalBaseUrl = "https://<customer_portal>.helloid.com";
$HelloIDApiKey = "<Provide your API key here>";
$HelloIDApiSecret = "<Provide your API secret here>";

# Enable TLS 1.2
if ([Net.ServicePointManager]::SecurityProtocol -notmatch "Tls12") {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}

#Initialize default properties
$success = $False;
$p = $person | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$aRef = $accountReference | ConvertFrom-Json;
$mRef = $managerAccountReference | ConvertFrom-Json;
$auditMessage = "Account for person " + $p.DisplayName + " not disabled succesfully";

try{
    if(-Not($dryRun -eq $True)) {
        # Create authorization headers with HelloID API key
        $pair = "${HelloIDApiKey}:${HelloIDApiSecret}"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $key = "Basic $base64"

        $headers = @{"authorization" = $Key}

        # Define specific endpoint URI
        if($PortalBaseUrl.EndsWith("/") -eq $false){
            $PortalBaseUrl = $PortalBaseUrl + "/"
        }
        $uri = ($PortalBaseUrl +"api/v1/users/$aRef")

        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false

        Write-Verbose -Verbose ("Account for person " + $p.DisplayName + " gathered succesfully");
    }
}catch{
    if(-Not($_.Exception.Response -eq $null)){
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $errResponse = $reader.ReadToEnd();
        Write-Verbose -Verbose (" not gathered succesfully: ${errResponse}");
    }else {
        Write-Verbose -Verbose (" not gathered succesfully: General error");
    }  
}

#Change mapping here
$account = $response 
$account.isEnabled = $false

try{
    if(-Not($dryRun -eq $True)) {
        # Define specific endpoint URI
        if($PortalBaseUrl.EndsWith("/") -eq $false){
            $PortalBaseUrl = $PortalBaseUrl + "/"
        }
        $uri = ($PortalBaseUrl +"api/v1/users/$aRef")

        $body = $account | ConvertTo-Json -Depth 10
        $response = Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ContentType "application/json" -Verbose:$false

        $success = $True;
        $auditMessage = " disabled succesfully"; 
    }
}catch{
    if(-Not($_.Exception.Response -eq $null)){
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $errResponse = $reader.ReadToEnd();
        $auditMessage = " not disabled succesfully: ${errResponse}";
    }else {
        $auditMessage = " not disabled succesfully: General error";
    }  
}

#build up result
$result = [PSCustomObject]@{ 
	Success = $success;
	AccountReference = $aRef;
	AuditDetails = $auditMessage;
    Account = $account;

    # Optionally return data for use in other systems
    ExportData = [PSCustomObject]@{
        displayName = $account.DisplayName;
        userName = $account.UserName;
        externalId = $aRef;
    };
};

#send result back
Write-Output $result | ConvertTo-Json -Depth 10