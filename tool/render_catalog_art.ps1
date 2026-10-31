# Original code-drawn catalog illustrations, not photographs or manufacturer art.
# Uses Windows' existing System.Drawing; no new application dependency.
param([string]$CatalogPath = '.catalog-art.json')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$outputDirectory = Join-Path (Get-Location) 'assets/images/catalog'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
function Points($coordinates) {
  ,([System.Drawing.PointF[]]@($coordinates | ForEach-Object { [System.Drawing.PointF]::new($_[0], $_[1]) }))
}
foreach ($product in $catalog) {
  foreach ($color in $product.colors) {
    foreach ($media in $color.images | Where-Object kind -eq 'illustration') {
      $bitmap = [System.Drawing.Bitmap]::new(600,720)
      $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
      $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
      $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#FAF7F2'))
      $fill = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($color.hex))
      $outline = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#51493F'),3)
      $seam = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(100,165,138,87),2)
      $metal = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#A58A57'),8)
      $soft = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#F0E9DE'))
      $graphics.FillEllipse($soft,60,85,480,490)
      $graphics.SetClip([System.Drawing.Rectangle]::new(28,75,544,535))
      if ($media.id.EndsWith(':detail')) { $graphics.TranslateTransform(-42,-38); $graphics.ScaleTransform(1.16,1.16) }
      switch ($product.type) {
        {$_ -in 'sweater','shirt','blazer','coat'} {
          $hem = if ($product.type -eq 'coat') { 565 } else { 490 }
          $shape = Points @(@(225,165),@(175,185),@(95,345),@(155,375),@(205,290),@(205,$hem),@(395,$hem),@(395,290),@(445,375),@(505,345),@(425,185),@(375,165),@(345,200),@(255,200))
          $graphics.FillPolygon($fill,$shape); $graphics.DrawPolygon($outline,$shape)
          $graphics.DrawArc($outline,255,145,90,62,0,180)
          if ($product.type -in 'blazer','coat','shirt') {
            $graphics.DrawLines($seam,(Points @(@(245,178),@(292,270),@(300,$hem))))
            $graphics.DrawLines($seam,(Points @(@(355,178),@(308,270))))
            foreach ($y in 290,340,390,440) { $graphics.DrawEllipse($seam,310,$y,7,7) }
            $graphics.DrawLine($seam,225,380,275,375); $graphics.DrawLine($seam,325,375,375,380)
          } else {
            foreach ($x in 220..380 | Where-Object { $_ % 12 -eq 0 }) { $graphics.DrawLine($seam,$x,220,$x,$hem-10) }
          }
          $graphics.DrawLine($seam,210,$hem-18,390,$hem-18)
        }
        'trousers' {
          $shape = Points @(@(200,150),@(400,150),@(435,540),@(315,540),@(300,325),@(285,540),@(165,540))
          $graphics.FillPolygon($fill,$shape); $graphics.DrawPolygon($outline,$shape)
          $graphics.DrawLine($seam,200,180,400,180); $graphics.DrawLine($seam,300,180,300,325)
          $graphics.DrawLine($seam,225,205,220,520); $graphics.DrawLine($seam,375,205,380,520)
          $graphics.DrawLine($seam,195,190,245,230); $graphics.DrawLine($seam,405,190,355,230)
        }
        'skirt' {
          $shape = Points @(@(230,165),@(370,165),@(455,530),@(145,530))
          $graphics.FillPolygon($fill,$shape); $graphics.DrawPolygon($outline,$shape)
          foreach ($i in 0..7) { $graphics.DrawLine($seam,230+$i*20,185,145+$i*44,520) }
          $graphics.DrawLine($seam,225,190,375,190)
        }
        'dress' {
          $shape = Points @(@(245,145),@(205,175),@(155,300),@(210,315),@(245,265),@(240,325),@(155,545),@(445,545),@(360,325),@(355,265),@(390,315),@(445,300),@(395,175),@(355,145),@(300,210))
          $graphics.FillPolygon($fill,$shape); $graphics.DrawPolygon($outline,$shape)
          $graphics.DrawLine($seam,245,150,355,325); $graphics.DrawLine($metal,240,325,360,325)
          $graphics.DrawLine($seam,330,335,265,525)
        }
        {$_ -in 'bag','tote'} {
          $top = if ($product.type -eq 'tote') { 245 } else { 285 }
          $graphics.DrawArc($outline,205,130,190,250,180,180)
          $graphics.DrawArc($metal,215,140,170,235,180,180)
          $shape = Points @(@(170,$top),@(430,$top),@(450,485),@(410,515),@(190,515),@(150,485))
          $graphics.FillPolygon($fill,$shape); $graphics.DrawPolygon($outline,$shape)
          $graphics.DrawLine($seam,180,$top+15,420,$top+15); $graphics.DrawLine($seam,175,480,420,480)
          $graphics.DrawRectangle($metal,280,$top+40,40,24)
        }
        {$_ -in 'loafers','sneakers','flats','boots'} {
          $top = if ($product.type -eq 'boots') { 190 } else { 310 }
          $shape = Points @(@(155,$top),@(280,$top),@(295,355),@(380,390),@(465,405),@(480,445),@(450,470),@(130,470),@(115,440),@(140,370))
          $graphics.FillPolygon($fill,$shape); $graphics.DrawPolygon($outline,$shape)
          $graphics.DrawLine($seam,135,450,465,450)
          if ($product.type -eq 'sneakers') { foreach ($i in 0..4) { $graphics.DrawLine($metal,280+$i*20,370+$i*7,310+$i*20,355+$i*8) } }
          if ($product.type -eq 'loafers') { $graphics.DrawLine($metal,280,380,340,420) }
          if ($product.type -eq 'boots') { $graphics.DrawLine($seam,175,210,175,365) }
        }
        'earrings' {
          $jewel = [System.Drawing.Pen]::new($fill.Color,22)
          $graphics.DrawEllipse($jewel,140,230,130,210); $graphics.DrawEllipse($jewel,330,230,130,210)
          $graphics.DrawArc($seam,130,220,150,230,95,160); $graphics.DrawArc($seam,320,220,150,230,95,160)
          $jewel.Dispose()
        }
        'necklace' {
          $jewel = [System.Drawing.Pen]::new($fill.Color,12)
          $graphics.DrawBezier($jewel,170,165,150,390,450,390,430,165)
          $graphics.FillEllipse($fill,275,340,50,75); $graphics.DrawEllipse($outline,275,340,50,75)
          $jewel.Dispose()
        }
        {$_ -in 'bracelet','rings'} {
          $jewel = [System.Drawing.Pen]::new($fill.Color,20)
          if ($product.type -eq 'rings') {
            $graphics.DrawEllipse($jewel,160,250,140,140); $graphics.DrawEllipse($jewel,295,300,140,140)
          } else {
            foreach ($i in 0..11) { $angle=$i*[Math]::PI/6; $graphics.DrawEllipse($jewel,[single](280+125*[Math]::Cos($angle)),[single](330+95*[Math]::Sin($angle)),45,35) }
          }
          $jewel.Dispose()
        }
        'scarf' {
          $shape = Points @(@(300,145),@(490,340),@(300,540),@(110,340))
          $graphics.FillPolygon($fill,$shape); $graphics.DrawPolygon($outline,$shape)
          $graphics.DrawPolygon($metal,(Points @(@(300,190),@(445,340),@(300,490),@(155,340))))
          $graphics.DrawLine($seam,200,250,400,440); $graphics.DrawLine($seam,400,250,200,440)
        }
        'belt' {
          $graphics.FillRectangle($fill,125,300,350,60); $graphics.DrawRectangle($outline,125,300,350,60)
          $graphics.DrawRectangle($metal,150,285,70,90); $graphics.DrawLine($metal,165,330,215,330)
          foreach ($x in 360,385,410,435) { $graphics.FillEllipse($soft,$x,325,7,7) }
        }
        'glasses' {
          $jewel = [System.Drawing.Pen]::new($fill.Color,15)
          $graphics.DrawEllipse($jewel,105,270,170,120); $graphics.DrawEllipse($jewel,325,270,170,120)
          $graphics.DrawArc($jewel,270,285,60,50,180,180); $graphics.DrawLine($jewel,110,300,85,270); $graphics.DrawLine($jewel,490,300,515,270)
          $jewel.Dispose()
        }
        'beanie' {
          $graphics.FillEllipse($fill,180,175,240,330); $graphics.DrawArc($outline,180,175,240,330,180,180)
          $graphics.FillRectangle($fill,170,370,260,90); $graphics.DrawRectangle($outline,170,370,260,90)
          foreach ($x in 185..415 | Where-Object { $_ % 12 -eq 0 }) { $graphics.DrawLine($seam,$x,380,$x,450) }
        }
      }
      $graphics.ResetTransform(); $graphics.ResetClip()
      $caption = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#716A61'))
      $font = [System.Drawing.Font]::new('Segoe UI',12)
      $titleFont = [System.Drawing.Font]::new('Georgia',20)
      $graphics.DrawString('M O D A  /  D E M O', $font, $caption, 35, 28)
      $graphics.DrawString($product.name,$titleFont,$caption,[System.Drawing.RectangleF]::new(35,615,530,48))
      $graphics.DrawString(($color.name + ' / ORIGINAL ILLUSTRATION'),$font,$caption,35,674)
      $bitmap.Save((Join-Path (Get-Location) $media.path),[System.Drawing.Imaging.ImageFormat]::Png)
      foreach ($resource in @($font,$titleFont,$caption,$fill,$outline,$seam,$metal,$soft,$graphics,$bitmap)) { $resource.Dispose() }
    }
  }
}
Write-Output 'Original bundled catalog illustrations rendered.'
