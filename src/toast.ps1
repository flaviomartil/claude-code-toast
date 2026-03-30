param(
  [string]$TitleB64,
  [string]$BodyB64,
  [string]$TimerB64 = "",
  [string]$ConfigB64 = "",
  [int]$Duration = 6
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$title = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($TitleB64))
$body  = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($BodyB64))
$timer = if ($TimerB64) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($TimerB64)) } else { "" }

$cfg = @{ theme = "claude"; position = "bottom-right"; opacity = 0.92; sound = @{ enabled = $true; file = $null } }
if ($ConfigB64) {
  try {
    $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ConfigB64))
    $parsed = $json | ConvertFrom-Json
    if ($parsed.theme)    { $cfg.theme    = $parsed.theme }
    if ($parsed.position) { $cfg.position = $parsed.position }
    if ($null -ne $parsed.opacity) { $cfg.opacity = [double]$parsed.opacity }
    if ($null -ne $parsed.sound) {
      $cfg.sound.enabled = [bool]$parsed.sound.enabled
      if ($parsed.sound.file) { $cfg.sound.file = $parsed.sound.file }
    }
  } catch {}
}

$themes = @{
  claude   = @{ accent = @(124,58,237);  bg = @(15,15,25);    text = @(240,240,255); timerC = @(52,255,180);  brand = @(220,200,255) }
  github   = @{ accent = @(35,134,54);   bg = @(13,17,23);    text = @(230,237,243); timerC = @(88,166,255);  brand = @(125,185,130) }
  minimal  = @{ accent = @(107,114,128); bg = @(31,41,55);    text = @(249,250,251); timerC = @(209,213,219); brand = @(156,163,175) }
  midnight = @{ accent = @(59,130,246);  bg = @(2,6,23);      text = @(226,232,240); timerC = @(245,158,11);  brand = @(147,180,255) }
}

$t = $themes[$cfg.theme]
if (-not $t) { $t = $themes["claude"] }

$accentColor = [System.Drawing.Color]::FromArgb($t.accent[0], $t.accent[1], $t.accent[2])
$bgColor     = [System.Drawing.Color]::FromArgb($t.bg[0], $t.bg[1], $t.bg[2])
$textColor   = [System.Drawing.Color]::FromArgb($t.text[0], $t.text[1], $t.text[2])
$timerColor  = [System.Drawing.Color]::FromArgb($t.timerC[0], $t.timerC[1], $t.timerC[2])
$brandColor  = [System.Drawing.Color]::FromArgb($t.brand[0], $t.brand[1], $t.brand[2])

$dpi = [System.Windows.Forms.Screen]::PrimaryScreen
$scaleFactor = 1.0
try {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DpiHelper {
    [DllImport("user32.dll")] public static extern int GetDpiForSystem();
}
"@
  $sysDpi = [DpiHelper]::GetDpiForSystem()
  if ($sysDpi -gt 0) { $scaleFactor = $sysDpi / 96.0 }
} catch {}

function Scale([int]$v) { [int]([math]::Round($v * $scaleFactor)) }

