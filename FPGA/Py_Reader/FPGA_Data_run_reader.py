import serial
import numpy as np
from pathlib import Path
from PIL import Image

PORT = "COM6"      
BAUD = 115200
CLK_HZ = 12_000_000
W = 32
H = 32

OUTPUT_IMAGE = Path(r"C:\FPGA\sobel_diss_v2\python\fpga_verify_output.png")

def read_exact(ser: serial.Serial, n: int) -> bytes:
    data = bytearray()
    while len(data) < n:
        chunk = ser.read(n - len(data))
        if not chunk:
            raise TimeoutError(f"Timed out while waiting for {n} bytes")
        data.extend(chunk)
    return bytes(data)

def wait_for_header(ser: serial.Serial, target: bytes) -> None:
    header = bytearray()
    while True:
        b = ser.read(1)
        if not b:
            continue
        header.append(b[0])

        if len(header) > len(target):
            header = header[-len(target):]

        if bytes(header) == target:
            return

def main() -> None:
    print(f"Opening {PORT} at {BAUD} baud...")
    with serial.Serial(PORT, BAUD, timeout=2.0) as ser:
        ser.reset_input_buffer()

        # --------------------------------------------------------
        # Verification image packet
        # Header:
        # A5 5A F1 W H THRESH
        # then W*H image bytes
        # --------------------------------------------------------
        print("Waiting for FPGA verification frame...")
        wait_for_header(ser, b"\xA5\x5A\xF1")

        meta = read_exact(ser, 3)
        w = meta[0]
        h = meta[1]
        threshold = meta[2]

        payload = read_exact(ser, w * h)

        arr = np.frombuffer(payload, dtype=np.uint8).reshape((h, w))
        Image.fromarray(arr).save(OUTPUT_IMAGE)

        print("FPGA verification frame received.")
        print(f"Resolution: {w}x{h}")
        print(f"Threshold: {threshold}")
        print(f"Saved: {OUTPUT_IMAGE}")

        # --------------------------------------------------------
        # Final summary packet
        # Header:
        # A5 5A 01
        # then 4 bytes frame_count + 4 bytes cycle_count
        # --------------------------------------------------------
        print("Waiting for FPGA summary packet...")
        wait_for_header(ser, b"\xA5\x5A\x01")

        payload = read_exact(ser, 8)

        frame_count = int.from_bytes(payload[0:4], byteorder="little", signed=False)
        cycle_count = int.from_bytes(payload[4:8], byteorder="little", signed=False)

        elapsed_s = cycle_count / CLK_HZ
        fps = frame_count / elapsed_s if elapsed_s > 0 else 0.0
        latency_ms = (1.0 / fps) * 1e3 if fps > 0 else 0.0
        pixel_throughput = fps * (w * h)

        print("FPGA benchmark summary received.")
        print(f"Frames_processed:      {frame_count}")
        print(f"Elapsed_cycles:        {cycle_count}")
        print(f"Elapsed_s:             {elapsed_s:.9f}")
        print(f"Frame_rate_fps:        {fps:.9f}")
        print(f"Latency_ms_per_frame:  {latency_ms:.9f}")
        print(f"Pixel_throughput_pps:  {pixel_throughput:.9f}")

if __name__ == "__main__":
    main()