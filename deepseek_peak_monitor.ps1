#Requires -Version 3.0
# ============================================================
#  DeepSeek-V4-Flash 错峰定价提醒器（桌面小程序）
#  仅使用 Windows 原生组件（PowerShell + WinForms），无第三方依赖
#
#  规则（自 8 月 17 日起，北京时间）：
#    高峰涨价时段：09:00-12:00、14:00-18:00
#    空闲低价时段：其余全部时间
#
#  功能：
#    1. 实时显示当前北京时间，醒目颜色标明当前高峰/低价
#    2. 距离下一次时段切换的倒计时
#    3. 内置价格对照表
#    4. 进入高峰前 10 分钟弹出置顶预警弹窗
# ============================================================
param(
    [switch]$Selftest,
    [switch]$SmokeTest
)

$ErrorActionPreference = 'Stop'

# ---------------- 可配置项（按需修改） ----------------
$script:PEAK_PRICE    = 0.28    # 高峰涨价时段单价（元 / 千 tokens）
$script:OFFPEAK_PRICE = 0.08    # 空闲低价时段单价（元 / 千 tokens）
$script:WARN_MINUTES  = 10      # 进入高峰前预警提前量（分钟）
# 高峰时段定义（北京时间）固定为 09:00-12:00、14:00-18:00
# --------------------------------------------------------

function Get-BJTime {
    # 北京时间 = UTC+8（无夏令时），直接由 UTC 计算
    return [DateTime]::UtcNow.AddHours(8)
}

function Test-IsPeak([datetime]$dt) {
    $t = $dt.TimeOfDay
    return (($t -ge [TimeSpan]::FromHours(9))  -and ($t -lt [TimeSpan]::FromHours(12))) -or
           (($t -ge [TimeSpan]::FromHours(14)) -and ($t -lt [TimeSpan]::FromHours(18)))
}

function Get-NextSwitch([datetime]$dt) {
    $candidates = @()
    foreach ($h in @(9, 12, 14, 18)) {
        $b = [datetime]::new($dt.Year, $dt.Month, $dt.Day, $h, 0, 0)
        if ($b -le $dt) { $b = $b.AddDays(1) }
        $candidates += $b
    }
    $boundary = ($candidates | Sort-Object | Select-Object -First 1)
    return @{ Boundary = $boundary; EnterPeak = (Test-IsPeak $boundary) }
}

