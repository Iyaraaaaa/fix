import sys
sys.path.insert(0, r'D:\Final Project\fix\Veriframe-main\Veriframe-main\backend')
from config import config as app_config
print('BLUR_VAR_THRESHOLD:', app_config.BLUR_VAR_THRESHOLD)
print('BRIGHTNESS_MIN:', app_config.BRIGHTNESS_MIN)
print('BRIGHTNESS_MAX:', app_config.BRIGHTNESS_MAX)
print('FACE_SIZE_RATIO_MIN:', app_config.FACE_SIZE_RATIO_MIN)
print('FACE_SIZE_RATIO_MAX:', app_config.FACE_SIZE_RATIO_MAX)