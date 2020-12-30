import cv2
import simple_detect


if __name__ == '__main__':
    # multiproc.freeze_support()
    print("Starting find_circle test")
    img = cv2.imread("test_image.png")
    distance_pixels, theta = simple_detect.find_circle(img)
    print("dpx/theta: %.2f/%.1f" %(distance_pixels, theta*57.3))

    cv2.waitKey(0)