function Invoke-SelfTest {
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
    $now = Get-BJTime
    $peak = Test-IsPeak $now
    $sw = Get-NextSwitch $now

    Write-Host ''
    Write-Host ('当前北京时间 : {0:yyyy-MM-dd HH:mm:ss}  (UTC+8)' -f $now)
    Write-Host ('当前状态     : {0}' -f $(if ($peak) { '高峰涨价时段' } else { '空闲低价时段' }))
    Write-Host ('下次切换     : {0:yyyy-MM-dd HH:mm:ss} 进入{1}' -f $sw.Boundary, $(if ($sw.EnterPeak) { '高峰涨价' } else { '空闲低价' }))
    if (-not $peak -and $sw.EnterPeak -and (($sw.Boundary - $now).TotalMinutes -le $script:WARN_MINUTES)) {
        Write-Host ('预警触发     : 距进入高峰不足 {0} 分钟，将弹出预警弹窗' -f $script:WARN_MINUTES)
    } else {
        Write-Host ('预警触发     : 当前不满足预警条件（仅在低价时段且进入高峰前 {0} 分钟内触发）' -f $script:WARN_MINUTES)
    }

    $fail = 0

    Write-Host ''
    Write-Host '时段判定自检（今日各时刻）:'
    $cases = @(
        @{ T = [TimeSpan]::FromHours(0);  E = '低价' },
        @{ T = [TimeSpan]::FromHours(8);  E = '低价' },
        @{ T = [TimeSpan]::FromHours(9);  E = '高峰' },
        @{ T = [TimeSpan]::FromHours(11); E = '高峰' },
        @{ T = [TimeSpan]::FromHours(12); E = '低价' },
        @{ T = [TimeSpan]::FromHours(13); E = '低价' },
        @{ T = [TimeSpan]::FromHours(14); E = '高峰' },
        @{ T = [TimeSpan]::FromHours(17); E = '高峰' },
        @{ T = [TimeSpan]::FromHours(18); E = '低价' },
        @{ T = [TimeSpan]::FromHours(23); E = '低价' }
    )
    foreach ($c in $cases) {
        $dt = [datetime]::Today.Add($c.T)
        $got = if (Test-IsPeak $dt) { '高峰' } else { '低价' }
        $ok = ($got -eq $c.E)
        if (-not $ok) { $fail++ }
        Write-Host ('  {0}  判定={1}  期望={2}  [{3}]' -f $c.T.ToString('hh\:mm\:ss'), $got, $c.E, $(if ($ok) { 'OK' } else { '!! 不符' }))
    }

    Write-Host ''
    Write-Host '下一切换点自检:'
    $swcases = @(
        @{ T = '08:30'; H = 9;  D = 0; E = $true },
        @{ T = '11:00'; H = 12; D = 0; E = $false },
        @{ T = '13:00'; H = 14; D = 0; E = $true },
        @{ T = '16:00'; H = 18; D = 0; E = $false },
        @{ T = '20:00'; H = 9;  D = 1; E = $true },
        @{ T = '23:59'; H = 9;  D = 1; E = $true }
    )
    foreach ($c in $swcases) {
        $dt = [datetime]::Today.Add([TimeSpan]::Parse($c.T))
        $sw2 = Get-NextSwitch $dt
        $expDate = $dt.Date.AddDays($c.D)
        $expB = [datetime]::new($expDate.Year, $expDate.Month, $expDate.Day, $c.H, 0, 0)
        $ok = ($sw2.Boundary -eq $expB) -and ($sw2.EnterPeak -eq $c.E)
        if (-not $ok) { $fail++ }
        Write-Host ('  {0}  下一切换={1:MM-dd HH:mm} 进入{2}  期望={3:MM-dd HH:mm} 进入{4}  [{5}]' -f $c.T, $sw2.Boundary, $(if ($sw2.EnterPeak) { '高峰' } else { '低价' }), $expB, $(if ($c.E) { '高峰' } else { '低价' }), $(if ($ok) { 'OK' } else { '!! 不符' }))
    }

    Write-Host ''
    if ($fail -eq 0) { Write-Host '自检结果: 全部通过，规则实现正确。' }
    else { Write-Host ('自检结果: {0} 项不符，请检查脚本配置。' -f $fail) }
    exit 0
}

# ---------------- GUI（Windows 原生 WinForms） ----------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:C_BG     = [System.Drawing.Color]::FromArgb(30, 31, 36)
$script:C_FG     = [System.Drawing.Color]::FromArgb(232, 232, 236)
$script:C_PEAK   = [System.Drawing.Color]::FromArgb(255, 77, 79)
$script:C_OFF    = [System.Drawing.Color]::FromArgb(61, 220, 132)
$script:C_ACCENT = [System.Drawing.Color]::FromArgb(240, 160, 32)
$script:C_HDR    = [System.Drawing.Color]::FromArgb(44, 45, 52)
$script:C_ROW1   = [System.Drawing.Color]::FromArgb(35, 36, 41)
$script:C_ROW2   = [System.Drawing.Color]::FromArgb(41, 42, 48)
$script:C_MUTED  = [System.Drawing.Color]::FromArgb(154, 154, 165)
$script:C_WARNBG = [System.Drawing.Color]::FromArgb(58, 31, 34)
$script:C_WARNFG = [System.Drawing.Color]::FromArgb(255, 120, 117)

