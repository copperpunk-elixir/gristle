import getopt
import sys
import tkinter as tk
import math
from time import sleep
from threading import Timer
from src.comms.operator import Operator
from src.image.camera import Camera
from src.common.location import position_with_distance_and_bearing

class Gcs(tk.Frame):
    def __init__(self, parent, camera_timeout):
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
        self.operator.send_message("generic_sub", [0,50])
        if camera_timeout != None:
            self.camera = Camera(timeout=camera_timeout)
        else:
            self.camera = None
        self.loop()

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
        # print("loop"):52
        
        # self.after(10, self.serial_tasks)
    
    def camera_tasks(self):
        distance_pixels, angle_rad = self.camera.read()
        if distance_pixels is not None:
            position = self.operator.position
            if position is not None:
                attitude = self.operator.attitude
                image_height = self.camera.image_height
                object_size_sensor_mm = 2*distance_pixels/image_height
                distance_m = position["agl"]*object_size_sensor_mm
                heading_to_object = attitude["yaw"] + angle_rad
                obj_lat, obj_lon = position_with_distance_and_bearing(position["latitude"], position["longitude"], distance_m, heading_to_object)
                print("lat/lon: %.5f/%.5f" %(obj_lat*180./math.pi, obj_lon*180./math.pi))


    def loop(self):
        while True:
            self.serial_tasks()
            self.camera_tasks()
            sleep(0.01)


def process_args(argv):
    arg_list = argv[1:]
    arguments, _values = getopt.getopt(arg_list, 'c:')
    for arg, value in arguments:
        print("arg/value: {}/{}".format(arg, value))
        if arg == "-c":
            print('use camera: {}'.format(value))
            return float(value)
    return None




if __name__ == "__main__":
    camera_timeout = process_args(sys.argv)
    root = tk.Tk()
    root.title = "Camera"
    root.geometry("500x300")
    Gcs(root, camera_timeout).pack()
    root.mainloop()