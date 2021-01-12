import cv2
import numpy as np
import math

def find_circle(img):
    # img = cv2.imread("test_image.png")
    # cv2.imshow('Raw',img)
    min_circle_radius = 8
    max_circle_radius = 50
    hsv_image = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

    # The red color wraps around the HSV wheel, from approx 160-180 deg, and 0-10 deg
    # Thus we will split this into 2 operations
    lower_red_1 = np.array([0,50,50])
    upper_red_1 = np.array([10,255,255])
    red1 = cv2.inRange(hsv_image, lower_red_1 , upper_red_1)

    lower_red_2 = np.array([170,50,50])
    upper_red_2 = np.array([180,255,255])
    red2 = cv2.inRange(hsv_image, lower_red_2 , upper_red_2)
    
# Combine the two red images to get a single red-only image
    red_only_img = cv2.addWeighted(red1, 1.0, red2, 1.0, 0.0)
    # cv2.imshow('Red',red_only_img)
    # Blur
    blur_img_red = cv2.GaussianBlur(red_only_img,(15,15),cv2.BORDER_DEFAULT)
    # cv2.imshow('Blurred',blur_img_red)
    # Detect circles
    circles_red = cv2.HoughCircles(blur_img_red,cv2.HOUGH_GRADIENT,0.5,2*max_circle_radius, param1=70,param2=30,minRadius=min_circle_radius,maxRadius=max_circle_radius)

    # If we find a red light, then we're done
    # Return immediately
    dimensions = img.shape
    height_mid = dimensions[0]/2
    width_mid = dimensions[1]/2
    center_pt = (round(width_mid), round(height_mid))
    distance = None
    theta = None
    if circles_red is not None:
        # print("cr: {}".format(circles_red))
        pt = circles_red[0,:][0]
        # print("pt: {}".format(pt))
        x, y, r = pt[0], pt[1], pt[2] 
        # print("circle at x/y/r: {}/{}/{}".format(x, y, r))
        cv2.circle(img,(x,y),r,(0, 255, 255),5)
        dx = x - width_mid
        dy = height_mid-y
        # print("dx/dy: {}/{}".format(dx, dy))
        theta = np.arctan2(dx, dy)
        # print("angle from center to point: {}".format(theta*180/np.pi))
        distance = math.sqrt(dx*dx + dy*dy)
        # print("distance: %d" %round(distance))
        # print("cnter pt: {}".format(center_pt))
        # cv2.circle(img, center_pt, round(distance), (0,0,0))
        cv2.circle(img, (x,y), round(distance), (0,0,0))
        cv2.line(img, center_pt, (x,y), (128, 0, 0), 2)
        # self.annotated_image_pub.publish(self.bridge.cv2_to_imgmsg(red_only_img, "8UC1"))
        # return result
    cv2.imshow('circles',img)
    cv2.waitKey(1)
    return (distance, theta, img)