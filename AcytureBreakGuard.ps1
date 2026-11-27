Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Enable DPI awareness so boxes and text align pixel-for-pixel at 100%, 125%, or 150% scaling
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
"@
[void][DpiHelper]::SetProcessDPIAware()

# ==========================================================
# TEST MODE SETTINGS (Change these 3 numbers for real mode!)
# Real mode: $WorkIntervalSeconds = 3600 (1 hour)
#            $BreakDurationSeconds = 60  (1 minute per hour)
#            $SnoozeSeconds = 300        (5 minutes)
# ==========================================================
$WorkIntervalSeconds = 5
$BreakDurationSeconds = 15
$SnoozeSeconds = 5

$script:SnoozesLeft = 3
$script:GlassesDrunk = 0
$script:BreaksTaken = 0
$script:QuitApp = $false

function Get-BestFontName {
    $installed = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    if ($installed -contains "Lexend") { return "Lexend" }
    if ($installed -contains "Segoe UI") { return "Segoe UI" }
    return "Arial"
}

function Test-InTeamsMeeting {
    $micPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\NonPackaged",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
    )
    foreach ($basePath in $micPaths) {
        if (Test-Path $basePath) {
            Get-ChildItem $basePath -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.PSChildName -match "Teams") {
                    $stopTime = (Get-ItemProperty $_.PSPath -Name "LastUsedTimeStop" -ErrorAction SilentlyContinue).LastUsedTimeStop
                    if ($stopTime -eq 0) { return $true }
                }
            }
        }
    }
    return $false
}

function New-RoundedPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-CenteredText($g, [string]$text, $font, $brush, [float]$centerX, [float]$y) {
    $size = $g.MeasureString($text, $font)
    $g.DrawString($text, $font, $brush, ($centerX - ($size.Width / 2)), $y)
}

function Get-WaterAdvice($glasses, $breakNum) {
    if ($glasses -ge 15) {
        return "You have done well preserving your life!"
    } elseif ($glasses -lt ($breakNum * 1.4)) {
        return "Drink 2 glasses of water this break to catch up!"
    } else {
        return "Drink 1 glass of water to stay on track!"
    }
}

