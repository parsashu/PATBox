% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Core Forward Simulation Orchestrator & Sensor Array Dispatcher
% Authors:   Parsa Shahidi
% Date:      June 2026
%
% Description:
%   This function serves as the central orchestration framework for forward 
%   photoacoustic simulations within PATBox. It features an automated multi-
%   geometry dispatcher supporting linear, square, and circular sensor arrays. 
%   The module encapsulates configuration overrides, manages file-caching to 
%   bypass redundant k-Wave computational execution, and utilizes polymorphic 
%   output packaging to match variable downstream pipeline demands.
% =========================================================================

function varargout = patSimulate(img_path, varargin)
%PATSIMULATE Run a k-Wave forward simulation or load saved sensor data.
%
%   sim = patSimulate()
%   sim = patSimulate(img_path)
%   sim = patSimulate(..., 'SensorType', 'linear', 'NoiseLevel', 0.1)
%
%   [sensor_data, sensor, kgrid, source, noisy_p0, sound_speed] = patSimulate(...)
%
%   Defaults come from PATBox/params.yaml (simulation section). Set
%   UseSimulation to false and SensorDataPath to load a saved .mat file
%   instead of running k-Wave.

    cfg = applySimOverrides(simParameters(), varargin);

    if ~cfg.UseSimulation
        sim = loadSimulation(resolvePatboxPath(cfg.SensorDataPath));
        varargout = packageSimOutput(sim, nargout);
        return;
    end

    if nargin < 1 || isempty(img_path)
        img_path = cfg.ImagePath;
    end
    img_path = resolvePatboxPath(img_path);

    if ~exist(img_path, 'file')
        error('PATBox:ImageNotFound', 'Could not find image: %s', img_path);
    end

    sim_opts = buildForwardSimOptions(cfg);

    switch lower(char(cfg.SensorType))
        case 'linear'
            [sensor_data, sensor, kgrid, source, noisy_p0, sound_speed] = ...
                forward_simulation_linear(img_path, cfg.NoiseLevel, sim_opts);
        case 'square'
            [sensor_data, sensor, kgrid, source, noisy_p0, sound_speed] = ...
                forward_simulation_square(img_path, cfg.NoiseLevel, sim_opts);
        case 'circular'
            [sensor_data, sensor, kgrid, source, noisy_p0, sound_speed] = ...
                forward_simulation_circular(img_path, cfg.NoiseLevel, sim_opts);
        otherwise
            error('PATBox:InvalidSensorType', 'Unknown SensorType: %s', cfg.SensorType);
    end

    sim = buildSimStruct(sensor_data, sensor, kgrid, source, noisy_p0, sound_speed, cfg, img_path);
    varargout = packageSimOutput(sim, nargout, sensor_data, sensor, kgrid, source, noisy_p0, sound_speed);
end

function sim_opts = buildForwardSimOptions(cfg)
    sim_opts = struct( ...
        'GridSize', cfg.GridSize, ...
        'MinFrequency', cfg.MinFrequency, ...
        'MaxFrequency', cfg.MaxFrequency, ...
        'SoundSpeed', cfg.SoundSpeed, ...
        'Density', cfg.Density, ...
        'NumTransducers', cfg.NumTransducers, ...
        'Pitch', cfg.Pitch, ...
        'Kerf', cfg.Kerf);
end

function cfg = applySimOverrides(cfg, args)
    sim_fields = {
        'UseSimulation'
        'SensorDataPath'
        'ImagePath'
        'SensorType'
        'NoiseLevel'
        'GridSize'
        'MinFrequency'
        'MaxFrequency'
        'SoundSpeed'
        'Density'
        'NumTransducers'
        'Pitch'
        'Kerf'
    };

    i = 1;
    while i <= numel(args)
        name = args{i};
        if ~(ischar(name) || isstring(name))
            error('PATBox:InvalidParameter', 'Expected name-value pairs.');
        end
        key = matlab.lang.makeValidName(char(name));
        if i == numel(args)
            error('PATBox:MissingValue', 'Missing value for parameter %s.', char(name));
        end
        if any(strcmp(key, sim_fields))
            cfg.(key) = args{i + 1};
        else
            error('PATBox:UnknownParameter', 'Unknown simulation parameter: %s', char(name));
        end
        i = i + 2;
    end

    cfg.SensorType = lower(char(cfg.SensorType));
    if ~ismember(cfg.SensorType, {'linear', 'square', 'circular'})
        error('PATBox:InvalidSensorType', 'SensorType must be linear, square, or circular.');
    end
end

function sim = buildSimStruct(sensor_data, sensor, kgrid, source, noisy_p0, sound_speed, cfg, img_path)
    sim = struct( ...
        'sensor_data', sensor_data, ...
        'sensor', sensor, ...
        'kgrid', kgrid, ...
        'source', source, ...
        'noisy_p0', noisy_p0, ...
        'sound_speed', sound_speed, ...
        'info', struct( ...
            'use_simulation', true, ...
            'sensor_type', cfg.SensorType, ...
            'noise_level', cfg.NoiseLevel, ...
            'grid_size', cfg.GridSize, ...
            'min_frequency', cfg.MinFrequency, ...
            'max_frequency', cfg.MaxFrequency, ...
            'img_path', char(img_path), ...
            'num_sensors', countSensors(sensor), ...
            'loaded_from_file', false));
end

function outputs = packageSimOutput(sim, n_out, sensor_data, sensor, kgrid, source, noisy_p0, sound_speed)
    if nargin < 3
        sensor_data = sim.sensor_data;
        sensor = sim.sensor;
        kgrid = sim.kgrid;
        source = sim.source;
        noisy_p0 = sim.noisy_p0;
        sound_speed = sim.sound_speed;
    end

    if n_out <= 1
        outputs = {sim};
        return;
    end

    outputs = {sensor_data, sensor, kgrid, source, noisy_p0, sound_speed};
    if n_out >= 7
        outputs{7} = sim.info;
    end
end

function n = countSensors(sensor)
    if isfield(sensor, 'mask')
        if ndims(sensor.mask) == 2
            n = sum(sensor.mask(:) > 0);
        else
            n = size(sensor.mask, 2);
        end
    else
        n = NaN;
    end
end
