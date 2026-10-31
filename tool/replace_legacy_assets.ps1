param([Parameter(Mandatory = $true)][string]$HeroPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$backup = Join-Path $root 'build/rights-quarantine'
New-Item -ItemType Directory -Path $backup -Force | Out-Null
$mappings = @{
 'knit_sweater.png' = 'knit-sweater_cream_front.jpg'
 'wide_leg_trousers.png' = 'wide-leg-trousers_sand_front.jpg'
 'tailored_blazer.png' = 'tailored-blazer_black_front.jpg'
 'shoulder_bag.png' = 'shoulder-bag_black_front.jpg'
}
foreach ($name in @('moda_banner.png') + @($mappings.Keys)) {
 $destination = Join-Path $root "assets/images/$name"
 $saved = Join-Path $backup $name
 if (!(Test-Path -LiteralPath $saved)) { Copy-Item -LiteralPath $destination -Destination $saved }
}
$oldScreenshot = Join-Path $root 'docs/screenshots/home.png'
$savedScreenshot = Join-Path $backup 'previous-home.png'
if ((Test-Path -LiteralPath $oldScreenshot) -and !(Test-Path -LiteralPath $savedScreenshot)) { Copy-Item -LiteralPath $oldScreenshot -Destination $savedScreenshot }
Copy-Item -LiteralPath $HeroPath -Destination (Join-Path $root 'assets/images/moda_banner.png') -Force
foreach ($name in $mappings.Keys) {
 $source = Join-Path $root "assets/images/photography/$($mappings[$name])"
 $image = [System.Drawing.Image]::FromFile($source)
 try {
  # Lossless format conversion only: no resize, crop, filter or design edit.
  $image.Save((Join-Path $root "assets/images/$name"), [System.Drawing.Imaging.ImageFormat]::Png)
 } finally { $image.Dispose() }
}
Write-Output 'Replaced five publication candidates. Previous bytes remain in ignored build/rights-quarantine.'