$script:F_TITLE  = New-Object System.Drawing.Font('Microsoft YaHei UI', 14, [System.Drawing.FontStyle]::Bold)
$script:F_TIME   = New-Object System.Drawing.Font('Consolas', 42, [System.Drawing.FontStyle]::Bold)
$script:F_STATUS = New-Object System.Drawing.Font('Microsoft YaHei UI', 16, [System.Drawing.FontStyle]::Bold)
$script:F_COUNT  = New-Object System.Drawing.Font('Consolas', 13)
$script:F_SMALL  = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
$script:F_TINY   = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$script:F_HDR    = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)

$script:LastWarn = $null

function New-TableCell($parent, $text, $x, $y, $w, $h, $bg, $fg, $font) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.BackColor = $bg
    $l.ForeColor = $fg
    $l.Font = $font
    $l.TextAlign = 'MiddleLeft'
    $l.AutoSize = $false
    $l.SetBounds($x, $y, $w, $h)
    $parent.Controls.Add($l)
}

function Show-Warning([datetime]$boundary) {
    if ($boundary.Hour -eq 9) { $seg = '09:00-12:00' } else { $seg = '14:00-18:00' }

    $w = New-Object System.Windows.Forms.Form
    $script:WarnWin = $w
    $w.Text = '高峰预警'
    $w.ClientSize = New-Object System.Drawing.Size(400, 235)
    $w.FormBorderStyle = 'FixedDialog'
    $w.StartPosition = 'CenterScreen'
    $w.TopMost = $true
    $w.ControlBox = $false
    $w.BackColor = $script:C_WARNBG
    $w.Font = $script:F_SMALL

    $l1 = New-Object System.Windows.Forms.Label
    $l1.Text = '⚠ 即将进入高峰涨价时段'
    $l1.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 16, [System.Drawing.FontStyle]::Bold)
    $l1.ForeColor = $script:C_WARNFG
    $l1.BackColor = $script:C_WARNBG
    $l1.TextAlign = 'MiddleCenter'
    $l1.AutoSize = $false
    $l1.SetBounds(0, 16, 400, 34)

    $msg = "距离 $($boundary.ToString('HH:mm')) 进入高峰时段（$seg）`n还有不到 $($script:WARN_MINUTES) 分钟。`n如计划调用 DeepSeek-V4-Flash，请提前安排，`n或等高峰结束后再执行批量任务。"
    $l2 = New-Object System.Windows.Forms.Label
    $l2.Text = $msg
    $l2.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11)
    $l2.ForeColor = $script:C_FG
    $l2.BackColor = $script:C_WARNBG
    $l2.TextAlign = 'MiddleCenter'
    $l2.AutoSize = $false
    $l2.SetBounds(16, 54, 368, 108)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = '知道了'
    $btn.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11)
    $btn.BackColor = $script:C_PEAK
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.FlatStyle = 'Flat'
    $btn.SetBounds(150, 176, 100, 38)
    $btn.Add_Click({ $script:WarnWin.Close() })

    $w.Controls.Add($l1)
    $w.Controls.Add($l2)
    $w.Controls.Add($btn)

    [System.Media.SystemSounds]::Exclamation.Play()

    $script:WarnAuto = New-Object System.Windows.Forms.Timer
    $script:WarnAuto.Interval = 60000
    $script:WarnAuto.Add_Tick({ param($s) $s.Stop(); $script:WarnWin.Close() })
    $script:WarnAuto.Start()

    $w.Show()
}

function Update-UI {
    $now = Get-BJTime
    $peak = Test-IsPeak $now
    $sw = Get-NextSwitch $now
    $boundary = $sw.Boundary
    $enterPeak = $sw.EnterPeak

    $script:lblTime.Text = $now.ToString('HH:mm:ss')

    if ($peak) {
        $script:lblStatus.Text = '● 高峰涨价时段'
        $script:lblStatus.ForeColor = $script:C_PEAK
    } else {
        $script:lblStatus.Text = '● 空闲低价时段'
        $script:lblStatus.ForeColor = $script:C_OFF
    }

    $total = [int]($boundary - $now).TotalSeconds
    $h = [int][math]::Floor($total / 3600)
    $m = [int][math]::Floor(($total % 3600) / 60)
    $s = $total % 60
    $what = if ($enterPeak) { '进入高峰涨价' } else { '进入空闲低价' }
    $script:lblCount.Text = ('距下次切换 {0:00}:{1:00}:{2:00}  （{3:HH:mm} {4}）' -f $h, $m, $s, $boundary, $what)

    if (-not $peak -and $enterPeak -and (($boundary - $now).TotalMinutes -le $script:WARN_MINUTES)) {
        if ($script:LastWarn -ne $boundary) {
            $script:LastWarn = $boundary
            Show-Warning $boundary
        }
    } else {
        $script:LastWarn = $null
    }
}

