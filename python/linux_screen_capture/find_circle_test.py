import cv2
import simple_detect


if __name__ == '__main__':
    # multiproc.freeze_support()
    print("Starting find_circle test")
    img = cv2.imread("test_image.png")
    simple_detect.find_circle(img)
    cv2.waitKey(0)