import tkinter as tk
from time import sleep
from threading import Timer
from src.comms.operator import Operator

class Gcs(tk.Frame):
    def __init__(self, parent):
        tk.Frame.__init__(self, parent)
        frame = tk.Frame(self)
        left_orbit_button = tk.Button(frame, text="Left Inline Orbit", command=self.left_orbit_callback)
        left_orbit_button.grid(row=1, column=0)
        centered_orbit_button = tk.Button(frame, text="Centered Orbit\n(right)", command=self.centered_orbit_callback)
        centered_orbit_button.grid(row=1, column=1)
        right_orbit_button = tk.Button(frame, text="Right Inline Orbit", command=self.right_orbit_callback)
        right_orbit_button.grid(row=1, column=2)
        orbit_radius_entry = tk.Entry(frame)
        orbit_radius_entry.insert(0,60)
        orbit_radius_entry.grid(row=3, column=1)

        frame.pack()
        self.orbit_radius_entry = orbit_radius_entry
        self.operator = Operator(115200, "USB Serial")
        self.operator.open()
        self.serial_tasks()

    def left_orbit_callback(self):
        radius = self.get_radius()
        self.operator.send_message("orbit_inline", [-radius, 1])
        print("left orbit")

    def centered_orbit_callback(self):
        radius = self.get_radius()
        self.operator.send_message("orbit_centered", [radius, 1])
        print("centered orbit")

    def right_orbit_callback(self):
        radius = self.get_radius()
        self.operator.send_message("orbit_inline", [radius, 1])
        print("right orbit")

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