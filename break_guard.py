import time
import tkinter as tk

WORK_INTERVAL_SECONDS = 10   # Change to 45 * 60 (2700) for real 45-min work blocks
BREAK_DURATION_SECONDS = 15  # Change to 120 for a real 2-min break
SNOOZE_SECONDS = 5           # Change to 5 * 60 (300) for a real 5-min snooze

snoozes_left = 1

def show_break_screen():
    global snoozes_left
    root = tk.Tk()
    root.title("Acyture Break Guard")
    root.attributes("-fullscreen", True)
    root.attributes("-topmost", True)
    root.configure(bg="#0F172A")

    # Block Alt+F4 / window close button during break
    root.protocol("WM_DELETE_WINDOW", lambda: None)

    snoozed = {"value": False}

    title = tk.Label(
        root,
        text="💧 WATER & WASHROOM BREAK!",
        font=("Segoe UI", 38, "bold"),
        fg="#38BDF8",
        bg="#0F172A"
    )
    title.pack(pady=(140, 20))

    subtitle = tk.Label(
        root,
        text="Stand up, grab a glass of water, and give your eyes a rest.",
        font=("Segoe UI", 20),
        fg="#CBD5E1",
        bg="#0F172A"
    )
    subtitle.pack(pady=10)

    timer_label = tk.Label(
        root,
        text=f"Screen unlocks in {BREAK_DURATION_SECONDS}s",
        font=("Segoe UI", 28, "bold"),
        fg="#F8FAFC",
        bg="#0F172A"
    )
    timer_label.pack(pady=40)

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
            fg="#0F172A",
            bg="#FBBF24",
            padx=20,
            pady=10,
            command=trigger_snooze
        )
        snooze_btn.pack(pady=20)

    def countdown(remaining):
        if remaining > 0:
            timer_label.config(text=f"Screen unlocks in {remaining}s")
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
        snoozes_left = 1  # Reset snooze for the next work cycle
