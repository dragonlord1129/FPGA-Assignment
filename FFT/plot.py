#!/usr/bin/env python3
"""
plot_fft_results.py

Reads fft_results.txt (produced by fft_tb.v) and plots, for each test case:
  1. The time-domain input samples fed into the Verilog FFT.
  2. The magnitude spectrum produced by the Verilog FFT hardware.
  3. A reference magnitude spectrum computed with numpy.fft for comparison.

Usage:
    python3 plot_fft_results.py [path_to_results_file]

If no path is given, "fft_results.txt" in the current directory is used.
"""

import sys
import os
import numpy as np
import matplotlib.pyplot as plt


def parse_results(path):
    """Parse the fft_results.txt file into a list of test-case dicts."""
    tests = []
    current = None

    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith("# TEST"):
                if current is not None:
                    tests.append(current)
                current = {
                    "name": line.split("# TEST", 1)[1].strip(),
                    "n": [],
                    "in_re": [],
                    "in_im": [],
                    "out_re": [],
                    "out_im": [],
                }
            elif line.startswith("N "):
                continue  # sample count, not needed beyond len()
            else:
                parts = line.split()
                if len(parts) != 5:
                    continue
                idx, in_re, in_im, out_re, out_im = parts
                current["n"].append(int(idx))
                current["in_re"].append(float(in_re))
                current["in_im"].append(float(in_im))
                current["out_re"].append(float(out_re))
                current["out_im"].append(float(out_im))

    if current is not None:
        tests.append(current)
    return tests


def plot_test(test, save_path=None):
    n = np.array(test["n"])
    x = np.array(test["in_re"]) + 1j * np.array(test["in_im"])
    y_hw = np.array(test["out_re"]) + 1j * np.array(test["out_im"])

    # Reference: numpy FFT of the same input, scaled by 1/N to match the
    # Verilog "scaled FFT" convention (each butterfly stage divides by 2).
    y_ref = np.fft.fft(x) / len(x)

    N = len(n)
    fig, axes = plt.subplots(1, 3, figsize=(15, 4))
    fig.suptitle(f"FFT Test Case: {test['name']}  (N={N})", fontsize=13)

    # --- Time domain input ---
    ax = axes[0]
    ax.stem(n, x.real, linefmt="C0-", markerfmt="C0o", basefmt="k-", label="Re")
    if np.any(np.abs(x.imag) > 1e-9):
        ax.stem(n, x.imag, linefmt="C1--", markerfmt="C1s", basefmt="k-", label="Im")
    ax.set_title("Time-domain input")
    ax.set_xlabel("sample n")
    ax.set_ylabel("amplitude")
    ax.legend()
    ax.grid(alpha=0.3)

    # --- Hardware FFT magnitude spectrum ---
    ax = axes[1]
    ax.stem(n, np.abs(y_hw), linefmt="C2-", markerfmt="C2o", basefmt="k-")
    ax.set_title("Verilog FFT output |X[k]|")
    ax.set_xlabel("bin k")
    ax.set_ylabel("magnitude")
    ax.grid(alpha=0.3)

    # --- numpy reference spectrum ---
    ax = axes[2]
    ax.stem(n, np.abs(y_ref), linefmt="C3-", markerfmt="C3o", basefmt="k-")
    ax.set_title("numpy.fft reference |X[k]|/N")
    ax.set_xlabel("bin k")
    ax.set_ylabel("magnitude")
    ax.grid(alpha=0.3)

    plt.tight_layout(rect=[0, 0, 1, 0.93])

    if save_path:
        plt.savefig(save_path, dpi=150)
        print(f"Saved: {save_path}")
    else:
        plt.show()

    # Print numeric comparison / error
    err = np.abs(y_hw - y_ref)
    print(f"[{test['name']}] max |hw - numpy_ref| error = {err.max():.6f}")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "fft_results.txt"
    if not os.path.exists(path):
        print(f"Results file not found: {path}")
        print("Run the Verilog testbench first (see README) to generate it.")
        sys.exit(1)

    tests = parse_results(path)
    if not tests:
        print("No test cases found in results file.")
        sys.exit(1)

    out_dir = os.path.dirname(os.path.abspath(path)) or "."
    for test in tests:
        save_path = os.path.join(out_dir, f"fft_plot_{test['name']}.png")
        plot_test(test, save_path=save_path)


if __name__ == "__main__":
    main()