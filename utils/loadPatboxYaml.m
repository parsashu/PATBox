function cfg = loadPatboxYaml(section)
%LOADPATBOXYAML Load PATBox configuration from params.yaml.
%
%   cfg = loadPatboxYaml()              % full config struct
%   cfg = loadPatboxYaml('simulation')  % one section

    cfg_file = fullfile(patboxRoot(), 'params.yaml');
    defaults = defaultPatboxConfig();

    if ~isfile(cfg_file)
        cfg = defaults;
    else
        cfg = parseSectionedYaml(cfg_file);
        cfg = mergePatboxConfig(defaults, cfg);
    end

    if nargin >= 1
        section = matlab.lang.makeValidName(char(section));
        if ~isfield(cfg, section)
            error('PATBox:UnknownSection', 'Unknown params.yaml section: %s', section);
        end
        cfg = cfg.(section);
    end
end

function root = patboxRoot()
    root = fileparts(fileparts(mfilename('fullpath')));
end

function cfg = defaultPatboxConfig()
    cfg.reconstruction = struct( ...
        'AlgorithmName', 'DMAS', ...
        'envelope_signal', false, ...
        'remove_negatives', true, ...
        'bandpass_filter', false, ...
        'frequency_low', 0.1e6, ...
        'frequency_high', 10.0e6, ...
        'SaveOutput', true, ...
        'SaveMat', true, ...
        'SavePng', true, ...
        'OutputDir', 'output/recon', ...
        'OutputSuffix', '', ...
        'iterative', struct( ...
            'interp_method', 'linear', ...
            'InitialGuess', 'DMAS', ...
            'NumIterations', 5, ...
            'StepSize', 0.25, ...
            'UpdateMethod', 'TR'));
    cfg.simulation = struct( ...
        'UseSimulation', true, ...
        'SensorDataPath', '', ...
        'ImagePath', 'data/example.bmp', ...
        'SensorType', 'linear', ...
        'NoiseLevel', 0.1, ...
        'GridSize', 512, ...
        'MinFrequency', 0, ...
        'MaxFrequency', 5.0e6, ...
        'SoundSpeed', 1500, ...
        'Density', 1000, ...
        'NumTransducers', 128, ...
        'Pitch', 3.0e-4, ...
        'Kerf', 3.0e-5);
    cfg.benchmark_algorithms = struct( ...
        'IncludeIterative', true, ...
        'envelope_signal', false, ...
        'remove_negatives', true, ...
        'bandpass_filter', false, ...
        'frequency_low', 0.1e6, ...
        'frequency_high', 10.0e6, ...
        'Algorithms', {{}}, ...
        'Metrics', {{'CompTime', 'RMSE', 'PSNR', 'SSIM', 'SNR', 'Sharpness', 'UIQI', 'CNR', 'SBR'}}, ...
        'OutputPath', 'output/algorithm_benchmark_table.png', ...
        'SaveCsv', true, ...
        'CsvPath', 'output/algorithm_benchmark_table.csv');
    cfg.multi_reconstruction = struct( ...
        'IncludeIterative', false, ...
        'envelope_signal', false, ...
        'remove_negatives', true, ...
        'bandpass_filter', false, ...
        'frequency_low', 0.1e6, ...
        'frequency_high', 10.0e6, ...
        'Algorithms', {{ ...
            'DS-DMAS' ...
            'MV-DAS' ...
            'VDAS' ...
            'SCF-DAS' ...
            'CFMV-DAS' ...
            'FBP' ...
            'UBP' ...
            'DMAS-UBP' ...
            'VDAS-UBP' ...
            'TR'}}, ...
        'OutputDir', 'output/recon', ...
        'OutputSuffix', '', ...
        'SaveFigure', true, ...
        'SaveMat', true, ...
        'SavePng', false);
end

function cfg = mergePatboxConfig(defaults, overrides)
    cfg = defaults;
    sections = intersect(fieldnames(defaults), fieldnames(overrides));
    for i = 1:numel(sections)
        cfg.(sections{i}) = mergeStructFields(defaults.(sections{i}), overrides.(sections{i}));
    end
