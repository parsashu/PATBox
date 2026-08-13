function [sensorData,sensor,kgrid,source,p0Reference,soundSpeed] = ...
        forward_simulation_legacy_adapter(imgPath,noiseLevel,simOptions,sensorType)
%FORWARD_SIMULATION_LEGACY_ADAPTER Route old APIs through the physical core.
%
% noiseLevel historically scaled noise by max(signal), which was not an SNR.
% It is mapped approximately to a nominal amplitude SNR only to keep old
% scripts runnable. New work should call patSimulate with TargetSNRdB.

    if nargin<2 || isempty(noiseLevel), noiseLevel=0; end
    if nargin<3 || isempty(simOptions), simOptions=struct(); end
    if ~(isnumeric(noiseLevel)&&isscalar(noiseLevel)&&isfinite(noiseLevel)&&noiseLevel>=0)
        error('PATBox:InvalidLegacyNoiseLevel','noiseLevel must be nonnegative.');
    end
    warning('PATBox:DeprecatedForwardSimulation', ...
        ['forward_simulation_%s is deprecated. Use patSimulate and the returned ' ...
         'simulation struct so medium and physical geometry metadata are preserved.'],sensorType);

    cfg=simParameters();
    cfg.SensorType=sensorType;
    fields=fieldnames(simOptions);
    for i=1:numel(fields)
        if isfield(cfg,fields{i}), cfg.(fields{i})=simOptions.(fields{i}); end
    end
    if noiseLevel==0
        cfg.NoiseModel='none';
    else
        cfg.NoiseModel='awgn';
        cfg.TargetSNRdB=-20*log10(max(double(noiseLevel),eps));
    end
    sim=forward_simulation_physical(resolvePatboxPath(imgPath),cfg);
    sensorData=sim.sensor_data;
    sensor=sim.sensor;
    kgrid=sim.kgrid;
    source=sim.source;
    p0Reference=sim.p0_reference;
    soundSpeed=sim.sound_speed;
end
