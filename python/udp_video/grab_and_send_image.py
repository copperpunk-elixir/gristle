#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Dec 14 11:14:48 2020

@author: ubuntu
"""
import d3dshot
import time
import numpy as np
import cv2
import socket
import argparse
import sys


ap = argparse.ArgumentParser()
# ap.add_argument("--host", type=str, default=None, required=True)
ap.add_argument("--host", type=str, default="192.168.7.196")
ap.add_argument("--port", type=int, default=19721)
ap.add_argument("--region", type=str, default="0,100,1014,800")
ap.add_argument("--rate", type=int, default=50)
ap.add_argument("--quality", type=int, default=20)

args = ap.parse_args()

usock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
usock.connect((args.host, args.port))

region = args.region.split(',')
if len(region) != 4:
    print("Region must be 'x,y,width,height'")
    sys.exit(1)
region = (int(region[0]),int(region[1]),int(region[2]),int(region[3]))


last_print_s = time.time()
count = 0
target_dt = 1.0 / args.rate
total_size = 0

d = d3dshot.create(capture_output="numpy")

while True:
    t1 = time.time()
    img = d.screenshot(region=region)
    encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), args.quality, cv2.IMWRITE_JPEG_OPTIMIZE, True]
    result, encimg = cv2.imencode('.jpg', img, encode_param)
    total_size += len(encimg)
    usock.send(encimg)
    t2 = time.time()
    dt = t2 - t1
    #if dt < target_dt:
     #   time.sleep(target_dt - dt)
    count += 1
    now = time.time()
    if now - last_print_s >= 1.0:
        dt = now - last_print_s
        print("%.1f FPS %.1f kByte/sec" % (count/dt, (total_size/1024.0)/dt))
        last_print_s = now
        count = 0
        total_size = 0