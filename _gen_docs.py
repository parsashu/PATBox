#!/usr/bin/env python3
"""Generate PATBox GitHub Pages documentation."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
GITHUB = "https://github.com/parsashu/PATBox"

NAV = [
    ("index.html", "Overview"),
    ("install.html", "Install"),
    ("quickstart.html", "Quick start"),
    ("simulation.html", "Simulation"),
    ("modules.html", "Modules"),
    ("reconstruction.html", "Reconstruction"),
    ("architecture.html", "Architecture"),
    ("api.html", "API"),
    ("configuration.html", "Configuration"),
    ("examples.html", "Examples"),
    ("faq.html", "FAQ"),
]


def shell(active: str, title: str, description: str, body: str) -> str:
    links = []
    for href, label in NAV:
        cls = ' class="active"' if href == active else ""
        links.append(f'<a href="{href}"{cls}>{label}</a>')
    nav = "\n        ".join(links)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{title} · PATBox</title>
  <meta name="description" content="{description}" />
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&amp;family=IBM+Plex+Sans:wght@400;500;600;700&amp;family=Source+Serif+4:opsz,wght@8..60,500;8..60,600;8..60,650&amp;display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="assets/style.css" />
  <link rel="icon" href="assets/logo.svg" type="image/svg+xml" />
</head>
<body>
  <div class="app">
    <aside class="sidebar" id="sidebar">
      <a class="brand" href="index.html">
        <img class="brand-mark" src="assets/logo.svg" alt="" width="32" height="32" />
        <span class="brand-text">PATBox <small>v0.6.7</small></span>
      </a>
      <nav class="side-nav" aria-label="Documentation">
        {nav}
      </nav>
      <a class="side-github" href="{GITHUB}" target="_blank" rel="noopener">GitHub</a>
    </aside>
    <div class="shell">
      <header class="topbar">
        <button class="nav-toggle" type="button" aria-label="Open menu" aria-controls="sidebar">Menu</button>
        <div class="topbar-title">{title}</div>
        <a class="topbar-github" href="{GITHUB}" target="_blank" rel="noopener">GitHub</a>
      </header>
      <main class="content">
{body}
      </main>
      <footer class="site-footer">
        <div class="inner">
          <div class="footer-brand">
            <img src="assets/logo.svg" alt="" width="24" height="24" />
            <span>PATBox · MIT · <a href="http://www.k-wave.org/" target="_blank" rel="noopener">k-Wave</a></span>
          </div>
          <div><a href="{GITHUB}">github.com/parsashu/PATBox</a></div>
        </div>
      </footer>
    </div>
  </div>
  <div class="sidebar-backdrop" id="sidebar-backdrop" hidden></div>
  <script src="assets/site.js"></script>
</body>
</html>
"""


PAGES = {}

PAGES["index.html"] = (
    "Overview",
    "PATBox is a MATLAB toolbox for photoacoustic forward simulation and reconstruction.",
    r"""
    <section class="hero hero-simple">
      <div class="kicker">MATLAB · photoacoustic</div>
      <h1>PATBox</h1>
      <p class="lead">
        Simulate with k-Wave. Reconstruct with fifteen algorithms. Configure from <code>params.yaml</code>.
      </p>
      <div class="hero-actions">
        <a class="btn btn-primary" href="install.html">Install</a>
        <a class="btn btn-ghost" href="quickstart.html">Quick start</a>
      </div>
    </section>

    <figure class="pipeline-figure">
      <img src="assets/recon/comparison_montage.png" alt="Phantom and reconstruction comparison" width="932" height="652" loading="lazy" />
    </figure>
    <p class="figure-caption">Example1 phantom and circular-array reconstructions.</p>

<pre><code>install_patbox('/path/to/k-Wave')
[p0, sim, info, metrics] = patReconImage('data/Example1.bmp', ...
    'SensorType', 'circular', 'TargetSNRdB', 20, 'Algorithm', 'DMAS');</code></pre>
""",
)

PAGES["install.html"] = (
    "Install",
    "Install PATBox and configure k-Wave for MATLAB.",
    """
    <p class="kicker">Setup</p>
    <h1 class="page-title">Installation</h1>
    <p class="lead">PATBox runs in MATLAB and uses k-Wave for acoustic wave propagation.</p>

    <h2>Requirements</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Component</th><th>Notes</th></tr></thead>
        <tbody>
          <tr><td>MATLAB R2019b+</td><td>Declared in <code>info.xml</code></td></tr>
          <tr><td>Image Processing Toolbox</td><td><code>ssim</code>, <code>mat2gray</code>, image I/O</td></tr>
          <tr><td><a href="http://www.k-wave.org/">k-Wave</a></td><td>Required for forward simulation</td></tr>
          <tr><td>GPU (optional)</td><td>Parallel Computing Toolbox + NVIDIA GPU for <code>gpuArray-single</code></td></tr>
          <tr><td>Signal Processing Toolbox (optional)</td><td>Only if <code>bandpass_filter=true</code></td></tr>
        </tbody>
      </table>
    </div>

    <h2>1. Clone the repository</h2>
<pre><code>git clone https://github.com/parsashu/PATBox.git
cd PATBox</code></pre>

    <h2>2. Add PATBox to the MATLAB path</h2>
<pre><code>addpath('/absolute/path/to/PATBox')</code></pre>

    <h2>3. Configure k-Wave</h2>
<pre><code>install_patbox('/absolute/path/to/k-Wave')</code></pre>
    <p>This will:</p>
    <ul>
      <li>Add PATBox folders: <code>recon</code>, <code>simulation</code>, <code>physics</code>, <code>geometry</code>, <code>noise</code>, <code>utils</code></li>
      <li>Add k-Wave to the MATLAB path</li>
      <li>Write <code>kwave_path.txt</code> in the package root</li>
      <li>Append a <code>% PATBox auto-load</code> block to MATLAB <code>startup.m</code></li>
    </ul>
    <div class="callout">
      <p>After the first successful install, <strong>new MATLAB sessions load PATBox automatically</strong>.</p>
    </div>

    <h2>4. Verify</h2>
<pre><code>which patSimulate
which kspaceFirstOrder2D
patVersion
patListAlgorithms</code></pre>

    <h2>Running examples</h2>
<pre><code>cd('/absolute/path/to/PATBox/examples')
reconstruct_image</code></pre>

    <h2>Troubleshooting</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Symptom</th><th>Fix</th></tr></thead>
        <tbody>
          <tr><td><code>Undefined function 'patSimulate'</code></td><td>Run <code>addpath</code> then <code>install_patbox</code></td></tr>
          <tr><td><code>Undefined function 'kspaceFirstOrder2D'</code></td><td>Pass a valid k-Wave folder to <code>install_patbox</code></td></tr>
          <tr><td>GPU warnings</td><td>PATBox falls back to CPU <code>single</code> when no usable GPU is found</td></tr>
          <tr><td>Stale YAML values</td><td>Run <code>clear functions</code> after editing <code>params.yaml</code></td></tr>
        </tbody>
      </table>
    </div>
""",
)

