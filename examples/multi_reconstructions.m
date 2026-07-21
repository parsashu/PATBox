% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Multi-Algorithm Reconstruction and Visual Analytics Framework
% Authors:   Bahareh Khishkhah & Parsa Shahidi
% Date:      June 2026
%
% Description:
%   This script executes a comparative evaluation of multiple photoacoustic 
%   reconstruction algorithms, generating per-algorithm diagnostic figures. 
%   It visualizes structural discrepancies using spatial difference maps, 
%   evaluates 6-DoF image quality metrics (MSE, PSNR, SSIM, SNR, Sharpness, 
%   UIQI), and exports quantitative data alongside high-resolution RGB maps.
% =========================================================================

close all;
clc;

patbox_root = fileparts(fileparts(mfilename('fullpath')));
addpath(patbox_root);
install_patbox();

multi_cfg = multiReconParameters();
sim_cfg = simParameters();
algorithms = multi_cfg.Algorithms;

img_path = resolvePatboxPath(sim_cfg.ImagePath);
if ~exist(img_path, 'file')
    img_path = fullfile(fileparts(patbox_root), 'simulation', '3.bmp');
end
if ~exist(img_path, 'file')
    img_path = fullfile(fileparts(patbox_root), 'rotation_method', 'ground_truth', '3.bmp');
end
if ~exist(img_path, 'file')
    error('No example image found. Set simulation.ImagePath in params.yaml.');
end

sensor_type_display = [upper(sim_cfg.SensorType(1)), sim_cfg.SensorType(2:end)];
fprintf('============================================================\n');
fprintf('   Test Reconstruction Algorithms with %s Sensor\n', sensor_type_display);
fprintf('============================================================\n\n');

fprintf('Running forward simulation (%s sensor, %.0f%% noise)...\n', ...
    sim_cfg.SensorType, sim_cfg.NoiseLevel * 100);
[sensor_data, sensor, kgrid, source, noisy_p0, sound_speed] = patSimulate(img_path);

p0_ground_truth = source.p0;
output_root = resolvePatboxOutputPath(multi_cfg.OutputDir);
if output_root ~= "" && ~exist(output_root, 'dir')
    mkdir(output_root);
end

recon_args = multiReconArgs(multi_cfg);

fprintf('\nStarting reconstruction loop (%d algorithms)...\n', numel(algorithms));
for i = 1:numel(algorithms)
    algo_name = algorithms{i};
    fprintf('============================================================\n');
    fprintf('Running %s reconstruction...\n', algo_name);

    [p0_recon, info] = patReconstruct(sensor_data, sensor, kgrid, ...
        sound_speed, algo_name, recon_args{:});
    metrics = patEvaluate(p0_recon, p0_ground_truth);

    fprintf('Reconstruction Time: %.2f s\n', info.elapsed_seconds);
    fprintf('Mean Squared Error (MSE): %.4f\n', metrics.mse);
    fprintf('PSNR: %.4f dB\n', metrics.psnr);
    fprintf('SSIM: %.4f\n', metrics.ssim);
    fprintf('SNR: %.4f dB\n', metrics.snr);
    fprintf('Sharpness: %.4f\n', metrics.sharpness);
    fprintf('UIQI: %.4f\n\n', metrics.uiqi);

    file_stem = buildMultiReconOutputStem(algo_name, sim_cfg, multi_cfg);

    if multi_cfg.SaveFigure
        fig_path = fullfile(output_root, [file_stem '.png']);
        saveReconComparisonFigure(fig_path, kgrid, p0_ground_truth, noisy_p0, ...
            p0_recon, algo_name, sim_cfg, metrics);
        fprintf('Saved comparison figure to: %s\n', fig_path);
    end

    if multi_cfg.SaveMat
        mat_path = fullfile(output_root, [file_stem '.mat']);
        p0_recon_normalized = mat2gray(gather(p0_recon));
        sensor_type = sim_cfg.SensorType;
        noise_level = sim_cfg.NoiseLevel;
        recon_time = info.elapsed_seconds;
        save(mat_path, 'p0_recon', 'p0_recon_normalized', 'source', 'kgrid', ...
            'algo_name', 'sensor_type', 'noise_level', 'recon_time', ...
            'metrics', 'info', 'sim_cfg', 'multi_cfg');
        fprintf('Saved reconstruction to: %s\n', mat_path);
    end

    if multi_cfg.SavePng
        png_path = fullfile(output_root, [file_stem '_recon.png']);
        rgb = ind2rgb(im2uint8(mat2gray(gather(p0_recon))), hot(256));
        imwrite(rgb, png_path);
        fprintf('Saved reconstruction image to: %s\n', png_path);
    end
end

fprintf('\nReconstruction algorithms tested successfully!\n');

function saveReconComparisonFigure(fig_path, kgrid, p0_gt, noisy_p0, p0_recon, ...
        algo_name, sim_cfg, metrics)
    p0_gt_norm = mat2gray(gather(p0_gt));
    noisy_p0_norm = mat2gray(gather(noisy_p0));
    p0_recon_norm = mat2gray(gather(p0_recon));
    diff_image = p0_gt_norm - p0_recon_norm;

    sensor_type_display = [upper(sim_cfg.SensorType(1)), sim_cfg.SensorType(2:end)];
    fig = figure('Position', [50, 100, 1600, 400], 'Visible', 'off');
    colormap(hot);

    subplot(1, 4, 1);
    imagesc(kgrid.y_vec * 1e3, kgrid.x_vec * 1e3, p0_gt_norm);
    title('True Initial Pressure', 'FontSize', 12);
    axis image; xlabel('y [mm]'); ylabel('x [mm]'); colorbar;

    subplot(1, 4, 2);
    imagesc(kgrid.y_vec * 1e3, kgrid.x_vec * 1e3, noisy_p0_norm);
    title(sprintf('Noisy Initial Pressure (%.0f%%)', sim_cfg.NoiseLevel * 100), 'FontSize', 10);
    axis image; xlabel('y [mm]'); ylabel('x [mm]'); colorbar;

    subplot(1, 4, 3);
    imagesc(kgrid.y_vec * 1e3, kgrid.x_vec * 1e3, p0_recon_norm);
    title(sprintf('%s Reconstruction\nRMSE: %.3f, PSNR: %.1f dB, SSIM: %.3f', ...
        algo_name, metrics.rmse, metrics.psnr, metrics.ssim), 'FontSize', 10);
    axis image; xlabel('y [mm]'); ylabel('x [mm]'); colorbar;

    subplot(1, 4, 4);
    imagesc(kgrid.y_vec * 1e3, kgrid.x_vec * 1e3, diff_image);
    title('Difference (True - Recon)', 'FontSize', 12);
    axis image; xlabel('y [mm]'); ylabel('x [mm]'); colorbar; colormap(gca, 'jet');

    sgtitle(sprintf('%s Reconstruction with %s Array (%.0f%% Noise)', ...
        algo_name, sensor_type_display, sim_cfg.NoiseLevel * 100), ...
        'FontSize', 10, 'FontWeight', 'bold');

    output_dir = fileparts(fig_path);
    if output_dir ~= "" && ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    saveas(fig, fig_path);
    close(fig);
end
