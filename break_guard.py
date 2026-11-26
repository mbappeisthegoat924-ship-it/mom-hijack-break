import time
import ctypes
import tkinter as tk
from tkinter import font as tkfont

try:
    from water_check import get_water_advice
except ImportError:
    def get_water_advice(glasses, break_num):
        if glasses >= 15:
            return "You have done well preserving your life!"
        elif glasses < break_num * 1.4:
            return "Drink 2 glasses of water this break to catch up!"
        return "Drink 1 glass of water to stay on track!"

# Normal work schedule settings
WORK_INTERVAL_SECONDS = 60 * 60  # 1 hour (3600 seconds)
BREAK_DURATION_SECONDS = 120     # 2-minute break
SNOOZE_SECONDS = 5 * 60          # 5-minute snooze

snoozes_left = 3
glasses_drunk = 0
breaks_taken = 0

def get_best_font(root):
    available = {f.lower(): f for f in tkfont.families(root)}
    for preferred in ("lexend", "segoe ui", "arial"):
        if preferred in available:
            return available[preferred]
    return "TkDefaultFont"

def draw_gradient(canvas, width, height, start_rgb, end_rgb):
    r1, g1, b1 = start_rgb
    r2, g2, b2 = end_rgb
    step = 2
    for i in range(0, height, step):
        ratio = i / max(height, 1)
        r = int(r1 + (r2 - r1) * ratio)
        g = int(g1 + (g2 - g1) * ratio)
        b = int(b1 + (b2 - b1) * ratio)
        color = f"#{r:02x}{g:02x}{b:02x}"
        canvas.create_rectangle(0, i, width, i + step, outline="", fill=color)

def show_break_screen(is_snooze_retry=False):
    global snoozes_left, glasses_drunk, breaks_taken
    if not is_snooze_retry:
        breaks_taken += 1

    ctypes.windll.user32.SetProcessDPIAware()
    user32 = ctypes.windll.user32

    v_left = user32.GetSystemMetrics(76)
    v_top = user32.GetSystemMetrics(77)
    screen_w = user32.GetSystemMetrics(78)
    screen_h = user32.GetSystemMetrics(79)
    primary_w = user32.GetSystemMetrics(0)
    primary_h = user32.GetSystemMetrics(1)

    root = tk.Tk()
    root.title("Acyture Break Guard")
    root.overrideredirect(True)
    root.geometry(f"{screen_w}x{screen_h}+{v_left}+{v_top}")
    root.attributes("-topmost", True)
    root.protocol("WM_DELETE_WINDOW", lambda: None)

    ui_font = get_best_font(root)

    canvas = tk.Canvas(root, width=screen_w, height=screen_h, highlightthickness=0)
    canvas.pack(fill="both", expand=True)

    # Smooth turquoise-teal gradient
    draw_gradient(canvas, screen_w, screen_h, (4, 47, 46), (13, 148, 136))

    snoozed = {"value": False}
    cx = abs(v_left) + (primary_w // 2)

    canvas.create_text(
        cx, int(primary_h * 0.25),
        text="💧 Time for a water and washroom break",
        font=(ui_font, 36, "normal"),
        fill="#CCFBF1"
    )

    initial_advice = get_water_advice(glasses_drunk, breaks_taken)
    advice_id = canvas.create_text(
        cx, int(primary_h * 0.36),
        text=f"Total: {glasses_drunk}/15 cups — {initial_advice}",
        font=(ui_font, 20, "normal"),
        fill="#F0FDFA"
    )

    timer_id = canvas.create_text(
        cx, int(primary_h * 0.48),
        text=f"Screen unlocks in {BREAK_DURATION_SECONDS}s",
        font=(ui_font, 26, "normal"),
        fill="#FFFFFF"
    )

    def add_glass():
        global glasses_drunk
        glasses_drunk += 1
        new_advice = get_water_advice(glasses_drunk, breaks_taken)
        canvas.itemconfig(advice_id, text=f"Total: {glasses_drunk}/15 cups — {new_advice}")

    drink_btn = tk.Button(
        root,
        text="💧 I drank 1 tiny cup (+1)",
        font=(ui_font, 16, "normal"),
        fg="#042F2E",
        bg="#5EEAD4",
        activebackground="#99F6E4",
        relief="flat",
        padx=24,
        pady=12,
        cursor="hand2",
        command=add_glass
    )
    canvas.create_window(cx, int(primary_h * 0.60), window=drink_btn)

    def trigger_snooze():
        global snoozes_left
        if snoozes_left > 0:
            snoozes_left -= 1
            snoozed["value"] = True
            root.destroy()

    if snoozes_left > 0:
        snooze_btn = tk.Button(
            root,
            text=f"Emergency snooze ({snoozes_left} left)",
            font=(ui_font, 14, "normal"),
            fg="#042F2E",
            bg="#FDE047",
            activebackground="#FEF08A",
            relief="flat",
            padx=20,
            pady=10,
            cursor="hand2",
            command=trigger_snooze
        )
        canvas.create_window(cx, int(primary_h * 0.71), window=snooze_btn)

    def countdown(remaining):
        if remaining > 0:
            canvas.itemconfig(timer_id, text=f"Screen unlocks in {remaining}s")
            root.after(1000, countdown, remaining - 1)
        else:
            root.destroy()

    countdown(BREAK_DURATION_SECONDS)
    root.mainloop()
    return snoozed["value"]

if __name__ == "__main__":
    while True:
        time.sleep(WORK_INTERVAL_SECONDS)
        was_snoozed = show_break_screen()
        if was_snoozed:
            time.sleep(SNOOZE_SECONDS)
            show_break_screen(is_snooze_retry=True)
        snoozes_left = 3