PAGES["quickstart.html"] = (
    "Quick start",
    "Run your first PATBox simulation and reconstruction.",
    """
    <p class="kicker">Usage</p>
    <h1 class="page-title">Quick start</h1>
    <p class="lead">Three ways to use PATBox: one-shot API, step-by-step pipeline, or YAML-driven examples.</p>

    <h2>1. One-shot: patReconImage</h2>
<pre><code>[p0_recon, sim, info, metrics] = patReconImage('data/Example1.bmp', ...
    'SensorType', 'circular', ...
    'TargetSNRdB', 20, ...
    'Algorithm', 'DMAS');

disp(info)
disp(metrics)</code></pre>

    <h2>2. Step-by-step pipeline</h2>
<pre><code>img = fullfile(fileparts(which('patSimulate')), 'data', 'Example1.bmp');

sim = patSimulate(img, 'SensorType', 'linear', 'TargetSNRdB', 20);
[p0_recon, info] = patReconstruct(sim, 'DS-DMAS');
metrics = patEvaluate(p0_recon, sim.p0_reference);</code></pre>

    <h2>3. Prefer the sim struct</h2>
    <p>Use the single-struct output whenever possible. It carries medium maps, ordered element geometry, clean/system/measured RF, and provenance metadata.</p>
<pre><code>sim = patSimulate(img);           % preferred
[p0, info] = patReconstruct(sim, 'UBP');</code></pre>

    <h2>4. Override parameters</h2>
<pre><code>sim = patSimulate(img, ...
    'SensorType', 'arc', ...
    'SensorArcDeg', 120, ...
    'MediumModel', 'gaussian', ...
    'NoiseModel', 'awgn', ...
    'TargetSNRdB', 15, ...
    'GridSize', 256);

[p0, info] = patReconstruct(sim, 'ITERATIVE-TR', ...
    'NumIterations', 8, ...
    'StepSize', 0.2);</code></pre>

    <h2>5. Load saved sensor data</h2>
<pre><code>sim = patSimulate([], ...
    'UseSimulation', false, ...
    'SensorDataPath', 'path/to/sim.mat');
[p0, info] = patReconstruct(sim, 'DAS');</code></pre>

    <div class="callout">
      <p><strong>Noise tip.</strong> Prefer <code>TargetSNRdB</code> with <code>NoiseModel</code>. Legacy <code>NoiseLevel</code> exists only for old scripts.</p>
    </div>
""",
)

