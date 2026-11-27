Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Normal work schedule settings (1 hour = 3600s, 2 min = 120s, 5 min = 300s)
$WorkIntervalSeconds = 3600
$BreakDurationSeconds = 120
$SnoozeSeconds = 300

$script:SnoozesLeft = 3
$script:GlassesDrunk = 0
$script:BreaksTaken = 0

function Get-BestFontName {
    $installed = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    if ($installed -contains "Lexend") { return "Lexend" }
    if ($installed -contains "Segoe UI") { return "Segoe UI" }
    return "Arial"
}

function Test-InTeamsMeeting {
    # Checks Windows microphone usage registry for active Teams calls
    $micPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\NonPackaged",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
    )
    foreach ($basePath in $micPaths) {
        if (Test-Path $basePath) {
            Get-ChildItem $basePath -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.PSChildName -match "Teams") {
                    $stopTime = (Get-ItemProperty $_.PSPath -Name "LastUsedTimeStop" -ErrorAction SilentlyContinue).LastUsedTimeStop
                    if ($stopTime -eq 0) {
                        return $true
                    }
                }
            }
        }
    }
    return $false
}

function New-RoundedPath([int]$x, [int]$y, [int]$w, [int]$h, [int]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Set-RoundedRegion($control, [int]$radius) {
    $path = New-RoundedPath 0 0 $control.Width $control.Height $radius
    $control.Region = New-Object System.Drawing.Region($path)
    $path.Dispose()
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
    $fontName = Get-BestFontName

    # Cover all monitors, but target the external monitor if connected
    $vBounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $allScreens = [System.Windows.Forms.Screen]::AllScreens
    $targetScreen = $allScreens | Where-Object { -not $_.Primary } | Select-Object -First 1
    if (-not $targetScreen) {
        $targetScreen = [System.Windows.Forms.Screen]::PrimaryScreen
    }
    $targetBounds = $targetScreen.Bounds

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Acyture Break Guard"
    $form.FormBorderStyle = "None"
    $form.StartPosition = "Manual"
    $form.Location = New-Object System.Drawing.Point($vBounds.X, $vBounds.Y)
    $form.Size = New-Object System.Drawing.Size($vBounds.Width, $vBounds.Height)
    $form.TopMost = $true
    $form.KeyPreview = $true

    $form.Add_FormClosing({
        if ($script:Remaining -gt 0 -and -not $script:WasSnoozed) {
            $_.Cancel = $true
        }
    })

    # Calculate centered glass card coordinates on her external monitor
    $offsetX = $targetBounds.X - $vBounds.X
    $offsetY = $targetBounds.Y - $vBounds.Y
    $centerX = $offsetX + [int]($targetBounds.Width / 2)
    $centerY = $offsetY + [int]($targetBounds.Height / 2)

    $cardW = [Math]::Min(860, [int]($targetBounds.Width * 0.75))
    $cardH = 440
    $cardX = $centerX - [int]($cardW / 2)
    $cardY = $centerY - [int]($cardH / 2)

    # Turquoise-teal gradient + curved translucent center card
    $form.Add_Paint({
        param($sender, $e)
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        $rect = New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)
        $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $rect,
            [System.Drawing.Color]::FromArgb(4, 47, 46),
            [System.Drawing.Color]::FromArgb(13, 148, 136),
            [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
        )
        $e.Graphics.FillRectangle($bgBrush, $rect)
        $bgBrush.Dispose()

        # Curved glass card
        $cardPath = New-RoundedPath $cardX $cardY $cardW $cardH 28
        $cardBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(75, 2, 24, 23))
        $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, 94, 234, 212), 2)
        $e.Graphics.FillPath($cardBrush, $cardPath)
        $e.Graphics.DrawPath($borderPen, $cardPath)
        $cardBrush.Dispose()
        $borderPen.Dispose()
        $cardPath.Dispose()
    })

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Time for a water and washroom break"
    $title.Font = New-Object System.Drawing.Font($fontName, 28, [System.Drawing.FontStyle]::Regular)
    $title.ForeColor = [System.Drawing.Color]::FromArgb(204, 251, 241)
    $title.BackColor = [System.Drawing.Color]::Transparent
    $title.AutoSize = $true
    $form.Controls.Add($title)
    $title.Location = New-Object System.Drawing.Point(($centerX - [int]($title.Width / 2)), ($cardY + 45))

    $adviceLabel = New-Object System.Windows.Forms.Label
    $initialAdvice = Get-WaterAdvice $script:GlassesDrunk $script:BreaksTaken
    $adviceLabel.Text = "Total: $($script:GlassesDrunk)/15 cups — $initialAdvice"
    $adviceLabel.Font = New-Object System.Drawing.Font($fontName, 16, [System.Drawing.FontStyle]::Regular)
    $adviceLabel.ForeColor = [System.Drawing.Color]::FromArgb(240, 253, 250)
    $adviceLabel.BackColor = [System.Drawing.Color]::Transparent
    $adviceLabel.AutoSize = $true
    $form.Controls.Add($adviceLabel)
    $adviceLabel.Location = New-Object System.Drawing.Point(($centerX - [int]($adviceLabel.Width / 2)), ($cardY + 125))

    $timerLabel = New-Object System.Windows.Forms.Label
    $timerLabel.Text = "Screen unlocks in $($script:Remaining)s"
    $timerLabel.Font = New-Object System.Drawing.Font($fontName, 22, [System.Drawing.FontStyle]::Regular)
    $timerLabel.ForeColor = [System.Drawing.Color]::White
    $timerLabel.BackColor = [System.Drawing.Color]::Transparent
    $timerLabel.AutoSize = $true
    $form.Controls.Add($timerLabel)
    $timerLabel.Location = New-Object System.Drawing.Point(($centerX - [int]($timerLabel.Width / 2)), ($cardY + 195))

    # Rounded "+1 cup" button
    $drinkBtn = New-Object System.Windows.Forms.Button
    $drinkBtn.Text = "I drank 1 tiny cup (+1)"
    $drinkBtn.Font = New-Object System.Drawing.Font($fontName, 13, [System.Drawing.FontStyle]::Regular)
    $drinkBtn.ForeColor = [System.Drawing.Color]::FromArgb(4, 47, 46)
    $drinkBtn.BackColor = [System.Drawing.Color]::FromArgb(94, 234, 212)
    $drinkBtn.FlatStyle = "Flat"
    $drinkBtn.FlatAppearance.BorderSize = 0
    $drinkBtn.Size = New-Object System.Drawing.Size(290, 50)
    $drinkBtn.Location = New-Object System.Drawing.Point(($centerX - 145), ($cardY + 275))
    Set-RoundedRegion $drinkBtn 22
    $drinkBtn.Add_Click({
        $script:GlassesDrunk++
        $newAdvice = Get-WaterAdvice $script:GlassesDrunk $script:BreaksTaken
        $adviceLabel.Text = "Total: $($script:GlassesDrunk)/15 cups — $newAdvice"
        $adviceLabel.Location = New-Object System.Drawing.Point(($centerX - [int]($adviceLabel.Width / 2)), ($cardY + 125))
    })
    $form.Controls.Add($drinkBtn)

    # Rounded "Emergency snooze" button
    if ($script:SnoozesLeft -gt 0) {
        $snoozeBtn = New-Object System.Windows.Forms.Button
        $snoozeBtn.Text = "Emergency snooze ($($script:SnoozesLeft) left)"
        $snoozeBtn.Font = New-Object System.Drawing.Font($fontName, 12, [System.Drawing.FontStyle]::Regular)
        $snoozeBtn.ForeColor = [System.Drawing.Color]::FromArgb(4, 47, 46)
        $snoozeBtn.BackColor = [System.Drawing.Color]::FromArgb(253, 224, 71)
        $snoozeBtn.FlatStyle = "Flat"
        $snoozeBtn.FlatAppearance.BorderSize = 0
        $snoozeBtn.Size = New-Object System.Drawing.Size(270, 44)
        $snoozeBtn.Location = New-Object System.Drawing.Point(($centerX - 135), ($cardY + 345))
        Set-RoundedRegion $snoozeBtn 20
        $snoozeBtn.Add_Click({
            $script:SnoozesLeft--
            $script:WasSnoozed = $true
            $timer.Stop()
            $form.Close()
        })
        $form.Controls.Add($snoozeBtn)
    }

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        $script:Remaining--
        if ($script:Remaining -gt 0) {
            $timerLabel.Text = "Screen unlocks in $($script:Remaining)s"
            $timerLabel.Location = New-Object System.Drawing.Point(($centerX - [int]($timerLabel.Width / 2)), ($cardY + 195))
        } else {
            $timer.Stop()
            $form.Close()
        }
    })
    $timer.Start()

    [void]$form.ShowDialog()
    return $script:WasSnoozed
}

while ($true) {
    Start-Sleep -Seconds $WorkIntervalSeconds

    # Wait politely if she is currently on a Microsoft Teams call
    while (Test-InTeamsMeeting) {
        Start-Sleep -Seconds 60
    }

    $snoozed = Show-BreakScreen
    if ($snoozed) {
        Start-Sleep -Seconds $SnoozeSeconds
        while (Test-InTeamsMeeting) {
            Start-Sleep -Seconds 60
        }
        [void](Show-BreakScreen -IsSnoozeRetry $true)
    }
    $script:SnoozesLeft = 3
}
