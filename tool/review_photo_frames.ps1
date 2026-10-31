Add-Type -AssemblyName System.Drawing
$root=Split-Path -Parent $PSScriptRoot
$images=@(Get-ChildItem "$root/assets/images/photography" -Filter *.jpg | Sort-Object Name)
[System.IO.Directory]::CreateDirectory("$root/docs/photo-framing-qa") | Out-Null
for($batch=0;$batch -lt [Math]::Ceiling($images.Count/20);$batch++) {
 $sheet=New-Object System.Drawing.Bitmap(720,864)
 $g=[System.Drawing.Graphics]::FromImage($sheet);$g.Clear([System.Drawing.Color]::White)
 $font=New-Object System.Drawing.Font('Arial',8)
 for($cell=0;$cell -lt 20;$cell++) {
  $index=$batch*20+$cell;if($index -ge $images.Count){break}
  $src=[System.Drawing.Image]::FromFile($images[$index].FullName)
  $x=($cell%5)*144;$y=[Math]::Floor($cell/5)*216
  $g.DrawImage($src,[int]$x,[int]$y,140,187)
  $g.DrawString($images[$index].BaseName,$font,[System.Drawing.Brushes]::Black,[System.Drawing.RectangleF]::new($x,$y+188,140,28))
  $src.Dispose()
 }
 $sheet.Save("$root/docs/photo-framing-qa/sheet-$batch.jpg",[System.Drawing.Imaging.ImageFormat]::Jpeg)
 $font.Dispose();$g.Dispose();$sheet.Dispose()
}