function Show-BreakScreen([bool]$IsSnoozeRetry = $false) {
    if (-not $IsSnoozeRetry) {
        $script:BreaksTaken++
    }

    $script:WasSnoozed = $false
    $script:Remaining = $BreakDurationSeconds
    $script:HoverDrink = $false
    $script:HoverSnooze = $false
    $fontName = Get-BestFontName

    # Target external monitor if connected; fallback to primary monitor
    $allScreens = [System.Windows.Forms.Screen]::AllScreens
    $targetScreen = $allScreens | Where-Object { -not $_.Primary } | Select-Object -First 1
    if (-not $targetScreen) {
        $targetScreen = [System.Windows.Forms.Screen]::PrimaryScreen
    }
    $bounds = $targetScreen.Bounds

    $centerX = [int]($bounds.Width / 2)
    $centerY = [int]($bounds.Height / 2)
    $cardW = [Math]::Min(860, [int]($bounds.Width * 0.80))
    $cardH = 450
    $cardX = $centerX - [int]($cardW / 2)
    $cardY = $centerY - [int]($cardH / 2)

    # Smooth button hitboxes (no Set-RoundedRegion clipping!)
    $drinkRect = New-Object System.Drawing.Rectangle(($centerX - 150), ($cardY + 265), 300, 50)
    $snoozeRect = New-Object System.Drawing.Rectangle(($centerX - 140), ($cardY + 332), 280, 44)

    # Pre-render static background + glass card once
    $staticBg = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
    $bgG = [System.Drawing.Graphics]::FromImage($staticBg)
    $bgG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $fullRect = New-Object System.Drawing.Rectangle(0, 0, $bounds.Width, $bounds.Height)
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $fullRect,
        [System.Drawing.Color]::FromArgb(4, 47, 46),
        [System.Drawing.Color]::FromArgb(13, 148, 136),
        [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
    )
    $bgG.FillRectangle($bgBrush, $fullRect)
    $bgBrush.Dispose()

    $cardPath = New-RoundedPath $cardX $cardY $cardW $cardH 28
    $cardBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(85, 2, 24, 23))
    $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(140, 94, 234, 212), 2)
    $bgG.FillPath($cardBrush, $cardPath)
    $bgG.DrawPath($borderPen, $cardPath)
    $cardBrush.Dispose()
    $borderPen.Dispose()
    $cardPath.Dispose()
    $bgG.Dispose()

    # Fonts & Brushes
    $titleFont = New-Object System.Drawing.Font($fontName, 26, [System.Drawing.FontStyle]::Regular)
    $adviceFont = New-Object System.Drawing.Font($fontName, 15, [System.Drawing.FontStyle]::Regular)
    $timerFont = New-Object System.Drawing.Font($fontName, 22, [System.Drawing.FontStyle]::Regular)
    $btnFont = New-Object System.Drawing.Font($fontName, 13, [System.Drawing.FontStyle]::Regular)
    $snoozeFont = New-Object System.Drawing.Font($fontName, 12, [System.Drawing.FontStyle]::Regular)
    $hintFont = New-Object System.Drawing.Font($fontName, 10, [System.Drawing.FontStyle]::Regular)

    $titleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(204, 251, 241))
    $adviceBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240, 253, 250))
    $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $darkTextBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(4, 47, 46))
    $hintBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(153, 246, 228))

    # Double-buffered Form (zero flicker, smooth anti-aliased rendering)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Acyture Break Guard"
    $form.FormBorderStyle = "None"
    $form.StartPosition = "Manual"
    $form.Location = New-Object System.Drawing.Point($bounds.X, $bounds.Y)
    $form.Size = New-Object System.Drawing.Size($bounds.Width, $bounds.Height)
    $form.TopMost = $true
    $form.KeyPreview = $true

    $doubleBufferProp = [System.Windows.Forms.Control].GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]"NonPublic,Instance")
    $doubleBufferProp.SetValue($form, $true, $null)

    $form.Add_Paint({
        param($sender, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

        # Draw cached gradient & card
        $g.DrawImageUnscaled($staticBg, 0, 0)

        # Draw smooth Lexend text directly onto glass card (no boxy label backgrounds!)
        Draw-CenteredText $g "Time for a water and washroom break" $titleFont $titleBrush $centerX ($cardY + 42)

        $advice = Get-WaterAdvice $script:GlassesDrunk $script:BreaksTaken
        Draw-CenteredText $g "Total: $($script:GlassesDrunk)/15 cups — $advice" $adviceFont $adviceBrush $centerX ($cardY + 118)

        Draw-CenteredText $g "Screen unlocks in $($script:Remaining)s" $timerFont $whiteBrush $centerX ($cardY + 185)

        # Smooth anti-aliased "+1 cup" pill button
        $drinkColor = if ($script:HoverDrink) { [System.Drawing.Color]::FromArgb(153, 246, 228) } else { [System.Drawing.Color]::FromArgb(94, 234, 212) }
        $drinkBrush = New-Object System.Drawing.SolidBrush($drinkColor)
        $drinkPath = New-RoundedPath $drinkRect.X $drinkRect.Y $drinkRect.Width $drinkRect.Height 25
        $g.FillPath($drinkBrush, $drinkPath)
        Draw-CenteredText $g "I drank 1 tiny cup (+1)" $btnFont $darkTextBrush $centerX ($drinkRect.Y + 12)
        $drinkBrush.Dispose()
        $drinkPath.Dispose()

        # Smooth anti-aliased "Emergency snooze" pill button
        if ($script:SnoozesLeft -gt 0) {
            $snoozeColor = if ($script:HoverSnooze) { [System.Drawing.Color]::FromArgb(254, 240, 138) } else { [System.Drawing.Color]::FromArgb(253, 224, 71) }
            $snoozeBrush = New-Object System.Drawing.SolidBrush($snoozeColor)
            $snoozePath = New-RoundedPath $snoozeRect.X $snoozeRect.Y $snoozeRect.Width $snoozeRect.Height 22
            $g.FillPath($snoozeBrush, $snoozePath)
            Draw-CenteredText $g "Emergency snooze ($($script:SnoozesLeft) left)" $snoozeFont $darkTextBrush $centerX ($snoozeRect.Y + 10)
            $snoozeBrush.Dispose()
            $snoozePath.Dispose()
        }

        Draw-CenteredText $g "Press Ctrl + Shift + Q anytime to quit Break Guard" $hintFont $hintBrush $centerX ($cardY + 398)
    })

    # Hover cursor & highlight detection
    $form.Add_MouseMove({
        param($sender, $e)
        $overDrink = $drinkRect.Contains($e.Location)
        $overSnooze = ($script:SnoozesLeft -gt 0) -and $snoozeRect.Contains($e.Location)

        if ($overDrink -or $overSnooze) {
            $form.Cursor = [System.Windows.Forms.Cursors]::Hand
        } else {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }

        if ($overDrink -ne $script:HoverDrink -or $overSnooze -ne $script:HoverSnooze) {
            $script:HoverDrink = $overDrink
            $script:HoverSnooze = $overSnooze
            $form.Invalidate()
        }
    })

    # Click detection for custom smooth buttons
    $form.Add_MouseClick({
param($sender, $e)
if ($drinkRect.Contains($e.Location)) {
$script:GlassesDrunk++
$form.Invalidate()
} elseif (($script:SnoozesLeft -gt 0) -and $snoozeRect.Contains($e.Location)) {
$script:SnoozesLeft--
$script:WasSnoozed = $true
$timer.Stop()
$form.Close()
}
})
# Instant quit hotkey: Ctrl + Shift + Q
$form.Add_KeyDown({
param($sender, $e)
if ($e.Control -and $e.Shift -and $e.KeyCode -eq "Q") {
$script:QuitApp = $true
$timer.Stop()
$form.Close()
}
})
$form.Add_FormClosing({
if ($script:Remaining -gt 0 -and -not $script:WasSnoozed -and -not $script:QuitApp) {
$_.Cancel = $true
}
})
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
$script:Remaining--
if ($script:Remaining -gt 0) {
$form.Invalidate()
} else {
$timer.Stop()
$form.Close()
}
})
$timer.Start()
[void]$form.ShowDialog()
# Clean up GDI objects
$staticBg.Dispose()
$titleFont.Dispose()
$adviceFont.Dispose()
$timerFont.Dispose()
$btnFont.Dispose()
$snoozeFont.Dispose()
$hintFont.Dispose()
$titleBrush.Dispose()
$adviceBrush.Dispose()
$whiteBrush.Dispose()
$darkTextBrush.Dispose()
$hintBrush.Dispose()
return $script:WasSnoozed
}
while (-not $script:QuitApp) {
Start-Sleep -Seconds $WorkIntervalSeconds
if ($script:QuitApp) { break }
while (Test-InTeamsMeeting) {
Start-Sleep -Seconds 60
}
$snoozed = Show-BreakScreen
if ($script:QuitApp) { break }
if ($snoozed) {
Start-Sleep -Seconds $SnoozeSeconds
if ($script:QuitApp) { break }
while (Test-InTeamsMeeting) {
Start-Sleep -Seconds 60
}
[void](Show-BreakScreen -IsSnoozeRetry $true)
}
$script:SnoozesLeft = 3
}