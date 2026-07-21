function value = getSimOption(opts, name, default_value)
%GETSIMOPTION Read one simulation option with a fallback default.

    if nargin < 1 || isempty(opts) || ~isfield(opts, name)
        value = default_value;
    else
        value = opts.(name);
    end
end
