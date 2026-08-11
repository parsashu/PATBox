function params = sequentialBenchmarkParameters(name)
%SEQUENTIALBENCHMARKPARAMETERS Settings for sequential physics benchmark.
%
%   cfg = sequentialBenchmarkParameters()
%   value = sequentialBenchmarkParameters('OutputDir')
%
% Loads params.yaml section sequential_benchmark when present; otherwise
% falls back to benchmark_algorithms for Algorithms / Metrics / recon flags.

    defaults = defaultSequentialBenchmarkConfig();
    try
        cfg = loadPatboxYaml('sequential_benchmark');
        cfg = mergeStructFieldsLocal(defaults, cfg);
    catch
        cfg = defaults;
    end

    bench = benchmarkParameters();
    if isempty(cfg.Algorithms)
        cfg.Algorithms = bench.Algorithms;
    else
        cfg.Algorithms = normalizeStringListLocal(cfg.Algorithms);
        if ~logical(cfg.IncludeIterative)
            cfg.Algorithms = cfg.Algorithms(~contains(upper(string(cfg.Algorithms)), 'ITERATIVE'));
        end
    end
    if isempty(cfg.Metrics)
        cfg.Metrics = bench.Metrics;
    else
        cfg.Metrics = normalizeStringListLocal(cfg.Metrics);
    end

    cfg.IncludeIterative = coerceLogical(cfg.IncludeIterative);
    cfg.envelope_signal = coerceLogical(cfg.envelope_signal);
    cfg.remove_negatives = coerceLogical(cfg.remove_negatives);
    cfg.bandpass_filter = coerceLogical(cfg.bandpass_filter);
    cfg.SaveCsv = coerceLogical(cfg.SaveCsv);
    cfg.SaveTablePng = coerceLogical(cfg.SaveTablePng);

    if nargin >= 1
        key = matlab.lang.makeValidName(char(name));
        if ~isfield(cfg, key)
            error('PATBox:UnknownParameter', 'Unknown sequential benchmark parameter: %s', name);
        end
        params = cfg.(key);
        return;
    end
    params = cfg;
end

function cfg = defaultSequentialBenchmarkConfig()
    cfg = struct( ...
        'IncludeIterative', false, ...
        'envelope_signal', true, ...
        'remove_negatives', true, ...
        'bandpass_filter', false, ...
        'frequency_low', 0.1e6, ...
        'frequency_high', 10.0e6, ...
        'Algorithms', {{}}, ...
        'Metrics', {{}}, ...
        'GridSize', 256, ...
        'FractionalBandwidthPercent', 80, ...
        'CenterFrequency', 5.0e6, ...
        'SensorArcDeg', 180, ...
        'AlphaCoeff', 0.75, ...
        'AlphaPower', 1.5, ...
        'TargetSNRdB', 20, ...
        'SoundSpeedStd', 20, ...
        'DensityStd', 15, ...
        'OutputDir', 'output/benchmark/sequential', ...
        'SaveCsv', true, ...
        'SaveTablePng', true);
end

function out = mergeStructFieldsLocal(defaults, overrides)
    out = defaults;
    keys = fieldnames(overrides);
    for i = 1:numel(keys)
        out.(keys{i}) = overrides.(keys{i});
    end
end

function list = normalizeStringListLocal(value)
    if isempty(value)
        list = {};
        return;
    end
    if isstring(value)
        value = cellstr(value);
    end
    if ischar(value)
        list = {value};
        return;
    end
    if iscell(value)
        list = cellfun(@char, value, 'UniformOutput', false);
        return;
    end
    list = {};
end
