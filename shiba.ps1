# Shiba desktop pet - refined side-profile Shiba that roams your desktop
# It walks/runs along the bottom, flips at screen edges, idles (blink/tail/ear),
# and pauses while you pet its head (hearts/happy/blush/boop) or drag it.
# Right-click -> context menu (pet / exit). No external images or audio files.

$ErrorActionPreference = 'Stop'
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $src = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Media;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Globalization;
using System.Windows.Forms;

public class ShibaForm : Form
{
    const int W = 280, H = 220;
    static readonly Color ORANGE   = Color.FromArgb(244, 166, 74);
    static readonly Color ORANGE_D = Color.FromArgb(214, 124, 44);
    static readonly Color ORANGE_H = Color.FromArgb(255, 216, 152);
    static readonly Color FARLEG   = Color.FromArgb(196, 116, 40);
    static readonly Color CREAM    = Color.FromArgb(255, 242, 224);
    static readonly Color CREAM_D  = Color.FromArgb(233, 214, 186);
    static readonly Color DARK     = Color.FromArgb(45, 32, 26);
    static readonly Color HEART    = Color.FromArgb(255, 105, 135);
    static readonly Color OUTLINE  = Color.FromArgb(126, 74, 36);

    Bitmap _bmp;
    Graphics _g;
    Stopwatch _sw = Stopwatch.StartNew();
    Random _rnd = new Random();
    System.Windows.Forms.Timer _timer;
    SoundPlayer _boop;
    SoundPlayer _chirp;

    double _last = 0;
    double _petTimer = 0;
    double _petStart = 0;
    double _blink = 1;
    double _blinkTimer = 0;
    double _blinkNext = 2.5;
    double _wagTimer = 0;
    double _wagNext = 3.0;
    double _tailWag = 0;
    double _earTimer = 0;
    double _earNext = 4.5;
    double _earA = 0;
    double _lastBoop = -10;

    // movement
    int _mode = 0;            // 0 idle, 1 move
    double _modeTimer = 2.0;
    double _turnTimer = 3.0;
    bool _run = false;
    double _vx = 0;
    double _vy = 0;
    bool _airborne = false;
    int _facing = 1;
    double _phase = 0;
    Rectangle _bounds;
    PointF _pos;
    bool _frameMoving = false;
    const double GRAV = 1300, RESTIT = 0.5, FLOOR = 178;
    double _flingVX = 0, _flingVY = 0;
    double _lastMoveTime = 0;
    Point _lastMove;

    // pose / body form: 0 stand, 1 sit, 2 lie
    int _pose = 0;
    double _poseTimer = 0;

    bool _dragging = false;
    Point _dragOffset;
    List<Heart> _hearts = new List<Heart>();

    // screen-time reminder
    double _focusTime = 0;
    bool _remindActive = false;
    double _remindStart = 0;
    public int RemindMinutes = 20;
    public string ReminderText = "Take a break";

    // random speech bubbles
    public string[] Sayings = new string[0];
    public string[] Titles = new string[0];
    bool _sayActive = false;
    double _sayStart = 0;
    double _sayNext = 14;
    string _sayText = "";

    // leveling system
    int _level = 1;
    double _xp = 0;
    double _xpNeed = 120;
    double _scale = 1.0;
    const double XP_RATE = 1.0;
    double _saveTimer = 15;
    public string SaveFile = "";
    public string LevelUpText = "Level up!";
    bool _lvlUpActive = false;
    double _lvlUpStart = 0;
    int _lvlUpLevel = 1;
    List<Spark> _sparks = new List<Spark>();
    SoundPlayer _fanfare;
    static readonly Color[] SPARK_COLORS = new Color[] {
        Color.FromArgb(255, 214, 60), Color.White, Color.FromArgb(255, 130, 170), Color.FromArgb(130, 200, 255)
    };

    class Spark { public double x, y, vx, vy, alpha, size; public int ci; }

    class Heart { public double dx, y, vy, alpha, scale; }

