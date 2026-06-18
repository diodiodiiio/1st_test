#!/usr/bin/env python3
"""
Highlight-to-translate: select English text, right-click, choose "日本語に翻訳"
Requirements:
    pip install pynput pyperclip deep-translator
On Linux also install xclip or xdotool:
    sudo apt-get install xclip
"""

import threading
import time
import tkinter as tk
from tkinter import messagebox

import pyperclip
from pynput import mouse
from deep_translator import GoogleTranslator


def get_selected_text() -> str:
    """Copy current selection to clipboard and return it."""
    original = pyperclip.paste()

    # Simulate Ctrl+C to copy the current selection
    from pynput.keyboard import Controller as KbController, Key
    kb = KbController()
    kb.press(Key.ctrl)
    kb.press('c')
    kb.release('c')
    kb.release(Key.ctrl)

    time.sleep(0.15)  # wait for clipboard update

    selected = pyperclip.paste()

    # If clipboard didn't change, no text was selected
    if selected == original:
        return ""
    return selected.strip()


def translate_to_japanese(text: str) -> str:
    try:
        return GoogleTranslator(source='auto', target='ja').translate(text)
    except Exception as e:
        return f"翻訳エラー: {e}"


def show_popup(x: int, y: int, selected_text: str):
    """Show a small popup menu near the mouse position."""
    root = tk.Tk()
    root.withdraw()  # hide main window

    menu = tk.Menu(root, tearoff=0)

    def do_translate():
        if not selected_text:
            messagebox.showinfo("翻訳", "テキストが選択されていません。\nテキストをハイライトしてから右クリックしてください。", parent=root)
        else:
            result = translate_to_japanese(selected_text)
            show_result_window(selected_text, result)
        root.destroy()

    def cancel():
        root.destroy()

    preview = selected_text[:30] + "..." if len(selected_text) > 30 else selected_text
    if preview:
        menu.add_command(label=f"「{preview}」", state="disabled")
        menu.add_separator()
    menu.add_command(label="日本語に翻訳", command=do_translate)
    menu.add_separator()
    menu.add_command(label="キャンセル", command=cancel)

    # Show menu near cursor
    try:
        menu.tk_popup(x, y)
    finally:
        menu.grab_release()

    root.mainloop()


def show_result_window(original: str, translated: str):
    """Display translation result in a small floating window."""
    win = tk.Tk()
    win.title("翻訳結果")
    win.resizable(False, False)
    win.attributes('-topmost', True)

    # Original
    tk.Label(win, text="原文:", font=("Arial", 9, "bold"), anchor="w").pack(fill="x", padx=10, pady=(10, 0))
    orig_text = tk.Text(win, height=3, width=50, wrap="word", font=("Arial", 10), bg="#f5f5f5", relief="flat")
    orig_text.insert("1.0", original)
    orig_text.config(state="disabled")
    orig_text.pack(padx=10, pady=(2, 8))

    # Translation
    tk.Label(win, text="日本語訳:", font=("Arial", 9, "bold"), anchor="w").pack(fill="x", padx=10)
    trans_text = tk.Text(win, height=4, width=50, wrap="word", font=("Arial", 10), bg="#e8f4fd", relief="flat")
    trans_text.insert("1.0", translated)
    trans_text.config(state="disabled")
    trans_text.pack(padx=10, pady=(2, 8))

    def copy_translation():
        win.clipboard_clear()
        win.clipboard_append(translated)
        copy_btn.config(text="コピー済み ✓")
        win.after(1500, lambda: copy_btn.config(text="訳文をコピー"))

    btn_frame = tk.Frame(win)
    btn_frame.pack(pady=(0, 10))
    copy_btn = tk.Button(btn_frame, text="訳文をコピー", command=copy_translation, width=14)
    copy_btn.pack(side="left", padx=5)
    tk.Button(btn_frame, text="閉じる", command=win.destroy, width=10).pack(side="left", padx=5)

    # Center window near screen center
    win.update_idletasks()
    w, h = win.winfo_width(), win.winfo_height()
    sw, sh = win.winfo_screenwidth(), win.winfo_screenheight()
    win.geometry(f"+{(sw - w) // 2}+{(sh - h) // 2}")

    win.mainloop()


class TranslateListener:
    def __init__(self):
        self._last_click_pos = (0, 0)
        self._listener = mouse.Listener(on_click=self._on_click)

    def _on_click(self, x, y, button, pressed):
        if button == mouse.Button.right and pressed:
            self._last_click_pos = (x, y)
            # Run popup in a separate thread so listener isn't blocked
            threading.Thread(
                target=show_popup,
                args=(x, y, get_selected_text()),
                daemon=True
            ).start()

    def start(self):
        print("=" * 50)
        print("  翻訳ポップアップ — 起動しました")
        print("=" * 50)
        print("使い方:")
        print("  1. 翻訳したい英語テキストをマウスでハイライト")
        print("  2. 右クリック →「日本語に翻訳」を選択")
        print("  3. 翻訳結果がウィンドウに表示されます")
        print()
        print("終了: Ctrl+C")
        print("=" * 50)
        with self._listener:
            self._listener.join()


if __name__ == "__main__":
    TranslateListener().start()
