clear;
clc;

%% ============================================================
% STEP 09B-0
% Audit the ACTUAL installed PATBox interfaces before
% launching the expanded Monte Carlo study.
% ============================================================

patboxRoot = ...
    'C:\Users\asus\Documents\GitHub\PATBox';

revisionDir = ...
    fullfile(patboxRoot,'revision');

addpath(patboxRoot,'-begin');
addpath(revisionDir,'-begin');

install_patbox();

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 09B-0: PATBOX INTERFACE AUDIT\n');
fprintf('============================================================\n');

%% ============================================================
% 1. CORE FUNCTION LOCATIONS
% ============================================================

names = { ...
    'patSimulate', ...
    'patBenchmarkRealisticAcquisition2D', ...
    'patBenchmarkRealisticMonteCarlo2D', ...
    'publicationBeamformers', ...
    'publicationTimeReversal', ...
    'publicationEvaluate'};

fprintf('\nFUNCTION LOCATIONS\n');
fprintf('------------------------------------------------------------\n');

for k = 1:numel(names)

    f = which(names{k});

    if isempty(f)
        fprintf('%-40s : NOT FOUND\n',names{k});
    else
        fprintf('%-40s : %s\n',names{k},f);
    end
end

%% ============================================================
% 2. SHOW FIRST LINE / FUNCTION DECLARATION
% ============================================================

fprintf('\n');
fprintf('FUNCTION DECLARATIONS\n');
fprintf('------------------------------------------------------------\n');

for k = 1:3

    filePath = which(names{k});

    fprintf('\n--- %s ---\n',names{k});

    if isempty(filePath)
        fprintf('NOT FOUND\n');
        continue;
    end

    fid = fopen(filePath,'r');

    if fid < 0
        fprintf('Unable to open file.\n');
        continue;
    end

    cleanupObj = onCleanup(@() fclose(fid));

    lineCount = 0;

    while ~feof(fid) && lineCount < 30

        line = fgetl(fid);

        if ischar(line)

            trimmed = strtrim(line);

            if startsWith(trimmed,'function')

                fprintf('%s\n',trimmed);
                break;
            end
        end

        lineCount = lineCount + 1;
    end

    clear cleanupObj;
end

%% ============================================================
% 3. PAT-SIMULATE PARAMETER NAMES
%
% Extract the parameter names from simParameters.m if available.
% ============================================================

fprintf('\n');
fprintf('SIMULATION PARAMETER SOURCE\n');
fprintf('------------------------------------------------------------\n');

simParamPath = which('simParameters');

if isempty(simParamPath)

    fprintf('simParameters : NOT FOUND\n');

else

    fprintf('simParameters : %s\n',simParamPath);

    txt = fileread(simParamPath);

    requestedNames = { ...
        'SourceModel', ...
        'InitialPressureVariable', ...
        'GridSizeX', ...
        'GridSizeY', ...
        'Dx', ...
        'Dy', ...
        'CFL', ...
        'SimulationEndTime', ...
        'MediumModel', ...
        'MediumMapPath', ...
        'AlphaCoeff', ...
        'AlphaPower', ...
        'SensorType', ...
        'SensorModel', ...
        'NumTransducers', ...
        'ElementWidth', ...
        'CenterFrequency', ...
        'FractionalBandwidth', ...
        'NoiseModel', ...
        'TargetSNR', ...
        'RandomSeed'};

    fprintf('\nRequested parameter-name audit:\n');

    for k = 1:numel(requestedNames)

        tf = contains( ...
            txt, ...
            requestedNames{k}, ...
            'IgnoreCase',false);

        fprintf('%-30s : %d\n', ...
            requestedNames{k},tf);
    end
end

%% ============================================================
% 4. FIND EXISTING MONTE CARLO OUTPUTS
% ============================================================

fprintf('\n');
fprintf('EXISTING MONTE CARLO / REALISTIC OUTPUTS\n');
fprintf('------------------------------------------------------------\n');

searchRoots = { ...
    fullfile(patboxRoot,'outputs'), ...
    fullfile(patboxRoot,'results'), ...
    fullfile(revisionDir,'outputs')};

