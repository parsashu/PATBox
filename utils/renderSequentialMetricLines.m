function fig = renderSequentialMetricLines(results_table, output_path)
%RENDERSEQUENTIALMETRICLINES Paper-style sequential physics line plots.
%
% One panel per metric (real units, not normalized).
% X-axis: sequential physics stages.
% Colored lines: one per algorithm.
%
% Optional second page (same PNG stem + "_delta.png"): change relative to
% the ideal stage, which highlights the impact of each added impairment.

    required = {'StageId', 'Algorithm'};
    for i = 1:numel(required)
        if ~ismember(required{i}, results_table.Properties.VariableNames)
            error('PATBox:InvalidTable', 'results_table must contain %s.', required{i});
        end
    end

    stage_ids = unique(results_table.StageId, 'stable');
    algorithms = unique(results_table.Algorithm, 'stable');
    metric_names = setdiff(results_table.Properties.VariableNames, ...
        {'Stage', 'StageId', 'Algorithm'}, 'stable');
    if isempty(metric_names)
        error('PATBox:InvalidTable', 'No metric columns found.');
    end

    stage_labels = shortenStageLabels(stage_ids);
    nS = numel(stage_ids);
    nA = numel(algorithms);
    nM = numel(metric_names);
    x = 1:nS;
    colors = lines(nA);
    markers = {'o', 's', 'd', '^', 'v', '>', '<', 'p', 'h', '*', 'x', '+', '.'};

    % Absolute metric values vs stage.
    fig = buildMetricFigure(results_table, stage_ids, stage_labels, algorithms, ...
        metric_names, x, colors, markers, false, ...
        'Sequential physics benchmark — absolute metrics');

    if nargin >= 2 && ~isempty(output_path)
        saveFigure(fig, output_path);
    end

    % Relative to ideal: (value - ideal) for most metrics; CompTime stays absolute
    % delta as well so runtime growth is visible.
    fig_delta = buildMetricFigure(results_table, stage_ids, stage_labels, algorithms, ...
        metric_names, x, colors, markers, true, ...
        'Sequential physics benchmark — change from ideal');

    if nargin >= 2 && ~isempty(output_path)
        [folder, stem, ext] = fileparts(output_path);
        if ext == ""
            ext = '.png';
        end
        delta_path = fullfile(folder, [stem, '_delta', ext]);
        saveFigure(fig_delta, delta_path);
    end
end

function fig = buildMetricFigure(results_table, stage_ids, stage_labels, ...
        algorithms, metric_names, x, colors, markers, relative_to_ideal, fig_title)

    nS = numel(stage_ids);
    nA = numel(algorithms);
    nM = numel(metric_names);
    nCols = min(3, nM);
    nRows = ceil(nM / nCols);
    fig_w = max(1100, 360 * nCols + 180);
    fig_h = max(480, 250 * nRows);
    fig = figure('Color', 'w', 'Position', [50, 50, fig_w, fig_h], 'Visible', 'off');

    use_tiled = exist('tiledlayout', 'file') == 2;
    if use_tiled
        tl = tiledlayout(fig, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
    end

    line_handles = gobjects(nA, 1);
    for m = 1:nM
        if use_tiled
            ax = nexttile(tl);
        else
            ax = subplot(nRows, nCols, m);
        end
        hold(ax, 'on');

        ideal_vals = nan(nA, 1);
        for a = 1:nA
            mask_ideal = results_table.Algorithm == algorithms(a) & ...
                results_table.StageId == stage_ids(1);
            if any(mask_ideal)
                ideal_vals(a) = double(results_table.(metric_names{m})(find(mask_ideal, 1, 'first')));
            end
        end

        for a = 1:nA
            y = nan(1, nS);
            for s = 1:nS
                mask = results_table.Algorithm == algorithms(a) & ...
                    results_table.StageId == stage_ids(s);
                if ~any(mask)
                    continue;
                end
                raw = double(results_table.(metric_names{m})(find(mask, 1, 'first')));
                if relative_to_ideal && isfinite(ideal_vals(a))
                    y(s) = raw - ideal_vals(a);
                else
                    y(s) = raw;
                end
            end
            mk = markers{1 + mod(a - 1, numel(markers))};
            h = plot(ax, x, y, ['-' mk], ...
                'Color', colors(a, :), ...
                'LineWidth', 1.5, ...
                'MarkerSize', 5, ...
                'MarkerFaceColor', colors(a, :), ...
                'DisplayName', char(algorithms(a)));
            if m == 1
                line_handles(a) = h;
            end
        end

        hold(ax, 'off');
        grid(ax, 'on');
        box(ax, 'on');
        xlim(ax, [0.5, nS + 0.5]);
        if relative_to_ideal
            yline(ax, 0, ':', 'Color', [0.4, 0.4, 0.4], 'LineWidth', 1, 'HandleVisibility', 'off');
        end
        set(ax, 'XTick', x, 'XTickLabel', stage_labels, ...
            'TickLabelInterpreter', 'none', 'FontSize', 9);
        xtickangle(ax, 25);
        title(ax, metric_names{m}, 'Interpreter', 'none', 'FontWeight', 'bold');
        if m > nM - nCols
            xlabel(ax, 'Sequential physics');
        end
        if relative_to_ideal
            ylabel(ax, '\Delta from ideal');
        else
            ylabel(ax, metricAxisLabel(metric_names{m}));
        end
    end

    if use_tiled
        lgd = legend(line_handles, cellstr(algorithms), 'Interpreter', 'none');
        lgd.Layout.Tile = 'east';
        title(tl, fig_title);
    else
        legend(subplot(nRows, nCols, 1), cellstr(algorithms), ...
            'Interpreter', 'none', 'Location', 'best');
        sgtitle(fig, fig_title, 'FontSize', 12, 'FontWeight', 'bold');
    end
end

function labels = shortenStageLabels(stage_ids)
    labels = cell(size(stage_ids));
    for i = 1:numel(stage_ids)
        id = char(stage_ids(i));
        switch id
            case 'ideal'
                labels{i} = 'ideal';
            case 'bw'
                labels{i} = '+BW';
            case 'bw_aperture'
                labels{i} = '+aperture';
            case 'bw_aperture_hetero'
                labels{i} = '+hetero';
            case 'bw_aperture_hetero_att'
                labels{i} = '+atten';
            case 'bw_aperture_hetero_att_pl'
                labels{i} = '+power-law';
            case 'bw_aperture_hetero_att_pl_noise'
                labels{i} = '+noise';
            otherwise
                labels{i} = id;
        end
    end
end

function label = metricAxisLabel(name)
    switch upper(char(name))
        case 'COMPTIME'
            label = 'Time (s)';
        case 'PSNR'
            label = 'PSNR (dB)';
        case 'SNR'
            label = 'SNR (dB)';
        case 'SBR'
            label = 'SBR (dB)';
        otherwise
            label = char(name);
    end
end

function saveFigure(fig, output_path)
    out_dir = fileparts(output_path);
    if out_dir ~= "" && ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, output_path, 'Resolution', 200, 'BackgroundColor', 'w');
    else
        saveas(fig, output_path);
    end
    fprintf('Saved plot: %s\n', output_path);
end
