# Get-LinesOfCodeOverview

This script can be used to count the total lines of code in all git repositories of an Azure DevOps or Bitbucket Data Center project.

## Requirements

This tool is written in PowerShell but makes use of:
- [git](https://git-scm.com/)
- [cloc](https://github.com/AlDanial/cloc)

The script assume both tools are available.

## API access - personal access tokens
The script uses the Azure DevOps and/or Bitbucket Data Center API to fetch all the repositories in your project. Therefore it requires a personal access token (PAT) that has read access to your code. No other privileges are required.

## Run the script

```ps
# Install git https://git-scm.com/ or another option
# Install cloc:
npm install -g cloc  # other options are available, check the GitHub page of cloc

# Run the script against Bitbucket Data Center
.\Get-LinesOfCodeOverview.ps1 -PersonalAccessToken "MyToken" -Project "MyProject" -ServerUrl "https://my.domain.name/path" -Source "bitbucket"
# Run the script against Azure DevOps
.\Get-LinesOfCodeOverview.ps1 -Organization "MyOrg" -PersonalAccessToken "MyToken" -Project "MyProject" -Source "azure-devops"
```