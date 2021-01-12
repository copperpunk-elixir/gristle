import cv2
import socket
import numpy
import select
import time
import src.image.simple_detect as sd

class Camera:
    def __init__(self, timeout):
        port = 19721
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(('', port))
        sock.setblocking(0)
        self.socket = sock
        self.read_timeout = timeout
        self.image_height = None
        filename = "output_video_{}.mp4".format(round(time.time()))
        print("filename: %s" %filename)
        self.video_output = cv2.VideoWriter(filename, cv2.VideoWriter_fourcc(*'mp4v'), 12, (700,700))

    def read(self):
        ready = select.select([self.socket], [], [], self.read_timeout)
        if ready[0]:
            p = self.socket.recv(80000)
            img = cv2.imdecode(numpy.fromstring(p, dtype=numpy.uint8), -1)
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            # print("received img")
            self.image_height = img.shape[1]
            distance, angle, img_annotated = sd.find_circle(img)
            self.video_output.write(img_annotated)
            return distance, angle

        return None, None
        
    def release_video(self):
        self.video_output.release()