PAGES["simulation.html"] = (
    "Simulation",
    "PATBox forward simulation modules, sensor types, media, and acquisition model.",
    """
    <p class="kicker">Modules</p>
    <h1 class="page-title">Simulation</h1>
    <p class="lead">Forward modeling is centered on <code>forward_simulation_physical</code>, called by <code>patSimulate</code>.</p>

    <h2>Pipeline</h2>
    <ol>
      <li>Design grid (<code>GridSize</code>, <code>Dx/Dy</code> or points-per-wavelength)</li>
      <li>Build acoustic medium (<code>buildAcousticMedium2D</code>)</li>
      <li>Place sensors (<code>buildSensorGeometry2D</code>)</li>
      <li>Build initial pressure (<code>buildInitialPressure2D</code>)</li>
      <li>Run <code>kspaceFirstOrder2D</code></li>
      <li>Combine simulation points into physical-element traces</li>
      <li>Apply acquisition model (<code>applyAcquisitionModel</code>)</li>
    </ol>

    <h2>Module map</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Module</th><th>File</th><th>Role</th></tr></thead>
        <tbody>
          <tr><td>Physical core</td><td><code>simulation/forward_simulation_physical.m</code></td><td>End-to-end 2-D PAT acquisition</td></tr>
          <tr><td>Medium</td><td><code>physics/buildAcousticMedium2D.m</code></td><td>Homogeneous / Gaussian / MAT / segmented media</td></tr>
          <tr><td>Source</td><td><code>physics/buildInitialPressure2D.m</code></td><td>Image, MAT, or absorption×fluence sources</td></tr>
          <tr><td>Geometry</td><td><code>geometry/buildSensorGeometry2D.m</code></td><td>Ordered physical elements + kWaveArray support</td></tr>
          <tr><td>Acquisition</td><td><code>noise/applyAcquisitionModel.m</code></td><td>System impairments + noise models</td></tr>
          <tr><td>Legacy wrappers</td><td><code>forward_simulation_linear/square/circular.m</code></td><td>Deprecated APIs routed through the physical core</td></tr>
        </tbody>
      </table>
    </div>

    <h2>Sensor types</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>SensorType</th><th>Description</th><th>Key options</th></tr></thead>
        <tbody>
          <tr><td><code>linear</code></td><td>Linear array (default near xmin + margin)</td><td><code>NumTransducers</code>, <code>Pitch</code>, <code>Kerf</code>, <code>ElementWidth</code></td></tr>
          <tr><td><code>square</code></td><td>Square aperture around the FOV</td><td><code>NumTransducers</code>, <code>SensorMargin</code></td></tr>
          <tr><td><code>circular</code></td><td>Closed circular array</td><td><code>SensorRadius</code>, <code>NumTransducers</code></td></tr>
          <tr><td><code>arc</code></td><td>Limited-view arc</td><td><code>SensorArcDeg</code>, <code>SensorStartAngleDeg</code></td></tr>
        </tbody>
      </table>
    </div>

    <h2>Sensor models</h2>
    <p><code>SensorModel</code>: <code>auto</code> | <code>kwave_array</code> | <code>rasterized</code> | <code>point</code> | <code>cartesian_point</code></p>
    <p><code>auto</code> selects <code>kWaveArray</code> when available, otherwise rasterized finite elements.</p>

    <h2>Media</h2>
    <ul>
      <li><code>homogeneous</code> — constant sound speed / density</li>
      <li><code>gaussian</code> — correlated random heterogeneity (<code>SoundSpeedStd</code>, <code>DensityStd</code>, <code>CorrelationLength</code>)</li>
      <li><code>mat</code> / <code>segmented</code> — load maps from file</li>
    </ul>
    <p>Attenuation uses <code>AlphaCoeff</code>, <code>AlphaPower</code>, and <code>AlphaMode</code> (<code>full</code>, <code>no_dispersion</code>, <code>no_absorption</code>). k-Wave rejects <code>AlphaPower = 1</code> with full dispersion — use <code>no_dispersion</code> for that case.</p>

    <h2>Initial pressure sources</h2>
    <ul>
      <li><code>normalized_image</code> — BMP/PNG scaled by <code>P0Scale</code> (default convenience mode)</li>
      <li><code>initial_pressure_mat</code> — load a numeric map from a MAT file</li>
      <li><code>absorption_fluence</code> — build \(p_0\) from absorption and fluence maps</li>
    </ul>

    <h2>Acquisition / noise</h2>
    <p><code>NoiseModel</code>: <code>none</code> | <code>awgn</code> | <code>colored</code> | <code>measured</code> | <code>hybrid</code></p>
    <p>Prefer <code>TargetSNRdB</code>. Additional knobs include channel gain, time/trigger jitter, crosstalk, dead channels, interference tones, and ADC bit depth.</p>

    <h2>Returned sim struct</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Field</th><th>Meaning</th></tr></thead>
        <tbody>
          <tr><td><code>sensor_data</code></td><td>Measured RF (<code>.p</code>), physical elements × time</td></tr>
          <tr><td><code>sensor_data_clean</code></td><td>Ideal element traces before acquisition model</td></tr>
          <tr><td><code>sensor_data_system</code></td><td>System-impaired traces before additive noise</td></tr>
          <tr><td><code>sensor</code> / <code>sensor_geometry</code></td><td>Ordered element geometry used for reconstruction</td></tr>
          <tr><td><code>kgrid</code>, <code>source</code>, <code>medium</code></td><td>k-Wave objects / maps</td></tr>
          <tr><td><code>p0_reference</code></td><td>Ground-truth initial pressure</td></tr>
          <tr><td><code>info</code></td><td>Provenance, aperture audit, acquisition metadata</td></tr>
        </tbody>
      </table>
    </div>
""",
)