end

function out = mergeStructFields(defaults, overrides)
    out = defaults;
    keys = fieldnames(overrides);
    for i = 1:numel(keys)
        key = keys{i};
        if ~isfield(defaults, key)
            out.(key) = overrides.(key);
            continue;
        end
        if isstruct(defaults.(key)) && isstruct(overrides.(key))
            out.(key) = mergeStructFields(defaults.(key), overrides.(key));
        else
            out.(key) = overrides.(key);
        end
    end
end

function cfg = parseSectionedYaml(cfg_file)
    cfg = defaultPatboxConfig();
    current_section = '';
    current_subsection = '';
    list_key = '';
    lines = split(string(fileread(cfg_file)), newline);

    for i = 1:numel(lines)
        raw_line = lines(i);
        line = strtrim(raw_line);
        if line == "" || startsWith(line, "#")
            continue;
        end

        if startsWith(line, "- ")
            item = char(strtrim(extractAfter(line, 2)));
            if strcmp(current_section, 'benchmark_algorithms') && ~isempty(list_key)
                cfg.benchmark_algorithms.(list_key){end + 1} = parseYamlValue(item); %#ok<AGROW>
            elseif strcmp(current_section, 'multi_reconstruction') && ~isempty(list_key)
                cfg.multi_reconstruction.(list_key){end + 1} = parseYamlValue(item); %#ok<AGROW>
            end
            continue;
        end

        if endsWith(line, ":") && ~contains(strtrim(extractBefore(line, ":")), " ")
            section_name = char(strtrim(extractBefore(line, ":")));
            if startsWith(raw_line, "  ") && strcmp(current_section, 'reconstruction') && ...
                    strcmp(section_name, 'iterative')
                current_subsection = 'iterative';
                list_key = '';
                continue;
            end
            if isTopLevelYamlLine(raw_line)
                current_section = section_name;
                current_subsection = '';
                list_key = '';
                continue;
            end
        end

        parts = split(line, ":", 2);
        if numel(parts) < 2
            continue;
        end

        key = matlab.lang.makeValidName(strtrim(parts(1)));
        raw_value = strtrim(parts(2));
        if raw_value == ""
            if strcmp(current_section, 'benchmark_algorithms')
                list_key = key;
                cfg.benchmark_algorithms.(list_key) = {};
            elseif strcmp(current_section, 'multi_reconstruction')
                list_key = key;
                cfg.multi_reconstruction.(list_key) = {};
            end
            continue;
        end
        value = parseYamlValue(raw_value);

        if strcmp(current_section, 'reconstruction') && strcmp(current_subsection, 'iterative')
            cfg.reconstruction.iterative.(key) = value;
        elseif strcmp(current_section, 'reconstruction')
            cfg.reconstruction.(key) = value;
        elseif strcmp(current_section, 'simulation')
            cfg.simulation.(key) = value;
        elseif strcmp(current_section, 'benchmark_algorithms')
            cfg.benchmark_algorithms.(key) = value;
            list_key = '';
        elseif strcmp(current_section, 'multi_reconstruction')
            cfg.multi_reconstruction.(key) = value;
            list_key = '';
        end
    end
end

function tf = isTopLevelYamlLine(raw_line)
    tf = ~startsWith(raw_line, " ") && ~startsWith(raw_line, sprintf('\t'));
end

function value = parseYamlValue(raw_value)
    raw_value = char(raw_value);

    if strcmpi(raw_value, 'true')
        value = true;
    elseif strcmpi(raw_value, 'false')
        value = false;
    elseif (startsWith(raw_value, '"') && endsWith(raw_value, '"')) || ...
            (startsWith(raw_value, '''') && endsWith(raw_value, ''''))
        value = char(raw_value(2:end - 1));
    elseif strcmp(raw_value, '""') || strcmp(raw_value, "''")
        value = '';
    elseif ~isnan(str2double(raw_value))
        value = str2double(raw_value);
    else
        value = raw_value;
    end
end
