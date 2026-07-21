function params = benchmarkParameters(name)
%BENCHMARKPARAMETERS Benchmark-algorithms example settings for PATBox.
%
%   cfg = benchmarkParameters()
%   value = benchmarkParameters('Metrics')
%
%   Defaults are loaded from PATBox/params.yaml (benchmark_algorithms section).

    cfg = loadPatboxYaml('benchmark_algorithms');
    cfg.IncludeIterative = coerceLogical(cfg.IncludeIterative);
    cfg.envelope_signal = coerceLogical(cfg.envelope_signal);
    cfg.remove_negatives = coerceLogical(cfg.remove_negatives);
    cfg.bandpass_filter = coerceLogical(cfg.bandpass_filter);
    cfg.SaveCsv = coerceLogical(cfg.SaveCsv);
    cfg.Algorithms = resolveBenchmarkAlgorithms(cfg);
    cfg.Metrics = normalizeStringList(cfg.Metrics);

    if nargin >= 1
        key = matlab.lang.makeValidName(char(name));
        if ~isfield(cfg, key)
            error('PATBox:UnknownParameter', 'Unknown benchmark parameter: %s', name);
        end
        params = cfg.(key);
        return;
    end

    params = cfg;
end

function algorithms = resolveBenchmarkAlgorithms(cfg)
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
