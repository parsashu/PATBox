function geom = resolveSensorElementGeometry(sensorGeometry, kgrid, expectedChannels)
%RESOLVESENSORELEMENTGEOMETRY Resolve ordered physical receiver geometry.
%
% Geometry structs created by buildSensorGeometry2D preserve user-defined
% element order and acquisition metadata. Binary masks do not; their order
% is MATLAB column-major. This function therefore prefers explicit
% positions and, critically, propagates the detector model and acquisition
% metadata used by reconstruction compatibility guards.
%
% The returned geometry is the canonical reconstruction-side contract. In
% particular, model, directivity, detector bandwidth, and geometry-error
% fields must not be silently discarded: doing so can either reject valid
% ideal Cartesian point data or incorrectly admit non-ideal data to exact
% analytic inversions.

    if isstruct(sensorGeometry)
        if isfield(sensorGeometry, 'positions')
            positions = sensorGeometry.positions;
        elseif isfield(sensorGeometry, 'element_positions')
            positions = sensorGeometry.element_positions;
        else
            positions = [];
        end

        if isfield(sensorGeometry, 'normals')
            normals = sensorGeometry.normals;
        elseif isfield(sensorGeometry, 'element_normals')
            normals = sensorGeometry.element_normals;
        else
            normals = [];
        end

        if isfield(sensorGeometry, 'element_measure')
            measure = sensorGeometry.element_measure;
        elseif isfield(sensorGeometry, 'element_width')
            measure = sensorGeometry.element_width;
        else
            measure = 1;
        end

        if isfield(sensorGeometry, 'type')
            type = canonicalText(sensorGeometry.type, 'unknown');
        else
            type = 'unknown';
        end

        if isfield(sensorGeometry, 'model')
            model = canonicalSensorModel(sensorGeometry.model);
        elseif isfield(sensorGeometry, 'combine_mode')
            model = canonicalSensorModel(sensorGeometry.combine_mode);
        else
            model = 'unknown';
        end

        if isempty(positions) && isfield(sensorGeometry, 'mask')
            mask = sensorGeometry.mask;
        else
            mask = [];
        end
    else
        positions = [];
        normals = [];
        measure = 1;
        type = 'unknown';
        model = 'unknown';
        mask = sensorGeometry;
    end

    if isempty(positions)
        if isempty(mask) || ~isequal(size(mask), [kgrid.Nx, kgrid.Ny])
            error('PATBox:InvalidSensorGeometry', ...
                'Provide explicit element positions or a binary grid mask.');
        end
        [ix, iy] = find(mask > 0);
        positions = [double(kgrid.x_vec(ix(:))), double(kgrid.y_vec(iy(:)))];
    else
        positions = double(positions);
    end

    if size(positions,2) ~= 2
        if size(positions,1) == 2
            positions = positions.';
        else
            error('PATBox:InvalidSensorPositions', ...
                'Sensor positions must be [M x 2] or [2 x M].');
        end
    end

    nElem = size(positions,1);
    if nargin >= 3 && ~isempty(expectedChannels) && nElem ~= expectedChannels
        error('PATBox:SensorGeometryChannelMismatch', ...
            'Geometry contains %d elements but data contain %d channels.', ...
            nElem, expectedChannels);
    end

    if isempty(normals)
        centre = [mean(double(kgrid.x_vec)), mean(double(kgrid.y_vec))];
        normals = centre - positions;
        lengths = sqrt(sum(normals.^2,2));
        zero = lengths <= eps;
        normals(~zero,:) = normals(~zero,:) ./ lengths(~zero);
        normals(zero,:) = repmat([1,0], nnz(zero), 1);
    else
        normals = double(normals);
        if size(normals,2) ~= 2 && size(normals,1) == 2
            normals = normals.';
        end
        if ~isequal(size(normals), size(positions))
            error('PATBox:InvalidSensorNormals', ...
                'Sensor normals must have the same size as positions.');
        end
        lengths = sqrt(sum(normals.^2,2));
        if any(lengths <= eps)
            error('PATBox:ZeroSensorNormal', 'Sensor normals must be non-zero.');
        end
        normals = normals ./ lengths;
    end

    if isscalar(measure)
        measure = repmat(double(measure), nElem, 1);
    else
        measure = double(measure(:));
    end
    if numel(measure) ~= nElem || any(~isfinite(measure)) || any(measure <= 0)
        error('PATBox:InvalidElementMeasure', ...
            'element_measure must be positive and contain one value per element.');
    end

    geom = struct('positions', positions, 'normals', normals, ...
        'element_measure', measure, 'num_elements', nElem, ...
        'type', type, 'model', model);

    % Preserve acquisition metadata required by exact-inversion guards and
    % downstream provenance. Defaults are conservative and do not turn an
    % unknown detector into an ideal point receiver.
    if isstruct(sensorGeometry)
        geom = copyFieldIfPresent(geom, sensorGeometry, 'tangents');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'element_tangents');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'physical_positions');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'physical_normals');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'nominal_positions');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'nominal_normals');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'geometry_error');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'combine_mode');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'array_center');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'aperture_deg');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'start_angle_deg');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'rotation_deg');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'pitch');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'requested_pitch');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'kerf');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'element_width');
        geom = copyFieldIfPresent(geom, sensorGeometry, 'directivity_pattern');

        geom.use_directivity = logicalScalarField( ...
            sensorGeometry, 'use_directivity', false);
        geom.center_frequency_hz = numericScalarField( ...
            sensorGeometry, 'center_frequency_hz', 0);
        geom.fractional_bandwidth_percent = numericScalarField( ...
            sensorGeometry, 'fractional_bandwidth_percent', 0);
    else
        geom.use_directivity = false;
        geom.center_frequency_hz = 0;
        geom.fractional_bandwidth_percent = 0;
    end
end

function value = canonicalText(value, fallback)
    if isempty(value)
        value = fallback;
        return;
    end
    value = lower(strrep(char(value), '-', '_'));
end

function model = canonicalSensorModel(value)
    model = canonicalText(value, 'unknown');
    switch model
        case {'cartesian','offgrid_point','off_grid_point'}
            model = 'cartesian_point';
        case {'point_detector','point_pressure'}
            model = 'point';
        case {'kwavearray','array'}
            model = 'kwave_array';
        case {'finite_grid'}
            model = 'rasterized';
    end
end

function target = copyFieldIfPresent(target, source, fieldName)
    if isfield(source, fieldName)
        target.(fieldName) = source.(fieldName);
    end
end

function value = logicalScalarField(source, fieldName, fallback)
    if ~isfield(source, fieldName) || isempty(source.(fieldName))
        value = logical(fallback);
        return;
    end
    raw = source.(fieldName);
    if ~(islogical(raw) || isnumeric(raw)) || ~isscalar(raw) || ~isfinite(double(raw))
        error('PATBox:InvalidSensorMetadata', ...
            '%s must be a finite logical scalar.', fieldName);
    end
    value = logical(raw);
end

function value = numericScalarField(source, fieldName, fallback)
    if ~isfield(source, fieldName) || isempty(source.(fieldName))
        value = double(fallback);
        return;
    end
    raw = double(source.(fieldName));
    if ~isscalar(raw) || ~isfinite(raw)
        error('PATBox:InvalidSensorMetadata', ...
            '%s must be a finite numeric scalar.', fieldName);
    end
    value = raw;
end
