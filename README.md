# PATBox

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

PATBox wraps k-Wave forward simulation and a collection of delay-and-sum style reconstruction algorithms (DAS, DMAS, UBP, VDAS, iterative methods, and others) behind a small unified API.

It is especially useful for quickly comparing reconstruction algorithms and seeing how changes to simulation settings (sensor geometry, noise, grid) and reconstruction options (algorithm, envelopes, iterations) affect image quality — most defaults live in `params.yaml`, so you can swap settings and re-run without editing code.

## Requirements

- MATLAB R2019b or later (Image Processing Toolbox)
- [k-Wave](http://www.k-wave.org/) for forward simulation
- Optional: NVIDIA GPU + Parallel Computing Toolbox (used by k-Wave GPU mode)

## Installation

**1. Add PATBox to the path:**

```matlab
addpath('/path/to/PATBox')
```

**2. Configure once:**

```matlab
install_patbox('/path/to/k-Wave')
```

This saves the k-Wave path to `PATBox/kwave_path.txt` and adds a startup hook for new MATLAB sessions.

**That's it.** Every new MATLAB session loads PATBox automatically — you do not need to call `install_patbox()` again.

The only exception is the **first session**: run `addpath('/path/to/PATBox')` once before step 2 so MATLAB can find `install_patbox`. After the startup hook is installed, new sessions pick up PATBox without `addpath`.

### Run examples

```matlab
cd('/path/to/PATBox/examples')
reconstruct_image
```

Edit `PATBox/params.yaml` to change reconstruction defaults (`AlgorithmName`, `UpdateMethod`, …) and simulation settings (`SensorType`, `GridSize`, `UseSimulation`, `SensorDataPath`, …) before running the examples.

---

## Configuration (`params.yaml`)

Default values for reconstruction, simulation, and benchmarking live in `params.yaml`:

```yaml
reconstruction:
  AlgorithmName: DMAS
  remove_negatives: true
  bandpass_filter: false
  frequency_low: 0.1e6
  frequency_high: 10.0e6
  SaveOutput: true
  OutputDir: examples/output/recon
  iterative:
    NumIterations: 5
    UpdateMethod: TR

simulation:
  UseSimulation: true          # false = load SensorDataPath instead of k-Wave
  SensorDataPath: ""            # .mat with sim struct or legacy sensor fields
  ImagePath: data/example.bmp
  SensorType: linear            # linear | square | circular | arc
  NoiseModel: awgn
  TargetSNRdB: 20               # preferred noise control (NoiseLevel is deprecated)
  GridSize: 512
  MaxFrequency: 5.0e6
  SoundSpeed: 1500
  Density: 1000
  NumTransducers: 128
  Pitch: 3.0e-4
  Kerf: 3.0e-5

benchmark_algorithms:
  IncludeIterative: true
  envelope_signal: false
  remove_negatives: true
  bandpass_filter: false
  frequency_low: 0.1e6
  frequency_high: 10.0e6
  Algorithms:
    - DAS
    - DMAS
  Metrics:
    - CompTime
    - RMSE
    - PSNR
  OutputPath: examples/output/algorithm_benchmark_table.png
  SaveCsv: true
  CsvPath: examples/output/algorithm_benchmark_table.csv
```

Use `reconParameters()`, `simParameters()`, and `benchmarkParameters()` to read these in MATLAB, or override any field via name-value pairs at runtime.

To reconstruct from saved sensor data instead of simulating:

```yaml
simulation:
  UseSimulation: false
  SensorDataPath: data/my_sensor_data.mat
```

```matlab
[p0_recon, sim, info, metrics] = patReconImage();   % reads params.yaml
```

---

## Quick start

```matlab
install_patbox('/path/to/k-Wave')

[p0_recon, sim, info, metrics] = patReconImage('data/example.bmp', 'Algorithm', 'DMAS');

fprintf('Algorithm: %s | PSNR: %.2f dB | SSIM: %.3f\n', ...
    info.algorithm, metrics.psnr, metrics.ssim);
```

With simulation options:

```matlab
[p0_recon, sim, info, metrics] = patReconImage('data/example.bmp', ...
    'SensorType', 'linear', ...
    'TargetSNRdB', 20, ...
    'Algorithm', 'DS-DMAS');
```

Relative paths like `'data/example.bmp'` are resolved from the PATBox folder.

---

## Minimal example (step-by-step)

```matlab
install_patbox()

img_path = fullfile(fileparts(which('patSimulate')), 'data', 'example.bmp');
sim = patSimulate(img_path, 'SensorType', 'linear', 'TargetSNRdB', 20);

[p0_recon, info] = patReconstruct(sim, 'DS-DMAS');
metrics = patEvaluate(p0_recon, sim.source.p0);
fprintf('PSNR: %.2f dB\n', metrics.psnr);
```

---

## API overview

| Function | Role |
|----------|------|
| `install_patbox` | Add PATBox to the path; configure/load k-Wave |
| `patSimulate` | Physics-aware forward simulation (`SensorType`: linear, square, circular, arc) |
| `patReconstruct` | Unified reconstruction entry point (accepts sim struct or raw inputs) |
| `patReconImage` | Simulate + reconstruct + evaluate in one call |
| `patListAlgorithms` | List supported algorithm names |
| `patEvaluate` | MSE, RMSE, PSNR, SSIM, SNR, sharpness, UIQI, CNR, SBR |
| `renderAlgorithmTable` | Render a benchmark-style results table figure |

### Supported algorithms

`DAS`, `CF-DAS`, `DMAS`, `DS-DMAS`, `MV-DAS`, `VDAS`, `SCF-DAS`, `CFMV-DAS`, `FBP`, `UBP`, `DMAS-UBP`, `VDAS-UBP`, `TR`, `ITERATIVE-DAS`, `ITERATIVE-TR`

Algorithm-specific options (`remove_negatives`, `NumIterations`, etc.) pass through as name-value pairs to `patReconstruct`.

---

## Package layout

```
PATBox/
  install_patbox.m           % path setup + k-Wave config
  patSimulate.m              % forward sim API (physical core)
  patReconstruct.m           % main recon API
  patReconImage.m            % simulate + reconstruct + evaluate
  patEvaluate.m              % image quality metrics
  params.yaml                % default reconstruction + simulation parameters
  recon/                     % reconstruction .m files
  simulation/                % forward_simulation_physical + legacy wrappers
  physics/                   % medium + initial-pressure builders
  geometry/                  % physical sensor geometry
  noise/                     % acquisition / noise model
  utils/                     % helpers (simParameters, loadSimulation, ...)
  examples/
  data/
```

---

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for the full text.

[k-Wave](http://www.k-wave.org/) is a separate third-party dependency with its own license terms.
