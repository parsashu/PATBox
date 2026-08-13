% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
%
% Component: Core Forward Simulation Orchestrator
% Authors:   Parsa Shahidi
% Date:      June 2026
%
% Description:
%   Central entry point for physics-aware PATBox forward simulations. Dispatches
%   to forward_simulation_physical, supports loading saved datasets, and returns
%   either a rich simulation struct or legacy multi-output unpacking.
% =========================================================================

function varargout = patSimulate(img_path, varargin)
%PATSIMULATE Run a physics-aware k-Wave simulation or load saved data.
%
%   sim = patSimulate()
%   sim = patSimulate(img_path)
%   sim = patSimulate(..., 'SensorType', 'linear', 'TargetSNRdB', 20)
%
%   [sensor_data, sensor, kgrid, source, p0_reference, sound_speed] = patSimulate(...)
%
% Defaults come from PATBox/params.yaml (simulation section). Prefer the single
% struct output: it carries medium maps, ordered element geometry, and ideal /
% system / measured RF traces. Legacy multi-output calls remain supported.
% Deprecated geometry wrappers (forward_simulation_linear/square/circular) still
% route through the legacy adapter for old scripts.

    cfg = applySimOverrides(simParameters(), varargin);

    if ~logical(cfg.UseSimulation)
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

    sim = forward_simulation_physical(img_path, cfg);
    sim.info.use_simulation = true;
    sim.info.loaded_from_file = false;
    sim.info.config = cfg;
    if ~isfield(sim, 'noisy_p0') || isempty(sim.noisy_p0)
        sim.noisy_p0 = sim.p0_reference;
    end
    varargout = packageSimOutput(sim, nargout);
end

function cfg = applySimOverrides(cfg, args)
    valid = fieldnames(cfg);
    i = 1;
    while i <= numel(args)
        name = args{i};
        if ~(ischar(name) || isstring(name)) || i == numel(args)
            error('PATBox:InvalidParameter', 'Expected complete name-value pairs.');
        end
        key = matlab.lang.makeValidName(char(name));
        if ~any(strcmp(key, valid))
            error('PATBox:UnknownParameter', 'Unknown simulation parameter: %s', char(name));
        end
        cfg.(key) = args{i + 1};
        i = i + 2;
    end

    cfg.SensorType = lower(char(cfg.SensorType));
    if ~ismember(cfg.SensorType, {'linear', 'square', 'circular', 'arc'})
        error('PATBox:InvalidSensorType', ...
            'SensorType must be linear, square, circular, or arc.');
    end
end

function outputs = packageSimOutput(sim, nOut)
    if nOut <= 1
        outputs = {sim};
        return;
    end

    p0 = sim.p0_reference;
    if isfield(sim, 'noisy_p0') && ~isempty(sim.noisy_p0)
        p0Out = sim.noisy_p0;
    else
        p0Out = p0;
    end

    outputs = {sim.sensor_data, sim.sensor, sim.kgrid, sim.source, p0Out, sim.sound_speed};
    if nOut >= 7
        outputs{7} = sim.info;
    end
    if nOut >= 8
        outputs{8} = sim.medium;
    end
    if nOut >= 9
        outputs{9} = sim.sensor_geometry;
    end
end
