% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Reconstruction Algorithm Benchmarking Framework
% Authors:   Bahareh Khishkhah & Parsa Shahidi
% Date:      June 2026
%
% Description:
%   This script serves as the main evaluation framework for PATBox. It auto-
%   matches the execution of multiple photoacoustic image reconstruction 
%   algorithms under identical simulation baselines, computes quantitative 
%   performance metrics against the ground truth, and exports a comprehensive 
%   comparative benchmark tables in visual and CSV formats.
% =========================================================================

close all;
clc;

patbox_root = fileparts(fileparts(mfilename('fullpath')));
addpath(patbox_root);
install_patbox();

benchmark_cfg = benchmarkParameters();
sim_cfg = simParameters();
algorithms = benchmark_cfg.Algorithms;
metric_names = benchmark_cfg.Metrics;

img_path = fullfile(patbox_root, 'data', 'example.bmp');
if ~exist(img_path, 'file')
    img_path = fullfile(fileparts(patbox_root), 'simulation', '3.bmp');
end
if ~exist(img_path, 'file')
    error('Set img_path to a vessel BMP before running this example.');
end

table_cols = [{'Algorithm'}, metric_names];
results_table = table('Size', [0, numel(table_cols)], ...
    'VariableTypes', [{'string'}, repmat({'double'}, 1, numel(metric_names))], ...
    'VariableNames', table_cols);

fprintf('Running forward simulation (%s sensor)...\n', sim_cfg.SensorType);
[sensor_data, sensor, kgrid, source, ~, sound_speed] = patSimulate(img_path);

p0_ground_truth = source.p0;

fprintf('\nStarting reconstruction loop...\n');
for i = 1:numel(algorithms)
    algo_name = algorithms{i};
    fprintf('Running %s... ', algo_name);

    recon_args = benchmarkReconArgs(benchmark_cfg);
    [p0_recon, info] = patReconstruct(sensor_data, sensor, kgrid, ...
        sound_speed, algo_name, recon_args{:});
    metrics = patEvaluate(p0_recon, p0_ground_truth);

    row_values = cell(1, numel(table_cols));
    row_values{1} = string(algo_name);
    for m = 1:numel(metric_names)
        row_values{m + 1} = getBenchmarkMetricValue(metric_names{m}, metrics, info);
    end
    new_row = cell2table(row_values, 'VariableNames', table_cols);
    results_table = [results_table; new_row]; %#ok<AGROW>

    fprintf('Done! (t = %.2f s)\n', info.elapsed_seconds);
end

output_path = resolvePatboxOutputPath(benchmark_cfg.OutputPath);
output_dir = fileparts(output_path);
if output_dir ~= "" && ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

renderAlgorithmTable(results_table, output_path);

if benchmark_cfg.SaveCsv
    csv_path = resolvePatboxOutputPath(benchmark_cfg.CsvPath);
    saveBenchmarkCsv(results_table, csv_path);
end
