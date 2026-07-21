function saved_path = saveBenchmarkCsv(results_table, csv_path)
%SAVEBENCHMARKCSV Write benchmark results table to a CSV file.

    if ~(ischar(csv_path) || isstring(csv_path))
        error('PATBox:InvalidPath', 'CsvPath must be a string.');
    end

    csv_path = char(strtrim(csv_path));
    if csv_path == ""
        saved_path = '';
        return;
    end

    output_dir = fileparts(csv_path);
    if output_dir ~= "" && ~isfolder(output_dir)
        mkdir(output_dir);
    end

    writetable(results_table, csv_path);
    fprintf('Results table saved to: %s\n', csv_path);
    saved_path = csv_path;
end