$W = Scale 420
$H = Scale 160
$R = Scale 12
$pad = Scale 16
$margin = Scale 16

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
switch ($cfg.position) {
  "top-left"     { $posX = $screen.Left + $margin;        $posY = $screen.Top + $margin }
  "top-right"    { $posX = $screen.Right - $W - $margin;  $posY = $screen.Top + $margin }
  "bottom-left"  { $posX = $screen.Left + $margin;        $posY = $screen.Bottom - $H - $margin }
  default        { $posX = $screen.Right - $W - $margin;  $posY = $screen.Bottom - $H - $margin }
}

Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public class GlassForm : Form {
    private const int WS_EX_TOPMOST     = 0x00000008;
    private const int WS_EX_NOACTIVATE  = 0x08000000;
    private const int WS_EX_TOOLWINDOW  = 0x00000080;
    private const int WS_EX_LAYERED     = 0x00080000;

    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int sz);
    [DllImport("dwmapi.dll")] static extern int DwmExtendFrameIntoClientArea(IntPtr hwnd, ref MARGINS m);

    [StructLayout(LayoutKind.Sequential)]
    struct MARGINS { public int Left, Right, Top, Bottom; }

    private int _radius;
    private Color _bg;
    private Color _accent;
    private float _progressPct = 1.0f;
    private int _barHeight;

    public float ProgressPct { get { return _progressPct; } set { _progressPct = value; Invalidate(new Rectangle(0, Height - _barHeight - 2, Width, _barHeight + 2)); } }

    public GlassForm(int radius, Color bg, Color accent, int barH) {
        _radius = radius; _bg = bg; _accent = accent; _barHeight = barH;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.DoubleBuffer | ControlStyles.OptimizedDoubleBuffer, true);
    }

    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= WS_EX_TOPMOST | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_LAYERED;
            return cp;
        }
    }

    protected override bool ShowWithoutActivation { get { return true; } }

    protected override void OnHandleCreated(EventArgs e) {
        base.OnHandleCreated(e);
        int pref = 2;
        DwmSetWindowAttribute(Handle, 33, ref pref, 4);
        int dark = 1;
        DwmSetWindowAttribute(Handle, 20, ref dark, 4);
        MARGINS m = new MARGINS { Left = -1, Right = -1, Top = -1, Bottom = -1 };
        DwmExtendFrameIntoClientArea(Handle, ref m);
        int bd = 0x00000000;
        DwmSetWindowAttribute(Handle, 34, ref bd, 4);
    }

    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.HighQuality;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;

        g.Clear(Color.FromArgb(1, 0, 0, 0));

        using (GraphicsPath path = RoundRect(1, 1, Width - 2, Height - 2, _radius)) {
            using (SolidBrush b = new SolidBrush(Color.FromArgb(230, _bg.R, _bg.G, _bg.B)))
                g.FillPath(b, path);
            using (Pen p = new Pen(Color.FromArgb(40, 255, 255, 255), 1))
                g.DrawPath(p, path);
        }

        int barY = Height - _barHeight - 1;
        int barW = (int)(Width * _progressPct);
        if (barW > 0) {
            using (LinearGradientBrush gb = new LinearGradientBrush(
                new Rectangle(0, barY, Width, _barHeight),
                _accent, Color.FromArgb(180, _accent.R, _accent.G, _accent.B),
                LinearGradientMode.Horizontal))
                g.FillRectangle(gb, 1, barY, barW - 2, _barHeight);
        }
    }

    private GraphicsPath RoundRect(int x, int y, int w, int h, int r) {
        GraphicsPath gp = new GraphicsPath();
        int d = r * 2;
        gp.AddArc(x, y, d, d, 180, 90);
        gp.AddArc(x + w - d, y, d, d, 270, 90);
        gp.AddArc(x + w - d, y + h - d, d, d, 0, 90);
        gp.AddArc(x, y + h - d, d, d, 90, 90);
        gp.CloseFigure();
        return gp;
    }
}
"@ -ReferencedAssemblies System.Windows.Forms, System.Drawing

$barH = Scale 3
$form = New-Object GlassForm($R, $bgColor, $accentColor, $barH)
$form.FormBorderStyle = 'None'
$form.Size = New-Object System.Drawing.Size($W, $H)
$form.StartPosition = 'Manual'
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.Opacity = 0
$form.Location = New-Object System.Drawing.Point($posX, $posY)
$form.BackColor = [System.Drawing.Color]::Black
$form.TransparencyKey = [System.Drawing.Color]::Black

$brandY = Scale 14
$titleY = Scale 36
$bodyY  = Scale 68