function Build-MainForm {
    $form = New-Object System.Windows.Forms.Form
    $script:MainForm = $form
    $form.Text = 'DeepSeek-V4-Flash 错峰定价提醒器'
    $form.ClientSize = New-Object System.Drawing.Size(500, 400)
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.BackColor = $script:C_BG
    $form.StartPosition = 'CenterScreen'
    $form.Font = $script:F_SMALL

    $lTitle = New-Object System.Windows.Forms.Label
    $lTitle.Text = 'DeepSeek-V4-Flash 错峰定价监控'
    $lTitle.Font = $script:F_TITLE
    $lTitle.ForeColor = $script:C_FG
    $lTitle.BackColor = $script:C_BG
    $lTitle.TextAlign = 'MiddleCenter'
    $lTitle.AutoSize = $false
    $lTitle.SetBounds(0, 10, 500, 30)

    $script:lblTime = New-Object System.Windows.Forms.Label
    $script:lblTime.Text = '--:--:--'
    $script:lblTime.Font = $script:F_TIME
    $script:lblTime.ForeColor = $script:C_FG
    $script:lblTime.BackColor = $script:C_BG
    $script:lblTime.TextAlign = 'MiddleCenter'
    $script:lblTime.AutoSize = $false
    $script:lblTime.SetBounds(0, 42, 500, 62)

    $script:lblStatus = New-Object System.Windows.Forms.Label
    $script:lblStatus.Text = '● 空闲低价时段'
    $script:lblStatus.Font = $script:F_STATUS
    $script:lblStatus.ForeColor = $script:C_OFF
    $script:lblStatus.BackColor = $script:C_BG
    $script:lblStatus.TextAlign = 'MiddleCenter'
    $script:lblStatus.AutoSize = $false
    $script:lblStatus.SetBounds(0, 108, 500, 36)

    $script:lblCount = New-Object System.Windows.Forms.Label
    $script:lblCount.Text = '距下次切换 --:--:--'
    $script:lblCount.Font = $script:F_COUNT
    $script:lblCount.ForeColor = $script:C_FG
    $script:lblCount.BackColor = $script:C_BG
    $script:lblCount.TextAlign = 'MiddleCenter'
    $script:lblCount.AutoSize = $false
    $script:lblCount.SetBounds(0, 150, 500, 28)

    $lTblTitle = New-Object System.Windows.Forms.Label
    $lTblTitle.Text = '价格对照表（元 / 千 tokens）'
    $lTblTitle.Font = $script:F_SMALL
    $lTblTitle.ForeColor = $script:C_ACCENT
    $lTblTitle.BackColor = $script:C_BG
    $lTblTitle.TextAlign = 'MiddleCenter'
    $lTblTitle.AutoSize = $false
    $lTblTitle.SetBounds(0, 192, 500, 24)

    $cols = @(
        @{ T = '时段';     W = 100 },
        @{ T = '时间范围'; W = 190 },
        @{ T = '单价';     W = 110 },
        @{ T = '备注';     W = 100 }
    )
    $x = 0
    foreach ($col in $cols) {
        New-TableCell $form $col.T $x 220 $col.W 28 $script:C_HDR $script:C_FG $script:F_HDR
        $x += $col.W
    }

    $rows = @(
        @{ A = '高峰涨价'; B = '09:00-12:00、14:00-18:00'; C = ('{0:N2}' -f $script:PEAK_PRICE); D = '排队慢'; PK = $true },
        @{ A = '空闲低价'; B = '其余全部时间'; C = ('{0:N2}' -f $script:OFFPEAK_PRICE); D = '响应快'; PK = $false }
    )
    $y = 250
    $ri = 0
    foreach ($row in $rows) {
        $bg = if ($ri % 2 -eq 0) { $script:C_ROW1 } else { $script:C_ROW2 }
        $vals = @($row.A, $row.B, $row.C, $row.D)
        $x = 0
        for ($i = 0; $i -lt $cols.Count; $i++) {
            $fg = if ($i -eq 0) { if ($row.PK) { $script:C_PEAK } else { $script:C_OFF } } else { $script:C_FG }
            New-TableCell $form $vals[$i] $x $y $cols[$i].W 28 $bg $fg $script:F_SMALL
            $x += $cols[$i].W
        }
        $y += 28
        $ri++
    }

    $lTimeline = New-Object System.Windows.Forms.Label
    $lTimeline.Text = '一天时间轴: 00:00 低价 | 09:00 高峰 | 12:00 低价 | 14:00 高峰 | 18:00 低价'
    $lTimeline.Font = $script:F_TINY
    $lTimeline.ForeColor = $script:C_MUTED
    $lTimeline.BackColor = $script:C_BG
    $lTimeline.TextAlign = 'MiddleCenter'
    $lTimeline.AutoSize = $false
    $lTimeline.SetBounds(0, 322, 500, 24)

    $lNote = New-Object System.Windows.Forms.Label
    $lNote.Text = '规则自 8月17日 起适用（北京时间）· 价格可在脚本顶部修改'
    $lNote.Font = $script:F_TINY
    $lNote.ForeColor = $script:C_MUTED
    $lNote.BackColor = $script:C_BG
    $lNote.TextAlign = 'MiddleCenter'
    $lNote.AutoSize = $false
    $lNote.SetBounds(0, 348, 500, 22)

    $form.Controls.Add($lTitle)
    $form.Controls.Add($script:lblTime)
    $form.Controls.Add($script:lblStatus)
    $form.Controls.Add($script:lblCount)
    $form.Controls.Add($lTblTitle)
    $form.Controls.Add($lTimeline)
    $form.Controls.Add($lNote)

    $script:MainTimer = New-Object System.Windows.Forms.Timer
    $script:MainTimer.Interval = 200
    $script:MainTimer.Add_Tick({ Update-UI })
    $form.Add_Shown({ $script:MainTimer.Start(); Update-UI })
    $form.Add_FormClosed({ $script:MainTimer.Stop() })

    return $form
}

