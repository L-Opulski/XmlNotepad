param(
    [Parameter(Mandatory = $true)][string]$ImagePath,
    [Parameter(Mandatory = $true)][string]$MsixMgrPath,
    [Parameter(Mandatory = $true)][string]$ExpectedPublisher,
    [Parameter(Mandatory = $true)][string]$ExpectedPackageName
)

$ErrorActionPreference = 'Stop'
[Windows.Management.Deployment.PackageManager,Windows.Management.Deployment,ContentType=WindowsRuntime] | Out-Null
Add-Type -AssemblyName System.Runtime.WindowsRuntime

$before = @(Get-Volume | ForEach-Object { $_.UniqueId })
$mounted = $false
$staged = $false
$packageFullName = $null
try {
    $mountOutput = @(& $MsixMgrPath -MountImage -imagePath $ImagePath -fileType CIM 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Failed to mount the new CIM image: $($mountOutput -join ' ')" }
    $mounted = $true

    $newVolumes = @(Get-Volume | Where-Object { $_.UniqueId -and $before -notcontains $_.UniqueId })
    if ($newVolumes.Count -eq 1) {
        $deviceId = $newVolumes[0].UniqueId
    }
    else {
        $volumeId = [regex]::Match(($mountOutput -join ' '), '(?i)\\\\\?\\Volume\{([0-9a-f-]{36})\}\\?')
        if (-not $volumeId.Success) {
            $volumeId = [regex]::Match(($mountOutput -join ' '), '(?i)\b([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\b')
        }
        if (-not $volumeId.Success) {
            throw "Cannot identify mounted CIM volume. MSIXMGR output: $($mountOutput -join ' ')"
        }
        $deviceId = '\\?\Volume{' + $volumeId.Groups[1].Value + '}\'
    }
    if ($deviceId -notmatch '^\\\\\?\\Volume\{[0-9a-fA-F-]{36}\}\\$') {
        throw "Unexpected CIM volume path: $deviceId"
    }
    $root = Join-Path $deviceId 'apps'
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'Mounted CIM lacks the apps directory.' }

    $manifests = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'AppxManifest.xml')
    $mainPackages = @($manifests | Where-Object {
        [xml]$manifest = Get-Content -LiteralPath $_.FullName -Raw
        $identity = $manifest.Package.Identity
        $identity.Name -ceq $ExpectedPackageName -and
        $identity.Publisher -ceq $ExpectedPublisher -and
        -not $identity.ResourceId
    })
    if ($mainPackages.Count -ne 1) {
        throw "Expected one main package with the signed publisher in the CIM; found $($mainPackages.Count)."
    }
    $packageFolder = $mainPackages[0].DirectoryName
    $packageFullName = Split-Path -Leaf $packageFolder
    $acl = Get-Acl -LiteralPath $packageFolder
    if (-not $acl.Access) { throw 'The package folder has no readable ACL.' }

    $folderUri = $packageFolder.Replace('\\?\', 'file:\\\')
    $folderAbsoluteUri = ([Uri]$folderUri).AbsoluteUri
    $asTask = @([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.ToString() -eq 'System.Threading.Tasks.Task`1[TResult] AsTask[TResult,TProgress](Windows.Foundation.IAsyncOperationWithProgress`2[TResult,TProgress])'
    })
    if ($asTask.Count -ne 1) { throw 'Cannot use the Windows Runtime staging API.' }
    $asTaskAsyncOperation = $asTask[0].MakeGenericMethod(
        [Windows.Management.Deployment.DeploymentResult],
        [Windows.Management.Deployment.DeploymentProgress]
    )
    $manager = New-Object -TypeName Windows.Management.Deployment.PackageManager
    $operation = $manager.StagePackageAsync($folderAbsoluteUri, $null, 'StageInPlace')
    $task = $asTaskAsyncOperation.Invoke($null, @($operation))
    $result = $task.GetAwaiter().GetResult()
    if ($result.ErrorText) { throw "MSIX staging failed: $($result.ErrorText)" }
    $staged = $true
    Write-Output "Successfully staged $packageFullName from $ImagePath"
}
finally {
    if ($staged) {
        Remove-AppxPackage -AllUsers -Package $packageFullName -ErrorAction SilentlyContinue
    }
    if ($mounted) {
        & $MsixMgrPath -UnmountImage -imagePath $ImagePath -fileType CIM
        if ($LASTEXITCODE -ne 0) { throw 'Failed to unmount the CI test CIM image.' }
    }
}
