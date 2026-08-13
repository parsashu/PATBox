function sim = loadSimulation(sensor_data_path)
%LOADSIMULATION Load a PATBox simulation while preserving physical metadata.
%
% Preferred MAT format contains one variable named sim. Legacy files with
% sensor_data, sensor, kgrid, source, and sound_speed are also accepted.

    if ~(ischar(sensor_data_path)||isstring(sensor_data_path))
        error('PATBox:InvalidPath','SensorDataPath must be text.');
    end
    sensor_data_path=char(sensor_data_path);
    if ~isfile(sensor_data_path)
        error('PATBox:FileNotFound','Sensor data file not found: %s',sensor_data_path);
    end
    data=load(sensor_data_path);

    if isfield(data,'sim')&&isstruct(data.sim)
        sim=data.sim;
    else
        required={'sensor_data','sensor','kgrid','source'};
        for i=1:numel(required)
            if ~isfield(data,required{i})
                error('PATBox:InvalidSensorData', ...
                    'Missing field "%s" in %s.',required{i},sensor_data_path);
            end
        end
        if isfield(data,'medium')
            medium=data.medium;
        elseif isfield(data,'sound_speed')
            medium=struct('sound_speed',data.sound_speed,'density',1000);
        else
            error('PATBox:InvalidSensorData', ...
                'Saved data must contain medium or sound_speed.');
        end
        if isfield(data,'sensor_geometry')
            sensorGeometry=data.sensor_geometry;
        else
            sensorGeometry=legacyGeometry(data.sensor,data.kgrid,data.sensor_data);
        end
        if isfield(data,'sensor_data_clean'), clean=data.sensor_data_clean; else, clean=data.sensor_data; end
        if isfield(data,'sensor_data_system'), systemData=data.sensor_data_system; else, systemData=clean; end
        if isfield(data,'p0_reference'), p0=data.p0_reference; else, p0=data.source.p0; end
        sim=struct('sensor_data',data.sensor_data,'sensor_data_clean',clean, ...
            'sensor_data_system',systemData,'sensor',data.sensor, ...
            'sensor_geometry',sensorGeometry,'kgrid',data.kgrid,'source',data.source, ...
            'medium',medium,'sound_speed',medium.sound_speed, ...
            'p0_reference',p0,'noisy_p0',p0);
    end

    required={'sensor_data','sensor','kgrid','source'};
    if ~all(isfield(sim,required))
        error('PATBox:InvalidSimulationStruct', ...
            'Loaded sim struct is missing required PATBox fields.');
    end
    if ~isfield(sim,'medium')
        sim.medium=struct('sound_speed',sim.sound_speed,'density',1000);
    end
    if ~isfield(sim,'sound_speed'), sim.sound_speed=sim.medium.sound_speed; end
    if ~isfield(sim,'sensor_geometry')
        sim.sensor_geometry=legacyGeometry(sim.sensor,sim.kgrid,sim.sensor_data);
    end
    if ~isfield(sim,'p0_reference'), sim.p0_reference=sim.source.p0; end
    if ~isfield(sim,'noisy_p0'), sim.noisy_p0=sim.p0_reference; end
    if ~isfield(sim,'info')||~isstruct(sim.info), sim.info=struct(); end
    sim.info.loaded_from_file=true;
    sim.info.source_file=sensor_data_path;
    sim.info.num_sensors=sim.sensor_geometry.num_elements;
end

function geom=legacyGeometry(sensor,kgrid,sensorData)
    if isstruct(sensor)&&isfield(sensor,'element_positions')
        signals=sensorData; if isstruct(signals), signals=signals.p; end
        if size(signals,2)==kgrid.Nt
            expected=size(signals,1);
        elseif size(signals,1)==kgrid.Nt
            expected=size(signals,2);
        else
            error('PATBox:LegacyTimeDimensionMismatch', ...
                'Legacy sensor data do not contain kgrid.Nt=%d samples.',kgrid.Nt);
        end
        geom=resolveSensorElementGeometry(sensor,kgrid,expected);
        geom.model='legacy_explicit';
        return;
    end
    signals=sensorData; if isstruct(signals), signals=signals.p; end
    if size(signals,1)==kgrid.Nt, expected=size(signals,2); else, expected=size(signals,1); end
    resolved=resolveSensorElementGeometry(sensor,kgrid,expected);
    geom=resolved;
    geom.model='legacy_binary_mask';
end