function Start-App {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $form = Build-MainForm
    [System.Windows.Forms.Application]::Run($form)
}

function Invoke-SmokeTest {
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $form = Build-MainForm
    $script:SmokeForm = $form
    $script:SmokeTimer = New-Object System.Windows.Forms.Timer
    $script:SmokeTimer.Interval = 2500
    $script:SmokeTimer.Add_Tick({ $script:SmokeTimer.Stop(); $script:SmokeForm.Close() })
    $script:SmokeTimer.Start()
    [System.Windows.Forms.Application]::Run($form)
    Write-Host 'GUI 冒烟测试通过：窗口已成功构建并自动关闭。'
    exit 0
}

# ---------------- 入口 ----------------
try {
    if ($Selftest)      { Invoke-SelfTest }
    elseif ($SmokeTest) { Invoke-SmokeTest }
    else                { Start-App }
}
catch {
    $err = "$($_.Exception.GetType().FullName): $($_.Exception.Message)`r`n`r`n$($_.ScriptStackTrace)"
    try {
        [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'monitor_error.log'), $err, (New-Object System.Text.UTF8Encoding($false)))
    } catch {}
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    [System.Windows.Forms.MessageBox]::Show($err, 'DeepSeek-V4-Flash 提醒器错误', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit 1
}
