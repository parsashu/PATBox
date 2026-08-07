% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Core Image Reconstruction Dispatcher and Dynamic Interface
% Authors:   Parsa Shahidi
% Date:      June 2026
%
% Description:
%   This function serves as the central orchestration hub for photoacoustic 
%   image reconstruction within PATBox. It features a polymorphic input 
%   architecture that polymorphically processes either unified simulation 
%   structures or discrete physical fields, parses algorithm-specific meta-
%   parameters via a dynamic inputParser, handles asynchronous GPU execution 
%   fencing, and dispatches tasks to back-end computational engines.
% =========================================================================

function [p0_recon, info] = patReconstruct(varargin)
%PATRECONSTRUCT Photoacoustic image reconstruction.
%
%   p0_recon = patReconstruct(sim, 'DMAS')
%   p0_recon = patReconstruct(sensor_data, sensor, kgrid, sound_speed, 'DMAS')
%
%   [p0_recon, info] = patReconstruct(..., 'Algorithm', 'DS-DMAS', ...
%       'remove_negatives', true)
%
%   Use patListAlgorithms() to see supported names.

    if isempty(varargin)
        error('PATBox:InvalidInput', ...
            'Provide a simulation struct or sensor_data, sensor, kgrid, and sound_speed.');
    end

    if isSimStruct(varargin{1})
        sim = varargin{1};
        sensor_data = sim.sensor_data;
        if isfield(sim, 'sensor_geometry')
            sensor_geometry = sim.sensor_geometry;
        else
            sensor_geometry = sim.sensor;
        end
        kgrid = sim.kgrid;
        sound_speed = sim.sound_speed;
        recon_varargin = varargin(2:end);
        ground_truth = getGroundTruth(sim);
        sensor_type = resolveReconSensorType(sim);
    elseif numel(varargin) >= 4
        sensor_data = varargin{1};
        sensor_geometry = varargin{2};
        kgrid = varargin{3};
        sound_speed = varargin{4};
        recon_varargin = varargin(5:end);
        ground_truth = [];
        sensor_type = resolveReconSensorType([]);
    else
        error('PATBox:InvalidInput', ...
            'Provide a simulation struct or sensor_data, sensor, kgrid, and sound_speed.');
    end

    [sensor_data, sensor_geometry] = legacyCompatibleSensorInputs( ...
        sensor_data, sensor_geometry, kgrid);

    algorithm = reconParameters('AlgorithmName');
    algorithm_explicit = false;
    if ~isempty(recon_varargin) && (ischar(recon_varargin{1}) || isstring(recon_varargin{1})) && ...
            ~isReconParameterName(recon_varargin{1})
        algorithm = char(recon_varargin{1});
        algorithm_explicit = true;
        recon_varargin = recon_varargin(2:end);
    end

    p = inputParser;
    addParameter(p, 'Algorithm', algorithm, @(x) ischar(x) || isstring(x));
    recon_params = reconParameters();
    for i = 1:size(recon_params, 1)
        addParameter(p, recon_params{i, 1}, recon_params{i, 2}{1}, recon_params{i, 2}{2});
    end
    recon_varargin = coerceReconVarargs(recon_varargin);
    parse(p, recon_varargin{:});

    if algorithm_explicit || ~usedDefault(p, 'Algorithm')
        algo_name = char(p.Results.Algorithm);
    else
        algo_name = char(p.Results.AlgorithmName);
    end
    recon_func = getReconFunction(algo_name);
    recon_args = buildReconArgs(p, recon_params, algo_name);
    sensor_geometry = resolveSensorGeometry(sensor_geometry, algo_name);

    t0 = tic;
    p0_recon = recon_func(sensor_data, sensor_geometry, kgrid, sound_speed, recon_args{:});
    if exist('gpuDeviceCount', 'file') && gpuDeviceCount > 0
        wait(gpuDevice);
    end
    elapsed = toc(t0);

    saved_paths = saveReconOutput(p0_recon, ...
        struct('algorithm', upper(algo_name), 'elapsed_seconds', elapsed), ...
        'ground_truth', ground_truth, 'kgrid', kgrid, 'sensor_type', sensor_type, ...
        'SaveOutput', p.Results.SaveOutput, ...
        'SaveMat', p.Results.SaveMat, ...
        'SavePng', p.Results.SavePng, ...
        'OutputDir', p.Results.OutputDir);

    if nargout >= 2
        info = struct('algorithm', upper(algo_name), 'elapsed_seconds', elapsed);
        if saved_paths.mat ~= ""
            info.saved_mat = saved_paths.mat;
        end
        if saved_paths.png ~= ""
            info.saved_png = saved_paths.png;
        end
    end
end

function ground_truth = getGroundTruth(sim)
    ground_truth = [];
    if isfield(sim, 'p0_reference') && ~isempty(sim.p0_reference)
        ground_truth = sim.p0_reference;
    elseif isfield(sim, 'source') && isstruct(sim.source) && isfield(sim.source, 'p0')
        ground_truth = sim.source.p0;
    end
end

function tf = isSimStruct(value)
    tf = isstruct(value) && ...
        all(isfield(value, {'sensor_data', 'sensor', 'kgrid', 'sound_speed'}));
end

function tf = isReconParameterName(name)
    param_list = reconParameters();
    names = cell(1, size(param_list, 1) + 1);
    names{1} = 'Algorithm';
    for i = 1:size(param_list, 1)
        names{i + 1} = param_list{i, 1};
    end
    tf = any(strcmpi(char(name), names));
end

function args = coerceReconVarargs(args)
    logical_names = {'envelope_signal', 'remove_negatives', 'bandpass_filter'};
    i = 1;
    while i < numel(args)
        name = args{i};
        if (ischar(name) || isstring(name)) && any(strcmpi(char(name), logical_names))
            args{i + 1} = coerceLogical(args{i + 1});
        end
        i = i + 2;
    end
end

function tf = usedDefault(p, name)
    ud = p.UsingDefaults;
    if iscell(ud)
        tf = any(strcmp(name, ud));
    elseif isstruct(ud)
        tf = isfield(ud, name) && ud.(name);
    else
        tf = false;
    end
end

function geometry = resolveSensorGeometry(sensor_geometry, algo_name)
    if ~(isstruct(sensor_geometry) && isfield(sensor_geometry, 'mask'))
        geometry = sensor_geometry;
        return;
    end

    if isUbpAlgorithm(algo_name)
        geometry = sensor_geometry;
    else
        geometry = sensor_geometry.mask;
    end
end

function tf = isUbpAlgorithm(algo_name)
    tf = contains(upper(strrep(algo_name, '_', '-')), 'UBP');
end
