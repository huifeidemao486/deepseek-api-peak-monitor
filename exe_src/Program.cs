using System;
using System.Drawing;
using System.IO;
using System.Media;
using System.Text;
using System.Windows.Forms;

namespace DeepSeekPeakMonitor
{
    static class Core
    {
        // ============ 可配置项（改这里后重新运行 build_exe.bat 即可） ============
        public const double PeakPrice = 0.28;      // 高峰涨价时段单价（元/千 tokens）
        public const double OffPeakPrice = 0.08;   // 空闲低价时段单价（元/千 tokens）
        public const int WarnMinutes = 10;         // 进入高峰前预警提前量（分钟）
        // 高峰时段（北京时间）：09:00-12:00、14:00-18:00
        // =======================================================================

        public static DateTime BJNow()
        {
            return DateTime.UtcNow.AddHours(8);
        }

        public static bool IsPeak(DateTime dt)
        {
            TimeSpan t = dt.TimeOfDay;
            return (t >= TimeSpan.FromHours(9) && t < TimeSpan.FromHours(12)) ||
                   (t >= TimeSpan.FromHours(14) && t < TimeSpan.FromHours(18));
        }

        public static DateTime NextSwitch(DateTime dt, out bool enterPeak)
        {
            DateTime best = DateTime.MaxValue;
            foreach (int h in new int[] { 9, 12, 14, 18 })
            {
                DateTime b = new DateTime(dt.Year, dt.Month, dt.Day, h, 0, 0);
                if (b <= dt) b = b.AddDays(1);
                if (b < best) best = b;
            }
            enterPeak = IsPeak(best);
            return best;
        }
    }

    class MainForm : Form
    {
        private static readonly Color C_BG     = Color.FromArgb(30, 31, 36);
        private static readonly Color C_FG     = Color.FromArgb(232, 232, 236);
        private static readonly Color C_PEAK   = Color.FromArgb(255, 77, 79);
        private static readonly Color C_OFF    = Color.FromArgb(61, 220, 132);
        private static readonly Color C_ACCENT = Color.FromArgb(240, 160, 32);
        private static readonly Color C_HDR    = Color.FromArgb(44, 45, 52);
        private static readonly Color C_ROW1   = Color.FromArgb(35, 36, 41);
        private static readonly Color C_ROW2   = Color.FromArgb(41, 42, 48);
        private static readonly Color C_MUTED  = Color.FromArgb(154, 154, 165);
        private static readonly Color C_WARNBG = Color.FromArgb(58, 31, 34);
        private static readonly Color C_WARNFG = Color.FromArgb(255, 120, 117);

        private System.Windows.Forms.Timer _timer;
        private Label _lblTime, _lblStatus, _lblCount;
        private DateTime? _lastWarn;

        public MainForm()
        {
            Text = "DeepSeek-V4-Flash 错峰定价提醒器";
            ClientSize = new Size(500, 400);
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = C_BG;
            Font = new Font("Microsoft YaHei UI", 10F);

            BuildUi();

            _timer = new System.Windows.Forms.Timer();
            _timer.Interval = 200;
            _timer.Tick += delegate { UpdateUI(); };
            Shown += delegate { _timer.Start(); UpdateUI(); };
            FormClosed += delegate { _timer.Stop(); };
        }

        private Label MakeLabel(string text, int x, int y, int w, int h,
                                Color bg, Color fg, Font font, ContentAlignment align)
        {
            Label l = new Label();
            l.Text = text;
            l.SetBounds(x, y, w, h);
            l.BackColor = bg;
            l.ForeColor = fg;
            l.Font = font;
            l.TextAlign = align;
            l.AutoSize = false;
            Controls.Add(l);
            return l;
        }

