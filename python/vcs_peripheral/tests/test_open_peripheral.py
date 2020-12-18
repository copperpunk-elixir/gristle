import src.comms.operator as op
import src.comms.ublox as ub
import src.common.utils as ut
import src.common.math as mt
import pytest
import random
import peripheral as peri
import tkinter as tk

def test_open_peripheral():
    root = tk.Tk()
    root.title = "Camera"
    root.geometry("400x300")
    peri.Gcs(root).pack()
    root.mainloop()
    # assert False
