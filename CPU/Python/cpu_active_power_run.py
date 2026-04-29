from pathlib import Path

import numpy as np
from PIL import Image

INPUT_IMAGE = Path(r"C:\FPGA\sobel_diss_v2\CPU\data\1_ImageInputFolder\Test_Image1_32x32.PNG")
OUTPUT_IMAGE = Path(r"C:\FPGA\sobel_diss_v2\CPU\data\cpu_edges_32x32_check.png")
THRESHOLD = 120
WARMUP_RUNS = 50

def load_gray_32x32(path: Path) -> np.ndarray:
    img = Image.open(path).convert("L")
    arr = np.array(img, dtype=np.uint8)
    if arr.shape != (32, 32):
        raise ValueError(f"Expected 32x32 image, got {arr.shape}")
    return arr

def sobel_fpga_like(img_u8: np.ndarray, threshold: int) -> np.ndarray:
    img = img_u8.astype(np.int16)

    p00 = img[:-2, :-2]
    p01 = img[:-2, 1:-1]
    p02 = img[:-2, 2:]

    p10 = img[1:-1, :-2]
    p12 = img[1:-1, 2:]

    p20 = img[2:, :-2]
    p21 = img[2:, 1:-1]
    p22 = img[2:, 2:]

    gx = (p02 + (p12 << 1) + p22) - (p00 + (p10 << 1) + p20)
    gy = (p20 + (p21 << 1) + p22) - (p00 + (p01 << 1) + p02)

    mag = np.abs(gx) + np.abs(gy)

    out = np.zeros_like(img_u8, dtype=np.uint8)
    out[2:, 2:] = (mag > threshold).astype(np.uint8) * 255
    return out

def main() -> None:
    if not INPUT_IMAGE.exists():
        raise FileNotFoundError(f"Missing input image: {INPUT_IMAGE.resolve()}")

    img = load_gray_32x32(INPUT_IMAGE)

    for _ in range(WARMUP_RUNS):
        _ = sobel_fpga_like(img, THRESHOLD)

    image_saved = False

    print("CPU active power script started. Press Ctrl+C to stop.")

    try:
        while True:
            out = sobel_fpga_like(img, THRESHOLD)

            if not image_saved:
                Image.fromarray(out).save(OUTPUT_IMAGE)
                print(f"Saved sanity-check image: {OUTPUT_IMAGE}")
                image_saved = True

    except KeyboardInterrupt:
        print("CPU active power script stopped.")

if __name__ == "__main__":
    main()