PAGES["reconstruction.html"] = (
    "Reconstruction",
    "PATBox reconstruction algorithms and shared options.",
    """
    <p class="kicker">Algorithms</p>
    <h1 class="page-title">Reconstruction</h1>
    <p class="lead">All algorithms are dispatched by <code>patReconstruct</code> through <code>getReconFunction</code>.</p>

    <h2>Example reconstructions</h2>
    <p class="muted">Same circular-array acquisition of <code>data/Example1.bmp</code>, reconstructed with different algorithms.</p>
    <figure class="pipeline-figure">
      <img src="assets/recon/comparison_montage.png" alt="Side-by-side reconstruction comparison montage" width="932" height="652" loading="lazy" />
    </figure>
    <p class="figure-caption">Overview: phantom vs TR, UBP, DMAS, DAS, FBP.</p>
    <div class="gallery gallery-4">
      <figure>
        <img src="assets/recon/phantom_example1.png" alt="Example1 vessel phantom" width="512" height="512" loading="lazy" />
        <figcaption>Phantom · Example1</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/das.png" alt="DAS reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>DAS</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/dmas.png" alt="DMAS reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>DMAS</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/ds_dmas.png" alt="DS-DMAS reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>DS-DMAS</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/cf_das.png" alt="CF-DAS reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>CF-DAS</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/vdas.png" alt="VDAS reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>VDAS</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/fbp.png" alt="FBP reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>FBP</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/ubp.png" alt="UBP reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>UBP</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/tr.png" alt="Time-reversal reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>TR</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/scf_das.png" alt="SCF-DAS reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>SCF-DAS</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/dmas_ubp.png" alt="DMAS-UBP reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>DMAS-UBP</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/mv_das.png" alt="MV-DAS reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>MV-DAS</figcaption>
      </figure>
    </div>

    <h2>Supported names</h2>
<pre><code>patListAlgorithms
% DAS, CF-DAS, DMAS, DS-DMAS, MV-DAS, VDAS, SCF-DAS, CFMV-DAS,
% FBP, UBP, DMAS-UBP, VDAS-UBP, TR, ITERATIVE-DAS, ITERATIVE-TR</code></pre>

    <h2>Algorithm reference</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Name</th><th>File</th><th>Description</th></tr></thead>
        <tbody>
          <tr><td><code>DAS</code></td><td><code>recon/das.m</code></td><td>Delay-and-sum with subsample ToF interpolation</td></tr>
          <tr><td><code>CF-DAS</code></td><td><code>recon/cfdas.m</code></td><td>Coherence-factor–weighted DAS</td></tr>
          <tr><td><code>DMAS</code></td><td><code>recon/dmas.m</code></td><td>Delay-multiply-and-sum (nonlinear)</td></tr>
          <tr><td><code>DS-DMAS</code></td><td><code>recon/ds_dmas.m</code></td><td>Dual-stage DAS within subarrays, DMAS across them</td></tr>
          <tr><td><code>MV-DAS</code></td><td><code>recon/mv_das.m</code></td><td>Minimum-variance / Capon adaptive beamforming</td></tr>
          <tr><td><code>VDAS</code></td><td><code>recon/vdas.m</code></td><td>Variance-weighted DAS</td></tr>
          <tr><td><code>SCF-DAS</code></td><td><code>recon/scf_das.m</code></td><td>Sign-coherence-factor–weighted DAS</td></tr>
          <tr><td><code>CFMV-DAS</code></td><td><code>recon/cfmv_das.m</code></td><td>Coherence × MV hybrid</td></tr>
          <tr><td><code>FBP</code></td><td><code>recon/fbp.m</code></td><td>Filtered back-projection (Ram-Lak)</td></tr>
          <tr><td><code>UBP</code></td><td><code>recon/ubp.m</code></td><td>Xu–Wang universal back-projection</td></tr>
          <tr><td><code>DMAS-UBP</code></td><td><code>recon/dmas_ubp.m</code></td><td>UBP preprocessing + DMAS</td></tr>
          <tr><td><code>VDAS-UBP</code></td><td><code>recon/vdas_ubp.m</code></td><td>UBP preprocessing + variance-weighted DAS</td></tr>
          <tr><td><code>TR</code></td><td><code>recon/time_reversal.m</code></td><td>k-Wave time reversal</td></tr>
          <tr><td><code>ITERATIVE-DAS</code></td><td><code>recon/iterative.m</code></td><td>Iterative updates with DAS adjoint-like steps</td></tr>
          <tr><td><code>ITERATIVE-TR</code></td><td><code>recon/iterative.m</code></td><td>Iterative updates with time-reversal steps</td></tr>
        </tbody>
      </table>
    </div>

    <h2>Shared options</h2>
    <ul>
      <li><code>envelope_signal</code> — Hilbert envelope after reconstruction</li>
      <li><code>remove_negatives</code> — zero negative pressures</li>
      <li><code>bandpass_filter</code>, <code>frequency_low</code>, <code>frequency_high</code></li>
      <li><code>interp_method</code> — <code>nearest</code> | <code>linear</code> | <code>cubic</code></li>
    </ul>

    <h2>Algorithm-specific knobs</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Algorithm</th><th>Options</th></tr></thead>
        <tbody>
          <tr><td>DS-DMAS</td><td><code>num_subarrays</code></td></tr>
          <tr><td>MV-DAS / CFMV-DAS</td><td><code>dl_factor</code></td></tr>
          <tr><td>VDAS / VDAS-UBP</td><td><code>k_power</code></td></tr>
          <tr><td>SCF-DAS</td><td><code>scf_power</code></td></tr>
          <tr><td>ITERATIVE-*</td><td><code>InitialGuess</code>, <code>NumIterations</code>, <code>StepSize</code>, <code>UpdateMethod</code></td></tr>
        </tbody>
      </table>
    </div>

    <h2>Geometry compatibility</h2>
    <p>
      Physics-aware simulations return ordered physical-element traces.
      Current beamformers locate receivers with <code>find(mask)</code>.
      <code>patReconstruct</code> uses <code>legacyCompatibleSensorInputs</code> to snap element centres
      to the grid and reorder channels so legacy engines remain usable.
      UBP-family algorithms keep the geometry struct when needed.
    </p>

    <h2>Saving outputs</h2>
<pre><code>[p0, info] = patReconstruct(sim, 'DMAS', ...
    'SaveOutput', true, ...
    'SaveMat', true, ...
    'SavePng', true, ...
    'OutputDir', 'output/recon');</code></pre>

    <h2>Evaluation metrics</h2>
    <p><code>patEvaluate</code> compares a reconstruction to <code>sim.p0_reference</code> (or any ground-truth map):</p>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Field</th><th>Description</th></tr></thead>
        <tbody>
          <tr><td><code>mse</code> / <code>rmse</code></td><td>Mean / root-mean-square error (after <code>mat2gray</code>)</td></tr>
          <tr><td><code>psnr</code></td><td>Peak signal-to-noise ratio (dB)</td></tr>
          <tr><td><code>ssim</code></td><td>Structural similarity</td></tr>
          <tr><td><code>snr</code></td><td>Signal energy vs error energy (dB)</td></tr>
          <tr><td><code>sharpness</code></td><td>Mean gradient magnitude</td></tr>
          <tr><td><code>uiqi</code></td><td>Universal image quality index</td></tr>
          <tr><td><code>cnr</code></td><td>Contrast-to-noise ratio</td></tr>
          <tr><td><code>sbr</code></td><td>Signal-to-background ratio</td></tr>
        </tbody>
      </table>
    </div>
""",
)

