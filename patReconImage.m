% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
%
% Component: High-Level Unified Simulation & Reconstruction API Dispatcher
% Authors:   Parsa Shahidi
% Date:      June 2026
%
% Description:
%   High-level PATBox entry point: simulate (or load), reconstruct, and evaluate.
% =========================================================================

function [p0_recon, sim, info, metrics] = patReconImage(img_path, varargin)
%PATRECONIMAGE Simulate (or load) and reconstruct from a vessel image.
%
%   [p0_recon, sim, info, metrics] = patReconImage()
%   [p0_recon, sim, info, metrics] = patReconImage(img_path)
%   [p0_recon, sim, info, metrics] = patReconImage(img_path, ...
%       'SensorType', 'linear', 'TargetSNRdB', 20, 'Algorithm', 'DMAS')
%
% Simulation name-value pairs may be any field from simParameters() /
% params.yaml simulation section (for example SensorType, TargetSNRdB,
% NoiseModel, GridSize, MediumModel). Reconstruction options pass through to
% patReconstruct.

    if nargin < 1
        img_path = '';
    elseif ~(ischar(img_path) || isstring(img_path) || isempty(img_path))
        varargin = [{img_path}, varargin];
        img_path = '';
    elseif isSimulationParameterName(img_path) || isReconParameterNameLocal(img_path)
        varargin = [{img_path}, varargin];
        img_path = '';
    end

    [sim_args, recon_args] = splitNameValueArgs(varargin);
    sim_cfg = applySimOverridesFromArgs(simParameters(), sim_args);

    if ~logical(sim_cfg.UseSimulation)
        sim = loadSimulation(resolvePatboxPath(sim_cfg.SensorDataPath));
    else
        if isempty(img_path)
            img_path = sim_cfg.ImagePath;
        end
        sim = patSimulate(img_path, sim_args{:});
    end

    [p0_recon, info] = patReconstruct(sim, recon_args{:});
    if isfield(sim, 'p0_reference')
        truth = sim.p0_reference;
    else
        truth = sim.source.p0;
    end
    metrics = patEvaluate(p0_recon, truth);
end

function cfg = applySimOverridesFromArgs(cfg, args)
    for i = 1:2:numel(args)
        key = matlab.lang.makeValidName(char(args{i}));
        cfg.(key) = args{i + 1};
    end
end

function [simArgs, reconArgs] = splitNameValueArgs(args)
    simArgs = {};
    reconArgs = {};
    if mod(numel(args), 2) ~= 0
        if ~isempty(args) && (ischar(args{1}) || isstring(args{1})) && ...
                ~isSimulationParameterName(args{1}) && ~isReconParameterNameLocal(args{1})
            reconArgs = args(1);
            args = args(2:end);
        else
            error('PATBox:InvalidNameValuePairs', 'Expected complete name-value pairs.');
        end
    end

    for i = 1:2:numel(args)
        name = args{i};
        if ~(ischar(name) || isstring(name))
            error('PATBox:InvalidParameterName', ...
                'Parameter names must be character vectors or strings.');
        end
        if isSimulationParameterName(name)
            simArgs(end + 1:end + 2) = {char(name), args{i + 1}}; %#ok<AGROW>
        elseif isReconParameterNameLocal(name)
            reconArgs(end + 1:end + 2) = {char(name), args{i + 1}}; %#ok<AGROW>
        else
            error('PATBox:UnknownParameter', 'Unknown PATBox parameter: %s', char(name));
        end
    end
end

function tf = isSimulationParameterName(name)
    names = fieldnames(simParameters());
    tf = any(strcmpi(char(name), names));
end

function tf = isReconParameterNameLocal(name)
    paramList = reconParameters();
    names = [{'Algorithm'}; paramList(:, 1)];
    tf = any(strcmpi(char(name), names));
end
