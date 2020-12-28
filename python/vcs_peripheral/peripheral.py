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
        orbit_radius_entry.grid(row=1, column=1)
        clear_orbit_button = tk.Button(frame, text="Clear Orbit", command=self.clear_orbit_cb)
        clear_orbit_button.grid(row=2, column=1)
        orbit_at_button = tk.Button(frame, text="Orbit at Location", command=self.orbit_at_location_cb)
        orbit_at_button.grid(row=3, column=1)
        goto_latitude_entry = tk.Entry(frame)
        goto_latitude_entry.insert(0,41.77)
        goto_latitude_entry.grid(row=4, column=0)
        goto_longitude_entry = tk.Entry(frame)
        goto_longitude_entry.insert(0, -122.49)
        goto_longitude_entry.grid(row=4, column=1)
        goto_altitude_entry = tk.Entry(frame)
        goto_altitude_entry.insert(0,1250.0)
        goto_altitude_entry.grid(row=4, column=2)
        goto_button = tk.Button(frame, text="Go to Location", command=self.goto_cb)
        goto_button.grid(row=5, column=1)
        clear_goto_button = tk.Button(frame, text="Clear Goto", command=self.clear_goto_cb)
        clear_goto_button.grid(row=6, column=1)


        frame.pack()
        self.orbit_radius_entry = orbit_radius_entry
        self.goto_latitude_entry = goto_latitude_entry
        self.goto_longitude_entry = goto_longitude_entry
        self.goto_altitude_entry = goto_altitude_entry
        self.operator = Operator(115200, "USB Serial")
        self.operator.open()
        self.serial_tasks()

    def left_inline_orbit_cb(self):
        radius = self.get_radius()
        self.operator.send_message("orbit_inline", [-radius, 1])
        print("SEND: left orbit")

    def left_centered_orbit_cb(self):
        radius = self.get_radius()
        self.operator.send_message("orbit_centered", [-radius, 1])
        print("SEND: centered orbit")

    def right_centered_orbit_cb(self):
        radius = self.get_radius()
        self.operator.send_message("orbit_centered", [radius, 1])
        print("SEND: centered orbit")

    def right_inline_orbit_cb(self):
        radius = self.get_radius()
        self.operator.send_message("orbit_inline", [radius, 1])
        print("SEND: right orbit")

    def clear_orbit_cb(self):
        self.operator.send_message("clear_orbit", [1])
        print("SEND: clear orbit")

    def orbit_at_location_cb(self):
        radius = self.get_radius()
        latitude = self.get_latitude_goto()
        longitude = self.get_longitude_goto()
        altitude = self.get_altitude_goto()
        self.operator.send_message("orbit_at_location", [radius, latitude, longitude, altitude, 1])
        print("SEND: Go to location")

    def goto_cb(self):
        latitude = self.get_latitude_goto()
        longitude = self.get_longitude_goto()
        altitude = self.get_altitude_goto()
        self.operator.send_message("goto_location", [latitude, longitude, altitude, 1])
        print("SEND: Go to location")

    def clear_goto_cb(self):
        self.operator.send_message("clear_goto_location", [1])
        print("SEND: Clear Goto")


    def get_radius(self):
        return float(self.orbit_radius_entry.get())

    def get_latitude_goto(self):
        return float(self.goto_latitude_entry.get())

    def get_longitude_goto(self):
        return float(self.goto_longitude_entry.get())

    def get_altitude_goto(self):
        return float(self.goto_altitude_entry.get())



    def serial_tasks(self):
        self.operator.read()
        # print("loop")
        self.after(10, self.serial_tasks)



if __name__ == "__main__":
    root = tk.Tk()
    root.title = "Camera"
    root.geometry("500x300")
    Gcs(root).pack()
    root.mainloop()