        private void BuildUi()
        {
            Font fTitle  = new Font("Microsoft YaHei UI", 14F, FontStyle.Bold);
            Font fTime   = new Font("Consolas", 42F, FontStyle.Bold);
            Font fStatus = new Font("Microsoft YaHei UI", 16F, FontStyle.Bold);
            Font fCount  = new Font("Consolas", 13F);
            Font fSmall  = new Font("Microsoft YaHei UI", 10F);
            Font fTiny   = new Font("Microsoft YaHei UI", 9F);
            Font fHdr    = new Font("Microsoft YaHei UI", 10F, FontStyle.Bold);

            MakeLabel("DeepSeek-V4-Flash 错峰定价监控", 0, 10, 500, 30, C_BG, C_FG, fTitle, ContentAlignment.MiddleCenter);

            _lblTime = MakeLabel("--:--:--", 0, 42, 500, 62, C_BG, C_FG, fTime, ContentAlignment.MiddleCenter);

            _lblStatus = MakeLabel("● 空闲低价时段", 0, 108, 500, 36, C_BG, C_OFF, fStatus, ContentAlignment.MiddleCenter);

            _lblCount = MakeLabel("距下次切换 --:--:--", 0, 150, 500, 28, C_BG, C_FG, fCount, ContentAlignment.MiddleCenter);

            MakeLabel("价格对照表（元 / 千 tokens）", 0, 192, 500, 24, C_BG, C_ACCENT, fSmall, ContentAlignment.MiddleCenter);

            string[] headers = new string[] { "时段", "时间范围", "单价", "备注" };
            int[] widths = new int[] { 100, 190, 110, 100 };
            int x = 0;
            for (int i = 0; i < headers.Length; i++)
            {
                MakeLabel(headers[i], x, 220, widths[i], 28, C_HDR, C_FG, fHdr, ContentAlignment.MiddleLeft);
                x += widths[i];
            }

            string[][] rows = new string[][]
            {
                new string[] { "高峰涨价", "09:00-12:00、14:00-18:00", Core.PeakPrice.ToString("0.00"), "排队慢" },
                new string[] { "空闲低价", "其余全部时间", Core.OffPeakPrice.ToString("0.00"), "响应快" }
            };
            int y = 250;
            for (int r = 0; r < rows.Length; r++)
            {
                Color bg = (r % 2 == 0) ? C_ROW1 : C_ROW2;
                x = 0;
                for (int c = 0; c < widths.Length; c++)
                {
                    Color fg = (c == 0) ? (r == 0 ? C_PEAK : C_OFF) : C_FG;
                    MakeLabel(rows[r][c], x, y, widths[c], 28, bg, fg, fSmall, ContentAlignment.MiddleLeft);
                    x += widths[c];
                }
                y += 28;
            }

            MakeLabel("一天时间轴: 00:00 低价 | 09:00 高峰 | 12:00 低价 | 14:00 高峰 | 18:00 低价",
                      0, 322, 500, 24, C_BG, C_MUTED, fTiny, ContentAlignment.MiddleCenter);
            MakeLabel("规则自 8月17日 起适用（北京时间）· 价格可在源码顶部修改",
                      0, 348, 500, 22, C_BG, C_MUTED, fTiny, ContentAlignment.MiddleCenter);
        }

        private void UpdateUI()
        {
            DateTime now = Core.BJNow();
            bool peak = Core.IsPeak(now);
            bool enterPeak;
            DateTime boundary = Core.NextSwitch(now, out enterPeak);

            _lblTime.Text = now.ToString("HH:mm:ss");

            if (peak)
            {
                _lblStatus.Text = "● 高峰涨价时段";
                _lblStatus.ForeColor = C_PEAK;
            }
            else
            {
                _lblStatus.Text = "● 空闲低价时段";
                _lblStatus.ForeColor = C_OFF;
            }

            TimeSpan span = boundary - now;
            int total = (int)span.TotalSeconds;
            int h = total / 3600;
            int m = (total % 3600) / 60;
            int s = total % 60;
            string what = enterPeak ? "进入高峰涨价" : "进入空闲低价";
            _lblCount.Text = String.Format("距下次切换 {0:00}:{1:00}:{2:00}  （{3:HH:mm} {4}）",
                                           h, m, s, boundary, what);

            if (!peak && enterPeak && span.TotalMinutes <= Core.WarnMinutes)
            {
                if (_lastWarn != boundary)
                {
                    _lastWarn = boundary;
                    ShowWarning(boundary);
                }
            }
            else
            {
                _lastWarn = null;
            }
        }

