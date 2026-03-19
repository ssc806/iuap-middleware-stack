param(
    [string]$Component = "openresty",
    [string]$Version = "",
    [string]$ArtifactRetentionDays = "",
    [string]$Ref = $env:GITHUB_REF,
    [string]$Workspace = $env:GITHUB_WORKSPACE
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Workspace)) {
    $Workspace = (Get-Location).Path
}

function Read-EnvFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $values = @{}

    foreach ($rawLine in Get-Content -Path $Path) {
        $line = $rawLine.Trim()

        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }

        $parts = $line -split "=", 2
        if ($parts.Count -ne 2) {
            throw "Invalid config line in ${Path}: ${rawLine}"
        }

        $values[$parts[0].Trim()] = $parts[1].Trim()
    }

    return $values
}

function Get-ConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [bool]$Required = $true
    )

    if ($Config.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace($Config[$Key])) {
        return $Config[$Key]
    }

    if ($Required) {
        throw "Missing required config key '$Key'"
    }

    return $null
}

function Export-GitHubValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    Set-Item -Path "Env:$Name" -Value $Value

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_ENV)) {
        "$Name=$Value" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) {
        $outputName = $Name.ToLowerInvariant()
        "$outputName=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    }
}

$configPath = Join-Path $Workspace ("configs/{0}/windows.env" -f $Component)
$buildScript = Join-Path $Workspace ("build/{0}/windows/build.sh" -f $Component)
$patchDir = Join-Path $Workspace ("patches/{0}/windows" -f $Component)

if (-not (Test-Path -Path $configPath -PathType Leaf)) {
    throw "Missing component config: $configPath"
}

if (-not (Test-Path -Path $buildScript -PathType Leaf)) {
    throw "Missing component build script: $buildScript"
}

$config = Read-EnvFile -Path $configPath
$tagPrefix = Get-ConfigValue -Config $config -Key "TAG_PREFIX" -Required $false

if ([string]::IsNullOrWhiteSpace($Version) -and $Ref -like "refs/tags/*" -and -not [string]::IsNullOrWhiteSpace($tagPrefix)) {
    $tagName = $Ref.Substring("refs/tags/".Length)
    if ($tagName.StartsWith($tagPrefix)) {
        $Version = $tagName.Substring($tagPrefix.Length)
    }
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-ConfigValue -Config $config -Key "DEFAULT_VERSION"
}

if ([string]::IsNullOrWhiteSpace($ArtifactRetentionDays)) {
    $ArtifactRetentionDays = Get-ConfigValue -Config $config -Key "DEFAULT_RETENTION_DAYS"
}

$sourceArchivePrefix = Get-ConfigValue -Config $config -Key "SOURCE_ARCHIVE_PREFIX"
$sourceUrlTemplate = Get-ConfigValue -Config $config -Key "SOURCE_URL_TEMPLATE"
$artifactPrefix = Get-ConfigValue -Config $config -Key "ARTIFACT_PREFIX"

$sourceArchiveName = "{0}-{1}.tar.gz" -f $sourceArchivePrefix, $Version
$sourceDirName = "{0}-{1}" -f $sourceArchivePrefix, $Version
$sourceUrl = $sourceUrlTemplate.Replace("__VERSION__", $Version)
$artifactBundleName = "{0}-{1}-win64" -f $artifactPrefix, $Version
$packageFileName = "{0}.zip" -f $artifactBundleName
$artifactUploadPath = Join-Path $Workspace ("artifacts/{0}/{1}" -f $Component, $Version)
$packageFilePath = Join-Path $artifactUploadPath $packageFileName
$buildRoot = Join-Path $Workspace (".work/windows/{0}/{1}" -f $Component, $Version)

New-Item -ItemType Directory -Path $artifactUploadPath -Force | Out-Null
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null

$exports = [ordered]@{
    COMPONENT                = $Component
    COMPONENT_VERSION        = $Version
    COMPONENT_CONFIG         = $configPath
    BUILD_SCRIPT             = $buildScript
    PATCH_DIR                = $patchDir
    BUILD_ROOT               = $buildRoot
    SOURCE_ARCHIVE_NAME      = $sourceArchiveName
    SOURCE_DIR_NAME          = $sourceDirName
    SOURCE_URL               = $sourceUrl
    ARTIFACT_BUNDLE_NAME     = $artifactBundleName
    ARTIFACT_UPLOAD_PATH     = $artifactUploadPath
    PACKAGE_FILE_NAME        = $packageFileName
    PACKAGE_FILE_PATH        = $packageFilePath
    ARTIFACT_RETENTION_DAYS  = $ArtifactRetentionDays
}

foreach ($entry in $exports.GetEnumerator()) {
    Export-GitHubValue -Name $entry.Key -Value ([string]$entry.Value)
}
