clear;
close all;
clc;

%% ============================================================
% PATHS
% ============================================================

patboxRoot = ...
    'C:\Users\asus\Documents\GitHub\PATBox';

revisionDir = fullfile( ...
    patboxRoot, ...
    'revision');

addpath(patboxRoot,'-begin');
addpath(revisionDir,'-begin');

install_patbox();

fprintf('\nPATBox:\n');
disp(which('patSimulate'));

fprintf('k-Wave:\n');
disp(which('kspaceFirstOrder2D'));

%% ============================================================
% INPUT FILES
% ============================================================

sourceFile = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step01', ...
    'vascular_phantom_seed101.mat');

mediumFile = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step01', ...
    'forward_medium_seed31.mat');

assert(isfile(sourceFile), ...
    'Source phantom not found.');

assert(isfile(mediumFile), ...
    'Forward medium not found.');

%% ============================================================
% OUTPUT
% ============================================================

outputDir = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step03_sequential_forward');

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

%% ============================================================
% AUDIT THE HETEROGENEOUS MEDIUM
% ============================================================

M = load(mediumFile);

assert(isfield(M,'sound_speed'), ...
    'Medium file has no sound_speed.');

assert(isfield(M,'density'), ...
    'Medium file has no density.');

cMap = double(M.sound_speed);
rhoMap = double(M.density);

cMean = mean(cMap(:));
cStd  = std(cMap(:));

rhoMean = mean(rhoMap(:));
rhoStd  = std(rhoMap(:));

cMin = min(cMap(:));
cMax = max(cMap(:));

fprintf('\n=============================================\n');
fprintf('HETEROGENEOUS MEDIUM AUDIT\n');
fprintf('=============================================\n');

fprintf('c mean       = %.3f m/s\n',cMean);
fprintf('c std        = %.3f m/s\n',cStd);
fprintf('c min        = %.3f m/s\n',cMin);
fprintf('c max        = %.3f m/s\n',cMax);

fprintf('\nrho mean     = %.3f kg/m^3\n',rhoMean);
fprintf('rho std      = %.3f kg/m^3\n',rhoStd);

rhoCorr = corr(cMap(:),rhoMap(:));

fprintf('corr(c,rho)  = %.4f\n',rhoCorr);

% Publication-quality sanity checks
assert(abs(cMean-1500) < 10, ...
    ['Sound-speed mean is too far from 1500 m/s. ' ...
     'Regenerate the revised medium.']);

assert(cStd >= 12, ...
    ['Sound-speed heterogeneity is too weak. ' ...
     'This appears to be the OLD medium file.']);

assert(abs(rhoMean-1000) < 10, ...
    'Density mean is unexpectedly far from 1000 kg/m^3.');

assert(rhoStd >= 8, ...
    ['Density heterogeneity is too weak. ' ...
     'Regenerate the revised medium.']);

fprintf('\nMedium audit: PASS\n');

%% ============================================================
% CONTROLLED COMMON TEMPORAL SAMPLING
% ============================================================

dx = 50e-6;
dy = 50e-6;

baseCFL = 0.20;

cGlobalMax = max(1500,cMax);

dtTarget = ...
    baseCFL * min(dx,dy) / cGlobalMax;

% CFL required in homogeneous stages to generate the same dt
cflHomogeneous = ...
    dtTarget * 1500 / min(dx,dy);

% Heterogeneous stages use the global maximum speed
cflHeterogeneous = ...
    dtTarget * cMax / min(dx,dy);

fprintf('\n=============================================\n');
fprintf('COMMON TIME-SAMPLING DESIGN\n');
fprintf('=============================================\n');

fprintf('Global c max          = %.3f m/s\n', ...
    cGlobalMax);

fprintf('Target dt             = %.6f ns\n', ...
    dtTarget*1e9);

fprintf('Homogeneous CFL       = %.6f\n', ...
    cflHomogeneous);

fprintf('Heterogeneous CFL     = %.6f\n', ...
    cflHeterogeneous);

%% ============================================================
% COMMON SIMULATION SETTINGS
% ============================================================

