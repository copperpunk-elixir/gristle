import tkinter as tk
from time import sleep
from threading import Timer
from src.comms.operator import Operator

class Gcs(tk.Frame):
    def __init__(self, parent):
        tk.Frame.__init__(self, parent)
        frame = tk.Frame(self)
        left_inline_orbit_button = tk.Button(frame, text="Left Inline\nOrbit", command=self.left_inline_orbit_cb)
        left_inline_orbit_button.grid(row=1, column=0)
        left_centered_orbit_button = tk.Button(frame, text="Left Centered\nOrbit", command=self.left_centered_orbit_cb)
        left_centered_orbit_button.grid(row=2, column=0)
        right_centered_orbit_button = tk.Button(frame, text="Right Centered\nOrbit)", command=self.right_centered_orbit_cb)
        right_centered_orbit_button.grid(row=2, column=2)
        right_inline_orbit_button = tk.Button(frame, text="Right Inline\nOrbit", command=self.right_inline_orbit_cb)
        right_inline_orbit_button.grid(row=1, column=2)
        orbit_radius_entry = tk.Entry(frame)
        orbit_radius_entry.insert(0,60)
        orbit_radius_entry.grid(row=2, column=1)
        clear_orbit_button = tk.Button(frame, text="Clear Orbit", command=self.clear_orbit_cb)
        clear_orbit_button.grid(row=4, column=1)

        frame.pack()
        self.orbit_radius_entry = orbit_radius_entry
        self.operator = Operator(115200, "USB Serial")
        self.operator.open()
        self.serial_tasks()

    def left_inline_orbit_cb(self):
        radius = self.get_radius()
        self.operator.send_message("orbit_inline", [-radius, 1])
        print("left orbit")

    def left_centered_orbit_cb(self):
        radius = self.get_radius()
        self.operator.send_message("orbit_centered", [-radius, 1])
        print("centered orbit")

    def right_centered_orbit_cb(self):
        radius = self.get_radius()
        self.operator.send_message("orbit_centered", [radius, 1])
        print("centered orbit")

    def right_inline_orbit_cb(self):
        radius = self.get_radius()
        self.operator.send_message("orbit_inline", [radius, 1])
        print("right orbit")

    def clear_orbit_cb(self):
        self.operator.send_message("clear_orbit", [1])
        print("clear orbit")


    def get_radius(self):
        return float(self.orbit_radius_entry.get())

    def serial_tasks(self):
        self.operator.read()
        # print("loop")
        self.after(10, self.serial_tasks)



if __name__ == "__main__":
    root = tk.Tk()
    root.title = "Camera"
    root.geometry("440x300")
    Gcs(root).pack()
    root.mainloop()