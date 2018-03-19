

# Create file:
# $text | Set-Content 'InactiveSites.txt'

[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")

function Get-SPOAllWeb
{
  
   param (
   [Parameter(Mandatory=$true,Position=1)]
		[string]$Username,
		[Parameter(Mandatory=$true,Position=2)]
		$AdminPassword,
        [Parameter(Mandatory=$true,Position=3)]
		[string]$Url
		)
     try
    {
      $ctx=New-Object Microsoft.SharePoint.Client.ClientContext($Url)
      $ctx.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Username, $AdminPassword)
      $ctx.Load($ctx.Web.Webs)
      $ctx.Load($ctx.Web)
      $ctx.ExecuteQuery()
      $siteUsers=$ctx.Web.SiteUsers
      $ctx.Load($siteUsers)
      $ctx.ExecuteQuery()
      #Write-Host "Sites:"  $ctx.Web.Title
      if($ctx.Web.LastItemModifiedDate.ToLocalTime() -lt ((Get-Date).AddMonths(-12)))
      {
        # Append to file:
        $text = "Web:" + $ctx.Web.Url +" Last Modified on:" +$ctx.Web.LastItemModifiedDate.ToLocalTime()
        $text =$text+" Site Administrator:" 
        foreach ($user in $siteUsers)
            {
              if ($user.IsSiteAdmin)
              {
                  $text =$text + $user.Title.ToString() + ","            
              }
            }
          $text | Add-Content 'InactiveSites.txt'
          #Check for subsites
        }
        if($ctx.Web.Webs.Count -eq 0)
        {
        
        }
        else{
          #$text | Add-Content 'subsites'
          foreach ($web in $ctx.Web.Webs)
          {
            #Write-Host "Subsite sites:"  $web.Title
            Get-SPOAllWeb -Username $Username -AdminPassword $AdminPassword -Url $web.Url
          }
        }
      $text = "Web:" + $ctx.Web.Url +" Last Modified on:" +$ctx.Web.LastItemModifiedDate.ToLocalTime()
      $text | Add-Content 'AccessToSites.txt'
    }
  catch 
  { 
      $text=$Url
      $text | Add-Content 'ErrorInSites.txt'
   } 
  
#>
}

#Get All files from document folder of source site 
function Get-FilesFromSource
{
   param (
   [Parameter(Mandatory=$true,Position=1)]
		[string]$adminUserName,
		[Parameter(Mandatory=$true,Position=2)]
		$adminPassword,
        [Parameter(Mandatory=$true,Position=3)]
		[string]$sourceSite
		)
    $listTitle = "Documents"
    $sourceFolder = "/Shared Documents"
    
    #$sourceSite="https://myownsoftronic.sharepoint.com/Test-Subsite"
    $ctx = New-Object Microsoft.SharePoint.Client.ClientContext($sourceSite)
    $credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($adminUserName,$adminPassword)
    $ctx.credentials = $credentials
    #Write-Host $adminUrelek
    #Load items
    $ctx.Load($ctx.Web)
    $ctx.ExecuteQuery()
    $list = $ctx.Web.Lists.GetByTitle($listTitle)
    $query = [Microsoft.SharePoint.Client.CamlQuery]::CreateAllItemsQuery()
    $query.FolderServerRelativeUrl=$ctx.Web.ServerRelativeUrl + "/Shared Documents";
    $items = $list.GetItems($query)
    $ctx.Load($items)
    $ctx.ExecuteQuery()
    return $items;
}



