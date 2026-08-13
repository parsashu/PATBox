clear;
close all;
clc;

%% ============================================================
% PATHS
% ============================================================

patboxRoot = ...
    'C:\Users\asus\Documents\GitHub\PATBox';

revisionDir = ...
    fullfile(patboxRoot,'revision');

addpath(patboxRoot,'-begin');
addpath(revisionDir,'-begin');

install_patbox();

%% ============================================================
% LOAD FINAL D0 FROM STEP 03
% ============================================================

inputFile = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step03_sequential_forward', ...
    'D0_ideal.mat');

assert(isfile(inputFile), ...
    'D0 file not found.');

S = load(inputFile,'sim');

sim = S.sim;

fprintf('\nLoaded:\n%s\n',inputFile);

%% ============================================================
% RUN PUBLICATION TR
% ============================================================

[pTR,trInfo] = ...
    publicationTimeReversal( ...
    sim, ...
    'DataCast','single', ...
    'PMLSize',20, ...
    'PlotSimulation',false);

%% ============================================================
% EVALUATION
% ============================================================

pRef = double(sim.p0_reference);

metrics = ...
    publicationEvaluate(pTR,pRef);

fprintf('\n');
fprintf('=============================================\n');
fprintf('D0 IDEAL TR METRICS\n');
fprintf('=============================================\n');

fprintf('Raw NRMSE          = %.6f\n', ...
    metrics.raw_nrmse);

fprintf('SI-NRMSE           = %.6f\n', ...
    metrics.si_nrmse);

fprintf('Scale factor       = %.6f\n', ...
    metrics.scale_factor);

fprintf('Correlation        = %.6f\n', ...
    metrics.correlation);

fprintf('SSIM               = %.6f\n', ...
    metrics.ssim);

fprintf('CNR                = %.6f\n', ...
    metrics.cnr);

fprintf('SBR                = %.6f dB\n', ...
    metrics.sbr_db);

fprintf('Signal RMS         = %.6e\n', ...
    metrics.signal_rms);

fprintf('Background RMS     = %.6e\n', ...
    metrics.background_rms);

fprintf('Zero background    = %d\n', ...
    metrics.sbr_zero_background);

fprintf('TR runtime         = %.3f s\n', ...
    trInfo.elapsed_seconds);

%% ============================================================
% COMMON-SCALE VISUALIZATION
% ============================================================

pTRAligned = ...
    metrics.scale_factor .* pTR;

refPeak = max(abs(pRef(:)));

figure( ...
    'Color','w', ...
    'Position',[100 100 1200 520]);

subplot(1,2,1);

imagesc( ...
    1e3*double(sim.kgrid.y_vec), ...
    1e3*double(sim.kgrid.x_vec), ...
    pRef);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');
title('Reference p_0');

clim([-0.1 1]*refPeak);
colorbar;


subplot(1,2,2);

imagesc( ...
    1e3*double(sim.kgrid.y_vec), ...
    1e3*double(sim.kgrid.x_vec), ...
    pTRAligned);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');
title('TR, globally scale-aligned');

clim([-0.1 1]*refPeak);
colorbar;

sgtitle( ...
    'D0 ideal acquisition: publication TR validation');

%% ============================================================
% SAVE
% ============================================================

outputDir = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step04_TR_validation');

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

exportgraphics( ...
    gcf, ...
    fullfile(outputDir,'D0_TR_validation.png'), ...
    'Resolution',300);

save( ...
    fullfile(outputDir,'D0_TR_validation.mat'), ...
    'pTR', ...
    'trInfo', ...
    'metrics', ...
    '-v7.3');

fprintf('\nSaved to:\n%s\n',outputDir);

fprintf('\n=============================================\n');
fprintf('STEP 04B COMPLETE\n');
fprintf('=============================================\n');