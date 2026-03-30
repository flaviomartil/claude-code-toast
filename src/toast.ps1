param(
  [string]$TitleB64,
  [string]$BodyB64,
  [string]$TimerB64 = "",
  [int]$Duration = 6
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$title = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($TitleB64))
$body = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($BodyB64))
$timer = if ($TimerB64) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($TimerB64)) } else { "" }

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

$W = 520
$H = 200

Add-Type @"
using System;
using System.Windows.Forms;
public class NoActivateForm : Form {
    private const int WS_EX_TOPMOST = 0x00000008;
    private const int WS_EX_NOACTIVATE = 0x08000000;
    private const int WS_EX_TOOLWINDOW = 0x00000080;
    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= WS_EX_TOPMOST | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW;
            return cp;
        }
    }
    protected override bool ShowWithoutActivation { get { return true; } }
}
"@ -ReferencedAssemblies System.Windows.Forms

$form = New-Object NoActivateForm
$form.FormBorderStyle = 'None'
$form.BackColor = [System.Drawing.Color]::FromArgb(15, 15, 25)
$form.Size = New-Object System.Drawing.Size($W, $H)
$form.StartPosition = 'Manual'
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.Opacity = 0.98
$form.Location = New-Object System.Drawing.Point(($screen.Right - $W - 20), ($screen.Bottom - $H - 20))

$accent = New-Object System.Windows.Forms.Panel
$accent.BackColor = [System.Drawing.Color]::FromArgb(124, 58, 237)
$accent.Size = New-Object System.Drawing.Size(5, $H)
$accent.Location = New-Object System.Drawing.Point(0, 0)
$form.Controls.Add($accent)

$header = New-Object System.Windows.Forms.Panel
$header.BackColor = [System.Drawing.Color]::FromArgb(124, 58, 237)
$header.Size = New-Object System.Drawing.Size(($W - 5), 52)
$header.Location = New-Object System.Drawing.Point(5, 0)
$form.Controls.Add($header)

$lblBrand = New-Object System.Windows.Forms.Label
$lblBrand.Text = "CLAUDE CODE"
$lblBrand.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$lblBrand.ForeColor = [System.Drawing.Color]::FromArgb(220, 200, 255)
$lblBrand.Location = New-Object System.Drawing.Point(16, 5)
$lblBrand.AutoSize = $true
$header.Controls.Add($lblBrand)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = $title
$lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$lblTitle.Location = New-Object System.Drawing.Point(14, 22)
$lblTitle.Size = New-Object System.Drawing.Size(380, 28)
$header.Controls.Add($lblTitle)

if ($timer) {
  $lblTime = New-Object System.Windows.Forms.Label
  $lblTime.Text = $timer
  $lblTime.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
  $lblTime.ForeColor = [System.Drawing.Color]::FromArgb(52, 255, 180)
  $lblTime.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
  $lblTime.Location = New-Object System.Drawing.Point(400, 18)
  $lblTime.Size = New-Object System.Drawing.Size(100, 30)
  $header.Controls.Add($lblTime)
}

$lblBody = New-Object System.Windows.Forms.Label
$lblBody.Text = $body
$lblBody.Font = New-Object System.Drawing.Font('Segoe UI', 12)
$lblBody.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 255)
$lblBody.Location = New-Object System.Drawing.Point(20, 64)
$lblBody.Size = New-Object System.Drawing.Size(($W - 40), 120)
$form.Controls.Add($lblBody)

$progressBar = New-Object System.Windows.Forms.Panel
$progressBar.BackColor = [System.Drawing.Color]::FromArgb(124, 58, 237)
$progressBar.Size = New-Object System.Drawing.Size(($W - 5), 3)
$progressBar.Location = New-Object System.Drawing.Point(5, ($H - 3))
$form.Controls.Add($progressBar)

$steps = 40
$stepMs = [math]::Floor(($Duration * 1000) / $steps)
$barW = $W - 5
$shrinkTimer = New-Object System.Windows.Forms.Timer
$shrinkTimer.Interval = $stepMs
$currentStep = 0
$shrinkTimer.Add_Tick({
  $script:currentStep++
  $pct = 1.0 - ($script:currentStep / $steps)
  $progressBar.Size = New-Object System.Drawing.Size(([int]($barW * $pct)), 3)
  if ($script:currentStep -ge $steps) {
    $shrinkTimer.Stop()
    $form.Close()
  }
})
$shrinkTimer.Start()

$form.Add_Click({ $form.Close() })
$header.Add_Click({ $form.Close() })
$lblTitle.Add_Click({ $form.Close() })
$lblBody.Add_Click({ $form.Close() })
$lblBrand.Add_Click({ $form.Close() })

[System.Windows.Forms.Application]::Run($form)
