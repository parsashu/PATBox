clear;
clc;

%% ============================================================
% STEP 09B-1
% Freeze the exact current non-ideal protocol and locate the
% original fixed three-line source used by PATBox.
% ============================================================

patboxRoot = ...
    'C:\Users\asus\Documents\GitHub\PATBox';

revisionDir = ...
    fullfile(patboxRoot,'revision');

addpath(patboxRoot,'-begin');
addpath(revisionDir,'-begin');

install_patbox();

outDir = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step09_montecarlo');

if ~exist(outDir,'dir')
    mkdir(outDir);
end

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 09B-1: FREEZE MONTE CARLO PROTOCOL\n');
fprintf('============================================================\n');

%% ============================================================
% 1. LOAD SUCCESSFUL COMBINED NON-IDEAL REFERENCE
% ============================================================

refFile = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step03_sequential_forward', ...
    'D5_noise.mat');

assert(isfile(refFile), ...
    'Reference D5 file not found.');

S = load(refFile,'sim');

simRef = S.sim;

assert(isfield(simRef,'info'));
assert(isfield(simRef.info,'config'));

cfgRef = simRef.info.config;

fprintf('\nREFERENCE FILE\n');
fprintf('------------------------------------------------------------\n');
fprintf('%s\n',refFile);

fprintf('\nReference source path:\n');

if isfield(simRef.info,'image_path')
    fprintf('%s\n',string(simRef.info.image_path));
else
    fprintf('image_path not stored\n');
end

%% ============================================================
% 2. CONFIG FIELD AUDIT
% ============================================================

fprintf('\n');
fprintf('CONFIGURATION FIELD AUDIT\n');
fprintf('------------------------------------------------------------\n');

configNames = fieldnames(cfgRef);

tokens = { ...
    'grid','nx','ny','dx','dy', ...
    'cfl','time','duration', ...
    'sound','density','rho', ...
    'heter','corr', ...
    'alpha','atten', ...
    'sensor','transducer','receiver', ...
    'element','aperture', ...
    'frequency','freq','band', ...
    'noise','snr','seed', ...
    'pml','cast','smooth'};

keep = false(size(configNames));

for i = 1:numel(configNames)

    n = lower(configNames{i});

    for j = 1:numel(tokens)

        if contains(n,tokens{j})
            keep(i) = true;
            break;
        end
    end
end

selectedNames = configNames(keep);

for i = 1:numel(selectedNames)

    name = selectedNames{i};
    value = cfgRef.(name);

    fprintf('%-38s : ',name);

    printValueCompact(value);
end

%% ============================================================
% 3. CHECK CRITICAL REFERENCE PHYSICS FROM sim STRUCT
% ============================================================

fprintf('\n');
fprintf('REFERENCE PHYSICS\n');
fprintf('------------------------------------------------------------\n');

fprintf('Grid                 = %d x %d\n', ...
    simRef.kgrid.Nx,simRef.kgrid.Ny);

fprintf('dx                   = %.6f um\n', ...
    double(simRef.kgrid.dx)*1e6);

fprintf('dy                   = %.6f um\n', ...
    double(simRef.kgrid.dy)*1e6);

fprintf('Nt                   = %d\n', ...
    numel(simRef.kgrid.t_array));

if numel(simRef.kgrid.t_array) > 1
    dt = double(simRef.kgrid.t_array(2) - ...
        simRef.kgrid.t_array(1));

    fprintf('dt                   = %.9f ns\n', ...
        dt*1e9);

    fprintf('t_end                = %.6f us\n', ...
        double(simRef.kgrid.t_array(end))*1e6);
end

fprintf('Receivers            = %d\n', ...
    simRef.info.num_sensors);

fprintf('Sensor model         = %s\n', ...
    string(simRef.info.sensor_model));

fprintf('Element width        = %.4f mm\n', ...
    double(simRef.info.element_width_m)*1e3);

fprintf('Center frequency     = %.4f MHz\n', ...
    double(simRef.info.center_frequency_hz)*1e-6);

fprintf('Fractional bandwidth = %.2f %%\n', ...
    double(simRef.info.fractional_bandwidth_percent));

