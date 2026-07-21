function params = reconParameters(name)
%RECONPARAMETERS Reconstruction parameters for PATBox.
%
%   params = reconParameters()
%   value  = reconParameters('AlgorithmName')
%
%   Defaults are loaded from PATBox/params.yaml (reconstruction section).
%   Iterative parameters live under reconstruction.iterative in the yaml file
%   but are returned as a flat list for use with patReconstruct.

    general_names = {
        'AlgorithmName'
        'envelope_signal'
        'remove_negatives'
        'bandpass_filter'
        'frequency_low'
        'frequency_high'
        'SaveOutput'
        'SaveMat'
        'SavePng'
        'OutputDir'
        'OutputSuffix'
    };
    iterative_names = {
        'interp_method'
        'InitialGuess'
        'NumIterations'
        'StepSize'
        'UpdateMethod'
    };

    cfg = flattenReconConfig(loadPatboxYaml('reconstruction'));
    cfg = coerceReconLogicalParams(cfg);
    param_names = [general_names; iterative_names];
    params = cell(numel(param_names), 2);

    for i = 1:numel(param_names)
        key = param_names{i};
        params{i, 1} = key;
        params{i, 2} = {coerceReconValue(key, cfg.(key)), reconParamValidator(key)};
    end

    if nargin >= 1
        for i = 1:size(params, 1)
            if strcmpi(params{i, 1}, name)
                params = params{i, 2}{1};
                return;
            end
        end
        error('PATBox:UnknownParameter', 'Unknown parameter: %s', name);
    end
end

function cfg = flattenReconConfig(cfg)
    if ~isfield(cfg, 'iterative')
        return;
    end

    iter_fields = fieldnames(cfg.iterative);
    for i = 1:numel(iter_fields)
        key = iter_fields{i};
        cfg.(key) = cfg.iterative.(key);
    end
    cfg = rmfield(cfg, 'iterative');
end

function cfg = coerceReconLogicalParams(cfg)
    logical_fields = {'envelope_signal', 'remove_negatives', 'bandpass_filter', 'SaveOutput', 'SaveMat', 'SavePng'};
    for i = 1:numel(logical_fields)
        key = logical_fields{i};
        if isfield(cfg, key)
            cfg.(key) = coerceLogical(cfg.(key));
        end
    end
end

function value = coerceReconValue(name, value)
    if any(strcmp(name, {'envelope_signal', 'remove_negatives', 'bandpass_filter', 'SaveOutput', 'SaveMat', 'SavePng'}))
        value = coerceLogical(value);
    end
end

function validator = reconParamValidator(name)
    switch name
        case {'envelope_signal', 'remove_negatives', 'bandpass_filter', 'SaveOutput', 'SaveMat', 'SavePng'}
            validator = @isLogicalLike;
        case {'AlgorithmName', 'InitialGuess', 'UpdateMethod', 'interp_method', 'OutputDir', 'OutputSuffix'}
            validator = @(x) ischar(x) || isstring(x);
        case {'NumIterations', 'StepSize', 'frequency_low', 'frequency_high'}
            validator = @isnumeric;
        otherwise
            validator = @(x) true;
    end
end

function tf = isLogicalLike(value)
    tf = islogical(value) || (isnumeric(value) && isscalar(value) && (value == 0 || value == 1));
end
