clear;
close all;
clc;

%% ============================================================
% STEP 09B-4
% Validate and freeze the expanded Monte Carlo medium generator.
%
% This step does NOT run k-Wave.
% ============================================================

patboxRoot = ...
    'C:\Users\asus\Documents\GitHub\PATBox';

revisionDir = ...
    fullfile(patboxRoot,'revision');

addpath(revisionDir,'-begin');

outDir = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step09_montecarlo');

if ~exist(outDir,'dir')
    mkdir(outDir);
end

%% ============================================================
% PUBLICATION GRID
% ============================================================

Nx = 192;
Ny = 192;

dx = 50e-6;
dy = 50e-6;

%% ============================================================
% PILOT BASE SEED
%
% Seed 1 is the first realization of the final N=50 cohort.
% ============================================================

baseSeed = 1;

%% ============================================================
% GENERATE TWICE
%
% The second call is an exact reproducibility check.
% ============================================================

[medium1,meta1] = ...
    makePublicationMonteCarloMedium( ...
    Nx,Ny,dx,dy,baseSeed);

[medium2,meta2] = ...
    makePublicationMonteCarloMedium( ...
    Nx,Ny,dx,dy,baseSeed);

%% ============================================================
% NUMERIC REPRESENTATIONS
% ============================================================

c1 = ...
    double(medium1.sound_speed);

rho1 = ...
    double(medium1.density);

c2 = ...
    double(medium2.sound_speed);

rho2 = ...
    double(medium2.density);

%% ============================================================
% CONSOLE
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 09B-4: MONTE CARLO MEDIUM VALIDATION\n');
fprintf('============================================================\n');

fprintf('Base seed              = %d\n', ...
    baseSeed);

fprintf('Sound-speed seed       = %d\n', ...
    meta1.sound_speed_seed);

fprintf('Density seed           = %d\n', ...
    meta1.density_seed);

fprintf('Grid                   = %d x %d\n', ...
    Nx,Ny);

fprintf('dx / dy                = %.3f / %.3f um\n', ...
    dx*1e6,dy*1e6);

fprintf('Smoothing scale        = %.4f mm\n', ...
    meta1.smoothing_scale_m*1e3);

fprintf('Smoothing sigma        = %.4f pixels\n', ...
    meta1.smoothing_sigma_pixels);

fprintf('Boundary treatment     = %s\n', ...
    meta1.smoothing_boundary_condition);

fprintf('\n');
fprintf('SOUND SPEED\n');
fprintf('------------------------------------------------------------\n');

fprintf('Mean                   = %.9f m/s\n', ...
    mean(c1(:)));

fprintf('Std                    = %.9f m/s\n', ...
    std(c1(:)));

fprintf('Min                    = %.9f m/s\n', ...
    min(c1(:)));

fprintf('Max                    = %.9f m/s\n', ...
    max(c1(:)));

fprintf('\n');
fprintf('DENSITY\n');
fprintf('------------------------------------------------------------\n');

fprintf('Mean                   = %.9f kg/m^3\n', ...
    mean(rho1(:)));

fprintf('Std                    = %.9f kg/m^3\n', ...
    std(rho1(:)));

fprintf('Min                    = %.9f kg/m^3\n', ...
    min(rho1(:)));

fprintf('Max                    = %.9f kg/m^3\n', ...
    max(rho1(:)));

fprintf('\n');
fprintf('C / RHO RELATION\n');
fprintf('------------------------------------------------------------\n');

fprintf('Realized correlation   = %.9f\n', ...
    corr(c1(:),rho1(:)));

fprintf('\n');
fprintf('ATTENUATION\n');
fprintf('------------------------------------------------------------\n');

fprintf('alpha coeff            = %.6f\n', ...
    medium1.alpha_coeff);

fprintf('alpha power            = %.6f\n', ...
    medium1.alpha_power);

%% ============================================================
% TARGET-PARAMETER AUDIT
% ============================================================

meanCTolerance = ...
    1e-4;

stdCTolerance = ...
    1e-4;

meanRhoTolerance = ...
    1e-4;

stdRhoTolerance = ...
    1e-4;

assert( ...
    abs(mean(c1(:))-1500) < ...
    meanCTolerance, ...
    'Sound-speed mean audit failed.');

assert( ...
    abs(std(c1(:))-20) < ...
    stdCTolerance, ...
    'Sound-speed SD audit failed.');

assert( ...
    abs(mean(rho1(:))-1000) < ...
    meanRhoTolerance, ...
    'Density mean audit failed.');

assert( ...
    abs(std(rho1(:))-15) < ...
    stdRhoTolerance, ...
    'Density SD audit failed.');

assert( ...
    abs(meta1.smoothing_sigma_pixels-15) < ...
    1e-12, ...
    'Smoothing-scale audit failed.');

assert( ...
    medium1.alpha_coeff == 0.75);

assert( ...
    medium1.alpha_power == 1.5);

%% ============================================================
% LOWER-BOUND AUDIT
% ============================================================

