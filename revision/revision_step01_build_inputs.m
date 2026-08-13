clear;
close all;
clc;

%% ------------------------------------------------------------
% PATBox root
% -------------------------------------------------------------
thisFile = mfilename('fullpath');
revisionDir = fileparts(thisFile);
patboxRoot = fileparts(revisionDir);

addpath(patboxRoot);
install_patbox();

fprintf('\nPATBox revision study\n');
fprintf('Root: %s\n', patboxRoot);

%% ------------------------------------------------------------
% Fixed numerical grid
% -------------------------------------------------------------
Nx = 192;
Ny = 192;

dx = 50e-6;
dy = 50e-6;

kgrid = kWaveGrid(Nx, dx, Ny, dy);

%% ------------------------------------------------------------
% Output directory
% -------------------------------------------------------------
outputDir = fullfile(revisionDir, 'outputs', 'step01');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% ============================================================
% 1. PHOTOACOUSTIC SOURCE PHANTOM
% =============================================================
sourceCfg = struct();

sourceCfg.randomSeed       = 101;
sourceCfg.nTrees           = 2;
sourceCfg.maxDepth         = 4;

sourceCfg.trunkLength      = 1.35e-3;
sourceCfg.trunkWidth       = 0.28e-3;

sourceCfg.minVesselWidth   = 0.07e-3;

sourceCfg.branchAngleDeg   = 31;
sourceCfg.angleJitterDeg   = 8;

sourceCfg.peakPressurePa   = 1;

[p0, sourceMeta] = ...
    makeBranchingPAPhantom(kgrid, sourceCfg);

sourceFile = fullfile( ...
    outputDir, ...
    'vascular_phantom_seed101.mat');

save(sourceFile, ...
    'p0', ...
    'sourceMeta');

%% ============================================================
% 2. RANDOM FORWARD ACOUSTIC MEDIUM
% =============================================================
mediumCfg = struct();

mediumCfg.randomSeed = 31;

mediumCfg.c0 = 1500;

mediumCfg.soundSpeedBounds = ...
    [1450 1550];

mediumCfg.heterogeneityMaxDelta = 35;

mediumCfg.nInclusionsRange = ...
    [2 5];

mediumCfg.rho0 = 1000;

mediumCfg.densityFractionStd = ...
    0.02;

% IMPORTANT for controlled sensitivity study
mediumCfg.randomizeBaselineSoundSpeed = false;

[medium, mediumMeta] = ...
    makeRandomForwardMedium( ...
    kgrid, mediumCfg);

sound_speed = medium.sound_speed;
density     = medium.density;

mediumFile = fullfile( ...
    outputDir, ...
    'forward_medium_seed31.mat');

save(mediumFile, ...
    'sound_speed', ...
    'density', ...
    'mediumMeta');

%% ============================================================
% 3. VISUAL CHECK
% =============================================================
figure( ...
    'Color','w', ...
    'Position',[100 100 1250 380]);

subplot(1,3,1);

imagesc( ...
    1e3*double(kgrid.y_vec), ...
    1e3*double(kgrid.x_vec), ...
    p0);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');
title('Initial pressure p_0');

colorbar;


subplot(1,3,2);

imagesc( ...
    1e3*double(kgrid.y_vec), ...
    1e3*double(kgrid.x_vec), ...
    sound_speed);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');
title('Sound speed [m/s]');

colorbar;


subplot(1,3,3);

imagesc( ...
    1e3*double(kgrid.y_vec), ...
    1e3*double(kgrid.x_vec), ...
    density);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');
title('Density [kg/m^3]');

colorbar;

sgtitle( ...
    'PATBox revision study: source and forward medium');

figPath = fullfile( ...
    outputDir, ...
    'step01_source_and_medium.png');

exportgraphics( ...
    gcf, ...
    figPath, ...
    'Resolution',300);

%% ------------------------------------------------------------
% Console summary
% -------------------------------------------------------------
fprintf('\n=============================================\n');
fprintf('STEP 01 COMPLETE\n');
fprintf('=============================================\n');

fprintf('\nSource:\n');
fprintf('  Segments     = %d\n', ...
    sourceMeta.segmentCount);

fprintf('  Peak p0      = %.4g Pa\n', ...
    max(p0(:)));

fprintf('\nMedium:\n');
fprintf('  c mean       = %.3f m/s\n', ...
    mediumMeta.soundSpeedMean);

fprintf('  c std        = %.3f m/s\n', ...
    mediumMeta.soundSpeedStd);

fprintf('  c range      = %.3f -- %.3f m/s\n', ...
    mediumMeta.soundSpeedMin, ...
    mediumMeta.soundSpeedMax);

fprintf('  rho mean     = %.3f kg/m^3\n', ...
    mediumMeta.densityMean);

fprintf('  rho std      = %.3f kg/m^3\n', ...
    mediumMeta.densityStd);

fprintf('\nFiles written to:\n%s\n', ...
    outputDir);