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

inputDir = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step03_sequential_forward');

outputDir = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step04_TR_validation');

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

%% ============================================================
% STAGES TO TEST
% ============================================================

stageFiles = { ...
    'D2_finite_aperture.mat', ...
    'D3_heterogeneity.mat'};

stageNames = { ...
    'D2 finite aperture', ...
    'D3 + heterogeneity'};

nStages = numel(stageFiles);

results = struct([]);

%% ============================================================
% LOOP
% ============================================================

for s = 1:nStages

    inputFile = fullfile( ...
        inputDir, ...
        stageFiles{s});

    assert(isfile(inputFile), ...
        'Missing file: %s',inputFile);

    S = load(inputFile,'sim');

    sim = S.sim;

    fprintf('\n\n');
    fprintf('#################################################\n');
    fprintf('%s\n',stageNames{s});
    fprintf('#################################################\n');

    %% ---------------------------------------------------------
    % MEDIUM AUDIT
    % ----------------------------------------------------------

    cMap = double(sim.medium.sound_speed);
    rhoMap = double(sim.medium.density);

    fprintf('\nForward/reconstruction medium\n');
    fprintf('---------------------------------------------\n');

    fprintf('c mean       = %.3f m/s\n', ...
        mean(cMap(:)));

    fprintf('c std        = %.3f m/s\n', ...
        std(cMap(:)));

    fprintf('c min        = %.3f m/s\n', ...
        min(cMap(:)));

    fprintf('c max        = %.3f m/s\n', ...
        max(cMap(:)));

    fprintf('rho mean     = %.3f kg/m^3\n', ...
        mean(rhoMap(:)));

    fprintf('rho std      = %.3f kg/m^3\n', ...
        std(rhoMap(:)));

    %% ---------------------------------------------------------
    % TIME REVERSAL
    % ----------------------------------------------------------

    [pTR,trInfo] = ...
        publicationTimeReversal( ...
        sim, ...
        'DataCast','single', ...
        'PMLSize',20, ...
        'PlotSimulation',false);

    %% ---------------------------------------------------------
    % EVALUATION
    % ----------------------------------------------------------

    pRef = double(sim.p0_reference);

    metrics = ...
        publicationEvaluate( ...
        pTR, ...
        pRef);

    %% ---------------------------------------------------------
    % STORE
    % ----------------------------------------------------------

    results(s).stage = stageNames{s};

    results(s).pTR = pTR;

    results(s).trInfo = trInfo;

    results(s).metrics = metrics;

    results(s).pRef = pRef;

    %% ---------------------------------------------------------
    % PRINT
    % ----------------------------------------------------------

    fprintf('\nMetrics\n');
    fprintf('---------------------------------------------\n');

    fprintf('Raw NRMSE       = %.6f\n', ...
        metrics.raw_nrmse);

    fprintf('SI-NRMSE        = %.6f\n', ...
        metrics.si_nrmse);

    fprintf('Scale factor    = %.6f\n', ...
        metrics.scale_factor);

    fprintf('Correlation     = %.6f\n', ...
        metrics.correlation);

    fprintf('SSIM            = %.6f\n', ...
        metrics.ssim);

    fprintf('CNR             = %.6f\n', ...
        metrics.cnr);

    fprintf('SBR             = %.6f dB\n', ...
        metrics.sbr_db);

    fprintf('Signal RMS      = %.6e\n', ...
        metrics.signal_rms);

    fprintf('Background RMS  = %.6e\n', ...
        metrics.background_rms);

    fprintf('TR runtime      = %.3f s\n', ...
        trInfo.elapsed_seconds);

end

%% ============================================================
% METRIC CHANGE: D2 -> D3
% ============================================================

m2 = results(1).metrics;
m3 = results(2).metrics;

fprintf('\n\n');
fprintf('=============================================\n');
fprintf('D2 -> D3 HETEROGENEITY EFFECT ON TR\n');
fprintf('=============================================\n');

fprintf('Delta SI-NRMSE    = %+ .6f\n', ...
    m3.si_nrmse - m2.si_nrmse);

fprintf('Delta Correlation = %+ .6f\n', ...
    m3.correlation - m2.correlation);

fprintf('Delta SSIM        = %+ .6f\n', ...
    m3.ssim - m2.ssim);

fprintf('Delta CNR         = %+ .6f\n', ...
    m3.cnr - m2.cnr);

