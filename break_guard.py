import time
import tkinter as tk
from water_check import get_water_advice

WORK_INTERVAL_SECONDS = 5 * 60  # 1 hour (3600 seconds) — set back to 5 if you want a quick test
BREAK_DURATION_SECONDS = 120     # 2-minute break
SNOOZE_SECONDS = 5 * 60          # 5-minute snooze

snoozes_left = 3
glasses_drunk = 0
breaks_taken = 0

def draw_gradient(canvas, width, height, start_rgb, end_rgb):
    r1, g1, b1 = start_rgb
    r2, g2, b2 = end_rgb
    for i in range(height):
        ratio = i / max(height, 1)
        r = int(r1 + (r2 - r1) * ratio)
        g = int(g1 + (g2 - g1) * ratio)
        b = int(b1 + (b2 - b1) * ratio)
        color = f"#{r:02x}{g:02x}{b:02x}"
        canvas.create_line(0, i, width, i, fill=color)

def show_break_screen():
    global snoozes_left, glasses_drunk, breaks_taken
    breaks_taken += 1

    root = tk.Tk()
    root.title("Acyture Break Guard")
    root.attributes("-fullscreen", True)
    root.attributes("-topmost", True)
    root.protocol("WM_DELETE_WINDOW", lambda: None)

    screen_w = root.winfo_screenwidth()
    screen_h = root.winfo_screenheight()

    canvas = tk.Canvas(root, width=screen_w, height=screen_h, highlightthickness=0)
    canvas.pack(fill="both", expand=True)

    # Smooth gradient from deep teal (#042F2E) to bright turquoise (#0D9488)
    draw_gradient(canvas, screen_w, screen_h, (4, 47, 46), (13, 148, 136))

    snoozed = {"value": False}
    cx = screen_w // 2

    canvas.create_text(
        cx, int(screen_h * 0.25),
        text="💧 WATER & WASHROOM BREAK!",
        font=("Segoe UI", 40, "bold"),
        fill="#CCFBF1"
    )

    initial_advice = get_water_advice(glasses_drunk, breaks_taken)
    advice_id = canvas.create_text(
        cx, int(screen_h * 0.36),
        text=f"Total: {glasses_drunk}/15 cups — {initial_advice}",
        font=("Segoe UI", 20),
        fill="#F0FDFA"
    )

    timer_id = canvas.create_text(
        cx, int(screen_h * 0.48),
        text=f"Screen unlocks in {BREAK_DURATION_SECONDS}s",
        font=("Segoe UI", 28, "bold"),
        fill="#FFFFFF"
    )

    def add_glass():
        global glasses_drunk
        glasses_drunk += 1
        new_advice = get_water_advice(glasses_drunk, breaks_taken)
        canvas.itemconfig(advice_id, text=f"Total: {glasses_drunk}/15 cups — {new_advice}")

    drink_btn = tk.Button(
        root,
        text="💧 I Drank 1 Tiny Cup (+1)",
        font=("Segoe UI", 16, "bold"),
        fg="#042F2E",
        bg="#5EEAD4",
        activebackground="#99F6E4",
        relief="flat",
        padx=24,
        pady=12,
        cursor="hand2",
        command=add_glass
    )
    canvas.create_window(cx, int(screen_h * 0.60), window=drink_btn)

    def trigger_snooze():
        global snoozes_left
        if snoozes_left > 0:
            snoozes_left -= 1
            snoozed["value"] = True
            root.destroy()

    if snoozes_left > 0:
        snooze_btn = tk.Button(
            root,
            text=f"Emergency Snooze ({snoozes_left} left)",
            font=("Segoe UI", 14, "bold"),
            fg="#042F2E",
            bg="#FDE047",
            activebackground="#FEF08A",
            relief="flat",
            padx=20,
            pady=10,
            cursor="hand2",
            command=trigger_snooze
        )
        canvas.create_window(cx, int(screen_h * 0.71), window=snooze_btn)

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
    print("Acyture Break Guard is running... Press Ctrl+C in terminal to stop.")
    while True:
        time.sleep(WORK_INTERVAL_SECONDS)
        was_snoozed = show_break_screen()
        if was_snoozed:
            print("Snoozed! Waiting before next break...")
            time.sleep(SNOOZE_SECONDS)
            show_break_screen()
        snoozes_left = 3
