function resolved_path = resolvePatboxPath(path_value)
%RESOLVEPATBOXPATH Resolve a path relative to the PATBox root.

    if ~(ischar(path_value) || isstring(path_value))
        error('PATBox:InvalidPath', 'Path must be a string.');
    end

    resolved_path = char(path_value);
    if resolved_path == "" || exist(resolved_path, 'file')
        return;
    end

    patbox_root = fileparts(which('patSimulate'));
    candidate = fullfile(patbox_root, resolved_path);
    if exist(candidate, 'file')
        resolved_path = candidate;
    end
end
