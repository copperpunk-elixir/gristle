import cv2
import socket
import numpy
import argparse
import matplotlib.pyplot as plt
import simple_detect as sd

if __name__ == '__main__':
    # multiproc.freeze_support()
    print("Starting linux_screen_capture")
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=19721)
    ap.add_argument("--title", type=str, default='UDP Images')
    args = ap.parse_args()

    # viewer = mp_image.MPImage(title=args.title, width=200, height=200, auto_size=True)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(('', args.port))

    while True:
        p = sock.recv(80000)
        img = cv2.imdecode(numpy.fromstring(p, dtype=numpy.uint8), -1)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        print("received img")
        sd.find_circle(img)
        # cv2.imshow('img_decode',img)

        cv2.waitKey(1)
        # viewer.set_image(img)