fprintf('Delta SBR         = %+ .6f dB\n', ...
    m3.sbr_db - m2.sbr_db);

%% ============================================================
% COMMON-SCALE FIGURE
% ============================================================

pRef = results(1).pRef;

refPeak = max(abs(pRef(:)));

pD2 = ...
    results(1).metrics.scale_factor .* ...
    results(1).pTR;

pD3 = ...
    results(2).metrics.scale_factor .* ...
    results(2).pTR;

figure( ...
    'Color','w', ...
    'Position',[80 80 1550 520]);

%% Reference
subplot(1,3,1);

imagesc( ...
    1e3*double(S.sim.kgrid.y_vec), ...
    1e3*double(S.sim.kgrid.x_vec), ...
    pRef);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');

title('Reference p_0');

clim([-0.1 1]*refPeak);

colorbar;

%% D2
subplot(1,3,2);

imagesc( ...
    1e3*double(S.sim.kgrid.y_vec), ...
    1e3*double(S.sim.kgrid.x_vec), ...
    pD2);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');

title( ...
    sprintf( ...
    'D2: BW + aperture\nSSIM = %.3f', ...
    m2.ssim));

clim([-0.1 1]*refPeak);

colorbar;

%% D3
subplot(1,3,3);

imagesc( ...
    1e3*double(S.sim.kgrid.y_vec), ...
    1e3*double(S.sim.kgrid.x_vec), ...
    pD3);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');

title( ...
    sprintf( ...
    'D3: + heterogeneity\nSSIM = %.3f', ...
    m3.ssim));

clim([-0.1 1]*refPeak);

colorbar;

sgtitle( ...
    'Effect of acoustic heterogeneity on time-reversal reconstruction');

exportgraphics( ...
    gcf, ...
    fullfile( ...
        outputDir, ...
        'D2_D3_TR_comparison.png'), ...
    'Resolution',300);

%% ============================================================
% ABSOLUTE ERROR MAP
% ============================================================

errD2 = abs(pD2-pRef);
errD3 = abs(pD3-pRef);

maxError = max( ...
    [errD2(:);errD3(:)]);

figure( ...
    'Color','w', ...
    'Position',[100 100 1250 520]);

subplot(1,2,1);

imagesc( ...
    1e3*double(S.sim.kgrid.y_vec), ...
    1e3*double(S.sim.kgrid.x_vec), ...
    errD2);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');

title('|D2 - reference|');

clim([0 maxError]);

colorbar;


subplot(1,2,2);

imagesc( ...
    1e3*double(S.sim.kgrid.y_vec), ...
    1e3*double(S.sim.kgrid.x_vec), ...
    errD3);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');

title('|D3 - reference|');

clim([0 maxError]);

colorbar;

sgtitle( ...
    'TR reconstruction error before and after acoustic heterogeneity');

exportgraphics( ...
    gcf, ...
    fullfile( ...
        outputDir, ...
        'D2_D3_TR_error_maps.png'), ...
    'Resolution',300);

%% ============================================================
% SUMMARY TABLE
% ============================================================

Stage = [ ...
    "D2_finite_aperture"; ...
    "D3_heterogeneity"];

SI_NRMSE = [ ...
    m2.si_nrmse; ...
    m3.si_nrmse];

Correlation = [ ...
    m2.correlation; ...
    m3.correlation];

SSIM = [ ...
    m2.ssim; ...
    m3.ssim];

CNR = [ ...
    m2.cnr; ...
    m3.cnr];

SBR_dB = [ ...
    m2.sbr_db; ...
    m3.sbr_db];

Background_RMS = [ ...
    m2.background_rms; ...
    m3.background_rms];

TR_Runtime_s = [ ...
    results(1).trInfo.elapsed_seconds; ...
    results(2).trInfo.elapsed_seconds];

T = table( ...
    Stage, ...
    SI_NRMSE, ...
    Correlation, ...
    SSIM, ...
    CNR, ...
    SBR_dB, ...
    Background_RMS, ...
    TR_Runtime_s);

disp(T);

writetable( ...
    T, ...
    fullfile( ...
        outputDir, ...
        'D2_D3_TR_metrics.csv'));

save( ...
    fullfile( ...
        outputDir, ...
        'D2_D3_TR_results.mat'), ...
    'results', ...
    'T', ...
    '-v7.3');

fprintf('\n=============================================\n');
fprintf('STEP 04C COMPLETE\n');
fprintf('=============================================\n');