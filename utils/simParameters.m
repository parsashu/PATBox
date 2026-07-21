function params = simParameters(name)
%SIMPARAMETERS Simulation parameters for PATBox.
%
%   cfg = simParameters()
%   value = simParameters('SensorType')
%
%   Defaults are loaded from PATBox/params.yaml (simulation section).

    cfg = loadPatboxYaml('simulation');

    if nargin >= 1
        key = matlab.lang.makeValidName(char(name));
        if ~isfield(cfg, key)
            error('PATBox:UnknownParameter', 'Unknown simulation parameter: %s', name);
        end
        params = cfg.(key);
        return;
    end

    params = cfg;
end