commonArgs = { ...
    ...
    'SourceModel','initial_pressure_mat', ...
    'SourceMapPath',sourceFile, ...
    'InitialPressureVariable','p0', ...
    'SourceScale',1, ...
    'SmoothInitialPressure',false, ...
    ...
    'GridSizeX',192, ...
    'GridSizeY',192, ...
    'Dx',dx, ...
    'Dy',dy, ...
    'PointsPerWavelength',4, ...
    'MaxFrequency',6e6, ...
    ...
    'SimulationEndTime',16e-6, ...
    'PMLSize',20, ...
    'DataCast','single', ...
    'PlotSimulation',false, ...
    ...
    'SensorType','circular', ...
    'NumTransducers',128, ...
    'SensorRadius',4.2e-3, ...
    'UseDirectivity',false, ...
    ...
    'SensorPositionStd',0, ...
    'SensorRadialPositionStd',0, ...
    'SensorAngularPositionStdDeg',0, ...
    'TimeJitterStd',0, ...
    'TriggerJitterStd',0, ...
    ...
    'RandomSeed',31 ...
    };

%% ============================================================
% STAGES
% ============================================================

stages = revisionPhysicsStages(mediumFile);

nStages = numel(stages);

simulations = cell(nStages,1);

%% ============================================================
% RUN
% ============================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('SEQUENTIAL PHYSICS FORWARD STUDY\n');
fprintf('=============================================\n');

for s = 1:nStages

    stage = stages(s);

    fprintf('\n---------------------------------------------\n');
    fprintf('Stage %d/%d\n',s,nStages);
    fprintf('%s\n',stage.Label);
    fprintf('ID: %s\n',stage.Id);
    fprintf('---------------------------------------------\n');

    % --------------------------------------------------------
    % Choose CFL so temporal sampling remains common
    % --------------------------------------------------------

    isHeterogeneous = ...
        contains(stage.Id,'heterogeneity') || ...
        contains(stage.Id,'attenuation') || ...
        contains(stage.Id,'noise');

    if isHeterogeneous
        stageCFL = cflHeterogeneous;
    else
        stageCFL = cflHomogeneous;
    end

    tic;

    sim = patSimulate( ...
        sourceFile, ...
        commonArgs{:}, ...
        'CFL',stageCFL, ...
        stage.SimArgs{:});

    elapsed = toc;

    simulations{s} = sim;

    % --------------------------------------------------------
    % Basic audit
    % --------------------------------------------------------

    rfClean = double(sim.sensor_data_clean.p);
    rfMeasured = double(sim.sensor_data.p);

    fprintf('Runtime              = %.2f s\n',elapsed);

    fprintf('Sensor model         = %s\n', ...
        sim.info.sensor_model);

    fprintf('Element width        = %.4f mm\n', ...
        sim.info.element_width_m*1e3);

    fprintf('dt                   = %.6f ns\n', ...
        double(sim.kgrid.dt)*1e9);

    fprintf('Nt                   = %d\n', ...
        sim.kgrid.Nt);

    fprintf('RF dimensions        = %d x %d\n', ...
        size(rfMeasured,1), ...
        size(rfMeasured,2));

    fprintf('RF clean RMS         = %.6e\n', ...
        sqrt(mean(rfClean(:).^2)));

    fprintf('RF measured RMS      = %.6e\n', ...
        sqrt(mean(rfMeasured(:).^2)));

    if strcmpi(sim.info.acquisition.noise_model,'awgn')

        fprintf('Target SNR           = %.3f dB\n', ...
            sim.info.acquisition.target_snr_db);

        fprintf('Achieved SNR         = %.3f dB\n', ...
            sim.info.acquisition.achieved_additive_snr_db);
    end

    assert(all(isfinite(rfMeasured(:))), ...
        'Non-finite RF values detected.');

    assert(size(rfMeasured,1)==128, ...
        'Receiver-channel count changed.');

    % --------------------------------------------------------
    % Save each complete simulation record
    % --------------------------------------------------------

    fileName = sprintf( ...
        '%s.mat', ...
        stage.Id);

    save( ...
        fullfile(outputDir,fileName), ...
        'sim', ...
        'stage', ...
        'elapsed', ...
        '-v7.3');
end

%% ============================================================
% VERIFY COMMON TIME AXIS
% ============================================================

