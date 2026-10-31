$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
function Brand([int]$size,[string]$path,[bool]$transparent,[double]$width) {
 $bitmap = New-Object System.Drawing.Bitmap($size,$size)
 $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
 $graphics.SmoothingMode = 'AntiAlias'
 $graphics.TextRenderingHint = 'AntiAliasGridFit'
 if (!$transparent) { $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#FAF7F2')) } else { $graphics.Clear([System.Drawing.Color]::Transparent) }
 $font = New-Object System.Drawing.Font('Times New Roman',($size * .25),[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
 $format = [System.Drawing.StringFormat]::GenericTypographic.Clone()
 $measured = $graphics.MeasureString('MODA',$font,10000,$format)
 $graphics.TranslateTransform([single](($size-$size*$width)/2),[single](($size-$measured.Height)/2))
 $graphics.ScaleTransform([single]($size*$width/$measured.Width),1)
 $graphics.DrawString('MODA',$font,[System.Drawing.Brushes]::Black,0,0,$format)
 [System.IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
 $bitmap.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
 $format.Dispose();$font.Dispose();$graphics.Dispose();$bitmap.Dispose()
}
Brand 1024 "$root/assets/branding/moda-icon.png" $false .66
Brand 432 "$root/android/app/src/main/res/drawable-nodpi/moda_launcher_foreground.png" $true .56
Brand 512 "$root/android/app/src/main/res/drawable-nodpi/moda_splash.png" $true .66
foreach ($entry in @(@('mdpi',48),@('hdpi',72),@('xhdpi',96),@('xxhdpi',144),@('xxxhdpi',192))) {
 Brand $entry[1] "$root/android/app/src/main/res/mipmap-$($entry[0])/ic_launcher.png" $false .66
}