$lblBrand = New-Object System.Windows.Forms.Label
$lblBrand.Text = "CLAUDE CODE"
$lblBrand.Font = New-Object System.Drawing.Font('Segoe UI Variable Small', (8 * $scaleFactor), [System.Drawing.FontStyle]::Bold)
$lblBrand.ForeColor = $brandColor
$lblBrand.BackColor = [System.Drawing.Color]::Transparent
$lblBrand.Location = New-Object System.Drawing.Point($pad, $brandY)
$lblBrand.AutoSize = $true
$form.Controls.Add($lblBrand)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = $title
$lblTitle.Font = New-Object System.Drawing.Font('Segoe UI Variable Display', (13 * $scaleFactor), [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$lblTitle.BackColor = [System.Drawing.Color]::Transparent
$lblTitle.Location = New-Object System.Drawing.Point(($pad - (Scale 2)), $titleY)
$lblTitle.Size = New-Object System.Drawing.Size(($W - $pad * 2 - (Scale 80)), (Scale 24))
$form.Controls.Add($lblTitle)

if ($timer) {
  $lblTime = New-Object System.Windows.Forms.Label
  $lblTime.Text = $timer
  $lblTime.Font = New-Object System.Drawing.Font('Segoe UI Variable Display', (13 * $scaleFactor), [System.Drawing.FontStyle]::Bold)
  $lblTime.ForeColor = $timerColor
  $lblTime.BackColor = [System.Drawing.Color]::Transparent
  $lblTime.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
  $lblTime.Location = New-Object System.Drawing.Point(($W - $pad - (Scale 90)), $titleY)
  $lblTime.Size = New-Object System.Drawing.Size((Scale 90), (Scale 24))
  $form.Controls.Add($lblTime)
}

$lblBody = New-Object System.Windows.Forms.Label
$lblBody.Text = $body
$lblBody.Font = New-Object System.Drawing.Font('Segoe UI Variable Text', (10 * $scaleFactor))
$lblBody.ForeColor = [System.Drawing.Color]::FromArgb(180, $textColor.R, $textColor.G, $textColor.B)
$lblBody.BackColor = [System.Drawing.Color]::Transparent
$lblBody.Location = New-Object System.Drawing.Point($pad, $bodyY)
$lblBody.Size = New-Object System.Drawing.Size(($W - $pad * 2), ($H - $bodyY - (Scale 12)))
$form.Controls.Add($lblBody)

$targetOpacity = [math]::Min(1.0, [math]::Max(0.1, $cfg.opacity))
$fadeSteps = 12
$fadeMs = 16
$fadeTimer = New-Object System.Windows.Forms.Timer
$fadeTimer.Interval = $fadeMs
$fadeStep = 0
$fadeTimer.Add_Tick({
  $script:fadeStep++
  $pct = [math]::Min(1.0, $script:fadeStep / $fadeSteps)
  $eased = 1 - [math]::Pow(1 - $pct, 3)
  $form.Opacity = $targetOpacity * $eased
  if ($script:fadeStep -ge $fadeSteps) {
    $fadeTimer.Stop()
    $form.Opacity = $targetOpacity
  }
})

$steps = 50
$stepMs = [math]::Floor(($Duration * 1000) / $steps)
$shrinkTimer = New-Object System.Windows.Forms.Timer
$shrinkTimer.Interval = $stepMs
$currentStep = 0
$shrinkTimer.Add_Tick({
  $script:currentStep++
  $pct = 1.0 - ($script:currentStep / $steps)
  $form.ProgressPct = [float]$pct
  if ($script:currentStep -ge $steps) {
    $shrinkTimer.Stop()
    $fadeOutTimer.Start()
  }
})

$fadeOutSteps = 8
$fadeOutTimer = New-Object System.Windows.Forms.Timer
$fadeOutTimer.Interval = $fadeMs
$fadeOutStep = 0
$fadeOutTimer.Add_Tick({
  $script:fadeOutStep++
  $pct = [math]::Min(1.0, $script:fadeOutStep / $fadeOutSteps)
  $form.Opacity = $targetOpacity * (1 - $pct)
  if ($script:fadeOutStep -ge $fadeOutSteps) {
    $fadeOutTimer.Stop()
    $form.Close()
  }
})

if ($cfg.sound.enabled) {
  try {
    if ($cfg.sound.file -and (Test-Path $cfg.sound.file)) {
      $player = New-Object System.Media.SoundPlayer($cfg.sound.file)
      $player.Play()
    } else {
      [System.Media.SystemSounds]::Asterisk.Play()
    }
  } catch {}
}

$form.Add_Shown({ $fadeTimer.Start(); $shrinkTimer.Start() })

$dismiss = { $shrinkTimer.Stop(); $fadeTimer.Stop(); $fadeOutTimer.Stop(); $form.Close() }
$form.Add_Click($dismiss)
foreach ($c in $form.Controls) { $c.Add_Click($dismiss) }

[System.Windows.Forms.Application]::Run($form)
