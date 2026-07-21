function stem = buildMultiReconOutputStem(algo_name, sim_cfg, cfg)
%BUILDMULTIRECONOUTPUTSTEM Build a filename stem for multi-reconstruction outputs.
%
%   stem = buildMultiReconOutputStem('DAS', sim_cfg, multi_cfg)
%   -> das_recon_linear_512
%
%   With OutputSuffix: envelope -> das_recon_linear_512_envelope

    parts = {
        lower(strrep(char(algo_name), '-', '_')), ...
        'recon', ...
        sanitizeFileNameTag(sim_cfg.SensorType), ...
        num2str(sim_cfg.GridSize)
    };

    suffix = sanitizeFileNameTag(getStringCfgField(cfg, 'OutputSuffix'));
    if suffix ~= ""
        parts{end + 1} = suffix; %#ok<AGROW>
    end

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