PAGES["architecture.html"] = (
    "Architecture",
    "PATBox package layout and module responsibilities.",
    """
    <p class="kicker">Design</p>
    <h1 class="page-title">Architecture</h1>
    <p class="lead">PATBox is organized so public APIs stay thin while physics, geometry, noise, and reconstruction remain modular.</p>

    <h2>Package layout</h2>
<pre><code>PATBox/
  install_patbox.m
  patSimulate.m / patReconstruct.m / patReconImage.m
  patEvaluate.m / patListAlgorithms.m / patVersion.m
  params.yaml
  recon/           reconstruction engines
  simulation/      physical core + legacy wrappers
  physics/         medium + initial pressure
  geometry/        sensor arrays
  noise/           acquisition model
  utils/           YAML, I/O, helpers
  examples/
  data/
  docs/            this site</code></pre>

    <h2>Call graph (forward + recon)</h2>
<pre><code>patReconImage
  └─ patSimulate
       └─ forward_simulation_physical
            ├─ buildAcousticMedium2D
            ├─ buildSensorGeometry2D
            ├─ buildInitialPressure2D
            ├─ kspaceFirstOrder2D   (k-Wave)
            └─ applyAcquisitionModel
  └─ patReconstruct
       ├─ legacyCompatibleSensorInputs
       ├─ getReconFunction → recon/*.m
       └─ saveReconOutput (optional)
  └─ patEvaluate</code></pre>

    <h2>Design principles</h2>
    <ul>
      <li><strong>Single sim struct</strong> carries everything reconstruction and evaluation need</li>
      <li><strong>YAML defaults</strong> keep scripts short; overrides are name-value pairs</li>
      <li><strong>Physical elements first</strong>: RF is always channels × time after combining</li>
      <li><strong>Auditable acquisition</strong>: ideal, system-impaired, and measured data are stored separately</li>
      <li><strong>Legacy bridges</strong>: old multi-output APIs and mask-based recon still work</li>
    </ul>

    <h2>Utility modules</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Utility</th><th>Purpose</th></tr></thead>
        <tbody>
          <tr><td><code>loadPatboxYaml</code></td><td>Parse/merge <code>params.yaml</code></td></tr>
          <tr><td><code>simParameters</code> / <code>reconParameters</code></td><td>Section accessors</td></tr>
          <tr><td><code>loadSimulation</code></td><td>Load preferred <code>sim</code> MAT files</td></tr>
          <tr><td><code>resolvePatboxPath</code></td><td>Resolve paths relative to package root</td></tr>
          <tr><td><code>applySensorBandpassFilter</code></td><td>Butterworth bandpass on RF</td></tr>
          <tr><td><code>finalizeReconImage</code></td><td>Envelope / remove negatives</td></tr>
          <tr><td><code>renderAlgorithmTable</code></td><td>Benchmark table figure</td></tr>
        </tbody>
      </table>
    </div>
""",
)

PAGES["api.html"] = (
    "API",
    "PATBox public function reference.",
    """
    <p class="kicker">Reference</p>
    <h1 class="page-title">API</h1>
    <p class="lead">Public entry points. Prefer the <code>sim</code> struct form wherever available.</p>

    <h2>install_patbox</h2>
<pre><code>install_patbox('/path/to/k-Wave')
install_patbox()</code></pre>
    <p>Add PATBox + k-Wave to the path, persist k-Wave location, enable auto-load.</p>

    <h2>patSimulate</h2>
<pre><code>sim = patSimulate()
sim = patSimulate(img_path)
sim = patSimulate(..., 'SensorType', 'linear', 'TargetSNRdB', 20)
[sensor_data, sensor, kgrid, source, p0_reference, sound_speed] = patSimulate(...)
% nargout ≥ 7/8/9 also returns info, medium, sensor_geometry</code></pre>
    <p>Runs <code>forward_simulation_physical</code> or loads saved data when <code>UseSimulation=false</code>.</p>

    <h2>patReconstruct</h2>
<pre><code>[p0_recon, info] = patReconstruct(sim, 'DMAS')
[p0_recon, info] = patReconstruct(sensor_data, sensor, kgrid, sound_speed, 'DMAS')
[p0_recon, info] = patReconstruct(..., 'Algorithm', 'DS-DMAS', 'remove_negatives', true)</code></pre>
    <p><code>info</code> includes <code>algorithm</code>, <code>elapsed_seconds</code>, and optional save paths.</p>

    <h2>patReconImage</h2>
<pre><code>[p0_recon, sim, info, metrics] = patReconImage()
[p0_recon, sim, info, metrics] = patReconImage(img_path, ...
    'SensorType', 'linear', 'TargetSNRdB', 20, 'Algorithm', 'DMAS')</code></pre>
    <p>Simulate (or load) → reconstruct → evaluate. Name-value pairs may be simulation or reconstruction fields.</p>

    <h2>patEvaluate</h2>
<pre><code>metrics = patEvaluate(p0_recon, p0_ground_truth)</code></pre>
    <p>Returns <code>mse</code>, <code>rmse</code>, <code>psnr</code>, <code>ssim</code>, <code>snr</code>, <code>sharpness</code>, <code>uiqi</code>, <code>cnr</code>, <code>sbr</code>.</p>

    <h2>patListAlgorithms</h2>
<pre><code>names = patListAlgorithms()</code></pre>

    <h2>patVersion</h2>
<pre><code>[versionText, details] = patVersion()</code></pre>

    <h2>Helpers</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Function</th><th>Purpose</th></tr></thead>
        <tbody>
          <tr><td><code>simParameters</code> / <code>reconParameters</code></td><td>Read YAML sections</td></tr>
          <tr><td><code>loadSimulation</code></td><td>Load a saved <code>sim</code> MAT</td></tr>
          <tr><td><code>getReconFunction</code></td><td>Map algorithm name → handle</td></tr>
          <tr><td><code>saveReconOutput</code></td><td>Write MAT/PNG outputs</td></tr>
          <tr><td><code>renderAlgorithmTable</code></td><td>Draw benchmark tables</td></tr>
        </tbody>
      </table>
    </div>
""",
)

