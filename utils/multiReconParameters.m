function params = multiReconParameters(name)
%MULTIRECONPARAMETERS Multi-algorithm reconstruction example settings for PATBox.
%
%   cfg = multiReconParameters()
%   value = multiReconParameters('Algorithms')
%
%   Defaults are loaded from PATBox/params.yaml (multi_reconstruction section).

    cfg = loadPatboxYaml('multi_reconstruction');
    cfg.IncludeIterative = coerceLogical(cfg.IncludeIterative);
    cfg.envelope_signal = coerceLogical(cfg.envelope_signal);
    cfg.remove_negatives = coerceLogical(cfg.remove_negatives);
    cfg.bandpass_filter = coerceLogical(cfg.bandpass_filter);
    cfg.SaveMat = coerceLogical(cfg.SaveMat);
    cfg.SavePng = coerceLogical(cfg.SavePng);
    cfg.SaveFigure = coerceLogical(cfg.SaveFigure);
    cfg.Algorithms = resolveMultiReconAlgorithms(cfg);

    if nargin >= 1
        key = matlab.lang.makeValidName(char(name));
        if ~isfield(cfg, key)
            error('PATBox:UnknownParameter', 'Unknown multi-reconstruction parameter: %s', name);
        end
        params = cfg.(key);
        return;
    end

    params = cfg;
end

function algorithms = resolveMultiReconAlgorithms(cfg)
    algorithms = normalizeStringList(cfg.Algorithms);
    if isempty(algorithms)
        algorithms = patListAlgorithms();
    end
    if ~logical(cfg.IncludeIterative)
        algorithms = algorithms(~contains(upper(string(algorithms)), 'ITERATIVE'));
    end
end

function list = normalizeStringList(value)
    if isempty(value)
        list = {};
        return;
    end

    if isstring(value)
        value = cellstr(value);
    end

    if ischar(value)
        if contains(value, ',')
            parts = split(string(value), ',');
            list = cellstr(strtrim(parts));
        else
            list = {value};
        end
        return;
    end

    if iscell(value)
        list = cellfun(@char, value, 'UniformOutput', false);
        return;
    end

    list = {};
end