if isfield(simRef.medium,'alpha_coeff')

    fprintf('alpha coeff          = %.6f\n', ...
        double(simRef.medium.alpha_coeff));
end

if isfield(simRef.medium,'alpha_power')

    fprintf('alpha power          = %.6f\n', ...
        double(simRef.medium.alpha_power));
end

%% ============================================================
% 4. ACQUISITION RANDOM-SEED AUDIT
% ============================================================

A = simRef.info.acquisition;

fprintf('\n');
fprintf('RANDOM-SEED REFERENCE\n');
fprintf('------------------------------------------------------------\n');

fprintf('Base seed             = %d\n', ...
    A.base_random_seed);

fprintf('Acquisition seed      = %d\n', ...
    A.random_seed);

fprintf('Seed offset           = %d\n', ...
    A.random_seed - A.base_random_seed);

fprintf('Noise model           = %s\n', ...
    string(A.noise_model));

fprintf('Target SNR            = %.6f dB\n', ...
    double(A.target_snr_db));

fprintf('Achieved additive SNR = %.9f dB\n', ...
    double(A.achieved_additive_snr_db));

%% ============================================================
% 5. VERIFY RF SEPARATION
% ============================================================

pClean = double(simRef.sensor_data_clean.p);
pSystem = double(simRef.sensor_data_system.p);
pMeasured = double(simRef.sensor_data.p);

rmsClean = rmsGlobal(pClean);
rmsSystem = rmsGlobal(pSystem);
rmsNoise = rmsGlobal(pMeasured-pSystem);

achieved = ...
    20*log10(rmsSystem/rmsNoise);

fprintf('\n');
fprintf('RF SEPARATION AUDIT\n');
fprintf('------------------------------------------------------------\n');

fprintf('Clean RMS             = %.9e\n',rmsClean);
fprintf('System RMS            = %.9e\n',rmsSystem);
fprintf('Added-noise RMS       = %.9e\n',rmsNoise);
fprintf('Recomputed SNR        = %.9f dB\n',achieved);

assert(abs(achieved-double(A.target_snr_db)) < 1e-6);

fprintf('RF/SNR audit          = PASS\n');

%% ============================================================
% 6. SEARCH MATLAB SOURCE FILES FOR THREE-LINE IMPLEMENTATION
% ============================================================

fprintf('\n');
fprintf('THREE-LINE SOURCE CODE CANDIDATES\n');
fprintf('------------------------------------------------------------\n');

mFiles = dir(fullfile(patboxRoot,'**','*.m'));

candidateM = strings(0,1);

searchPatterns = { ...
    'three-line', ...
    'three_line', ...
    'three line', ...
    '0.125', ...
    '0.250', ...
    '0.500'};

for k = 1:numel(mFiles)

    path = fullfile(mFiles(k).folder,mFiles(k).name);

    try
        txt = lower(fileread(path));
    catch
        continue;
    end

    score = 0;

    for p = 1:numel(searchPatterns)

        if contains(txt,lower(searchPatterns{p}))
            score = score + 1;
        end
    end

    % Require evidence for both "line" and at least one width.
    hasLine = ...
        contains(txt,'three-line') || ...
        contains(txt,'three_line') || ...
        contains(txt,'three line');

    hasWidth = ...
        contains(txt,'0.125') || ...
        contains(txt,'0.250') || ...
        contains(txt,'0.500');

    if hasLine || (hasWidth && contains(txt,'line'))

        candidateM(end+1,1) = string(path); %#ok<AGROW>

        fprintf('%s\n',path);
    end
end

if isempty(candidateM)
    fprintf('No MATLAB candidates found.\n');
end

%% ============================================================
% 7. SEARCH MAT FILES BY NAME
% ============================================================

fprintf('\n');
fprintf('THREE-LINE MAT-FILE CANDIDATES\n');
fprintf('------------------------------------------------------------\n');

matFiles = dir(fullfile(patboxRoot,'**','*.mat'));

candidateMat = strings(0,1);

for k = 1:numel(matFiles)

    nameLower = lower(matFiles(k).name);

    if contains(nameLower,'line') || ...
       contains(nameLower,'phantom')

        path = fullfile( ...
            matFiles(k).folder, ...
            matFiles(k).name);

        candidateMat(end+1,1) = string(path); %#ok<AGROW>

        fprintf('%s\n',path);
    end
