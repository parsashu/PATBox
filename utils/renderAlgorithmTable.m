function fig = renderAlgorithmTable(results_table, output_path)
%RENDERALGORITHMTABLE Draw and optionally save a benchmark-style results table.
%
%   renderAlgorithmTable(results_table)
%   renderAlgorithmTable(results_table, output_path)

    if ~ismember('Algorithm', results_table.Properties.VariableNames)
        error('PATBox:InvalidTable', 'results_table must contain an Algorithm column.');
    end

    metric_cols = setdiff(results_table.Properties.VariableNames, {'Algorithm'}, 'stable');
    if isempty(metric_cols)
        error('PATBox:InvalidTable', 'results_table must contain at least one metric column.');
    end

    table_cols = [{'Algorithm'}, metric_cols];
    algorithms = cellstr(results_table.Algorithm);
    num_rows = height(results_table);
    fig_height = max(400, 80 + num_rows * 28);
    num_cols = numel(table_cols);

    fig = figure('Position', [100, 100, max(900, 120 * num_cols), fig_height], 'Color', 'w');
    ax = axes('Parent', fig, 'Position', [0 0 1 1]);
    axis(ax, 'off');
    hold(ax, 'on');

    pad = 0.1;
    xlim(ax, [0 - pad, 1 + pad]);
    ylim(ax, [0 - pad, 1 + pad]);
    plot(ax, [0 - pad, 1 + pad], [0 - pad, 1 + pad], 'w.', 'MarkerSize', 1);

    y_start = 0.85;
    y_step = 0.7 / (num_rows + 1);
    x_cols = linspace(0.05, 0.95, num_cols);

    for c = 1:num_cols
        text(x_cols(c), y_start, metricColumnLabel(table_cols{c}), ...
            'FontWeight', 'bold', 'FontSize', 12, ...
            'HorizontalAlignment', 'center', 'Interpreter', 'none');
    end

    line([0.02, 0.98], [y_start - y_step / 2, y_start - y_step / 2], ...
        'Color', 'k', 'LineWidth', 1.5);

    for r = 1:num_rows
        y = y_start - r * y_step;
        row = results_table(r, :);

        for c = 1:num_cols
            col_name = table_cols{c};
            if c == 1
                text(x_cols(c), y, algorithms{r}, 'FontSize', 11, ...
                    'HorizontalAlignment', 'center', 'Interpreter', 'none');
            else
                text(x_cols(c), y, formatMetricValue(col_name, row.(col_name)), ...
                    'FontSize', 11, 'HorizontalAlignment', 'center');
            end
        end
    end

    line([0.02, 0.98], [y - y_step / 2, y - y_step / 2], 'Color', 'k', 'LineWidth', 1.5);

    if nargin >= 2 && ~isempty(output_path)
        exportgraphics(fig, output_path, 'Resolution', 300, 'BackgroundColor', 'w');
        fprintf('Results table saved to: %s\n', output_path);
    end
end

function label = metricColumnLabel(col_name)
    switch upper(col_name)
        case 'COMPTIME'
            label = 'Time (s)';
        case 'PSNR'
            label = 'PSNR (dB)';
        case 'SNR'
            label = 'SNR (dB)';
        case 'SBR'
            label = 'SBR (dB)';
        otherwise
            label = col_name;
    end
end

function text_value = formatMetricValue(col_name, value)
    switch upper(col_name)
        case 'COMPTIME'
            text_value = sprintf('%.2f', value);
        case {'PSNR', 'SNR', 'SBR'}
            text_value = sprintf('%.2f', value);
        case 'SSIM'
            text_value = sprintf('%.4f', value);
        otherwise
            text_value = sprintf('%.4f', value);
    end
end