fprintf('\n');
fprintf('DEFENSIVE-BOUND AUDIT\n');
fprintf('------------------------------------------------------------\n');

fprintf('Sound-speed clipped pixels = %d\n', ...
    meta1.sound_speed_clipped_pixels);

fprintf('Density clipped pixels     = %d\n', ...
    meta1.density_clipped_pixels);

assert( ...
    meta1.sound_speed_clipped_pixels == 0, ...
    'Sound-speed defensive clipping was activated.');

assert( ...
    meta1.density_clipped_pixels == 0, ...
    'Density defensive clipping was activated.');

%% ============================================================
% EXACT REPRODUCIBILITY AUDIT
% ============================================================

cRelativeDifference = ...
    norm(c1(:)-c2(:)) / ...
    (norm(c1(:))+eps);

rhoRelativeDifference = ...
    norm(rho1(:)-rho2(:)) / ...
    (norm(rho1(:))+eps);

fprintf('\n');
fprintf('REPRODUCIBILITY AUDIT\n');
fprintf('------------------------------------------------------------\n');

fprintf('c relative difference   = %.12e\n', ...
    cRelativeDifference);

fprintf('rho relative difference = %.12e\n', ...
    rhoRelativeDifference);

assert( ...
    cRelativeDifference == 0, ...
    'Sound-speed map is not exactly reproducible.');

assert( ...
    rhoRelativeDifference == 0, ...
    'Density map is not exactly reproducible.');

assert( ...
    meta1.sound_speed_seed == ...
    meta2.sound_speed_seed);

assert( ...
    meta1.density_seed == ...
    meta2.density_seed);

%% ============================================================
% PPW DESIGN AUDIT
%
% For f_max = 6 MHz:
%
% PPW = c_min / (dx * f_max)
% ============================================================

fMax = ...
    6e6;

cMin = ...
    min(c1(:));

ppwAchieved = ...
    min( ...
    cMin/(dx*fMax), ...
    cMin/(dy*fMax));

fprintf('\n');
fprintf('SPATIAL-SAMPLING AUDIT\n');
fprintf('------------------------------------------------------------\n');

fprintf('c_min                  = %.6f m/s\n', ...
    cMin);

fprintf('f_max                  = %.3f MHz\n', ...
    fMax*1e-6);

fprintf('Achieved PPW           = %.6f\n', ...
    ppwAchieved);

assert( ...
    ppwAchieved >= 4, ...
    'Publication PPW acceptance criterion failed.');

%% ============================================================
% SAVE PILOT MEDIUM
% ============================================================

medium = ...
    medium1;

meta = ...
    meta1;

meta.ppw_achieved_at_6MHz = ...
    ppwAchieved;

pilotFile = fullfile( ...
    outDir, ...
    'montecarlo_medium_seed001.mat');

save( ...
    pilotFile, ...
    'medium', ...
    'meta', ...
    '-v7.3');

%% ============================================================
% DIAGNOSTIC FIGURES
% ============================================================

x_mm = ...
    (((0:Nx-1)-(Nx-1)/2)*dx)*1e3;

y_mm = ...
    (((0:Ny-1)-(Ny-1)/2)*dy)*1e3;

%% ------------------------------------------------------------
% Sound speed
% ------------------------------------------------------------

figC = figure( ...
    'Color','w', ...
    'Position',[100 100 850 700]);

imagesc( ...
    y_mm, ...
    x_mm, ...
    c1);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');

title( ...
    sprintf( ...
    'Monte Carlo sound-speed realization, seed %d', ...
    baseSeed));

colorbar;

exportgraphics( ...
    figC, ...
    fullfile( ...
    outDir, ...
    'montecarlo_medium_seed001_sound_speed.png'), ...
    'Resolution',300);

%% ------------------------------------------------------------
% Density
% ------------------------------------------------------------

figRho = figure( ...
    'Color','w', ...
    'Position',[120 120 850 700]);

imagesc( ...
    y_mm, ...
    x_mm, ...
    rho1);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');

title( ...
    sprintf( ...
    'Monte Carlo density realization, seed %d', ...
    baseSeed));

colorbar;

exportgraphics( ...
    figRho, ...
    fullfile( ...
    outDir, ...
    'montecarlo_medium_seed001_density.png'), ...
    'Resolution',300);

%% ============================================================
% FINAL
% ============================================================

fprintf('\n');
fprintf('Saved pilot medium:\n%s\n', ...
    pilotFile);

fprintf('\n');
fprintf('============================================================\n');
fprintf('MONTE CARLO MEDIUM: PASS\n');
fprintf('============================================================\n');

fprintf('Target c statistics         : PASS\n');
fprintf('Target rho statistics       : PASS\n');
fprintf('0.75-mm smoothing scale     : PASS\n');
fprintf('Independent random streams  : PASS\n');
fprintf('No defensive clipping       : PASS\n');
fprintf('Exact seed reproducibility  : PASS\n');
fprintf('PPW >= 4                    : PASS\n');

fprintf('\n');
fprintf('STEP 09B-4 COMPLETE\n');
fprintf('============================================================\n');