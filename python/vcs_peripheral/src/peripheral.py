import tkinter as tk
from time import sleep
from threading import Timer

class Example(tk.Frame):
    def __init__(self, parent):
        tk.Frame.__init__(self, parent)
        frame = tk.Frame(self)
        left_orbit_button = tk.Button(frame, text="Left Orbit", command=self.left_orbit_callback)
        left_orbit_button.grid(row=1, column=0)
        frame.pack()
        self.serial_tasks()

    def left_orbit_callback(self):
        print("left orbit")

    def serial_tasks(self):
        print("loop")
        self.after(10, self.serial_tasks)



if __name__ == "__main__":
    root = tk.Tk()
    root.title = "Camera"
    root.geometry("300x300")
    Example(root).pack()
    root.mainloop()