PAGES["configuration.html"] = (
    "Configuration",
    "Complete PATBox params.yaml reference for simulation and reconstruction.",
    r"""
    <p class="kicker">params.yaml</p>
    <h1 class="page-title">Configuration</h1>
    <p class="lead">Defaults live in <code>params.yaml</code> at the package root. Edit the file or override any field via name-value pairs.</p>

    <h2>Reading defaults in MATLAB</h2>
<pre><code>sim_cfg = simParameters();
recon_cfg = reconParameters();
algo = reconParameters('AlgorithmName');
bench = benchmarkParameters();
multi = multiReconParameters();</code></pre>

    <div class="callout">
      <p>After editing <code>params.yaml</code>, run <code>clear functions</code> so MATLAB reloads the YAML parser cache.</p>
    </div>

    <h2>reconstruction</h2>
<pre><code>reconstruction:
  AlgorithmName: DMAS
  envelope_signal: false
  remove_negatives: true
  bandpass_filter: false
  frequency_low: 0.1e6
  frequency_high: 10.0e6
  SaveOutput: false
  SaveMat: true
  SavePng: true
  OutputDir: output/recon
  OutputSuffix: ""
  iterative:
    interp_method: linear
    InitialGuess: DMAS
    NumIterations: 5
    StepSize: 0.25
    UpdateMethod: TR</code></pre>

    <h2>simulation — I/O and source</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Field</th><th>Default</th><th>Meaning</th></tr></thead>
        <tbody>
          <tr><td><code>UseSimulation</code></td><td><code>true</code></td><td>Run k-Wave; <code>false</code> loads <code>SensorDataPath</code></td></tr>
          <tr><td><code>ImagePath</code></td><td><code>data/Example1.bmp</code></td><td>Default phantom image</td></tr>
          <tr><td><code>SourceModel</code></td><td><code>normalized_image</code></td><td><code>normalized_image</code> | <code>initial_pressure_mat</code> | <code>absorption_fluence</code></td></tr>
          <tr><td><code>P0Scale</code></td><td><code>2</code></td><td>Scale for normalized images</td></tr>
          <tr><td><code>Gruneisen</code></td><td><code>0.12</code></td><td>Used with absorption×fluence sources</td></tr>
          <tr><td><code>RandomSeed</code></td><td><code>1</code></td><td>Reproducible media / noise draws</td></tr>
        </tbody>
      </table>
    </div>

    <h2>simulation — grid and solver</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Field</th><th>Default</th><th>Meaning</th></tr></thead>
        <tbody>
          <tr><td><code>GridSize</code> / <code>GridSizeX/Y</code></td><td>512 / 512×520</td><td>Computational grid size</td></tr>
          <tr><td><code>Dx</code> / <code>Dy</code></td><td><code>0</code></td><td>Explicit spacing; <code>0</code> derives from PPW</td></tr>
          <tr><td><code>PointsPerWavelength</code></td><td><code>4</code></td><td>Spatial sampling vs <code>MaxFrequency</code></td></tr>
          <tr><td><code>CFL</code></td><td><code>0.2</code></td><td>Time-step stability number</td></tr>
          <tr><td><code>PMLSize</code></td><td><code>20</code></td><td>Absorbing boundary thickness</td></tr>
          <tr><td><code>DataCast</code></td><td><code>gpuArray-single</code></td><td>Falls back to CPU <code>single</code> if needed</td></tr>
          <tr><td><code>MaxFrequency</code></td><td><code>5e6</code></td><td>Design frequency for grid spacing</td></tr>
        </tbody>
      </table>
    </div>

    <h2>simulation — medium</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Field</th><th>Default</th><th>Meaning</th></tr></thead>
        <tbody>
          <tr><td><code>MediumModel</code></td><td><code>homogeneous</code></td><td><code>homogeneous</code> | <code>gaussian</code> | <code>mat</code> | <code>segmented</code></td></tr>
          <tr><td><code>SoundSpeed</code> / <code>Density</code></td><td>1500 / 1000</td><td>Baseline acoustic properties</td></tr>
          <tr><td><code>SoundSpeedStd</code> / <code>DensityStd</code></td><td>20 / 15</td><td>Gaussian heterogeneity std</td></tr>
          <tr><td><code>CorrelationLength</code></td><td><code>1e-3</code></td><td>Heterogeneity correlation length (m)</td></tr>
          <tr><td><code>AlphaCoeff</code> / <code>AlphaPower</code></td><td>0 / 1.5</td><td>Absorption (k-Wave units)</td></tr>
          <tr><td><code>AlphaMode</code></td><td><code>full</code></td><td><code>full</code> | <code>no_dispersion</code> | <code>no_absorption</code></td></tr>
        </tbody>
      </table>
    </div>

    <h2>simulation — array</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Field</th><th>Default</th><th>Meaning</th></tr></thead>
        <tbody>
          <tr><td><code>SensorType</code></td><td><code>linear</code></td><td><code>linear</code> | <code>square</code> | <code>circular</code> | <code>arc</code></td></tr>
          <tr><td><code>SensorModel</code></td><td><code>auto</code></td><td><code>auto</code> | <code>kwave_array</code> | <code>rasterized</code> | <code>point</code> | <code>cartesian_point</code></td></tr>
          <tr><td><code>NumTransducers</code></td><td><code>128</code></td><td>Total physical elements</td></tr>
          <tr><td><code>Pitch</code> / <code>Kerf</code> / <code>ElementWidth</code></td><td>0.3 / 0.03 / 0.27 mm</td><td>Linear-array geometry</td></tr>
          <tr><td><code>SensorArcDeg</code></td><td><code>180</code></td><td>Arc span (degrees)</td></tr>
          <tr><td><code>ReconstructionGeometryMode</code></td><td><code>calibrated</code></td><td><code>calibrated</code> or <code>nominal</code> for recon</td></tr>
          <tr><td><code>CenterFrequency</code></td><td><code>5e6</code></td><td>Element centre frequency</td></tr>
          <tr><td><code>FractionalBandwidthPercent</code></td><td><code>80</code></td><td>Bandwidth for impulse response</td></tr>
        </tbody>
      </table>
    </div>

    <h2>simulation — acquisition / noise</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Field</th><th>Default</th><th>Meaning</th></tr></thead>
        <tbody>
          <tr><td><code>NoiseModel</code></td><td><code>awgn</code></td><td><code>none</code> | <code>awgn</code> | <code>colored</code> | <code>measured</code> | <code>hybrid</code></td></tr>
          <tr><td><code>TargetSNRdB</code></td><td><code>20</code></td><td>Preferred noise control</td></tr>
          <tr><td><code>NoiseLevel</code></td><td><code>0.1</code></td><td>Deprecated; prefer <code>TargetSNRdB</code></td></tr>
          <tr><td><code>NoiseScaling</code></td><td><code>global</code></td><td><code>global</code> or <code>per_channel</code></td></tr>
          <tr><td><code>ChannelGainStd</code></td><td><code>0</code></td><td>Lognormal element sensitivity</td></tr>
          <tr><td><code>TimeJitterStd</code> / <code>TriggerJitterStd</code></td><td>0</td><td>Per-channel / common timing skew</td></tr>
          <tr><td><code>CrosstalkFraction</code></td><td><code>0</code></td><td>Nearest-neighbour crosstalk</td></tr>
          <tr><td><code>DeadChannelFraction</code></td><td><code>0</code></td><td>Fraction of dead channels</td></tr>
          <tr><td><code>ADCBitDepth</code></td><td><code>0</code></td><td><code>0</code> disables quantisation</td></tr>
        </tbody>
      </table>
    </div>

    <h2>examples sections</h2>
    <p><code>benchmark_algorithms</code> and <code>multi_reconstruction</code> configure algorithm lists, metrics, envelopes, and output paths for scripts under <code>examples/</code>.</p>
""",
)

