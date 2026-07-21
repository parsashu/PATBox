function sim = loadSimulation(sensor_data_path)
%LOADSIMULATION Load a saved k-Wave simulation for reconstruction.
%
%   sim = loadSimulation('/path/to/sensor_data.mat')
%
%   The .mat file must contain: sensor_data, sensor, kgrid, source, sound_speed

    if ~(ischar(sensor_data_path) || isstring(sensor_data_path))
        error('PATBox:InvalidPath', 'SensorDataPath must be a string.');
    end

    sensor_data_path = char(sensor_data_path);
    if ~isfile(sensor_data_path)
        error('PATBox:FileNotFound', 'Sensor data file not found: %s', sensor_data_path);
    end

    data = load(sensor_data_path);
    required_fields = {'sensor_data', 'sensor', 'kgrid', 'source', 'sound_speed'};
    for i = 1:numel(required_fields)
        if ~isfield(data, required_fields{i})
            error('PATBox:InvalidSensorData', ...
                'Missing field ''%s'' in %s', required_fields{i}, sensor_data_path);
        end
    end

    if isfield(data, 'noisy_p0')
        noisy_p0 = data.noisy_p0;
    else
        noisy_p0 = data.source.p0;
    end

    sim = struct( ...
        'sensor_data', data.sensor_data, ...
        'sensor', data.sensor, ...
        'kgrid', data.kgrid, ...
        'source', data.source, ...
        'noisy_p0', noisy_p0, ...
        'sound_speed', data.sound_speed, ...
        'info', struct( ...
            'sensor_type', getFieldOrDefault(data, 'sensor_type', 'unknown'), ...
            'noise_level', getFieldOrDefault(data, 'noise_level', NaN), ...
            'img_path', sensor_data_path, ...
            'num_sensors', countSensors(data.sensor), ...
            'loaded_from_file', true));
end

function value = getFieldOrDefault(data, field_name, default_value)
    if isfield(data, field_name)
        value = data.(field_name);
    else
        value = default_value;
    end
end

function n = countSensors(sensor)
    if isfield(sensor, 'mask')
        if ndims(sensor.mask) == 2
            n = sum(sensor.mask(:) > 0);
        else
            n = size(sensor.mask, 2);
        end
    else
        n = NaN;
    end
end
