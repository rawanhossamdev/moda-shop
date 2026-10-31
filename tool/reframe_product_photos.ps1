# Geometric reframing requested by the user: no recoloring, retouching or product synthesis.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class ModaPhotoFrame {
 public static double[] Render(string sourcePath,string outputPath,bool detail) {
  using(var source=Image.FromFile(sourcePath))
  using(var sample=new Bitmap(360,(int)Math.Round(source.Height*360.0/source.Width),PixelFormat.Format24bppRgb)) {
   using(var g=Graphics.FromImage(sample)){g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.DrawImage(source,0,0,sample.Width,sample.Height);}
   int w=sample.Width,h=sample.Height;
   var bits=sample.LockBits(new Rectangle(0,0,w,h),ImageLockMode.ReadOnly,PixelFormat.Format24bppRgb);
   var bytes=new byte[bits.Stride*h];Marshal.Copy(bits.Scan0,bytes,0,bytes.Length);sample.UnlockBits(bits);
   int[] rows=new int[h],cols=new int[w];
   for(int y=0;y<h;y++)for(int x=4;x<w-4;x++){
    int i=y*bits.Stride+x*3;double t=x/(double)(w-1);double d=0;
    for(int c=0;c<3;c++){
     double left=0,right=0;for(int k=0;k<4;k++){left+=bytes[y*bits.Stride+k*3+c]/4.0;right+=bytes[y*bits.Stride+(w-1-k)*3+c]/4.0;}
     d=Math.Max(d,Math.Abs(bytes[i+c]-(left*(1-t)+right*t)));
    }
    if(d>24){rows[y]++;cols[x]++;}
   }
   int l=0,r=w-1,top=0,bottom=h-1;
   while(l<r&&cols[l]<4)l++;while(r>l&&cols[r]<4)r--;
   while(top<bottom&&rows[top]<4)top++;while(bottom>top&&rows[bottom]<4)bottom--;
   if(r-l<20||bottom-top<20){l=0;r=w-1;top=0;bottom=h-1;}
   double factor=source.Width/(double)w;
   double cw=Math.Max((r-l+1)*1.12,(bottom-top+1)*1.12*.75)*factor;
   double ch=cw/.75,cx=(l+r+1)*factor/2,cy=(top+bottom+1)*factor/2;
   if(detail){cw=source.Width;ch=cw/.75;cx=source.Width/2.0;cy=source.Height/2.0;}
   cw=Math.Min(cw,source.Width);ch=cw/.75;
   if(ch>source.Height){ch=source.Height;cw=ch*.75;}
   if(Math.Abs(source.Width/(double)source.Height-.75)<.01){cw=source.Width;ch=source.Height;cx=cw/2;cy=ch/2;}
   double sx=Math.Max(0,Math.Min(source.Width-cw,cx-cw/2));
   double sy=Math.Max(0,Math.Min(source.Height-ch,cy-ch/2));
   using(var target=new Bitmap(720,960,PixelFormat.Format24bppRgb)){
    using(var g=Graphics.FromImage(target)){
     g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.PixelOffsetMode=PixelOffsetMode.HighQuality;
     var dest=new RectangleF((float)(-sx*720/cw),(float)(-sy*960/ch),(float)(source.Width*720/cw),(float)(source.Height*960/ch));
     using(var attributes=new ImageAttributes()){
      attributes.SetWrapMode(WrapMode.TileFlipXY);
      g.DrawImage(source,Rectangle.Round(dest),0,0,source.Width,source.Height,GraphicsUnit.Pixel,attributes);
     }
    }
    var codec=Array.Find(ImageCodecInfo.GetImageEncoders(),c=>c.MimeType=="image/jpeg");
    using(var settings=new EncoderParameters(1)){settings.Param[0]=new EncoderParameter(Encoder.Quality,84L);target.Save(outputPath,codec,settings);}
   }
   return new double[]{l/(double)w,top/(double)h,(r+1)/(double)w,(bottom+1)/(double)h,sx/source.Width,sy/source.Height,cw/source.Width,ch/source.Height};
  }
 }
}
"@
$root=Split-Path -Parent $PSScriptRoot
$records=Get-Content "$PSScriptRoot/generated_photo_sources.json" -Raw | ConvertFrom-Json
$overrides=@()
if(Test-Path -LiteralPath "$PSScriptRoot/photo_reframe_sources.json") { $overrides=Get-Content "$PSScriptRoot/photo_reframe_sources.json" -Raw | ConvertFrom-Json }
$audit=@()
foreach($entry in $records){
 $path="$root/assets/images/photography/$($entry.id)_$($entry.key)_$($entry.view).jpg"
 $override=$overrides | Where-Object {$_.id -eq $entry.id -and $_.key -eq $entry.key -and $_.view -eq $entry.view} | Select-Object -First 1
 $sourcePath=if($null -ne $override){$override.source}else{$entry.source}
 $framing=[ModaPhotoFrame]::Render($sourcePath,$path,($entry.view -eq 'detail'))
 $audit+=@{asset="assets/images/photography/$($entry.id)_$($entry.key)_$($entry.view).jpg";subjectBounds=$framing[0..3];sourceFrame=$framing[4..7];width=720;height=960}
}
$audit | ConvertTo-Json -Depth 5 | Set-Content "$PSScriptRoot/photo_framing.json"
Write-Output "Reframed $($audit.Count) original studio images to 720x960 without changing product colors or geometry."

$manifestPath="$root/assets/images/photography/PROVENANCE.json"
if(Test-Path -LiteralPath $manifestPath){
 $manifest=Get-Content $manifestPath -Raw | ConvertFrom-Json
 foreach($photo in $manifest){
  $photo.sha256=(Get-FileHash -LiteralPath "$root/$($photo.asset)" -Algorithm SHA256).Hash.ToLowerInvariant()
  $photo.width=720
  if($null -eq $photo.PSObject.Properties['height']){$photo | Add-Member -NotePropertyName height -NotePropertyValue 960}else{$photo.height=960}
 }
 $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
}
