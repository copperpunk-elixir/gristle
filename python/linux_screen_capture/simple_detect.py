import cv2
import numpy as np

def find_circle(img):
    # cv2.imshow('Raw',img)
    min_circle_radius = 8
    max_circle_radius = 30
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
    if circles_red is not None:
        light_radius = []
        for pt in circles_red[0,:]:
            a, b, r = pt[0], pt[1], pt[2] 
            cv2.circle(img,(a,b),r,(0, 255, 255),5)
            light_radius.append(r)
        print("{} red circles: {}".format(len(light_radius),light_radius))
        # self.annotated_image_pub.publish(self.bridge.cv2_to_imgmsg(red_only_img, "8UC1"))
        # return result
    cv2.imshow('circles',img)

def find_circle_location(img, latitude, longitude, heading, agl):
    