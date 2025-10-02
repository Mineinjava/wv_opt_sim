from PIL import Image
import numpy as np
from math import sin, cos, sqrt
from numba import jit

LIGHT_WAVELENGTH = 550e-6  # 550nm in mm, TODO: multiple colors
GRID_SPACING = 0.1  # in mm
# DISTANCES = [2000, 20]  # in mm
# img_file_names = ["mask.png", "mask1.png"]

DISTANCES = [2000]  # in mm
img_file_names = ["mask.png"]
img_files = [Image.open(name).convert('RGB') for name in img_file_names]

width, height = img_files[0].size  # assume all images are same size
count = width * height

output = None
masks = []


@jit(cache=True)
def area_num_int(px, py, inp, dist) -> np.ndarray:
    xcs, ycs = np.zeros(count), np.zeros(count)
    i = 0
    for my, row in enumerate(inp):
        for mx, val in enumerate(row):
            distance = sqrt(
                    ((px - mx)*GRID_SPACING) ** 2
                    + ((py - my)*GRID_SPACING) ** 2
                    + dist ** 2
                    ) / LIGHT_WAVELENGTH
            xcs[i] = val[0]*(cos(distance))
            ycs[i] = val[0]*(sin(distance))
            i += 1

    intensity = sqrt(xcs.mean()**2 + ycs.mean()**2)
    return np.full(3, intensity)


for img_file in img_files:
    mask: np.ndarray = np.asarray(img_file.getdata()) \
                         .reshape(height, width, 3)
    masks.append(mask)

output = masks[0]

for i, mask in enumerate(masks):
    print(f"Found mask resolution {mask.shape[0:2]}")
    nxm = np.zeros_like(output).astype(np.float64)

    for y, row in enumerate(output):
        for x, val in enumerate(row):
            if i < (len(masks)-1):
                if masks[i+1][y][x][0] == 0:
                    nxm[y][x] = 0
                    continue
            nxm[y][x] = area_num_int(x, y, output, DISTANCES[i])

    output = nxm

print(output)
print(output.shape)
mx = output.max()
output = output * (200 / mx)
result = Image.fromarray(output.astype(np.uint8))
result.save('output.png')
