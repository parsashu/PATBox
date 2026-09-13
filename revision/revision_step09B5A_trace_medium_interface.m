clear;
clc;

%% ============================================================
% STEP 09B-5A
% Trace how the successful heterogeneous Step-03 simulation
% injected the acoustic medium into patSimulate.
%
% NO k-Wave simulation is run here.
% ============================================================

patboxRoot = ...
    'C:\Users\asus\Documents\GitHub\PATBox';

revisionDir = ...
    fullfile(patboxRoot,'revision');

addpath(patboxRoot,'-begin');
addpath(revisionDir,'-begin');

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 09B-5A: TRACE HETEROGENEOUS-MEDIUM INTERFACE\n');
fprintf('============================================================\n');

%% ============================================================
% 1. LOAD SUCCESSFUL STEP-03 HETEROGENEOUS CASE
% ============================================================

d5File = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step03_sequential_forward', ...
    'D5_noise.mat');

assert(isfile(d5File), ...
    'D5_noise.mat not found.');

S = load(d5File,'sim');

simD5 = S.sim;

fprintf('\n');
fprintf('SUCCESSFUL D5 MEDIUM\n');
fprintf('------------------------------------------------------------\n');

c = double(simD5.medium.sound_speed);
rho = double(simD5.medium.density);

fprintf('c mean/std/min/max = %.6f / %.6f / %.6f / %.6f\n', ...
    mean(c(:)), ...
    std(c(:)), ...
    min(c(:)), ...
    max(c(:)));

fprintf('rho mean/std/min/max = %.6f / %.6f / %.6f / %.6f\n', ...
    mean(rho(:)), ...
    std(rho(:)), ...
    min(rho(:)), ...
    max(rho(:)));

fprintf('corr(c,rho) = %.9f\n', ...
    corr(c(:),rho(:)));

%% ============================================================
% 2. DISPLAY sim.info.medium
% ============================================================

fprintf('\n');
fprintf('simD5.info.medium\n');
fprintf('------------------------------------------------------------\n');

if isfield(simD5.info,'medium')

    disp(simD5.info.medium);

else

    fprintf('sim.info.medium does not exist.\n');
end

%% ============================================================
% 3. SEARCH CONFIG FOR MEDIUM-RELATED FIELDS
% ============================================================

fprintf('\n');
fprintf('MEDIUM-RELATED CONFIG FIELDS\n');
fprintf('------------------------------------------------------------\n');

if isfield(simD5.info,'config')

    cfg = simD5.info.config;

    names = fieldnames(cfg);

    keys = { ...
        'medium', ...
        'sound', ...
        'density', ...
        'rho', ...
        'map', ...
        'heter', ...
        'corr', ...
        'alpha'};

    for k = 1:numel(names)

        n = lower(names{k});

        hit = false;

        for q = 1:numel(keys)

            if contains(n,keys{q})
                hit = true;
                break;
            end
        end

        if ~hit
            continue;
        end

        value = cfg.(names{k});

        fprintf('%-40s : ',names{k});

        printCompact(value);
    end
end

%% ============================================================
% 4. SEARCH REVISION SOURCE CODE
%
% Find the EXACT successful Step-03 implementation.
% ============================================================

fprintf('\n');
fprintf('REVISION SOURCE-CODE MATCHES\n');
fprintf('------------------------------------------------------------\n');

mFiles = ...
    dir(fullfile(revisionDir,'**','*.m'));

patterns = { ...
    'D3_heterogeneity', ...
    'D4_attenuation', ...
    'D5_noise', ...
    'makeRandomForwardMedium', ...
    'MediumMapPath', ...
    'MediumModel', ...
    'sound_speed', ...
    'SoundSpeedMap', ...
    'DensityMap'};

for f = 1:numel(mFiles)

    filePath = ...
        fullfile( ...
        mFiles(f).folder, ...
        mFiles(f).name);

    try
        txt = fileread(filePath);
    catch
        continue;
    end

    matched = false;

    for p = 1:numel(patterns)

        if contains(txt,patterns{p}, ...
                'IgnoreCase',true)

            matched = true;
            break;
        end
    end

    if ~matched
        continue;
    end

    fprintf('\n============================================================\n');
    fprintf('FILE: %s\n',filePath);
    fprintf('============================================================\n');

    lines = ...
        regexp(txt,'\r\n|\n|\r','split');

    hitLines = [];

    for i = 1:numel(lines)

        for p = 1:numel(patterns)

            if contains( ...
                    lines{i}, ...
                    patterns{p}, ...
                    'IgnoreCase',true)

                hitLines(end+1) = i; %#ok<AGROW>
                break;
            end
        end
    end

    if isempty(hitLines)
        continue;
    end

    % Print context around each hit.
    printed = false(1,numel(lines));

    for h = 1:numel(hitLines)

        i1 = max(1,hitLines(h)-8);
        i2 = min(numel(lines),hitLines(h)+12);

        for i = i1:i2

            if printed(i)
                continue;
            end

            fprintf('%5d | %s\n', ...
                i,lines{i});

            printed(i) = true;
        end

        fprintf('      ----------------------------------------\n');
    end
end

%% ============================================================
% 5. CURRENT FAILED PILOT COMPARISON
% ============================================================

pilotFile = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step09_montecarlo', ...
    'montecarlo_forward_pilot_seed001.mat');

fprintf('\n');
fprintf('CURRENT STEP-09 PILOT COMPARISON\n');
fprintf('------------------------------------------------------------\n');

if isfile(pilotFile)

    P = load(pilotFile,'simBase');

    cP = ...
        double(P.simBase.medium.sound_speed);

    rhoP = ...
        double(P.simBase.medium.density);

    fprintf('Pilot c std   = %.9f m/s\n', ...
        std(cP(:)));

    fprintf('Pilot rho std = %.9f kg/m^3\n', ...
        std(rhoP(:)));

    if std(cP(:)) == 0 || ...
       std(rhoP(:)) == 0

        fprintf('\n');
        fprintf('HETEROGENEITY STATUS = FAIL\n');
        fprintf(['The current Step-09 pilot used a homogeneous ', ...
                 'forward medium.\n']);
    end

else

    fprintf('Pilot MAT file not found.\n');
end

%% ============================================================
% FINAL
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 09B-5A COMPLETE\n');
fprintf('============================================================\n');


%% ============================================================
% LOCAL FUNCTION
% ============================================================

function printCompact(value)

    if ischar(value) || ...
            (isstring(value) && isscalar(value))

        fprintf('%s\n',string(value));

    elseif isnumeric(value) || islogical(value)

        if isempty(value)

            fprintf('[]\n');

        elseif isscalar(value)

            fprintf('%.12g\n',double(value));

        elseif ismatrix(value)

            fprintf( ...
                '%s [%d x %d]', ...
                class(value), ...
                size(value,1), ...
                size(value,2));

            v = double(value);

            fprintf( ...
                ' | mean %.6g | std %.6g | min %.6g | max %.6g\n', ...
                mean(v(:)), ...
                std(v(:)), ...
                min(v(:)), ...
                max(v(:)));

        else

            fprintf('%s\n',class(value));
        end

    elseif isstruct(value)

        fprintf('struct\n');

        disp(value);

    else

        fprintf('%s\n',class(value));
    end
end