#Retrieve list
#Copy all files from the listItems to document folder of Destination site
function Copy-FilesToDestination
{
   param (
   [Parameter(Mandatory=$true,Position=1)]
		[string]$adminUserName,
		[Parameter(Mandatory=$true,Position=2)]
		$adminPassword,
    [Parameter(Mandatory=$true,Position=3)]
		$Documentitems

		)
    $sourceSite="https://myownsoftronic.sharepoint.com/Test-Subsite"
    $ctx = New-Object Microsoft.SharePoint.Client.ClientContext($sourceSite)
    $credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($adminUserName,$adminPassword)
    $ctx.credentials = $credentials

    Write-Host  "Copying documents to Backup site...."
    $destFolder = "https://myownsoftronic.sharepoint.com/sites/BackupDocuments/Shared Documents"
    $destinationSite = "https://myownsoftronic.sharepoint.com/sites/BackupDocuments"
    $listTitle = "Documents"
    $destinationContext=New-Object Microsoft.SharePoint.Client.ClientContext($destinationSite)
    $credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($adminUserName,$adminPassword)
    $destinationContext.credentials = $credentials
    $destinationContext.Load($destinationContext.Web)
    $destinationContext.ExecuteQuery()
    $dList = $destinationContext.Web.Lists.GetByTitle($listTitle)
    $queryForD = [Microsoft.SharePoint.Client.CamlQuery]::CreateAllItemsQuery()
    $queryForD.FolderServerRelativeUrl=$destinationContext.Web.ServerRelativeUrl + "/Shared Documents";
    $dListFiles = $dList.GetItems($queryForD)
    $destinationContext.Load($dListFiles)
    $destinationContext.ExecuteQuery()
    #Retrieve list
    $documentList = $destinationContext.Web.Lists.GetByTitle($listTitle)
    $destinationContext.Load($documentList)
    $destinationContext.ExecuteQuery()
    Write-Host "In Progress."
    #Loop through the sourceListItems
    foreach ($File in $Documentitems){
          $destUrl = $destList.RootFolder.ServerRelativeUrl + "/" + $item.File.Name
              
          $FileRef = $File["FileRef"].split("/");
          $fileName = $FileRef[$FileRef.length-1];
          Write-Host "File Name is moving:"$fileName
          $destFileUrl = $destFolder+"/"+$fileName
          $sourceFile = [Microsoft.SharePoint.Client.File]::OpenBinaryDirect($ctx, $File["FileRef"])
          $FileStream = New-Object System.IO.MemoryStream
          $sourceFile.stream.copyTo($FileStream)
          $FileStream.Seek(0, [System.IO.SeekOrigin]::Begin)          
          $FileCreationInfo = New-Object Microsoft.SharePoint.Client.FileCreationInformation
          $FileCreationInfo.Overwrite = $true  
          $FileCreationInfo.ContentStream = $FileStream
          $FileCreationInfo.URL = $destFileUrl
          $Upload = $documentList.RootFolder.Files.Add($FileCreationInfo)
          write-host "Copying Metadata" -ForegroundColor DarkCyan
          $destinationContext.Load($Upload)
          $destinationContext.ExecuteQuery()
          write-host "File Copied" -ForegroundColor Green        
    }
}

<#
$passie=Read-Host -Prompt "Password" -AsSecureString
$adminUrelek=Read-Host -Prompt "Admin url"
$adminUserName=Read-Host -Prompt "Admin username" 
#>
$passie=Read-Host -Prompt "Password" -AsSecureString
$adminUrelek="https://myownsoftronic-admin.sharepoint.com/"
$adminUserName="umer@myownsoftronic.onmicrosoft.com"
Connect-SPOService -Url $adminUrelek -Credential $adminUserName
$sites=(Get-SPOSite -Limit ALL).Url
$webs=Get-SPOWeb -Username $adminUrelek -AdminPassword $passie -Url adminUrelek -IncludeSubsites $true | select url
foreach($url in $webs)
{
Write-Host $url
}
# Create file:
$text = 'List of Inactive sites '
$text | set-Content 'InactiveSites.txt'
'List of Unaccessable Sites ' | set-Content 'AccessToSites.txt'
'List of accessable Sites' | set-Content 'ErrorInSites.txt'

Write-Host "Number of sites:"  $sites.length
#Write-Host "Date 12 months back: " (Get-Date).AddMonths(-12)
Write-Host  "Adding Inactive Webs in the list...."
#Get-SPOAllWeb -Username $adminUserName -AdminPassword $passie -Url "https://softronic2.sharepoint.com/sites/SPO365test1"
<#foreach($url in $sites)
{
  Get-SPOAllWeb -Username $adminUserName -AdminPassword $passie -Url $url
}#>
Write-Host  "Adding webs finished."

#Get-Content 'InactiveSites.txt' -Raw

#Write-Host  "Moving documents to Backup site...."
#$Sourceurl="https://myownsoftronic.sharepoint.com/Test-Subsite"
<#
$returnList=Get-FilesFromSource -adminUserName $adminUserName -adminPassword $passie -sourceSite $Sourceurl
Copy-FilesToDestination -adminUserName $adminUserName -adminPassword $passie -Documentitems $returnList

Write-Host  "Files in the source site are...."
foreach ($item in $returnList){
  if($item.FileSystemObjectType -eq [Microsoft.SharePoint.Client.FileSystemObjectType ]::File) { 
     $FileRef = $item["FileRef"].split("/");
     $fileName = $FileRef[$FileRef.length-1];
     Write-Host  $fileName     
  }
}
#>

#Write-Host  "Moving documents finished."

