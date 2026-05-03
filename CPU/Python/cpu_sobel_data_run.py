import time
from pathlib import Path

import numpy as np
from PIL import Image

# ------------------------------------------------------------
# User settings
# ------------------------------------------------------------
INPUT_IMAGE = Path(r"C:\FPGA\sobel_diss_v2\CPU\data\1_ImageInputFolder\Test_Image1_32x32.PNG")
OUTPUT_IMAGE = Path(r"C:\FPGA\sobel_diss_v2\CPU\data\cpu_edges_32x32_data_collection.png")

THRESHOLD = 120
RUN_SECONDS = 60.0
WARMUP_RUNS = 50
# ------------------------------------------------------------


def load_gray_32x32(path: Path) -> np.ndarray:
    img = Image.open(path).convert("L")
    arr = np.array(img, dtype=np.uint8)
    if arr.shape != (32, 32):
        raise ValueError(f"Expected 32x32 image, got {arr.shape}")
    return arr


def sobel_fpga_like(img_u8: np.ndarray, threshold: int) -> np.ndarray:
    """
    Sobel matched to current FPGA/Arduino valid-window behaviour:
    - L1 magnitude: |Gx| + |Gy|
    - binary threshold
    - first two rows and first two columns are zero
    """
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

    # Warm-up
    for _ in range(WARMUP_RUNS):
        _ = sobel_fpga_like(img, THRESHOLD)

    frame_times = []
    frame_count = 0
    valid_count = 0
    edge_sum = 0
    activity_acc = 0
    out = None

    run_start = time.perf_counter()

    while (time.perf_counter() - run_start) < RUN_SECONDS:
        t0 = time.perf_counter()
        out = sobel_fpga_like(img, THRESHOLD)
        t1 = time.perf_counter()

        frame_times.append(t1 - t0)
        frame_count += 1
        valid_count += int(np.count_nonzero(out[2:, 2:]))
        edge_sum += int(out.sum())
        activity_acc ^= int(out[2:, 2:].sum()) & 0xFF

    run_end = time.perf_counter()

    if out is None:
        raise RuntimeError("No output produced.")

    Image.fromarray(out).save(OUTPUT_IMAGE)

    times = np.array(frame_times, dtype=np.float64)
    elapsed = run_end - run_start

    mean_ms = float(times.mean() * 1e3)
    median_ms = float(np.median(times) * 1e3)
    p95_ms = float(np.percentile(times, 95) * 1e3)
    min_ms = float(times.min() * 1e3)
    max_ms = float(times.max() * 1e3)
    std_ms = float(times.std(ddof=1) * 1e3) if len(times) > 1 else 0.0

    fps = frame_count / elapsed
    pixels_per_sec = (32 * 32 * frame_count) / elapsed

    print("CPU Sobel data collection complete.")
    print(f"Saved_output:             {OUTPUT_IMAGE}")
    print("Resolution:                32x32")
    print(f"Threshold:                {THRESHOLD}")
    print(f"Elapsed_s:                {elapsed:.9f}")
    print(f"Frames_processed:         {frame_count}")
    print(f"Frame_rate_fps:           {fps:.9f}")
    print(f"Pixel_throughput_pps:     {pixels_per_sec:.9f}")
    print(f"Mean_latency_ms:          {mean_ms:.9f}")
    print(f"Median_latency_ms:        {median_ms:.9f}")
    print(f"P95_latency_ms:           {p95_ms:.9f}")
    print(f"Min_latency_ms:           {min_ms:.9f}")
    print(f"Max_latency_ms:           {max_ms:.9f}")
    print(f"Std_latency_ms:           {std_ms:.9f}")
    print(f"Nonzero_pixels_output:    {np.count_nonzero(out)}")
    print(f"Valid_count:              {valid_count}")
    print(f"Edge_sum:                 {edge_sum}")
    print(f"Activity_acc:             {activity_acc}")


if __name__ == "__main__":
    main()
