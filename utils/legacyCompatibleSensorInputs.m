function [sensorData, sensorMask] = legacyCompatibleSensorInputs(sensorData, sensorGeometry, kgrid)
%LEGACYCOMPATIBLESENSORINPUTS Adapt physical-element RF to mask-based recon.
%
% Current PATBox reconstruction engines locate receivers with find(mask) and
% assume channel order matches that find order. Physics-aware simulations
% return ordered physical-element traces. This helper snaps element centres
% onto the grid and reorders channels so the legacy engines remain usable.

    if isnumeric(sensorGeometry) || islogical(sensorGeometry)
        sensorMask = sensorGeometry;
        return;
    end

    if ~(isstruct(sensorGeometry) && ...
            (isfield(sensorGeometry, 'positions') || isfield(sensorGeometry, 'element_positions')))
        if isstruct(sensorGeometry) && isfield(sensorGeometry, 'mask')
            sensorMask = sensorGeometry.mask;
        else
            sensorMask = sensorGeometry;
        end
        return;
    end

    if isfield(sensorGeometry, 'positions') && ~isempty(sensorGeometry.positions)
        positions = double(sensorGeometry.positions);
    else
        positions = double(sensorGeometry.element_positions);
    end
    if size(positions, 2) ~= 2
        if size(positions, 1) == 2
            positions = positions.';
        else
            error('PATBox:InvalidSensorPositions', ...
                'Sensor positions must be [M x 2].');
        end
    end

    if isstruct(sensorData)
        if ~isfield(sensorData, 'p')
            error('PATBox:MissingPressureData', 'sensor_data must contain field p.');
        end
        signals = sensorData.p;
    else
        signals = sensorData;
    end
    if isa(signals, 'gpuArray')
        signals = gather(signals);
    end

    nElem = size(positions, 1);
    if size(signals, 1) == nElem
        % already channels x time
    elseif size(signals, 2) == nElem
        signals = signals.';
    else
        error('PATBox:SensorDataSizeMismatch', ...
            'Sensor data size [%d x %d] does not match %d physical elements.', ...
            size(signals, 1), size(signals, 2), nElem);
    end

    x = double(kgrid.x_vec(:));
    y = double(kgrid.y_vec(:));
    ix = zeros(nElem, 1);
    iy = zeros(nElem, 1);
    for e = 1:nElem
        [~, ix(e)] = min(abs(x - positions(e, 1)));
        [~, iy(e)] = min(abs(y - positions(e, 2)));
    end

    keys = ix + (iy - 1) * double(kgrid.Nx);
    if numel(unique(keys)) < nElem
        error('PATBox:LegacyMaskCollision', ...
            ['Physical elements map to overlapping grid cells after snapping. ' ...
             'Use a finer grid, SensorModel=cartesian_point, or a physics-aware recon path.']);
    end

    mask = false(kgrid.Nx, kgrid.Ny);
    for e = 1:nElem
        mask(ix(e), iy(e)) = true;
    end

    [fx, fy] = find(mask);
    reorder = zeros(numel(fx), 1);
    for i = 1:numel(fx)
        reorder(i) = find(ix == fx(i) & iy == fy(i), 1, 'first');
    end
    signals = single(signals(reorder, :));

    if isstruct(sensorData)
        sensorData.p = signals;
    else
        sensorData = signals;
    end
    sensorMask = double(mask);
end
