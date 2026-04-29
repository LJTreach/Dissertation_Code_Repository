import time

print("CPU idle power script started. Press Ctrl+C to stop.")

def main() -> None:
    alive_counter = 0
    t_last = time.perf_counter()

    try:
        while True:
            now = time.perf_counter()

            # very light periodic activity, just enough to keep the loop alive
            if (now - t_last) >= 0.1:
                alive_counter += 1
                t_last = now

    except KeyboardInterrupt:
        print("CPU idle power script stopped.")

if __name__ == "__main__":
    main()