end

if isempty(candidateMat)
    fprintf('No MAT-file candidates found.\n');
end

%% ============================================================
% 8. INSPECT 192 x 192 P0-LIKE MAT VARIABLES
% ============================================================

fprintf('\n');
fprintf('192 x 192 P0-LIKE MAT CANDIDATES\n');
fprintf('------------------------------------------------------------\n');

p0Candidates = table();

for k = 1:numel(matFiles)

    path = fullfile( ...
        matFiles(k).folder, ...
        matFiles(k).name);

    try
        info = whos('-file',path);
    catch
        continue;
    end

    for j = 1:numel(info)

        sz = info(j).size;

        if numel(sz)==2 && ...
                isequal(sz,[192 192]) && ...
                any(strcmp( ...
                    info(j).class, ...
                    {'single','double','logical'}))

            variableName = string(info(j).name);

            if contains(lower(variableName),'p0') || ...
               contains(lower(variableName),'phantom') || ...
               contains(lower(variableName),'source')

                newRow = table( ...
                    string(path), ...
                    variableName, ...
                    string(info(j).class), ...
                    'VariableNames', ...
                    {'File','Variable','Class'});

                p0Candidates = ...
                    [p0Candidates;newRow]; %#ok<AGROW>

                fprintf('%s | variable = %s | %s\n', ...
                    path, ...
                    variableName, ...
                    info(j).class);
            end
        end
    end
end

if isempty(p0Candidates)
    fprintf('No 192 x 192 p0-like MAT candidates found.\n');
end

%% ============================================================
% 9. SAVE FROZEN REFERENCE
% ============================================================

protocol = struct();

protocol.referenceFile = refFile;
protocol.cfgReference = cfgRef;

protocol.grid.Nx = simRef.kgrid.Nx;
protocol.grid.Ny = simRef.kgrid.Ny;
protocol.grid.dx = simRef.kgrid.dx;
protocol.grid.dy = simRef.kgrid.dy;

protocol.sensor.model = simRef.info.sensor_model;
protocol.sensor.numSensors = simRef.info.num_sensors;
protocol.sensor.elementWidth_m = simRef.info.element_width_m;

protocol.detector.centerFrequency_hz = ...
    simRef.info.center_frequency_hz;

protocol.detector.fractionalBandwidth_percent = ...
    simRef.info.fractional_bandwidth_percent;

protocol.snrLevels_dB = [5 10 15 20 30];
protocol.baseSeeds = (1:50).';

protocol.referenceAcquisition = ...
    simRef.info.acquisition;

protocol.codeCandidates = candidateM;
protocol.matCandidates = candidateMat;
protocol.p0Candidates = p0Candidates;

save( ...
    fullfile(outDir,'montecarlo_protocol_frozen.mat'), ...
    'protocol', ...
    '-v7.3');

if ~isempty(p0Candidates)

    writetable( ...
        p0Candidates, ...
        fullfile( ...
            outDir, ...
            'p0_candidate_files.csv'));
end

fprintf('\n');
fprintf('Frozen protocol saved:\n');
fprintf('%s\n', ...
    fullfile(outDir,'montecarlo_protocol_frozen.mat'));

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 09B-1 COMPLETE\n');
fprintf('============================================================\n');


%% ============================================================
% LOCAL FUNCTIONS
% ============================================================

function r = rmsGlobal(x)

    x = double(x);

    r = sqrt(mean(x(:).^2));
end


function printValueCompact(value)

    if ischar(value) || ...
            (isstring(value) && isscalar(value))

        fprintf('%s\n',string(value));

    elseif isnumeric(value) || islogical(value)

        if isscalar(value)

            fprintf('%.12g\n',double(value));

        elseif numel(value) <= 8

            disp(value);

        else

            fprintf('%s [%s]\n', ...
                class(value), ...
                strjoin(string(size(value)),' x '));
        end

    elseif isstruct(value)

        fprintf('struct with %d fields\n', ...
            numel(fieldnames(value)));

    else

        fprintf('%s\n',class(value));
    end
end