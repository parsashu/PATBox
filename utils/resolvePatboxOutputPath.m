function resolved_path = resolvePatboxOutputPath(path_value)
%RESOLVEPATBOXOUTPUTPATH Resolve an output path relative to the PATBox root.

    if ~(ischar(path_value) || isstring(path_value))
        error('PATBox:InvalidPath', 'Path must be a string.');
    end

    resolved_path = char(strtrim(path_value));
    if resolved_path == ""
        return;
    end

    if isfile(resolved_path) || isfolder(resolved_path)
        return;
    end

    patbox_root = fileparts(which('patSimulate'));
    resolved_path = fullfile(patbox_root, resolved_path);
end
