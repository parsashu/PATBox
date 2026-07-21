function sensor_type = resolveReconSensorType(sim)
%RESOLVERECONSENSORTYPE Resolve sensor type for recon output naming.

    sensor_type = '';
    if nargin >= 1 && isstruct(sim) && isfield(sim, 'info') && isstruct(sim.info) && ...
            isfield(sim.info, 'sensor_type')
        sensor_type = char(sim.info.sensor_type);
    end

    if sensor_type == ""
        sensor_type = char(simParameters('SensorType'));
    end
end
