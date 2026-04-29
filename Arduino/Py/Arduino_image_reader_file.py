from pathlib import Path
import serial
import numpy as np
from PIL import Image

PORT = "COM3"   # change if needed
BAUD = 115200
OUTPUT_IMAGE = Path(r"C:\FPGA\sobel_diss_v2\Ardino\Ardu\arduino_verify_output.png")

def read_exact(ser, n):
    data = bytearray()
    while len(data) < n:
        chunk = ser.read(n - len(data))
        if not chunk:
            raise TimeoutError(f"Timed out waiting for {n} bytes")
        data.extend(chunk)
    return bytes(data)

def main():
    print(f"Opening {PORT} at {BAUD} baud...")
    with serial.Serial(PORT, BAUD, timeout=2.0) as ser:
        ser.reset_input_buffer()

        print("Waiting for Arduino verification frame...")
        header = bytearray()

        while True:
            b = ser.read(1)
            if not b:
                continue
            header.append(b[0])

            if len(header) > 3:
                header = header[-3:]

            if len(header) == 3 and header[0] == 0xA5 and header[1] == 0x5A and header[2] == 0xF1:
                break

        meta = read_exact(ser, 3)
        w = meta[0]
        h = meta[1]
        threshold = meta[2]

        payload = read_exact(ser, w * h)

        arr = np.frombuffer(payload, dtype=np.uint8).reshape((h, w))
        Image.fromarray(arr).save(OUTPUT_IMAGE)

        print("Arduino verification frame received.")
        print(f"Resolution: {w}x{h}")
        print(f"Threshold: {threshold}")
        print(f"Saved: {OUTPUT_IMAGE}")

if __name__ == "__main__":
    main()