        private void ShowWarning(DateTime boundary)
        {
            string seg = (boundary.Hour == 9) ? "09:00-12:00" : "14:00-18:00";

            Form w = new Form();
            w.Text = "高峰预警";
            w.ClientSize = new Size(400, 235);
            w.FormBorderStyle = FormBorderStyle.FixedDialog;
            w.StartPosition = FormStartPosition.CenterScreen;
            w.TopMost = true;
            w.ControlBox = false;
            w.BackColor = C_WARNBG;
            w.Font = new Font("Microsoft YaHei UI", 10F);

            Label l1 = new Label();
            l1.Text = "⚠ 即将进入高峰涨价时段";
            l1.Font = new Font("Microsoft YaHei UI", 16F, FontStyle.Bold);
            l1.ForeColor = C_WARNFG;
            l1.BackColor = C_WARNBG;
            l1.TextAlign = ContentAlignment.MiddleCenter;
            l1.AutoSize = false;
            l1.SetBounds(0, 16, 400, 34);

            string msg = String.Format(
                "距离 {0:HH:mm} 进入高峰时段（{1}）\n还有不到 {2} 分钟。\n如计划调用 DeepSeek-V4-Flash，请提前安排，\n或等高峰结束后再执行批量任务。",
                boundary, seg, Core.WarnMinutes);
            Label l2 = new Label();
            l2.Text = msg;
            l2.Font = new Font("Microsoft YaHei UI", 11F);
            l2.ForeColor = C_FG;
            l2.BackColor = C_WARNBG;
            l2.TextAlign = ContentAlignment.MiddleCenter;
            l2.AutoSize = false;
            l2.SetBounds(16, 54, 368, 108);

            Button btn = new Button();
            btn.Text = "知道了";
            btn.Font = new Font("Microsoft YaHei UI", 11F);
            btn.BackColor = C_PEAK;
            btn.ForeColor = Color.White;
            btn.FlatStyle = FlatStyle.Flat;
            btn.SetBounds(150, 176, 100, 38);
            btn.Click += delegate { w.Close(); };

            w.Controls.Add(l1);
            w.Controls.Add(l2);
            w.Controls.Add(btn);

            SystemSounds.Exclamation.Play();

            System.Windows.Forms.Timer auto = new System.Windows.Forms.Timer();
            auto.Interval = 60000;
            auto.Tick += delegate(object s, EventArgs e2)
            {
                ((System.Windows.Forms.Timer)s).Stop();
                w.Close();
            };
            auto.Start();

            w.Show();
        }
    }

    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            if (Array.IndexOf(args, "--selftest") >= 0)
            {
                string log = Path.Combine(Path.GetTempPath(), "DeepSeekPeakMonitor_selftest.txt");
                Environment.Exit(SelfTest(log));
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            try
            {
                Application.Run(new MainForm());
            }
            catch (Exception ex)
            {
                string msg = ex.GetType().FullName + ": " + ex.Message + "\r\n\r\n" + ex.StackTrace;
                try
                {
                    string log = Path.Combine(Path.GetTempPath(), "DeepSeekPeakMonitor_error.log");
                    File.WriteAllText(log, msg, new UTF8Encoding(true));
                }
                catch { }
                MessageBox.Show(msg, "DeepSeek-V4-Flash 提醒器错误",
                                MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private static int SelfTest(string logPath)
        {
            var sb = new StringBuilder();
            sb.AppendLine("DeepSeek-V4-Flash 提醒器自检 " +
                          Core.BJNow().ToString("yyyy-MM-dd HH:mm:ss") + " (北京时间)");
            sb.AppendLine();
            sb.AppendLine("时段判定自检:");
            int fail = 0;

            int[] hours = new int[] { 0, 8, 9, 11, 12, 13, 14, 17, 18, 23 };
            string[] expect = new string[] { "低价", "低价", "高峰", "高峰", "低价", "低价", "高峰", "高峰", "低价", "低价" };
            DateTime today = Core.BJNow().Date;
            for (int i = 0; i < hours.Length; i++)
            {
                bool peak = Core.IsPeak(today.AddHours(hours[i]));
                string got = peak ? "高峰" : "低价";
                bool ok = got == expect[i];
                if (!ok) fail++;
                sb.AppendLine(String.Format("  {0:00}:00  判定={1}  期望={2}  [{3}]",
                                            hours[i], got, expect[i], ok ? "OK" : "!! 不符"));
            }

            sb.AppendLine();
            sb.AppendLine("下一切换点自检:");
            int[,] sw = new int[,]
            {
                { 8, 30, 0, 9,  1 },  // 08:30 -> 当天09:00 进入高峰
                { 11, 0, 0, 12, 0 },  // 11:00 -> 当天12:00 进入低价
                { 13, 0, 0, 14, 1 },  // 13:00 -> 当天14:00 进入高峰
                { 16, 0, 0, 18, 0 },  // 16:00 -> 当天18:00 进入低价
                { 20, 0, 1, 9,  1 },  // 20:00 -> 次日09:00 进入高峰
                { 23, 59, 1, 9, 1 }   // 23:59 -> 次日09:00 进入高峰
            };
            for (int i = 0; i < sw.GetLength(0); i++)
            {
                DateTime dt = today.AddHours(sw[i, 0]).AddMinutes(sw[i, 1]);
                bool ep;
                DateTime b = Core.NextSwitch(dt, out ep);
                DateTime exp = today.AddDays(sw[i, 2]).AddHours(sw[i, 3]);
                bool ok = (b == exp) && (ep == (sw[i, 4] == 1));
                if (!ok) fail++;
                sb.AppendLine(String.Format(
                    "  {0:00}:{1:00}  下一切换={2:MM-dd HH:mm} 进入{3}  期望={4:MM-dd HH:mm} 进入{5}  [{6}]",
                    sw[i, 0], sw[i, 1], b, ep ? "高峰" : "低价",
                    exp, sw[i, 4] == 1 ? "高峰" : "低价", ok ? "OK" : "!! 不符"));
            }

            sb.AppendLine();
            sb.AppendLine(fail == 0 ? "自检结果: 全部通过，规则实现正确。" :
                                       String.Format("自检结果: {0} 项不符，请检查配置。", fail));
            File.WriteAllText(logPath, sb.ToString(), new UTF8Encoding(true));
            return fail == 0 ? 0 : 1;
        }
    }
}
