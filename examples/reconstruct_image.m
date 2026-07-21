% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Minimal Forward Simulation and Image Reconstruction Pipeline
% Authors:   Parsa Shahidi  &  Bahareh Khishkhah
% Date:      June 2026
%
% Description:
%   This script serves as the minimal demonstration example for PATBox. It 
%   orchestrates the end-to-end photoacoustic pipeline: launching a baseline 
%   forward simulation from a vascular target, applying a single-algorithm 
%   reconstruction, reporting primary quantitative accuracy metrics, and 
%   generating a side-by-side graphical comparison.
% =========================================================================

close all;
clc;

patbox_root = fileparts(fileparts(mfilename('fullpath')));
addpath(patbox_root);
install_patbox();

algorithm = reconParameters('AlgorithmName');
sim_cfg = simParameters();

img_path = fullfile(patbox_root, 'data', 'example.bmp');
if ~exist(img_path, 'file')
    img_path = fullfile(fileparts(patbox_root), 'simulation', '3.bmp');
end
if ~exist(img_path, 'file')
    img_path = fullfile(fileparts(patbox_root), 'rotation_method', 'ground_truth', '3.bmp');
end
if ~exist(img_path, 'file')
    error(['No example image found. Place a vessel BMP at:\n  %s\n' ...
           'or set img_path in this script.'], fullfile(patbox_root, 'data', 'example.bmp'));
end

fprintf('Simulating with %s sensor array...\n', sim_cfg.SensorType);
[sensor_data, sensor, kgrid, source, ~, sound_speed] = patSimulate(img_path);

fprintf('Reconstructing with %s...\n', algorithm);
[p0_recon, info] = patReconstruct(sensor_data, sensor, kgrid, sound_speed);
metrics = patEvaluate(p0_recon, source.p0);

fprintf('Algorithm: %s\n', info.algorithm);
fprintf('Time: %.2f s\n', info.elapsed_seconds);
fprintf('RMSE: %.4f | PSNR: %.2f dB | SSIM: %.3f | SNR: %.2f dB\n', ...
    metrics.rmse, metrics.psnr, metrics.ssim, metrics.snr);

figure;
colormap(hot);
subplot(1, 2, 1);
imagesc(kgrid.y_vec * 1e3, kgrid.x_vec * 1e3, mat2gray(source.p0));
axis image;
title('Ground truth p_0', 'FontSize', 16);
xlabel('y [mm]'); ylabel('x [mm]');

subplot(1, 2, 2);
imagesc(kgrid.y_vec * 1e3, kgrid.x_vec * 1e3, mat2gray(p0_recon));
axis image;
title(sprintf('%s (RMSE %.4f, PSNR %.1f dB, SSIM %.3f)', ...
    info.algorithm, metrics.rmse, metrics.psnr, metrics.ssim), 'FontSize', 16);
xlabel('y [mm]'); ylabel('x [mm]');
