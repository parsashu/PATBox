function fig = renderSequentialMetricHeatmap(results_table, output_path)
%RENDERSEQUENTIALMETRICHEATMAP Algorithms x stages heatmaps (normalized).
%
% One panel per metric.
% Rows (Y): algorithms
% Columns (X): sequential physics stages
% Color: that metric min-max normalized to [0, 1] across all algorithms/stages.

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

    nS = numel(stage_ids);
    nA = numel(algorithms);
    nM = numel(metric_names);
    stage_labels = shortenStageLabels(stage_ids);

    % heat(a, s, m): algorithm x stage x metric, normalized per metric.
    heat = nan(nA, nS, nM);
    for m = 1:nM
        vals = double(results_table.(metric_names{m}));
        vmin = min(vals, [], 'omitnan');
        vmax = max(vals, [], 'omitnan');
        if ~(isfinite(vmin) && isfinite(vmax)) || vmax <= vmin
            vmin = 0;
            vmax = 1;
        end

        for a = 1:nA
            for s = 1:nS
                mask = results_table.Algorithm == algorithms(a) & ...
                    results_table.StageId == stage_ids(s);
                if ~any(mask)
                    continue;
                end
                raw = double(results_table.(metric_names{m})(find(mask, 1, 'first')));
                heat(a, s, m) = (raw - vmin) / (vmax - vmin);
            end
        end
    end

    nCols = min(3, nM);
    nRows = ceil(nM / nCols);
    fig_w = max(1100, 340 * nCols + 140);
    fig_h = max(480, 260 * nRows);
    fig = figure('Color', 'w', 'Position', [40, 40, fig_w, fig_h], 'Visible', 'off');

    use_tiled = exist('tiledlayout', 'file') == 2;
    if use_tiled
        tl = tiledlayout(fig, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
    end

    for m = 1:nM
        if use_tiled
            ax = nexttile(tl);
        else
            ax = subplot(nRows, nCols, m);
        end
        imagesc(ax, heat(:, :, m), [0, 1]);
        axis(ax, 'tight');
        set(ax, ...
            'XTick', 1:nS, 'XTickLabel', stage_labels, ...
            'YTick', 1:nA, 'YTickLabel', cellstr(algorithms), ...
            'TickLabelInterpreter', 'none', 'FontSize', 8, ...
            'YDir', 'normal');
        xtickangle(ax, 30);
        title(ax, metric_names{m}, 'Interpreter', 'none', 'FontWeight', 'bold');
        if m > nM - nCols
            xlabel(ax, 'Sequential physics');
        end
        if mod(m - 1, nCols) == 0
            ylabel(ax, 'Algorithm');
        end
    end

    colormap(fig, parula);
    if use_tiled
        cb = colorbar;
        cb.Layout.Tile = 'east';
        cb.Label.String = 'Normalized value [0, 1]';
        title(tl, 'Sequential physics — algorithms \times stages (one panel per metric)');
    else
        cb = colorbar;
        cb.Label.String = 'Normalized value [0, 1]';
        sgtitle(fig, 'Sequential physics — algorithms \times stages (one panel per metric)', ...
            'FontWeight', 'bold');
    end

    if nargin >= 2 && ~isempty(output_path)
        out_dir = fileparts(output_path);
        if out_dir ~= "" && ~exist(out_dir, 'dir')
            mkdir(out_dir);
        end
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, output_path, 'Resolution', 200, 'BackgroundColor', 'w');
        else
            saveas(fig, output_path);
        end
        fprintf('Saved heatmap: %s\n', output_path);
        writeHeatmapCsvs(out_dir, heat, algorithms, stage_ids, metric_names);
    end
end

function writeHeatmapCsvs(out_dir, heat, algorithms, stage_ids, metric_names)
    nA = numel(algorithms);
    nS = numel(stage_ids);
    nM = numel(metric_names);
    stage_vars = matlab.lang.makeValidName(cellstr(stage_ids));

    csv_dir = fullfile(out_dir, 'heatmap_csv');
    if ~exist(csv_dir, 'dir')
        mkdir(csv_dir);
    end

    long_rows = cell(nA * nS * nM, 4);
    row = 0;
    for m = 1:nM
        T = table(algorithms(:), 'VariableNames', {'Algorithm'});
        for s = 1:nS
            T.(stage_vars{s}) = heat(:, s, m);
        end
        metric_csv = fullfile(csv_dir, sprintf('heatmap_%s.csv', ...
            matlab.lang.makeValidName(metric_names{m})));
        writetable(T, metric_csv);

        for a = 1:nA
            for s = 1:nS
                row = row + 1;
                long_rows{row, 1} = char(algorithms(a));
                long_rows{row, 2} = char(stage_ids(s));
                long_rows{row, 3} = metric_names{m};
                long_rows{row, 4} = heat(a, s, m);
            end
        end
    end

    long_table = cell2table(long_rows, ...
        'VariableNames', {'Algorithm', 'StageId', 'Metric', 'NormalizedValue'});
    long_csv = fullfile(out_dir, 'sequential_physics_heatmap_normalized.csv');
    writetable(long_table, long_csv);

    fprintf('Saved heatmap CSVs:\n  %s\n  %s%s*.csv\n', ...
        long_csv, csv_dir, filesep);
end

function labels = shortenStageLabels(stage_ids)
    labels = cell(size(stage_ids));
    for i = 1:numel(stage_ids)
        id = char(stage_ids(i));
        switch id
            case 'ideal', labels{i} = 'ideal';
            case 'bw', labels{i} = '+BW';
            case 'bw_aperture', labels{i} = '+aperture';
            case 'bw_aperture_hetero', labels{i} = '+hetero';
            case 'bw_aperture_hetero_att', labels{i} = '+atten';
            case 'bw_aperture_hetero_att_pl', labels{i} = '+power-law';
            case 'bw_aperture_hetero_att_pl_noise', labels{i} = '+noise';
            otherwise, labels{i} = id;
        end
    end
end
