from PIL import Image
import numpy as np
from math import sin, cos, sqrt
from numba import jit

LIGHT_WAVELENGTH = 550e-6  # 550nm in mm, TODO: multiple colors
GRID_SPACING = 0.1 # in mm
DISTANCE = 2000 # in mm

img_file = Image.open("mask.png").convert('RGB')
width, height = img_file.size
mask: np.ndarray = np.asarray(img_file.getdata()) \
                     .reshape(height, width, 3) \

count = width * height

print(f"Found mask resolution {mask.shape[0:2]} size")

output = np.zeros_like(mask).astype(np.float64)


@jit(cache=True)
def area_num_int(px, py, a) -> np.ndarray:
    xcs, ycs = np.zeros(count), np.zeros(count)
    i = 0
    for my, row in enumerate(mask):
        for mx, val in enumerate(row):
            distance = sqrt(
                    ((px - mx)*GRID_SPACING) ** 2
                    + ((py - my)*GRID_SPACING) ** 2
                    + DISTANCE ** 2
                    ) / LIGHT_WAVELENGTH
            xcs[i] = val[0]*(cos(distance))
            ycs[i] = val[0]*(sin(distance))
            i += 1

    intensity = sqrt(xcs.mean()**2 + ycs.mean()**2)
    return np.full(3, intensity)

print(output)
for y, row in enumerate(output):
    for x, val in enumerate(row):
        output[y][x] = area_num_int(x, y, val[0])
print(output)
print(output.shape)
mx = output.max()
output = output * (200 / mx)
result = Image.fromarray(output.astype(np.uint8))
result.save('output.png')
