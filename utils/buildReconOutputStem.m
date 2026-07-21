function stem = buildReconOutputStem(algo_name, cfg, sensor_type)
%BUILDRECONOUTPUTSTEM Build a timestamped filename stem for recon outputs.
%
%   stem = buildReconOutputStem('DMAS', cfg, 'linear')
%   -> dmas_linear_20260614_195618
%
%   With OutputSuffix: envelope -> dmas_linear_envelope_20260614_195618

    algo_tag = lower(strrep(char(algo_name), '-', '_'));
    parts = {algo_tag};

    if ~isempty(sensor_type)
        parts{end + 1} = sanitizeFileNameTag(sensor_type); %#ok<AGROW>
    end

    suffix = sanitizeFileNameTag(getStringCfgField(cfg, 'OutputSuffix'));
    if suffix ~= ""
        parts{end + 1} = suffix; %#ok<AGROW>
    end

    parts{end + 1} = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<AGROW>
    stem = strjoin(parts, '_');
end

function tag = sanitizeFileNameTag(value)
    tag = lower(strtrim(char(string(value))));
    tag = regexprep(tag, '[^a-z0-9]+', '_');
    tag = regexprep(tag, '^_+|_+$', '');
end

function value = getStringCfgField(cfg, name)
    if isfield(cfg, name)
        value = char(string(cfg.(name)));
    else
        value = '';
    end
end
