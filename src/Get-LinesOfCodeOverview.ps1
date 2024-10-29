<#
.SYNOPSIS
  Get-LinesOfCodeOverview

.DESCRIPTION
  This script can be used to count the total lines of code in all git repositories of an Azure DevOps or Bitbucket Data Center project.

.PARAMETER Force
  OPTIONAL - If set to true, the script will overwrite existing line count files.

.PARAMETER Organization
  AZURE DEVOPS ONLY - Your Azure DevOps organization.

.PARAMETER OutputFolder
  OPTIONAL - Folder where the output will be stored. Default is ".azure-devops" or ".bitbucket" depending on source.

.PARAMETER PersonalAccessToken
  REQUIRED - Personal Access Token (PAT) that has read access to your repositories.

.PARAMETER Project
  REQUIRED - Project inside Azure DevOps or Bitbucket Data Center that will be scanned.

.PARAMETER ServerUrl
  BITBUCKET DATA CENTER ONLY - Base URL of the Bitbucket Data Center server.

.PARAMETER Source
  REQUIRED - Source of the project. Possible values: "azure-devops", "bitbucket".

.PARAMETER Username
  BITBUCKET DATA CENTER ONLY - Username that has read access to your repositories. Required to fetch the repositories that are part of your project.

.OUTPUTS
  Overview of the total lines of code in all git repositories of your project.
  
.EXAMPLE
  .\Get-LinesOfCodeOverview.ps1 -PersonalAccessToken "MyToken" -Project "MyProject" -ServerUrl "https://my.domain.name/path" -Source "bitbucket"
.EXAMPLE
  .\Get-LinesOfCodeOverview.ps1 -Organization "MyOrg" -PersonalAccessToken "MyToken" -Project "MyProject" -Source "azure-devops"
#>

param(
  [Parameter()]
  [bool]$Force = $false,

  [Parameter(Mandatory = $true, ParameterSetName = "azure-devops")]
  [string]$Organization,

  [Parameter()]
  [string]$OutputFolder,

  [Parameter(Mandatory = $true)]
  [string]$PersonalAccessToken,

  [Parameter(Mandatory = $true)]
  [string]$Project,

  [Parameter(Mandatory = $true, ParameterSetName = "bitbucket")]
  [string]$ServerUrl,

  [Parameter(Mandatory = $true)]
  [ValidateSet("azure-devops", "bitbucket")]
  [string]$Source,

  [Parameter(Mandatory = $true, ParameterSetName = "bitbucket")]
  [string]$Username
)

# Validate that the CLI tool cloc can be found
if (-not (Get-Command cloc -ErrorAction SilentlyContinue)) {
  Write-Error "The 'cloc' command-line tool (https://github.com/AlDanial/cloc) is not installed or not found in the system PATH. This tool can be installed directly, via 'npm' (https://www.npmjs.com/package/cloc), or (on Windows) via 'winget install AlDanial.Cloc'."
  exit 1
}

# Set output folder to default if not set.
if ($OutputFolder -eq $null -or $OutputFolder -eq "") {
  $OutputFolder = if ($Source -eq "azure-devops") { ".azure-devops" } else { ".bitbucket" }
}

# Start script
Write-Host "Start lines of code calculation for $Project."

# Set header with personal access token
$token = [System.Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username, $PersonalAccessToken)))
$header = @{Authorization = ("Basic {0}" -f $token) }

# Get project
$projectUrl = if ($Source -eq "azure-devops") { "https://dev.azure.com/$($Organization)/_apis/projects/$($Project)?api-version=7.1" } else { "$($ServerUrl)/rest/api/1.0/projects/$($Project)" }
$projectName = (Invoke-RestMethod -Uri $projectUrl -Method Get -Headers $header).name

# Get all repositories
$baseUrl = if ($Source -eq "azure-devops") { "https://dev.azure.com/$($Organization)/$($Project)/_apis/git/repositories?api-version=7.1" } else { "$($ServerUrl)/rest/api/1.0/projects/$($Project)/repos?limit=1000" }
$repositoriesResponse = Invoke-RestMethod -Uri $baseUrl -Method Get -Headers $header
$repositories = if ($Source -eq "azure-devops") { $repositoriesResponse.value } else { $repositoriesResponse.values }

# Create needed directories if they do not exist
if (-not (Test-Path -Path "$OutputFolder")) {
  New-Item -Path . -Name "$OutputFolder" -ItemType "Directory"
}
if (-not (Test-Path -Path "$OutputFolder/$projectName")) {
  New-Item -Path . -Name "$OutputFolder/$projectName" -ItemType "Directory"
}
if (-not (Test-Path -Path "$OutputFolder/$projectName/Repositories")) {
  New-Item -Path . -Name "$OutputFolder/$projectName/Repositories" -ItemType "Directory"
}

# Set current location to a variable.
$originalLocation = Get-Location

# Update working directory to Repositories
Set-Location -Path "$OutputFolder/$projectName/Repositories"

# Calculate lines of code per repository
foreach ($repository in $repositories) {
  $uriSafeRepoName = [Uri]::EscapeDataString($repository.name)

  if ($repository.isDisabled) {
    Write-Host "Skipping repository $($repository.name) because it is disabled."
    continue
  }
  if (Test-Path "$($uriSafeRepoName).txt" -PathType Leaf) {
    if ($Force -eq $true) {
      Write-Host "Line count file for repository $($repository.name) already exists, but Force flag is set."
    }
    else {
      Write-Host "Skipping repository $($repository.name) because line count file already exists."
      continue
    }
  }

  Write-Host "Calculating lines of code for $($repository.name)"
  $cloneUrl = if ($Source -eq "azure-devops") { $repository.remoteUrl } else { ($repository.links.clone | Where-Object { $_.name -eq 'http' }).href }
  
  git -c http.extraHeader="$header" clone $cloneUrl
  cloc "./$($uriSafeRepoName)" --out "$($uriSafeRepoName).txt"
  Remove-Item -Recurse -Force "./$($uriSafeRepoName)"
}

# Make a sum of all the lines of code
$sumCommand = "cloc --sum-reports --report-file=""../$($projectName).txt"""
foreach ($repository in $repositories) {
  $uriSafeRepoName = [Uri]::EscapeDataString($repository.name)
  $sumCommand += " $($uriSafeRepoName).txt"
}
Invoke-Expression -Command $sumCommand

Write-Host "Found $($repositories.length) repositories"

# Set working directory back to the previous location
Set-Location -Path $originalLocation