for r = 1:numel(searchRoots)

    root = searchRoots{r};

    if ~isfolder(root)
        continue;
    end

    fprintf('\nRoot: %s\n',root);

    filesA = dir( ...
        fullfile(root,'**','*monte*carlo*.mat'));

    filesB = dir( ...
        fullfile(root,'**','*realistic*.mat'));

    candidates = [filesA;filesB];

    for k = 1:min(numel(candidates),20)

        fprintf('  %s\n', ...
            fullfile( ...
            candidates(k).folder, ...
            candidates(k).name));
    end
end

%% ============================================================
% 5. AUDIT ONE EXISTING SIM STRUCT IF AVAILABLE
%
% Prefer the successful D5 combined non-ideal simulation already
% produced during the sequential revision study.
% ============================================================

referenceSimFile = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step03_sequential_forward', ...
    'D5_noise.mat');

fprintf('\n');
fprintf('REFERENCE SIMULATION STRUCTURE\n');
fprintf('------------------------------------------------------------\n');

if ~isfile(referenceSimFile)

    fprintf('Reference file not found:\n%s\n', ...
        referenceSimFile);

else

    S = load(referenceSimFile);

    vars = fieldnames(S);

    fprintf('MAT variables:\n');

    for k = 1:numel(vars)
        fprintf('  %s\n',vars{k});
    end

    if isfield(S,'sim')
        sim = S.sim;
    else

        sim = [];

        for k = 1:numel(vars)

            value = S.(vars{k});

            if isstruct(value) && ...
                    isfield(value,'sensor_data')

                sim = value;
                break;
            end
        end
    end

    if isempty(sim)

        fprintf('\nCould not automatically identify sim struct.\n');

    else

        fprintf('\nsim fields:\n');

        disp(fieldnames(sim));

        %% ----------------------------------------------------
        % RF variants
        % -----------------------------------------------------

        fprintf('\nRF DATA VARIANTS\n');
        fprintf('------------------------------------------------------------\n');

        auditRFField(sim,'sensor_data_clean');
        auditRFField(sim,'sensor_data_system');
        auditRFField(sim,'sensor_data');

        %% ----------------------------------------------------
        % Acquisition metadata
        % -----------------------------------------------------

        if isfield(sim,'info')

            fprintf('\nsim.info fields:\n');
            disp(fieldnames(sim.info));

            if isfield(sim.info,'acquisition')

                fprintf('\nsim.info.acquisition fields:\n');
                disp(fieldnames(sim.info.acquisition));

                fprintf('\nAcquisition metadata:\n');
                disp(sim.info.acquisition);
            end
        end

        %% ----------------------------------------------------
        % Medium
        % -----------------------------------------------------

        if isfield(sim,'medium')

            fprintf('\nMedium fields:\n');
            disp(fieldnames(sim.medium));

            if isfield(sim.medium,'sound_speed')

                c = double(sim.medium.sound_speed);

                fprintf( ...
                    'c mean/std/range = %.4f / %.4f / %.4f--%.4f m/s\n', ...
                    mean(c(:)), ...
                    std(c(:)), ...
                    min(c(:)), ...
                    max(c(:)));
            end

            if isfield(sim.medium,'density')

                rho = double(sim.medium.density);

                fprintf( ...
                    'rho mean/std = %.4f / %.4f kg/m^3\n', ...
                    mean(rho(:)), ...
                    std(rho(:)));
            end
        end
    end
end

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 09B-0 COMPLETE\n');
fprintf('============================================================\n');


%% ============================================================
% LOCAL FUNCTION
% ============================================================

function auditRFField(sim,name)

    fprintf('%-24s : ',name);

    if ~isfield(sim,name)

        fprintf('MISSING\n');
        return;
    end

    value = sim.(name);

    if isstruct(value)

        fprintf('struct');

        if isfield(value,'p')

            p = double(value.p);

            fprintf( ...
                ' | p = %d x %d | RMS %.6e', ...
                size(p,1), ...
                size(p,2), ...
                sqrt(mean(p(:).^2)));
        end

        fprintf('\n');

    elseif isnumeric(value)

        p = double(value);

        fprintf( ...
            '%s | %d x %d | RMS %.6e\n', ...
            class(value), ...
            size(p,1), ...
            size(p,2), ...
            sqrt(mean(p(:).^2)));

    else

        fprintf('%s\n',class(value));
    end
end