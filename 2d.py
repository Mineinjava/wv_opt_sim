from PIL import Image
import numpy as np

img_file = Image.open("mask.png").form
width, height = img_file.size
mask: np.ndarray = np.asarray(img_file.getdata()) \
                     .reshape(width, height, 3)

print(f"Found mask resolution {mask.shape[0:2]} size")