PAGES["modules.html"] = (
    "Modules",
    "Detailed explanation of PATBox physics, geometry, noise, simulation, and util modules.",
    r"""
    <p class="kicker">Code map</p>
    <h1 class="page-title">Modules</h1>
    <p class="lead">Each folder is a self-contained concern. Public scripts stay thin; modules own the physics.</p>

    <nav class="toc">
      <a href="#simulation-core">Simulation core</a>
      <a href="#physics">physics/</a>
      <a href="#geometry">geometry/</a>
      <a href="#noise">noise/</a>
      <a href="#recon">recon/</a>
      <a href="#utils">utils/</a>
    </nav>

    <h2 id="simulation-core">Simulation core</h2>
    <div class="panel">
      <h3>forward_simulation_physical.m</h3>
      <p>End-to-end 2-D PAT acquisition. Builds the grid, medium, sensors, and initial pressure; runs <code>kspaceFirstOrder2D</code>; combines integration points into physical-element RF; applies the acquisition model; packages the <code>sim</code> struct.</p>
    </div>
    <div class="panel">
      <h3>Legacy wrappers</h3>
      <p><code>forward_simulation_linear.m</code>, <code>forward_simulation_square.m</code>, <code>forward_simulation_circular.m</code> remain for old scripts. They route through <code>forward_simulation_legacy_adapter.m</code> into the physical core. Prefer <code>patSimulate</code>.</p>
    </div>

    <h2 id="physics">physics/</h2>
    <div class="panel">
      <h3>buildAcousticMedium2D</h3>
      <p>Builds validated sound-speed / density maps for k-Wave.</p>
      <ul>
        <li><code>homogeneous</code> — scalar properties</li>
        <li><code>gaussian</code> — correlated random heterogeneity</li>
        <li><code>mat</code> — load maps from a MAT file</li>
        <li><code>segmented</code> — label map + tissue property table</li>
      </ul>
      <p>Attenuation uses k-Wave units <code>dB/(MHz^α · cm)</code>. Optional coupling layers can be attached to a domain edge.</p>
    </div>
    <div class="panel">
      <h3>buildInitialPressure2D</h3>
      <p>Creates the initial-pressure field from a normalized image, a MAT map, or absorption × fluence × Grüneisen.</p>
    </div>

    <h2 id="geometry">geometry/</h2>
    <div class="panel">
      <h3>buildSensorGeometry2D</h3>
      <p>Builds ordered physical receivers. <code>NumTransducers</code> is always the total element count. Element order is stored in <code>geom.positions</code> and must be preserved for reconstruction.</p>
      <p><code>SensorModel</code> selects how finite elements are represented:</p>
      <ul>
        <li><code>auto</code> — <code>kWaveArray</code> when available, else rasterized</li>
        <li><code>kwave_array</code> — off-grid line elements (recommended)</li>
        <li><code>rasterized</code> — explicit on-grid integration points</li>
        <li><code>point</code> / <code>cartesian_point</code> — one point per element</li>
      </ul>
    </div>

    <h2 id="noise">noise/</h2>
    <div class="panel">
      <h3>applyAcquisitionModel</h3>
      <p>Receive-chain model on <code>[channels × time]</code> data. Separates:</p>
      <ul>
        <li><strong>clean</strong> — ideal integrated element pressure</li>
        <li><strong>system</strong> — gain, jitter, crosstalk, dead channels, interference</li>
        <li><strong>measured</strong> — after additive noise / ADC</li>
      </ul>
      <p>Noise models: <code>none</code>, <code>awgn</code>, <code>colored</code>, <code>measured</code>, <code>hybrid</code>. Prefer <code>TargetSNRdB</code>.</p>
    </div>

    <h2 id="recon">recon/</h2>
    <p>One file per algorithm (or shared iterative engine). Selected through <code>getReconFunction</code>. See <a href="reconstruction.html">Reconstruction</a>.</p>

    <h2 id="utils">utils/</h2>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Helper</th><th>Role</th></tr></thead>
        <tbody>
          <tr><td><code>loadPatboxYaml</code></td><td>Parse <code>params.yaml</code> (inline comments supported)</td></tr>
          <tr><td><code>simParameters</code> / <code>reconParameters</code></td><td>Section accessors</td></tr>
          <tr><td><code>benchmarkParameters</code> / <code>multiReconParameters</code></td><td>Example script configs</td></tr>
          <tr><td><code>loadSimulation</code></td><td>Load preferred <code>sim</code> MAT files</td></tr>
          <tr><td><code>legacyCompatibleSensorInputs</code></td><td>Bridge physical elements → mask-based recon</td></tr>
          <tr><td><code>resolveSensorElementGeometry</code></td><td>Calibrated vs nominal geometry</td></tr>
          <tr><td><code>applySensorBandpassFilter</code></td><td>Optional RF bandpass</td></tr>
          <tr><td><code>finalizeReconImage</code></td><td>Envelope / remove negatives</td></tr>
          <tr><td><code>saveReconOutput</code></td><td>MAT / PNG writers</td></tr>
          <tr><td><code>renderAlgorithmTable</code></td><td>Benchmark table figure</td></tr>
        </tbody>
      </table>
    </div>
""",
)