    [StructLayout(LayoutKind.Sequential)] struct PT { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] struct SZ { public int cx, cy; }
    [StructLayout(LayoutKind.Sequential)] struct BF { public byte BlendOp, BlendFlags, SourceConstantAlpha, AlphaFormat; }
    [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [StructLayout(LayoutKind.Sequential)] struct BITMAPINFOHEADER
    {
        public uint biSize; public int biWidth, biHeight; public ushort biPlanes, biBitCount;
        public uint biCompression, biSizeImage; public int biXPelsPerMeter, biYPelsPerMeter;
        public uint biClrUsed, biClrImportant;
    }
    [StructLayout(LayoutKind.Sequential)] struct BITMAPINFO { public BITMAPINFOHEADER bmiHeader; public uint bmiColors; }

    const int GWL_EXSTYLE = -20;
    const int WS_EX_LAYERED = 0x80000;
    const int ULW_ALPHA = 2;
    const byte AC_SRC_OVER = 0;
    const byte AC_SRC_ALPHA = 1;
    const int BI_RGB = 0;

    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int n);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int n, int v);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr h);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr h, IntPtr o);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
    [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateDIBSection(IntPtr hdc, ref BITMAPINFO bmi, uint usage, out IntPtr bits, IntPtr hSection, uint dwOffset);
    [DllImport("user32.dll", SetLastError = true)] static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref PT ptDst, ref SZ sz, IntPtr hdcSrc, ref PT ptSrc, int crKey, ref BF pblend, int dwFlags);
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    public ShibaForm()
    {
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        ShowInTaskbar = true;
        TopMost = true;
        ClientSize = new Size(W, H);
        BackColor = Color.Magenta;
        Cursor = Cursors.Hand;
        Text = "ShibaPet";

        _bounds = Screen.PrimaryScreen.WorkingArea;
        _pos = new PointF(_bounds.Right - W - 60, _bounds.Bottom - 178);
        Location = new Point((int)_pos.X, (int)_pos.Y);

        _bmp = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        _g = Graphics.FromImage(_bmp);
        _g.SmoothingMode = SmoothingMode.AntiAlias;
        _g.TextRenderingHint = TextRenderingHint.AntiAlias;

        ContextMenuStrip cms = new ContextMenuStrip();
        cms.Items.Add("Pet", null, (s, e) => Pet());
        cms.Items.Add("Talk", null, (s, e) => SayRandom());
        cms.Items.Add("Walk", null, (s, e) => StartWalk());
        cms.Items.Add("Sit", null, (s, e) => SetPose(1));
        cms.Items.Add("Sleep", null, (s, e) => SetPose(2));
        cms.Items.Add("Stand", null, (s, e) => SetPose(0));
        cms.Items.Add(new ToolStripSeparator());
        cms.Items.Add("Exit", null, (s, e) => Close());
        ContextMenuStrip = cms;

        _timer = new System.Windows.Forms.Timer();
        _timer.Interval = 33;
        _timer.Tick += OnTick;
        _timer.Start();

        BuildBoop();
        BuildChirp();
        BuildFanfare();
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        LoadGame();
        _scale = 1.0 + Math.Min(_level - 1, 6) * 0.02;
        Render();
    }

    void OnTick(object s, EventArgs e)
    {
        double now = _sw.Elapsed.TotalSeconds;
        double dt = now - _last; _last = now;
        if (dt <= 0) dt = 0.016;
        if (dt > 0.1) dt = 0.1;

        // blink
        _blinkNext -= dt;
        if (_blinkNext <= 0 && _blinkTimer <= 0) _blinkTimer = 0.13;
        if (_blinkTimer > 0)
        {
            _blinkTimer -= dt;
            double p = _blinkTimer / 0.13;
            _blink = 2.0 * Math.Abs(p - 0.5);
            if (_blinkTimer <= 0) { _blink = 1; _blinkNext = 2 + _rnd.NextDouble() * 2.5; }
        }

        // ear twitch
        _earNext -= dt;
        if (_earNext <= 0 && _earTimer <= 0) _earTimer = 0.2;
        if (_earTimer > 0) _earTimer -= dt;
        _earA = (_earTimer > 0) ? Math.Sin(now * 26) * 0.08 : 0;

        // screen-time reminder (counts only active time, pauses when idle/away)
        if (!_remindActive)
        {
            uint tickNow = (uint)Environment.TickCount;
            LASTINPUTINFO lii = new LASTINPUTINFO();
            lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
            GetLastInputInfo(ref lii);
            if (tickNow - lii.dwTime < 60000) _focusTime += dt;
            if (_focusTime >= RemindMinutes * 60) { _focusTime = 0; TriggerReminder(); }
        }
        else if (now - _remindStart > 6.0)
            _remindActive = false;

        bool busy = _petTimer > 0 || _dragging || _remindActive;
        _frameMoving = (_mode == 1 || _airborne) && !busy;

        // pose: wake to stand on activity, otherwise auto sit/lie while idle
        if (busy || _mode == 1 || _airborne)
        {
            _pose = 0;
            _poseTimer = 0;
        }
        else
        {
            _poseTimer += dt;
            if (_poseTimer > 18 && _pose == 0) _pose = 1;
            if (_poseTimer > 40) _pose = 2;
        }

        // tail
        if (_frameMoving)
            _tailWag = Math.Sin(now * 16) * 0.35;
        else
        {
            _wagNext -= dt;
            if (_wagNext <= 0 && _wagTimer <= 0) _wagTimer = 1.6 + _rnd.NextDouble() * 1.2;
            if (_wagTimer > 0)
            {
                _wagTimer -= dt;
                _tailWag = Math.Sin(now * 9) * 0.4 * Math.Max(0, _wagTimer / 1.6);
                if (_wagTimer <= 0) { _tailWag = 0; _wagNext = 2.5 + _rnd.NextDouble() * 3; }
            }
            else _tailWag = 0;
        }

        if (_petTimer > 0) _petTimer -= dt;

        // movement state machine
        if (!busy && !_airborne)
        {
            _modeTimer -= dt;
            if (_modeTimer <= 0)
            {
                if (_mode == 0)
                {
                    _mode = 1;
                    _run = _rnd.NextDouble() < 0.35;
                    double speed = _run ? (55 + _rnd.NextDouble() * 35) : (20 + _rnd.NextDouble() * 15);
                    _vx = (_rnd.NextDouble() < 0.5 ? -speed : speed);
                    _facing = _vx > 0 ? 1 : -1;
                    _modeTimer = 2.5 + _rnd.NextDouble() * 3.5;
                    _phase = 0;
                    _turnTimer = 2 + _rnd.NextDouble() * 3;
                }
                else
                {
                    _mode = 0;
                    _modeTimer = 1.5 + _rnd.NextDouble() * 3;
                }
            }
            if (_mode == 1)
            {
                _phase += dt * (_run ? 14 : 6);
                _pos.X += (float)(_vx * dt);
                float minX = _bounds.Left + 4;
                float maxX = _bounds.Right - W - 4;
                if (_pos.X < minX) { _pos.X = minX; _vx = Math.Abs(_vx); _facing = 1; }
                else if (_pos.X > maxX) { _pos.X = maxX; _vx = -Math.Abs(_vx); _facing = -1; }
                else
                {
                    _turnTimer -= dt;
                    if (_turnTimer <= 0)
                    {
                        _turnTimer = 2 + _rnd.NextDouble() * 3;
                        if (_rnd.NextDouble() < 0.4) { _vx = -_vx; _facing = _vx > 0 ? 1 : -1; }
                    }
                }
                Location = new Point((int)Math.Round(_pos.X), (int)Math.Round(_pos.Y));
            }
        }

        // throw physics (gravity + bounce)
        if (_airborne)
        {
            _phase += dt * (_run ? 14 : 10);
            _vy += GRAV * dt;
            _pos.X += (float)(_vx * dt);
            _pos.Y += (float)(_vy * dt);
            float minX = _bounds.Left + 4;
            float maxX = _bounds.Right - W - 4;
            float floorY = _bounds.Bottom - (float)FLOOR;
            if (_pos.X < minX) { _pos.X = minX; _vx = -_vx * 0.6; _facing = 1; }
            else if (_pos.X > maxX) { _pos.X = maxX; _vx = -_vx * 0.6; _facing = -1; }
            if (_pos.Y < _bounds.Top) { _pos.Y = _bounds.Top; _vy = Math.Abs(_vy) * RESTIT; }
            else if (_pos.Y > floorY)
            {
                _pos.Y = floorY;
                if (Math.Abs(_vy) < 40) _vy = 0;
                else _vy = -_vy * RESTIT;
                _vx *= 0.85;
                if (Math.Abs(_vx) < 30 && _vy == 0)
                {
                    _vx = 0; _airborne = false; _mode = 0; _modeTimer = 1.0;
                }
            }
            Location = new Point((int)Math.Round(_pos.X), (int)Math.Round(_pos.Y));
        }

        // random speech bubbles while idle
        if (_sayActive)
        {
            if (now - _sayStart > 2.6) { _sayActive = false; _sayNext = 12 + _rnd.NextDouble() * 18; }
        }
        else if (!busy && _mode == 0)
        {
            _sayNext -= dt;
            if (_sayNext <= 0) SayRandom();
        }

        // hearts
        for (int i = _hearts.Count - 1; i >= 0; i--)
        {
            Heart h = _hearts[i];
            h.y += h.vy * dt;
            h.alpha -= dt * 0.9;
            if (h.alpha <= 0 || h.y < -20) _hearts.RemoveAt(i);
        }

        // leveling: gain xp over time + autosave
        GainXp(dt * XP_RATE);
        _saveTimer -= dt;
        if (_saveTimer <= 0) { SaveGame(); _saveTimer = 15; }

        // level-up celebration expiry
        if (_lvlUpActive && now - _lvlUpStart > 3.0) _lvlUpActive = false;

        // sparkle particles
        for (int i = _sparks.Count - 1; i >= 0; i--)
        {
            Spark sp = _sparks[i];
            sp.vy += 300 * dt;
            sp.x += sp.vx * dt;
            sp.y += sp.vy * dt;
            sp.alpha -= dt * 1.1;
            if (sp.alpha <= 0) _sparks.RemoveAt(i);
        }

        Render();
    }

    void Pet()
    {
        double now = _sw.Elapsed.TotalSeconds;
        if (now - _lastBoop > 0.2 && _boop != null) { _boop.Play(); _lastBoop = now; }
        _petTimer = 1.2;
        _petStart = now;
        GainXp(15);
        for (int i = 0; i < 4; i++)
            _hearts.Add(new Heart { dx = _rnd.NextDouble() * 30 - 15, y = 100, vy = -(45 + _rnd.NextDouble() * 40), alpha = 1, scale = 0.7 + _rnd.NextDouble() * 0.6 });
    }

    void TriggerReminder()
    {
        _remindActive = true;
        _remindStart = _sw.Elapsed.TotalSeconds;
        if (_chirp != null) _chirp.Play();
    }

    void StartWalk()
    {
        _airborne = false;
        _mode = 1;
        _run = false;
        double speed = 25 + _rnd.NextDouble() * 15;
        _vx = (_rnd.NextDouble() < 0.5 ? -speed : speed);
        _facing = _vx > 0 ? 1 : -1;
        _modeTimer = 3.0;
        _phase = 0;
    }

    void SetPose(int p)
    {
        _pose = p;
        _poseTimer = 0;
        _mode = 0;
        _airborne = false;
        _modeTimer = 3.0;
    }

    void SayRandom()
    {
        if (Sayings == null || Sayings.Length == 0) return;
        _sayText = Sayings[_rnd.Next(Sayings.Length)];
        _sayActive = true;
        _sayStart = _sw.Elapsed.TotalSeconds;
        if (_boop != null) _boop.Play();
    }

    void GainXp(double amt)
    {
        _xp += amt;
        while (_xp >= _xpNeed)
        {
            _xp -= _xpNeed;
            _level++;
            _xpNeed = 120.0 * _level;
            _scale = 1.0 + Math.Min(_level - 1, 6) * 0.02;
            OnLevelUp();
        }
    }

    string TitleFor(int level)
    {
        if (Titles == null || Titles.Length == 0) return "";
        int idx = Math.Min((level - 1) / 2, Titles.Length - 1);
        return Titles[idx];
    }

    void OnLevelUp()
    {
        _lvlUpActive = true;
        _lvlUpStart = _sw.Elapsed.TotalSeconds;
        _lvlUpLevel = _level;
        if (_fanfare != null) _fanfare.Play();
        for (int i = 0; i < 18; i++)
            _sparks.Add(new Spark
            {
                x = W / 2 + _rnd.NextDouble() * 120 - 60,
                y = 70 + _rnd.NextDouble() * 40,
                vx = (_rnd.NextDouble() - 0.5) * 160,
                vy = -60 - _rnd.NextDouble() * 120,
                alpha = 1,
                size = 3 + _rnd.NextDouble() * 4,
                ci = _rnd.Next(SPARK_COLORS.Length)
            });
        SaveGame();
    }

    void BuildFanfare()
    {
        int sr = 22050;
        double[] freqs = new double[] { 523.25, 659.25, 783.99, 1046.5 };
        int nn = (int)(sr * 0.11);
        short[] s = new short[nn * 4];
        for (int k = 0; k < 4; k++)
        {
            for (int i = 0; i < nn; i++)
            {
                double t = i / (double)sr;
                double env = Math.Min(1, t / 0.005) * Math.Exp(-t * 9);
                s[k * nn + i] = (short)(Math.Sin(2 * Math.PI * freqs[k] * t) * env * 0.30 * 32767);
            }
        }
        _fanfare = MakePlayer(s, sr);
    }

    void SaveGame()
    {
        if (string.IsNullOrEmpty(SaveFile)) return;
        try { System.IO.File.WriteAllText(SaveFile, _level.ToString() + "|" + _xp.ToString("0.###", CultureInfo.InvariantCulture)); } catch { }
    }

    void LoadGame()
    {
        if (string.IsNullOrEmpty(SaveFile) || !System.IO.File.Exists(SaveFile)) return;
        try
        {
            string txt = System.IO.File.ReadAllText(SaveFile).Trim();
            int p = txt.IndexOf('|');
            if (p > 0)
            {
                int lv = int.Parse(txt.Substring(0, p), CultureInfo.InvariantCulture);
                double xp = double.Parse(txt.Substring(p + 1), CultureInfo.InvariantCulture);
                if (lv >= 1) { _level = lv; _xp = xp; _xpNeed = 120.0 * _level; }
            }
        }
        catch { }
    }

    SoundPlayer MakePlayer(short[] samples, int sr)
    {
        int n = samples.Length;
        MemoryStream ms = new MemoryStream();
        BinaryWriter bw = new BinaryWriter(ms);
        bw.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));
        bw.Write(36 + n * 2);
        bw.Write(System.Text.Encoding.ASCII.GetBytes("WAVE"));
        bw.Write(System.Text.Encoding.ASCII.GetBytes("fmt "));
        bw.Write(16); bw.Write((short)1); bw.Write((short)1); bw.Write(sr); bw.Write(sr * 2); bw.Write((short)2); bw.Write((short)16);
        bw.Write(System.Text.Encoding.ASCII.GetBytes("data")); bw.Write(n * 2);
        for (int i = 0; i < n; i++) bw.Write(samples[i]);
        bw.Flush();
        SoundPlayer sp = new SoundPlayer(new MemoryStream(ms.ToArray()));
        sp.Load();
        return sp;
    }

    void BuildBoop()
    {
        int sr = 22050; double dur = 0.14; int n = (int)(sr * dur);
        double freq = 540;
        short[] s = new short[n];
        for (int i = 0; i < n; i++)
        {
            double t = i / (double)sr;
            double env = Math.Min(1, t / 0.008) * Math.Exp(-t * 15);
            double wv = Math.Sin(2 * Math.PI * freq * t) * env * 0.30;
            s[i] = (short)(wv * 32767);
        }
        _boop = MakePlayer(s, sr);
    }

    void BuildChirp()
    {
        int sr = 22050;
        int n1 = (int)(sr * 0.09), n2 = (int)(sr * 0.12);
        short[] s = new short[n1 + n2];
        for (int i = 0; i < n1; i++)
        {
            double t = i / (double)sr;
            double env = Math.Min(1, t / 0.006) * Math.Exp(-t * 20);
            s[i] = (short)(Math.Sin(2 * Math.PI * 660 * t) * env * 0.28 * 32767);
        }
        for (int i = 0; i < n2; i++)
        {
            double t = i / (double)sr;
            double env = Math.Min(1, t / 0.006) * Math.Exp(-t * 18);
            s[n1 + i] = (short)(Math.Sin(2 * Math.PI * 880 * t) * env * 0.28 * 32767);
        }
        _chirp = MakePlayer(s, sr);
    }

    void Render()
    {
        _g.ResetTransform();
        _g.Clear(Color.Transparent);
        DrawShiba(_g);
        _g.ResetTransform();
        DrawBubble(_g);
        DrawLevelUp(_g);
        DrawSay(_g);
        DrawSparks(_g);
        DrawLevelBadge(_g);
        Push();
    }

    void DrawShiba(Graphics g)
    {
        double now = _sw.Elapsed.TotalSeconds;
        bool happy = _petTimer > 0;
        bool moving = _frameMoving;
        double breath = Math.Sin(now * 2) * 1.6;
        double moveBob = moving ? Math.Sin(_phase * 2) * (_run ? 5 : 2.5) : 0;
        float bob = (float)(breath + moveBob);
        double wig = happy ? Math.Sin((now - _petStart) * 22) * 0.12 * Math.Exp(-(now - _petStart) / 0.35) : 0;

        float shadowY = (_pose == 2) ? 192f : 176f;
        using (SolidBrush b = new SolidBrush(Color.FromArgb(64, 0, 0, 0)))
            g.FillEllipse(b, W / 2f - 70, shadowY, 140, 15);

        g.TranslateTransform(-120, -120);
        g.RotateTransform((float)(wig * 180 / Math.PI));
        g.ScaleTransform((float)_facing, 1f);
        g.TranslateTransform(120, 120);
        g.TranslateTransform(-120, -190);
        g.ScaleTransform((float)_scale, (float)_scale);
        g.TranslateTransform(120, 190);
        g.TranslateTransform(0, bob);

        // far legs (standing only)
        if (_pose == 0)
        {
            DrawLeg(g, 90, 130, _phase + Math.PI, FARLEG);
            DrawLeg(g, 170, 126, _phase + 0, FARLEG);
        }

        // tail (behind body)
        GraphicsState stt = g.Save();
        g.TranslateTransform(-56, -110);
        g.RotateTransform((float)(_tailWag * 180 / Math.PI));
        g.TranslateTransform(56, 110);
        DrawTail(g);
        g.Restore(stt);

        if (_pose == 2) DrawLieBody(g);
        else if (_pose == 1) DrawSitBody(g);
        else DrawBody(g);

        // near legs (standing only)
        if (_pose == 0)
        {
            DrawLeg(g, 80, 128, _phase + 0, ORANGE);
            DrawLeg(g, 158, 124, _phase + Math.PI, ORANGE);
        }

        // head (lowered when lying)
        float headDy = (_pose == 2) ? 20f : 0f;
        GraphicsState hs = g.Save();
        g.TranslateTransform(0, headDy);
        DrawHead(g);
        DrawFace(g, happy);
        DrawAccessories(g);
        DrawHearts(g);
        g.Restore(hs);

        if (_pose == 2) DrawZzz(g);
    }

    void DrawLeg(Graphics g, float hipX, float hipY, double phi, Color c)
    {
        float swing = _frameMoving ? (_run ? 16f : 10f) : 0f;
        float lift = _frameMoving ? (_run ? 12f : 8f) : 0f;
        double sx = Math.Sin(phi);
        float px = hipX + (float)(sx * swing);
        float py = 175f - (float)(Math.Max(0, sx) * lift);
        Pen p = new Pen(c, _frameMoving ? 9f : 10f);
        p.StartCap = LineCap.Round; p.EndCap = LineCap.Round;
        g.DrawLine(p, hipX, hipY, px, py);
        p.Dispose();
        using (SolidBrush b = new SolidBrush(c)) g.FillEllipse(b, px - 6, py - 4, 12, 9);
    }

    void DrawTail(Graphics g)
    {
        PointF[] pts = new PointF[] { new PointF(56, 110), new PointF(46, 74), new PointF(74, 54), new PointF(98, 66) };
        Pen p0 = new Pen(ORANGE_D, 15); p0.StartCap = LineCap.Round; p0.EndCap = LineCap.Round;
        g.DrawCurve(p0, pts); p0.Dispose();
        Pen p1 = new Pen(ORANGE, 11); p1.StartCap = LineCap.Round; p1.EndCap = LineCap.Round;
        g.DrawCurve(p1, pts); p1.Dispose();
        Pen p2 = new Pen(ORANGE_H, 4); p2.StartCap = LineCap.Round; p2.EndCap = LineCap.Round;
        g.DrawCurve(p2, new PointF[] { new PointF(53, 107), new PointF(44, 72), new PointF(76, 58) }); p2.Dispose();
        using (SolidBrush b = new SolidBrush(CREAM)) g.FillEllipse(b, 90, 56, 17, 17);
    }

    void DrawBody(Graphics g)
    {
        RectangleF br = new RectangleF(48, 92, 128, 80);
        FillSphere(g, br, ORANGE, ORANGE_H, 0.42f, 0.28f);
        FillSphere(g, new RectangleF(62, 126, 104, 46), CREAM, Color.White, 0.5f, 0.12f);       // belly
        FillSphere(g, new RectangleF(146, 120, 42, 44), CREAM, Color.White, 0.5f, 0.2f);        // chest
        using (Pen p = new Pen(OUTLINE, 2f)) g.DrawEllipse(p, br);
        ShadeBottom(g, br, Color.FromArgb(150, 90, 35), 70);
    }

    void DrawSitBody(Graphics g)
    {
        RectangleF br = new RectangleF(48, 90, 128, 84);
        FillSphere(g, br, ORANGE, ORANGE_H, 0.42f, 0.26f);
        FillSphere(g, new RectangleF(60, 124, 102, 48), CREAM, Color.White, 0.5f, 0.12f);       // belly
        FillSphere(g, new RectangleF(146, 118, 42, 44), CREAM, Color.White, 0.5f, 0.2f);        // chest
        // folded hind thigh + tucked paw
        FillSphere(g, new RectangleF(66, 146, 52, 30), ORANGE_D, ORANGE, 0.5f, 0.35f);
        using (SolidBrush b = new SolidBrush(CREAM)) g.FillEllipse(b, 98, 164, 15, 11);
        // front legs (straight)
        DrawLeg(g, 148, 124, 0, FARLEG);
        DrawLeg(g, 160, 122, 0, ORANGE);
        using (Pen p = new Pen(OUTLINE, 2f)) g.DrawEllipse(p, br);
        ShadeBottom(g, br, Color.FromArgb(150, 90, 35), 70);
    }

    void DrawLieBody(Graphics g)
    {
        RectangleF br = new RectangleF(40, 138, 152, 56);
        FillSphere(g, br, ORANGE, ORANGE_H, 0.42f, 0.3f);
        FillSphere(g, new RectangleF(50, 150, 120, 40), CREAM, Color.White, 0.5f, 0.15f);       // belly
        // tucked front paws
        using (SolidBrush b = new SolidBrush(ORANGE)) { g.FillEllipse(b, 150, 186, 20, 12); g.FillEllipse(b, 176, 188, 18, 11); }
        using (SolidBrush b = new SolidBrush(CREAM)) { g.FillEllipse(b, 152, 190, 14, 8); g.FillEllipse(b, 178, 192, 12, 7); }
        // folded hind
        FillSphere(g, new RectangleF(52, 176, 44, 24), ORANGE_D, ORANGE, 0.5f, 0.35f);
        using (Pen p = new Pen(OUTLINE, 2f)) g.DrawEllipse(p, br);
        ShadeBottom(g, br, Color.FromArgb(150, 90, 35), 70);
    }

    void ShadeBottom(Graphics g, RectangleF rect, Color shade, int alpha)
    {
        GraphicsPath p = new GraphicsPath();
        p.AddEllipse(rect);
        GraphicsState st = g.Save();
        g.SetClip(p);
        RectangleF r = new RectangleF(rect.X, rect.Bottom - rect.Height * 0.55f, rect.Width, rect.Height * 0.55f);
        LinearGradientBrush lb = new LinearGradientBrush(r, Color.FromArgb(0, shade), Color.FromArgb(alpha, shade), 90f);
        g.FillRectangle(lb, r);
        lb.Dispose();
        g.Restore(st);
        p.Dispose();
    }

    void Specular(Graphics g, RectangleF rect, int alpha)
    {
        using (SolidBrush b = new SolidBrush(Color.FromArgb(alpha, 255, 255, 255)))
            g.FillEllipse(b, rect);
    }

    void DrawZzz(Graphics g)
    {
        double now = _sw.Elapsed.TotalSeconds;
        Font f = new Font("Segoe UI", 12f, FontStyle.Bold);
        for (int i = 0; i < 3; i++)
        {
            double ph = (now * 0.7 + i * 0.4) % 1.0;
            float y = 62 - i * 12 - (float)(ph * 8);
            float x = 194 + i * 12;
            int a = (int)(255 * (1.0 - ph) * (0.5 + 0.5 * Math.Sin(now * 2 + i)));
            if (a < 0) a = 0;
            using (SolidBrush b = new SolidBrush(Color.FromArgb(a, 120, 130, 160)))
                g.DrawString("Z", f, b, x, y);
        }
        f.Dispose();
    }

    void DrawHead(Graphics g)
    {
        RectangleF hr = new RectangleF(132, 66, 100, 100);
        FillSphere(g, hr, ORANGE, ORANGE_H, 0.42f, 0.28f);

        // ear with twitch
        GraphicsState ste = g.Save();
        g.TranslateTransform(-178, -64);
        g.RotateTransform((float)(_earA * 180 / Math.PI));
        g.TranslateTransform(178, 64);
        PointF[] ear = new PointF[] { new PointF(178, 64), new PointF(152, 98), new PointF(204, 92) };
        using (GraphicsPath ep = new GraphicsPath())
        {
            ep.AddPolygon(ear);
            LinearGradientBrush lb = new LinearGradientBrush(ear[0], new PointF(178, 98), ORANGE, ORANGE_D);
            g.FillPath(lb, ep);
            lb.Dispose();
        }
        FillPoly(g, CREAM, new PointF[] { new PointF(180, 80), new PointF(164, 96), new PointF(198, 92) });
        using (Pen p = new Pen(OUTLINE, 2f)) g.DrawPolygon(p, ear);
        g.Restore(ste);

        // cheek (behind snout)
        FillSphere(g, new RectangleF(168, 120, 46, 40), CREAM_D, CREAM, 0.55f, 0.15f);
        // muzzle (snout)
        FillSphere(g, new RectangleF(200, 110, 40, 34), CREAM, Color.White, 0.5f, 0.2f);

        // nose
        using (SolidBrush b = new SolidBrush(DARK)) g.FillEllipse(b, 232, 122, 12, 9);
        using (SolidBrush b = new SolidBrush(Color.FromArgb(130, 95, 80))) g.FillEllipse(b, 234, 123, 4, 3);

        using (Pen p = new Pen(OUTLINE, 2.2f)) g.DrawEllipse(p, hr);
        ShadeBottom(g, hr, Color.FromArgb(150, 90, 35), 60);
        Specular(g, new RectangleF(146, 80, 30, 16), 70);
    }

    void DrawFace(Graphics g, bool happy)
    {
        // urajiro eyebrow
        using (SolidBrush b = new SolidBrush(CREAM)) g.FillEllipse(b, 182, 88, 24, 9);

        // big anime eye
        DrawEyeAnime(g, 190, 110, 26, 24, happy);

        // mouth
        Pen mp = new Pen(DARK, 2); mp.StartCap = LineCap.Round; mp.EndCap = LineCap.Round;
        g.DrawCurve(mp, new PointF[] { new PointF(238, 130), new PointF(230, 138), new PointF(220, 132) });
        mp.Dispose();

        // soft anime blush
        double blush = happy ? 1.0 : 0.22;
        int ba = (int)(165 * blush);
        if (ba > 0)
        {
            RectangleF br = new RectangleF(194, 124, 28, 16);
            GraphicsPath bp = new GraphicsPath();
            bp.AddEllipse(br);
            PathGradientBrush pg = new PathGradientBrush(bp);
            pg.CenterColor = Color.FromArgb(ba, 255, 120, 145);
            pg.SurroundColors = new Color[] { Color.FromArgb(0, 255, 120, 145) };
            pg.CenterPoint = new PointF(br.X + br.Width * 0.5f, br.Y + br.Height * 0.5f);
            g.FillPath(pg, bp);
            pg.Dispose(); bp.Dispose();
        }
    }

    void DrawEyeAnime(Graphics g, float cx, float cy, float w, float h, bool happy)
    {
        if (_pose == 2)
        {
            Pen ep = new Pen(OUTLINE, 2.5f); ep.StartCap = LineCap.Round; ep.EndCap = LineCap.Round;
            g.DrawArc(ep, cx - w * 0.4f, cy - h * 0.1f, w * 0.8f, h * 0.55f, 0, 180);
            ep.Dispose();
            return;
        }
        if (happy)
        {
            Pen ep = new Pen(OUTLINE, 3f); ep.StartCap = LineCap.Round; ep.EndCap = LineCap.Round;
            g.DrawLine(ep, cx - w * 0.75f, cy + h * 0.5f, cx, cy - h * 0.55f);
            g.DrawLine(ep, cx, cy - h * 0.55f, cx + w * 0.75f, cy + h * 0.5f);
            ep.Dispose();
            return;
        }
        if (_blink <= 0.15)
        {
            Pen ep = new Pen(OUTLINE, 2.5f); ep.StartCap = LineCap.Round; ep.EndCap = LineCap.Round;
            g.DrawLine(ep, cx - w * 0.6f, cy, cx + w * 0.6f, cy);
            ep.Dispose();
            return;
        }
        float eh = h * (float)_blink;
        GraphicsPath epath = new GraphicsPath();
        epath.AddEllipse(cx - w / 2, cy - eh / 2, w, eh);
        PathGradientBrush ib = new PathGradientBrush(epath);
        ib.CenterColor = Color.FromArgb(122, 64, 34);
        ib.SurroundColors = new Color[] { Color.FromArgb(38, 22, 12) };
        ib.CenterPoint = new PointF(cx, cy - eh * 0.25f);
        g.FillPath(ib, epath);
        ib.Dispose();
        using (SolidBrush b = new SolidBrush(Color.FromArgb(18, 10, 6)))
            g.FillEllipse(b, cx - w * 0.16f, cy - eh * 0.1f, w * 0.34f, eh * 0.55f);
        using (SolidBrush b = new SolidBrush(Color.White))
        {
            g.FillEllipse(b, cx - w * 0.3f, cy - eh * 0.42f, w * 0.26f, w * 0.26f);
            g.FillEllipse(b, cx + w * 0.08f, cy + eh * 0.18f, w * 0.15f, w * 0.15f);
        }
        using (Pen p = new Pen(OUTLINE, 2.4f)) g.DrawEllipse(p, cx - w / 2, cy - eh / 2, w, eh);
        using (Pen p = new Pen(OUTLINE, 2.2f)) g.DrawArc(p, cx - w * 0.62f, cy - eh * 0.62f, w * 1.24f, eh * 0.85f, 195, 150);
        epath.Dispose();
    }

    void FillSphere(Graphics g, RectangleF rect, Color baseC, Color hi, float cxOff, float cyOff)
    {
        GraphicsPath p = new GraphicsPath();
        p.AddEllipse(rect);
        PathGradientBrush br = new PathGradientBrush(p);
        br.CenterColor = hi;
        br.SurroundColors = new Color[] { baseC };
        br.CenterPoint = new PointF(rect.X + rect.Width * cxOff, rect.Y + rect.Height * cyOff);
        g.FillPath(br, p);
        br.Dispose();
        p.Dispose();
    }

    void DrawAccessories(Graphics g)
    {
        if (_level >= 2)
        {
            // collar
            Pen cp = new Pen(Color.FromArgb(205, 62, 62), 5f); cp.StartCap = LineCap.Round; cp.EndCap = LineCap.Round;
            g.DrawLine(cp, 152, 128, 176, 120);
            cp.Dispose();
            using (SolidBrush b = new SolidBrush(Color.FromArgb(230, 190, 60))) g.FillEllipse(b, 170, 116, 6, 6);
        }
        if (_level >= 4)
        {
            // bow
            Color bow = Color.FromArgb(255, 110, 150);
            FillPoly(g, bow, new PointF[] { new PointF(170, 122), new PointF(160, 116), new PointF(160, 130) });
            FillPoly(g, bow, new PointF[] { new PointF(170, 122), new PointF(180, 116), new PointF(180, 130) });
            using (SolidBrush b = new SolidBrush(Color.FromArgb(255, 170, 200))) g.FillEllipse(b, 167, 119, 6, 6);
        }
        if (_level >= 6)
        {
            // crown
            Color gold = Color.FromArgb(255, 202, 40);
            FillPoly(g, gold, new PointF[] { new PointF(166, 62), new PointF(166, 52), new PointF(173, 58), new PointF(180, 52), new PointF(187, 58), new PointF(190, 52), new PointF(190, 62) });
            using (SolidBrush b = new SolidBrush(Color.FromArgb(230, 70, 80))) g.FillEllipse(b, 176, 56, 4, 4);
        }
    }

    void DrawHearts(Graphics g)
    {
        for (int i = _hearts.Count - 1; i >= 0; i--)
        {
            Heart h = _hearts[i];
            if (h.alpha <= 0) continue;
            float hx = (float)(182 + h.dx);
            float hy = (float)h.y;
            float s = (float)(8 * h.scale);
            int a = (int)(255 * Math.Min(1, h.alpha));
            Color c = Color.FromArgb(a, HEART);
            using (SolidBrush b = new SolidBrush(c))
            {
                g.FillEllipse(b, hx - s, hy - s * 0.3f, s, s);
                g.FillEllipse(b, hx, hy - s * 0.3f, s, s);
                g.FillPolygon(b, new PointF[] { new PointF(hx - s, hy - s * 0.3f), new PointF(hx + s, hy - s * 0.3f), new PointF(hx, hy + s) });
            }
            using (SolidBrush w = new SolidBrush(Color.FromArgb(a, 255, 255, 255)))
                g.FillEllipse(w, hx - s * 0.55f, hy - s * 0.1f, s * 0.3f, s * 0.3f);
        }
    }

    void FillPoly(Graphics g, Color c, PointF[] pts) { using (SolidBrush b = new SolidBrush(c)) g.FillPolygon(b, pts); }

    void DrawBubble(Graphics g)
    {
        if (!_remindActive) return;
        double now = _sw.Elapsed.TotalSeconds;
        double t = now - _remindStart;
        double dur = 6.0;
        if (t < 0 || t >= dur) return;
        double alpha = 1.0;
        if (t < 0.25) alpha = t / 0.25;
        else if (t > dur - 1.0) alpha = Math.Max(0, (dur - t) / 1.0);
        int A = (int)(255 * alpha);

        float bw = 224, bh = 54;
        float bx = W / 2f - bw / 2f;
        float by = 4f;

        using (GraphicsPath gp = RoundRect(bx, by, bw, bh, 16))
        {
            using (SolidBrush fb = new SolidBrush(Color.FromArgb(A, 255, 255, 255))) g.FillPath(fb, gp);
            using (Pen pn = new Pen(Color.FromArgb(A, 130, 90, 40), 2f)) g.DrawPath(pn, gp);
        }
        using (SolidBrush tb = new SolidBrush(Color.FromArgb(A, 255, 255, 255)))
            g.FillPolygon(tb, new PointF[] { new PointF(W / 2f - 9, by + bh - 3), new PointF(W / 2f + 9, by + bh - 3), new PointF(W / 2f, by + bh + 12) });

        using (Font f = new Font("Microsoft YaHei", 12f, FontStyle.Bold))
        using (SolidBrush tb = new SolidBrush(Color.FromArgb(A, 60, 40, 25)))
        {
            StringFormat sf = new StringFormat();
            sf.Alignment = StringAlignment.Center;
            sf.LineAlignment = StringAlignment.Center;
            g.DrawString(ReminderText, f, tb, new RectangleF(bx + 8, by + 4, bw - 16, bh - 8), sf);
        }
    }

    void DrawSay(Graphics g)
    {
        if (!_sayActive) return;
        double t = _sw.Elapsed.TotalSeconds - _sayStart;
        double dur = 2.6;
        if (t < 0 || t >= dur) return;
        double alpha = 1.0;
        if (t < 0.15) alpha = t / 0.15;
        else if (t > dur - 0.5) alpha = Math.Max(0, (dur - t) / 0.5);
        int A = (int)(255 * alpha);

        float bw = 150, bh = 32;
        float bx = W / 2f - bw / 2f;
        float by = 28f;

        using (GraphicsPath gp = RoundRect(bx, by, bw, bh, 14))
        {
            using (SolidBrush fb = new SolidBrush(Color.FromArgb(A, 255, 255, 255))) g.FillPath(fb, gp);
            using (Pen pn = new Pen(Color.FromArgb(A, 130, 90, 40), 1.5f)) g.DrawPath(pn, gp);
        }
        using (SolidBrush tb = new SolidBrush(Color.FromArgb(A, 255, 255, 255)))
            g.FillPolygon(tb, new PointF[] { new PointF(W / 2f - 7, by + bh - 2), new PointF(W / 2f + 7, by + bh - 2), new PointF(W / 2f, by + bh + 10) });

        using (Font f = new Font("Microsoft YaHei", 11f, FontStyle.Bold))
        using (SolidBrush tb = new SolidBrush(Color.FromArgb(A, 60, 40, 25)))
        {
            StringFormat sf = new StringFormat();
            sf.Alignment = StringAlignment.Center;
            sf.LineAlignment = StringAlignment.Center;
            g.DrawString(_sayText, f, tb, new RectangleF(bx + 4, by + 2, bw - 8, bh - 4), sf);
        }
    }

    void DrawLevelBadge(Graphics g)
    {
        string title = TitleFor(_level);
        string s = "Lv." + _level + (title.Length > 0 ? " " + title : "");
        Font f = new Font("Microsoft YaHei", 10f, FontStyle.Bold);
        SizeF sz = g.MeasureString(s, f);
        float w = sz.Width + 16, h = 20;
        float x = 5, y = 4;
        using (GraphicsPath gp = RoundRect(x, y, w, h, 10))
        {
            using (SolidBrush b = new SolidBrush(Color.FromArgb(235, 255, 240, 120))) g.FillPath(b, gp);
            using (Pen p = new Pen(Color.FromArgb(235, 190, 130, 20), 1.5f)) g.DrawPath(p, gp);
        }
        using (SolidBrush b = new SolidBrush(Color.FromArgb(130, 85, 20)))
            g.DrawString(s, f, b, x + 8, y + 3);

        // XP progress bar
        float barW = w, barH = 4f;
        float barX = x, barY = y + h + 3f;
        float frac = (float)Math.Min(1.0, _xp / _xpNeed);
        using (SolidBrush bg = new SolidBrush(Color.FromArgb(140, 120, 90, 50))) g.FillRectangle(bg, barX, barY, barW, barH);
        using (SolidBrush fg = new SolidBrush(Color.FromArgb(240, 255, 180, 40))) g.FillRectangle(fg, barX, barY, barW * frac, barH);
        f.Dispose();
    }

    void DrawLevelUp(Graphics g)
    {
        if (!_lvlUpActive) return;
        double t = _sw.Elapsed.TotalSeconds - _lvlUpStart;
        double dur = 3.0;
        if (t < 0 || t >= dur) return;
        double alpha = 1.0;
        if (t < 0.2) alpha = t / 0.2;
        else if (t > dur - 0.6) alpha = Math.Max(0, (dur - t) / 0.6);
        int A = (int)(255 * alpha);

        string s = LevelUpText + " Lv." + _lvlUpLevel;
        string ttl = TitleFor(_lvlUpLevel);
        if (ttl.Length > 0) s = s + "  " + ttl;
        Font f = new Font("Microsoft YaHei", 15f, FontStyle.Bold);
        SizeF sz = g.MeasureString(s, f);
        float bw = sz.Width + 26, bh = 42;
        float bx = W / 2f - bw / 2f, by = 6f;
        using (GraphicsPath gp = RoundRect(bx, by, bw, bh, 20))
        {
            using (SolidBrush b = new SolidBrush(Color.FromArgb(A, 255, 240, 150))) g.FillPath(b, gp);
            using (Pen p = new Pen(Color.FromArgb(A, 205, 140, 20), 2.5f)) g.DrawPath(p, gp);
        }
        using (SolidBrush b = new SolidBrush(Color.FromArgb(A, 150, 85, 10)))
        {
            StringFormat sf = new StringFormat();
            sf.Alignment = StringAlignment.Center;
            sf.LineAlignment = StringAlignment.Center;
            g.DrawString(s, f, b, new RectangleF(bx, by + 2, bw, bh - 4), sf);
        }
        f.Dispose();
    }

    void DrawSparks(Graphics g)
    {
        for (int i = _sparks.Count - 1; i >= 0; i--)
        {
            Spark sp = _sparks[i];
            int a = (int)(255 * Math.Min(1, sp.alpha));
            if (a <= 0) continue;
            Color c = Color.FromArgb(a, SPARK_COLORS[sp.ci]);
            float s = (float)sp.size;
            using (SolidBrush b = new SolidBrush(c))
                g.FillPolygon(b, new PointF[] {
                    new PointF((float)sp.x, (float)sp.y - s),
                    new PointF((float)sp.x + s * 0.6f, (float)sp.y),
                    new PointF((float)sp.x, (float)sp.y + s),
                    new PointF((float)sp.x - s * 0.6f, (float)sp.y) });
        }
    }

    GraphicsPath RoundRect(float x, float y, float w, float h, float r)
    {
        GraphicsPath p = new GraphicsPath();
        float d = r * 2;
        p.AddArc(x, y, d, d, 180, 90);
        p.AddArc(x + w - d, y, d, d, 270, 90);
        p.AddArc(x + w - d, y + h - d, d, d, 0, 90);
        p.AddArc(x, y + h - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    void Push()
    {
        IntPtr hwnd = Handle;
        int ex = GetWindowLong(hwnd, GWL_EXSTYLE);
        if ((ex & WS_EX_LAYERED) == 0) SetWindowLong(hwnd, GWL_EXSTYLE, ex | WS_EX_LAYERED);

        Rectangle rect = new Rectangle(0, 0, W, H);
        BitmapData bd = _bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int bytes = bd.Stride * H;
        byte[] src = new byte[bytes];
        Marshal.Copy(bd.Scan0, src, 0, bytes);
        _bmp.UnlockBits(bd);

        for (int i = 0; i < bytes; i += 4)
        {
            byte a = src[i + 3];
            if (a == 0) { src[i] = 0; src[i + 1] = 0; src[i + 2] = 0; }
            else { src[i] = (byte)(src[i] * a / 255); src[i + 1] = (byte)(src[i + 1] * a / 255); src[i + 2] = (byte)(src[i + 2] * a / 255); }
        }

        BITMAPINFO bmi = new BITMAPINFO();
        bmi.bmiHeader = new BITMAPINFOHEADER();
        bmi.bmiHeader.biSize = (uint)Marshal.SizeOf(typeof(BITMAPINFOHEADER));
        bmi.bmiHeader.biWidth = W;
        bmi.bmiHeader.biHeight = -H;
        bmi.bmiHeader.biPlanes = 1;
        bmi.bmiHeader.biBitCount = 32;
        bmi.bmiHeader.biCompression = BI_RGB;

        IntPtr bits;
        IntPtr hdcScreen = GetDC(IntPtr.Zero);
        IntPtr hBmp = CreateDIBSection(hdcScreen, ref bmi, 0, out bits, IntPtr.Zero, 0);
        Marshal.Copy(src, 0, bits, bytes);
        IntPtr memDc = CreateCompatibleDC(hdcScreen);
        IntPtr hOld = SelectObject(memDc, hBmp);
        SZ sz = new SZ { cx = W, cy = H };
        PT ps = new PT { x = 0, y = 0 };
        PT loc = new PT { x = Location.X, y = Location.Y };
        BF bf = new BF { BlendOp = AC_SRC_OVER, BlendFlags = 0, SourceConstantAlpha = 255, AlphaFormat = AC_SRC_ALPHA };
        UpdateLayeredWindow(hwnd, hdcScreen, ref loc, ref sz, memDc, ref ps, 0, ref bf, ULW_ALPHA);
        SelectObject(memDc, hOld);
        DeleteObject(hBmp);
        DeleteDC(memDc);
        ReleaseDC(IntPtr.Zero, hdcScreen);
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button != MouseButtons.Left) return;
        float hx0 = _facing > 0 ? 182 : (W - 182);
        double dx = e.X - hx0, dy = e.Y - 116;
        if (dx * dx + dy * dy < 54 * 54) Pet();
        else
        {
            _dragging = true;
            _mode = 0;
            _airborne = false;
            _flingVX = 0; _flingVY = 0;
            Point mp = Control.MousePosition;
            _lastMove = mp;
            _lastMoveTime = _sw.Elapsed.TotalSeconds;
            _dragOffset = new Point(mp.X - Location.X, mp.Y - Location.Y);
        }
    }
    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        if (_dragging)
        {
            Point mp = Control.MousePosition;
            double now = _sw.Elapsed.TotalSeconds;
            double dt2 = now - _lastMoveTime; if (dt2 <= 0) dt2 = 0.016;
            double vx = (mp.X - _lastMove.X) / dt2;
            double vy = (mp.Y - _lastMove.Y) / dt2;
            _flingVX = _flingVX * 0.7 + vx * 0.3;
            _flingVY = _flingVY * 0.7 + vy * 0.3;
            _lastMove = mp;
            _lastMoveTime = now;
            Location = new Point(mp.X - _dragOffset.X, mp.Y - _dragOffset.Y);
            _pos = new PointF(Location.X, Location.Y);
        }
    }
    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        _dragging = false;
        if (Math.Abs(_flingVY) > 200)
        {
            _airborne = true;
            _vx = _flingVX;
            _vy = _flingVY;
            _facing = _vx > 0 ? 1 : -1;
            _mode = 0;
        }
        else
        {
            _modeTimer = 1.0;
        }
    }
    protected override void OnFormClosed(FormClosedEventArgs e) { base.OnFormClosed(e); SaveGame(); }
}
'@
        Add-Type -TypeDefinition $src -ReferencedAssemblies System.Windows.Forms,System.Drawing -Language CSharp
    }
    catch {
        try { [System.Windows.Forms.MessageBox]::Show("Shiba pet failed to start:`r`n" + $_.Exception.Message, "Shiba") } catch { }
        return
    }

    $log = Join-Path $PSScriptRoot 'shiba_error.log'
    if (Test-Path $log) { Remove-Item $log -Force }
    $onThread = [System.Threading.ThreadExceptionEventHandler]{
        param($s, $e)
        try { ($e.Exception | Out-String) | Out-File -FilePath $log -Append -Encoding utf8 } catch {}
        [System.Windows.Forms.Application]::Exit()
    }
    [System.Windows.Forms.Application]::add_ThreadException($onThread)
    $onDom = [System.UnhandledExceptionEventHandler]{
        param($s, $e)
        try { ($e.ExceptionObject | Out-String) | Out-File -FilePath $log -Append -Encoding utf8 } catch {}
    }
    [System.AppDomain]::CurrentDomain.add_UnhandledException($onDom)

    $form = New-Object ShibaForm
    # Chinese menu labels via code points (keeps the .ps1 ASCII / encoding-proof)
    $form.ContextMenuStrip.Items[0].Text = [string]::new([char[]](0x6478,0x6478,0x5934))   # pet head
    $form.ContextMenuStrip.Items[1].Text = [string]::new([char[]](0x8BF4,0x53E5,0x8BDD))   # say something
    $form.ContextMenuStrip.Items[2].Text = [string]::new([char[]](0x8D70,0x4E00,0x8D70))   # take a walk
    $form.ContextMenuStrip.Items[3].Text = [string]::new([char[]](0x5750,0x4E0B))          # sit
    $form.ContextMenuStrip.Items[4].Text = [string]::new([char[]](0x7761,0x89C9))          # sleep
    $form.ContextMenuStrip.Items[5].Text = [string]::new([char[]](0x7AD9,0x8D77))          # stand
    $form.ContextMenuStrip.Items[7].Text = [string]::new([char[]](0x9000,0x51FA))          # exit
    # Random speech bubbles while idle
    $form.Sayings = [string[]]@(
        [string]::new([char[]](0x6C6A,0x7E)),
        [string]::new([char[]](0x6478,0x6211,0x5440,0x7E)),
        [string]::new([char[]](0x597D,0x65E0,0x804A,0x7E)),
        [string]::new([char[]](0x966A,0x4F60,0x52A0,0x73ED,0x7E)),
        [string]::new([char[]](0x563F,0x563F,0x7E))
    )
    # Screen-time reminder: message + interval (minutes)
    $form.ReminderText = [string]::new([char[]](0x76EF,0x5C4F,0x5E55,0x592A,0x4E45,0x5566,0xFF0C,0x770B,0x770B,0x8FDC,0x5904,0x5427,0x7E))
    $form.RemindMinutes = 20
    # Leveling system: save file + level-up text + rank titles
    $form.SaveFile = Join-Path $PSScriptRoot 'shiba_save.txt'
    $form.LevelUpText = [string]::new([char[]](0x5347,0x7EA7,0x5566,0xFF01))
    $form.Titles = [string[]]@(
        [string]::new([char[]](0x5E7C,0x72AC)),
        [string]::new([char[]](0x5C11,0x5E74,0x67F4)),
        [string]::new([char[]](0x6210,0x72AC)),
        [string]::new([char[]](0x67F4,0x72AC,0x4FA0)),
        [string]::new([char[]](0x67F4,0x795E))
    )
    [System.Windows.Forms.Application]::Run($form)