dtAll = zeros(nStages,1);
NtAll = zeros(nStages,1);

for s = 1:nStages

    dtAll(s) = ...
        double(simulations{s}.kgrid.dt);

    NtAll(s) = ...
        simulations{s}.kgrid.Nt;
end

fprintf('\n=============================================\n');
fprintf('TIME-AXIS CONSISTENCY\n');
fprintf('=============================================\n');

for s = 1:nStages

    fprintf('%-22s  dt = %.9f ns   Nt = %d\n', ...
        stages(s).Id, ...
        dtAll(s)*1e9, ...
        NtAll(s));
end

relativeDtSpread = ...
    (max(dtAll)-min(dtAll)) / mean(dtAll);

fprintf('\nRelative dt spread = %.6e\n', ...
    relativeDtSpread);

assert(relativeDtSpread < 1e-6, ...
    ['Time sampling differs between stages. ' ...
     'Do not proceed to reconstruction.']);

assert(all(NtAll == NtAll(1)), ...
    ['Number of temporal samples differs between stages. ' ...
     'Do not proceed to reconstruction.']);

fprintf('\nTime-axis consistency: PASS\n');

%% ============================================================
% STAGE SUMMARY
% ============================================================

Stage = strings(nStages,1);
Label = strings(nStages,1);

SensorModel = strings(nStages,1);

dt_ns = zeros(nStages,1);
Nt = zeros(nStages,1);

CleanRMS = zeros(nStages,1);
MeasuredRMS = zeros(nStages,1);

PreviousStageRelativeDifference = ...
    nan(nStages,1);

AchievedSNRdB = ...
    nan(nStages,1);

for s = 1:nStages

    sim = simulations{s};

    Stage(s) = stages(s).Id;
    Label(s) = stages(s).Label;

    SensorModel(s) = ...
        string(sim.info.sensor_model);

    dt_ns(s) = ...
        double(sim.kgrid.dt)*1e9;

    Nt(s) = ...
        sim.kgrid.Nt;

    rfClean = ...
        double(sim.sensor_data_clean.p);

    rfMeasured = ...
        double(sim.sensor_data.p);

    CleanRMS(s) = ...
        sqrt(mean(rfClean(:).^2));

    MeasuredRMS(s) = ...
        sqrt(mean(rfMeasured(:).^2));

    if s > 1

        previousSim = simulations{s-1};

        if strcmpi( ...
                sim.info.acquisition.noise_model, ...
                'awgn')

            currentRF = ...
                double(sim.sensor_data.p);

        else

            currentRF = ...
                double(sim.sensor_data_clean.p);
        end

        if strcmpi( ...
                previousSim.info.acquisition.noise_model, ...
                'awgn')

            previousRF = ...
                double(previousSim.sensor_data.p);

        else

            previousRF = ...
                double(previousSim.sensor_data_clean.p);
        end

        PreviousStageRelativeDifference(s) = ...
            norm(currentRF(:)-previousRF(:)) / ...
            (norm(previousRF(:))+eps);
    end

    if strcmpi( ...
            sim.info.acquisition.noise_model, ...
            'awgn')

        AchievedSNRdB(s) = ...
            sim.info.acquisition.achieved_additive_snr_db;
    end
end

summaryTable = table( ...
    Stage, ...
    Label, ...
    SensorModel, ...
    dt_ns, ...
    Nt, ...
    CleanRMS, ...
    MeasuredRMS, ...
    PreviousStageRelativeDifference, ...
    AchievedSNRdB);

disp(summaryTable);

writetable( ...
    summaryTable, ...
    fullfile( ...
        outputDir, ...
        'sequential_forward_summary.csv'));

%% ============================================================
% SAVE ALL STAGES
% ============================================================

save( ...
    fullfile( ...
        outputDir, ...
        'sequential_forward_workspace.mat'), ...
    'stages', ...
    'summaryTable', ...
    'dtTarget', ...
    'cGlobalMax', ...
    '-v7.3');

fprintf('\n');
fprintf('=============================================\n');
fprintf('STEP 03 COMPLETE\n');
fprintf('=============================================\n');

fprintf('\nOutputs:\n%s\n',outputDir);