PAGES["faq.html"] = (
    "FAQ",
    "PATBox troubleshooting and common questions.",
    r"""
    <p class="kicker">Help</p>
    <h1 class="page-title">FAQ</h1>
    <p class="lead">Common setup, simulation, and reconstruction questions.</p>

    <h2>k-Wave is not found</h2>
    <p>Pass an absolute path to the k-Wave root (the folder that contains <code>kspaceFirstOrder2D.m</code>):</p>
<pre><code>install_patbox('/absolute/path/to/k-Wave')
which kspaceFirstOrder2D</code></pre>

    <h2>GPU falls back to CPU</h2>
    <p>If no usable NVIDIA GPU / Parallel Computing Toolbox is available, PATBox uses CPU <code>single</code>. Set <code>DataCast: single</code> in YAML to silence GPU attempts.</p>

    <h2>AlphaPower = 1 with attenuation</h2>
    <p>k-Wave rejects <code>AlphaPower = 1</code> with full dispersion. Use <code>AlphaMode: no_dispersion</code> when you need that power-law exponent.</p>

    <h2>YAML changes are ignored</h2>
<pre><code>clear functions
simParameters()</code></pre>

    <h2>Which pressure reference for metrics?</h2>
<pre><code>metrics = patEvaluate(p0_recon, sim.p0_reference);</code></pre>

    <h2>Limited-view imaging</h2>
<pre><code>sim = patSimulate(img, 'SensorType', 'arc', 'SensorArcDeg', 120);</code></pre>

    <h2>Load experimental / saved RF</h2>
<pre><code>sim = patSimulate([], 'UseSimulation', false, 'SensorDataPath', 'path/to/sim.mat');
[p0, info] = patReconstruct(sim, 'UBP');</code></pre>
    <p>Prefer a MAT file that stores the full <code>sim</code> struct. Legacy field layouts are still accepted by <code>loadSimulation</code>.</p>

    <h2>How does this relate to k-Wave / j-Wave?</h2>
    <p>
      PATBox uses k-Wave for wave propagation (same role j-Wave plays in the JAX ecosystem).
      Documentation follows the same Getting Started → modules → API pattern:
      install, run a minimal IVP-style example, then dive into medium / sensor / acquisition modules.
    </p>
""",
)

PAGES["examples.html"] = (
    "Examples",
    "PATBox example scripts and how to run them.",
    """
    <p class="kicker">Scripts</p>
    <h1 class="page-title">Examples</h1>
    <p class="lead">Example scripts live in <code>examples/</code> and read defaults from <code>params.yaml</code>.</p>

    <h2>Sample outputs</h2>
    <div class="gallery">
      <figure>
        <img src="assets/recon/das.png" alt="DAS reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>DAS</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/dmas.png" alt="DMAS reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>DMAS</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/ubp.png" alt="UBP reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>UBP</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/tr.png" alt="TR reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>TR</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/vdas.png" alt="VDAS reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>VDAS</figcaption>
      </figure>
      <figure>
        <img src="assets/recon/dmas_ubp.png" alt="DMAS-UBP reconstruction" width="512" height="512" loading="lazy" />
        <figcaption>DMAS-UBP</figcaption>
      </figure>
    </div>

    <h2>reconstruct_image.m</h2>
    <p>Minimal end-to-end demo: simulate → reconstruct (default algorithm) → evaluate → side-by-side figure.</p>
<pre><code>cd('/path/to/PATBox/examples')
reconstruct_image</code></pre>

    <h2>multi_reconstructions.m</h2>
    <p>One forward simulation, then a loop over <code>multi_reconstruction.Algorithms</code>. Optionally saves comparison figures and MAT files under <code>output/recon</code>.</p>
<pre><code>multi_reconstructions</code></pre>

    <h2>benchmark_algorithms.m</h2>
    <p>Runs all algorithms listed under <code>benchmark_algorithms</code> on one shared simulation, builds a metrics table, renders a figure, and optionally writes CSV.</p>
<pre><code>benchmark_algorithms</code></pre>

    <h2>Sample data</h2>
    <ul>
      <li><code>data/Example1.bmp</code></li>
      <li><code>data/Example2.bmp</code></li>
      <li><code>data/Example3.bmp</code></li>
    </ul>
    <p>Change <code>simulation.ImagePath</code> in <code>params.yaml</code> to switch phantoms.</p>

    <h2>Typical workflow</h2>
    <ol>
      <li>Edit <code>params.yaml</code> (sensor, noise, algorithm list)</li>
      <li>Run an example script</li>
      <li>Inspect printed metrics and files under <code>output/</code></li>
    </ol>
""",
)


def main() -> None:
    for name, (title, desc, body) in PAGES.items():
        html = shell(name, title, desc, body)
        (ROOT / name).write_text(html, encoding="utf-8")
        print("wrote", name)
    print("done", len(PAGES), "pages")


if __name__ == "__main__":
    main()
