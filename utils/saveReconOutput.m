function saved_paths = saveReconOutput(p0_recon, info, varargin)
%SAVERECONOUTPUT Save reconstruction output to .mat and/or .png files.
%
%   saved_paths = saveReconOutput(p0_recon, info)
%   saved_paths = saveReconOutput(..., 'ground_truth', p0_gt, 'kgrid', kgrid)
%
%   Uses SaveMat, SavePng, and OutputDir from params.yaml (reconstruction section).
%   Optional SaveOutput, SaveMat, SavePng, and OutputDir arguments override yaml.

    saved_paths = struct('mat', '', 'png', '');

    p = inputParser;
    addParameter(p, 'ground_truth', [], @(x) isempty(x) || isnumeric(x) || isa(x, 'gpuArray'));
    addParameter(p, 'kgrid', [], @(x) isempty(x) || isstruct(x) || isobject(x));
    addParameter(p, 'sensor_type', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'SaveOutput', [], @(x) isempty(x) || isLogicalLike(x));
    addParameter(p, 'SaveMat', [], @(x) isempty(x) || isLogicalLike(x));
    addParameter(p, 'SavePng', [], @(x) isempty(x) || isLogicalLike(x));
    addParameter(p, 'OutputDir', '', @(x) ischar(x) || isstring(x));
    parse(p, varargin{:});

    cfg = flattenReconConfig(loadPatboxYaml('reconstruction'));
    cfg = applySaveOverrides(cfg, p.Results);
    [save_mat, save_png] = resolveSaveFormats(cfg);
    if ~save_mat && ~save_png
        return;
    end

    output_dir = resolvePatboxOutputDir(cfg.OutputDir);
    if output_dir == ""
        return;
    end

    file_stem = buildReconOutputStem(info.algorithm, cfg, char(p.Results.sensor_type));

    if save_mat
        saved_paths.mat = saveReconMat(p0_recon, info, p.Results, output_dir, file_stem);
    end
    if save_png
        saved_paths.png = saveReconPng(p0_recon, info, p.Results.kgrid, output_dir, file_stem);
    end
end

function cfg = applySaveOverrides(cfg, overrides)
    if ~isempty(overrides.SaveOutput)
        cfg.SaveOutput = coerceLogical(overrides.SaveOutput);
    end
    if ~isempty(overrides.SaveMat)
        cfg.SaveMat = coerceLogical(overrides.SaveMat);
    end
    if ~isempty(overrides.SavePng)
        cfg.SavePng = coerceLogical(overrides.SavePng);
    end
    if overrides.OutputDir ~= ""
        cfg.OutputDir = char(overrides.OutputDir);
    end
end

function tf = isLogicalLike(value)
    tf = islogical(value) || (isnumeric(value) && isscalar(value) && (value == 0 || value == 1));
end

function [save_mat, save_png] = resolveSaveFormats(cfg)
    save_mat = getLogicalField(cfg, 'SaveMat', false);
    save_png = getLogicalField(cfg, 'SavePng', false);

    if isfield(cfg, 'SaveOutput') && coerceLogical(cfg.SaveOutput)
        if ~isfield(cfg, 'SaveMat')
            save_mat = true;
        end
        return;
    end

    if isfield(cfg, 'SaveOutput') && ~coerceLogical(cfg.SaveOutput) && ~save_mat && ~save_png
        save_mat = false;
        save_png = false;
    end
end

function value = getLogicalField(cfg, name, default_value)
    if isfield(cfg, name)
        value = coerceLogical(cfg.(name));
    else
        value = default_value;
    end
end

function saved_path = saveReconMat(p0_recon, info, parse_results, output_dir, file_stem)
    saved_path = fullfile(output_dir, [file_stem '.mat']);

    out = struct('p0_recon', toHost(p0_recon), 'info', info);
    if ~isempty(parse_results.ground_truth)
        out.ground_truth = toHost(parse_results.ground_truth);
    end
    if ~isempty(parse_results.kgrid)
        out.kgrid = parse_results.kgrid;
    end

    save(saved_path, '-struct', 'out');
    fprintf('Saved reconstruction to: %s\n', saved_path);
end

function saved_path = saveReconPng(p0_recon, info, kgrid, output_dir, file_stem)
    saved_path = fullfile(output_dir, [file_stem '.png']);
    image_data = mat2gray(toHost(p0_recon));
    rgb = ind2rgb(im2uint8(image_data), hot(256));
    imwrite(rgb, saved_path);
    fprintf('Saved reconstruction image to: %s\n', saved_path);
end

function output_dir = resolvePatboxOutputDir(dir_path)
    if ~(ischar(dir_path) || isstring(dir_path))
        error('PATBox:InvalidPath', 'OutputDir must be a string.');
    end

    output_dir = resolvePatboxOutputPath(dir_path);
    if output_dir == ""
        return;
    end

    if ~isfolder(output_dir)
        mkdir(output_dir);
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

function data = toHost(data)
    if isa(data, 'gpuArray')
        data = gather(data);
    end
end
