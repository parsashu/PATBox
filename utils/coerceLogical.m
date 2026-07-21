function value = coerceLogical(value)
%COERCELOGICAL Convert yaml or numeric values to MATLAB logical.

    if islogical(value) && isscalar(value)
        return;
    end

    if isnumeric(value)
        value = logical(value ~= 0);
        return;
    end

    if isstring(value) || ischar(value)
        value = any(strcmpi(strtrim(string(value)), ["true", "1", "yes", "on"]));
        return;
    end

    try
        value = logical(value);
    catch
        value = false;
    end
end
