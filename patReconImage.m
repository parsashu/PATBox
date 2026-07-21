% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: High-Level Unified Simulation & Reconstruction API Dispatcher
% Authors:   Parsa Shahidi
% Date:      June 2026
%
% Description:
%   This function serves as the high-level entry-point API for PATBox. It 
%   features an automated parameter-splitting architecture that dispatches 
%   variable Name-Value pairs into separate simulation and reconstruction 
%   pipelines, dynamically switches between live forward modeling and pre-
%   computed dataset loading, and encapsulates the subsequent image 
%   reconstruction and quality metric evaluation.
% =========================================================================

function [p0_recon, sim, info, metrics] = patReconImage(img_path, varargin)
%PATRECONIMAGE Simulate (or load) and reconstruct from a vessel image.
%
%   [p0_recon, sim, info, metrics] = patReconImage()
%   [p0_recon, sim, info, metrics] = patReconImage(img_path)
%   [p0_recon, sim, info, metrics] = patReconImage(img_path, ...
%       'SensorType', 'linear', 'NoiseLevel', 0.1, 'Algorithm', 'DMAS')
%
%   Simulation options: UseSimulation, SensorDataPath, ImagePath, SensorType,
%   NoiseLevel, GridSize, MinFrequency, MaxFrequency, SoundSpeed, Density,
%   NumTransducers, Pitch, Kerf
%   Reconstruction options: Algorithm, remove_negatives, NumIterations, ...

    sim_param_names = {
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
    [sim_args, recon_args] = splitNameValueArgs(varargin, sim_param_names);

    sim_cfg = applySimOverridesFromArgs(simParameters(), sim_args);
    if ~sim_cfg.UseSimulation
        sim = loadSimulation(resolvePatboxPath(sim_cfg.SensorDataPath));
    else
        if nargin < 1 || isempty(img_path)
            img_path = sim_cfg.ImagePath;
        end
        sim = patSimulate(img_path, sim_args{:});
    end

    [p0_recon, info] = patReconstruct(sim, recon_args{:});
    metrics = patEvaluate(p0_recon, sim.source.p0);
end

function cfg = applySimOverridesFromArgs(cfg, args)
    i = 1;
    while i <= numel(args)
        key = matlab.lang.makeValidName(char(args{i}));
        cfg.(key) = args{i + 1};
        i = i + 2;
    end
end

function [matched, remaining] = splitNameValueArgs(args, names)
    matched = {};
    remaining = {};
    i = 1;
    while i <= numel(args)
        name = args{i};
        if (ischar(name) || isstring(name)) && any(strcmpi(char(name), names))
            if i == numel(args)
                error('PATBox:MissingValue', 'Missing value for parameter %s.', char(name));
            end
            matched(end + 1:end + 2) = {char(name), args{i + 1}}; %#ok<AGROW>
            i = i + 2;
        else
            remaining(end + 1:end + numel(args) - i + 1) = args(i:end); %#ok<AGROW>
            break;
        end
    end
end
