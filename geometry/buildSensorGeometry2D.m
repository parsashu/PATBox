function [sensor, geom, sensorForSimulation] = buildSensorGeometry2D(kgrid, cfg)
%BUILDSENSORGEOMETRY2D Build ordered physical 2-D receiver elements.
%
% SensorModel controls how finite elements are represented:
%   auto        use kWaveArray when available, otherwise rasterized lines
%   kwave_array use kWaveArray off-grid line elements (recommended)
%   rasterized  use explicit on-grid integration points
%   point       use one snapped grid point per element
%   cartesian_point use ordered off-grid Cartesian point receivers
%
% NumTransducers always means the TOTAL number of physical elements. The
% element order is preserved explicitly in geom.positions and must be used
% by reconstruction algorithms instead of relying on binary-mask ordering.

    type = lower(char(getCfg(cfg, 'SensorType', 'linear')));
    nElem = round(getCfg(cfg, 'NumTransducers', 128));
    pitch = double(getCfg(cfg, 'Pitch', 0.3e-3));
    kerf = double(getCfg(cfg, 'Kerf', 0.03e-3));
    width = double(getCfg(cfg, 'ElementWidth', pitch - kerf));
    configuredMargin = double(getCfg(cfg, 'SensorMargin', 0));
    margin = resolveBoundaryClearance(kgrid, width, configuredMargin);
    rotation = deg2rad(double(getCfg(cfg, 'SensorRotationDeg', 0)));
    centre = [double(getCfg(cfg, 'ArrayCenterX', 0)), ...
              double(getCfg(cfg, 'ArrayCenterY', 0))];
    span = NaN;
    startDeg = NaN;

    validateScalar(nElem, 'NumTransducers', 1, inf);
    validateScalar(pitch, 'Pitch', eps, inf);
    validateScalar(width, 'ElementWidth', eps, inf);
    if width > pitch && strcmp(type, 'linear')
        warning('PATBox:ElementOverlap', ...
            'ElementWidth exceeds Pitch; neighbouring physical elements overlap.');
    end

    switch type
        case 'linear'
            if all(abs(centre) < eps)
                centre = [min(double(kgrid.x_vec)) + margin, 0];
            end
            tangent = [sin(rotation), cos(rotation)];
            normal = [cos(rotation), -sin(rotation)];
            if dot(normal, gridCentre(kgrid) - centre) < 0
                normal = -normal;
            end
            offsets = ((0:nElem-1) - (nElem-1)/2) .* pitch;
            positions = centre + offsets(:) .* tangent;
            normals = repmat(normal, nElem, 1);
            tangents = repmat(tangent, nElem, 1);

        case {'circular', 'arc'}
            radius = double(getCfg(cfg, 'SensorRadius', 0));
            if radius <= 0
                radius = min(rangeOf(kgrid.x_vec), rangeOf(kgrid.y_vec))/2 - margin;
            end
            validateScalar(radius, 'SensorRadius', eps, inf);
            span = 360;
            if strcmp(type, 'arc')
                span = double(getCfg(cfg, 'SensorArcDeg', 180));
                validateScalar(span, 'SensorArcDeg', eps, 360);
            end
            startDeg = double(getCfg(cfg, 'SensorStartAngleDeg', -span/2)) + rad2deg(rotation);
            if span >= 360 - 1e-10
                theta = deg2rad(startDeg) + (0:nElem-1).' .* (2*pi/nElem);
            elseif nElem == 1
                theta = deg2rad(startDeg + span/2);
            else
                theta = linspace(deg2rad(startDeg), deg2rad(startDeg + span), nElem).';
            end
            positions = centre + radius .* [cos(theta), sin(theta)];
            normals = centre - positions;
            normals = rowNormalise(normals);
            tangents = [-normals(:,2), normals(:,1)];

        case 'square'
            [positions, normals, tangents] = squareGeometry(kgrid, nElem, ...
                margin, centre, rotation);

        otherwise
            error('PATBox:InvalidSensorType', ...
                'SensorType must be linear, circular, arc, or square.');
    end

    nominalPositions = positions;
    nominalNormals = normals;
    nominalTangents = tangents;
    [positions, normals, tangents, geometryError] = applyGeometryErrors( ...
        nominalPositions, nominalNormals, nominalTangents, cfg);

    physicalPositions = positions;
    physicalNormals = normals;
    physicalTangents = tangents;
    acquisitionPositions = physicalPositions;
    acquisitionNormals = physicalNormals;
    acquisitionTangents = physicalTangents;

    assertFiniteGeometry(physicalPositions, physicalNormals, physicalTangents);
    assertElementsInsideGrid(physicalPositions, physicalTangents, width, kgrid);
    actualSpacing=effectiveElementSpacing(physicalPositions,type,pitch);
    if width>actualSpacing
        warning('PATBox:PhysicalElementOverlap', ...
            ['ElementWidth %.3g m exceeds the median centre spacing %.3g m; ' ...
             'finite receiver elements overlap.'],width,actualSpacing);
    end

    model = lower(strrep(char(getCfg(cfg, 'SensorModel', 'auto')), '-', '_'));
    if strcmp(model, 'auto')
        if exist('kWaveArray', 'class') == 8 || exist('kWaveArray', 'file') == 2
            model = 'kwave_array';
        else
            model = 'rasterized';
        end
    end

    arrayObject = [];
    pointToElement = [];
    simulationWeights = [];

    switch model
        case {'kwave_array','kwavearray','array'}
            if ~(exist('kWaveArray', 'class') == 8 || exist('kWaveArray', 'file') == 2)
                error('PATBox:KWaveArrayUnavailable', ...
                    'SensorModel=kwave_array requires a k-Wave version containing kWaveArray.');
            end
            arrayObject = kWaveArray();
            for e = 1:nElem
                p1 = physicalPositions(e,:) - 0.5*width.*physicalTangents(e,:);
                p2 = physicalPositions(e,:) + 0.5*width.*physicalTangents(e,:);
                arrayObject.addLineElement(p1, p2);
            end
            simulationMask = arrayObject.getArrayBinaryMask(kgrid);
            combineMode = 'kwave_array';

        case {'rasterized','finite_grid'}
            integrationPoints = round(getCfg(cfg, 'ElementIntegrationPoints', 0));
            if integrationPoints <= 0
                integrationPoints = max(3, 2*ceil(width/min(kgrid.dx,kgrid.dy)) + 1);
            end
            [simulationMask, pointToElement, pointNormals] = rasteriseElements( ...
                physicalPositions, physicalNormals, physicalTangents, width, integrationPoints, kgrid);
            simulationWeights = ones(nnz(simulationMask),1,'single');
            combineMode = 'mapping';

        case {'cartesian_point','offgrid_point','cartesian'}
            if logical(getCfg(cfg,'UseDirectivity',false))
                error('PATBox:CartesianPointDirectivityUnsupported', ...
                    ['SensorModel=cartesian_point preserves ordered off-grid point receivers, ' ...
                     'but k-Wave directivity requires a binary grid mask.']);
            end
            simulationMask = physicalPositions.';
            pointToElement = (1:nElem).';
            pointNormals = physicalNormals;
            simulationWeights = ones(nElem,1,'single');
            integrationPoints = 1;
            combineMode = 'cartesian_point';

        case {'point','point_detector'}
            [simulationMask, pointToElement, pointNormals, snappedPositions] = ...
                rasterisePointElements(physicalPositions, physicalNormals, kgrid);
            acquisitionPositions = snappedPositions;
            if any(strcmp(type,{'circular','arc'}))
                acquisitionNormals = rowNormalise(centre-acquisitionPositions);
                acquisitionTangents = [-acquisitionNormals(:,2),acquisitionNormals(:,1)];
            end
            simulationWeights = ones(nnz(simulationMask),1,'single');
            integrationPoints = 1;
            combineMode = 'mapping';

        otherwise
            error('PATBox:InvalidSensorModel', 'Unknown SensorModel: %s', model);
    end

    centreMask = rasteriseCentres(acquisitionPositions, kgrid);

    sensorForSimulation = struct();
    sensorForSimulation.mask = simulationMask;
    sensorForSimulation.record = {'p'};

    % Directivity fields are only used for the point/raster fallback. A
    % kWaveArray finite element already performs spatial integration and
    % adding directivity here would count aperture effects twice.
    useDirectivity = logical(getCfg(cfg, 'UseDirectivity', true));
    if useDirectivity && ~strcmp(combineMode, 'kwave_array') && ...
            ~strcmp(combineMode, 'cartesian_point')
        angleMap = zeros(kgrid.Nx, kgrid.Ny, 'single');
        idx = find(simulationMask > 0);
        angleMap(idx) = atan2(single(pointNormals(:,2)), single(pointNormals(:,1)));
        sensorForSimulation.directivity_angle = angleMap;
        sensorForSimulation.directivity_size = width;
        sensorForSimulation.directivity_pattern = char(getCfg(cfg, 'DirectivityPattern', 'pressure'));
    end

    centreFrequency = double(getCfg(cfg, 'CenterFrequency', 0));
    bandwidthPercent = double(getCfg(cfg, 'FractionalBandwidthPercent', 0));
    if centreFrequency > 0 && bandwidthPercent > 0
        sensorForSimulation.frequency_response = [centreFrequency, bandwidthPercent];
    end

    sensor = struct();
    sensor.mask = centreMask;
    sensor.element_positions = acquisitionPositions;
    sensor.element_normals = acquisitionNormals;
    sensor.element_tangents = acquisitionTangents;
    sensor.physical_element_positions = physicalPositions;
    sensor.physical_element_normals = physicalNormals;
    sensor.physical_element_tangents = physicalTangents;
    sensor.nominal_element_positions = nominalPositions;
    sensor.nominal_element_normals = nominalNormals;
    sensor.nominal_element_tangents = nominalTangents;
    sensor.element_width = repmat(width, nElem, 1);
    sensor.element_measure = repmat(width, nElem, 1);
    sensor.pitch = actualSpacing;
    sensor.requested_pitch = pitch;
    sensor.type = type;
    sensor.model = model;
    sensor.array_center = centre;
    sensor.aperture_deg = geometryAperture(type,span);
    sensor.start_angle_deg = startDeg;
    sensor.center_frequency_hz = centreFrequency;
    sensor.fractional_bandwidth_percent = bandwidthPercent;
    sensor.use_directivity = useDirectivity;

    geom = struct();
    geom.type = type;
    geom.model = model;
    geom.positions = acquisitionPositions;
    geom.normals = acquisitionNormals;
    geom.tangents = acquisitionTangents;
    geom.physical_positions = physicalPositions;
    geom.physical_normals = physicalNormals;
    geom.physical_tangents = physicalTangents;
    % Public compatibility aliases. The canonical compact names above are
    % used internally, while these explicit names match sim.sensor and make
    % the metadata contract easier to discover for users and tests.
    geom.element_positions = acquisitionPositions;
    geom.element_normals = acquisitionNormals;
    geom.element_tangents = acquisitionTangents;
    geom.actual_positions = acquisitionPositions;
    geom.actual_normals = acquisitionNormals;
    geom.actual_tangents = acquisitionTangents;
    geom.nominal_positions = nominalPositions;
    geom.nominal_normals = nominalNormals;
    geom.nominal_tangents = nominalTangents;
    geom.nominal_element_positions = nominalPositions;
    geom.nominal_element_normals = nominalNormals;
    geom.nominal_element_tangents = nominalTangents;
    geom.geometry_error = geometryError;
    geom.element_width = repmat(width, nElem, 1);
    geom.element_measure = repmat(width, nElem, 1);
    geom.pitch = actualSpacing;
    geom.requested_pitch = pitch;
    geom.kerf = kerf;
    geom.point_to_element = pointToElement;
    geom.simulation_weights = simulationWeights;
    geom.simulation_mask = simulationMask;
    geom.centre_mask = centreMask;
    geom.num_elements = nElem;
    if strcmp(combineMode,'cartesian_point')
        geom.num_simulation_points = nElem;
    else
        geom.num_simulation_points = nnz(simulationMask);
    end
    geom.combine_mode = combineMode;
    geom.array_object = arrayObject;
    geom.use_directivity = useDirectivity;
    geom.directivity_pattern = char(getCfg(cfg,'DirectivityPattern','pressure'));
    geom.center_frequency_hz = double(getCfg(cfg,'CenterFrequency',0));
    geom.fractional_bandwidth_percent = double(getCfg(cfg,'FractionalBandwidthPercent',0));
    geom.array_center = centre;
    geom.aperture_deg = geometryAperture(type,span);
    geom.start_angle_deg = startDeg;
    geom.rotation_deg = rad2deg(rotation);
end

function aperture=geometryAperture(type,span)
    if strcmp(type,'circular')
        aperture=360;
    elseif strcmp(type,'arc')
        aperture=span;
    else
        aperture=NaN;
    end
end

function [positions, normals, tangents] = squareGeometry(kgrid, nElem, margin, centre, rotation)
    sideCounts = floor(nElem/4) * ones(1,4);
    sideCounts(1:mod(nElem,4)) = sideCounts(1:mod(nElem,4)) + 1;
    halfX = rangeOf(kgrid.x_vec)/2 - margin;
    halfY = rangeOf(kgrid.y_vec)/2 - margin;
    if halfX <= 0 || halfY <= 0
        error('PATBox:InvalidSensorMargin', 'SensorMargin leaves no square aperture.');
    end
    positions = zeros(nElem,2);
    normals = zeros(nElem,2);
    tangents = zeros(nElem,2);
    cursor = 1;
    sideSpec = {
        [-halfX, 0], [0, 1], [1, 0], halfY; ...
        [ halfX, 0], [0, 1], [-1, 0], halfY; ...
        [0, -halfY], [1, 0], [0, 1], halfX; ...
        [0,  halfY], [1, 0], [0,-1], halfX};
    for side = 1:4
        n = sideCounts(side);
        if n == 0, continue; end
        base = sideSpec{side,1};
        tangent = sideSpec{side,2};
        normal = sideSpec{side,3};
        halfLength = sideSpec{side,4};
        offsets = linspace(-halfLength, halfLength, n+2);
        offsets = offsets(2:end-1);
        ids = cursor:(cursor+n-1);
        positions(ids,:) = base + offsets(:).*tangent;
        normals(ids,:) = repmat(normal,n,1);
        tangents(ids,:) = repmat(tangent,n,1);
        cursor = cursor+n;
    end
    R = [cos(rotation), -sin(rotation); sin(rotation), cos(rotation)];
    positions = positions*R.' + centre;
    normals = normals*R.';
    tangents = tangents*R.';
end

function [mask, mapping, orderedNormals] = rasteriseElements(pos, normals, tangents, width, nPts, kgrid)
    offsets = linspace(-width/2, width/2, nPts);
    allIdx = [];
    allElem = [];
    allNormal = [];
    for e = 1:size(pos,1)
        points = pos(e,:) + offsets(:).*tangents(e,:);
        ix = nearestIndices(kgrid.x_vec, points(:,1));
        iy = nearestIndices(kgrid.y_vec, points(:,2));
        idx = unique(sub2ind([kgrid.Nx,kgrid.Ny],ix,iy),'stable');
        allIdx = [allIdx; idx(:)]; %#ok<AGROW>
        allElem = [allElem; repmat(e,numel(idx),1)]; %#ok<AGROW>
        allNormal = [allNormal; repmat(normals(e,:),numel(idx),1)]; %#ok<AGROW>
    end

    [~,~,group] = unique(allIdx);
    if any(accumarray(group,1) > 1)
        error('PATBox:RasterizedElementOverlap', ...
            ['Two finite elements share one or more grid points. Use SensorModel=' ...
             '"kwave_array", refine the grid, or reduce ElementWidth.']);
    end

    [sortedIdx, order] = sort(allIdx); % k-Wave binary-mask output order
    mapping = allElem(order);
    orderedNormals = allNormal(order,:);
    mask = zeros(kgrid.Nx,kgrid.Ny);
    mask(sortedIdx) = 1;
end

function [mask, mapping, orderedNormals, snappedPositions] = rasterisePointElements(pos, normals, kgrid)
    ix = nearestIndices(kgrid.x_vec,pos(:,1));
    iy = nearestIndices(kgrid.y_vec,pos(:,2));
    idx = sub2ind([kgrid.Nx,kgrid.Ny],ix,iy);
    if numel(unique(idx)) ~= numel(idx)
        error('PATBox:SensorGridCollision', ...
            'Two element centres map to the same grid point. Refine the grid.');
    end
    snappedPositions = [double(kgrid.x_vec(ix(:))),double(kgrid.y_vec(iy(:)))];
    [sortedIdx, order] = sort(idx(:));
    mapping = order(:); % sorted grid point -> original physical element
    orderedNormals = normals(order,:);
    mask = zeros(kgrid.Nx,kgrid.Ny);
    mask(sortedIdx)=1;
end

function mask = rasteriseCentres(pos, kgrid)
    ix = nearestIndices(kgrid.x_vec,pos(:,1));
    iy = nearestIndices(kgrid.y_vec,pos(:,2));
    idx = sub2ind([kgrid.Nx,kgrid.Ny],ix,iy);
    mask = zeros(kgrid.Nx,kgrid.Ny);
    mask(unique(idx)) = 1;
end

function idx = nearestIndices(vec, values)
    vec = double(vec(:));
    values = double(values(:));
    idx = interp1(vec, 1:numel(vec), values, 'nearest', 'extrap');
    idx = max(1, min(numel(vec), round(idx)));
end

function [pos, normals, tangents, meta] = applyGeometryErrors(pos0, normals0, tangents0, cfg)
    positionStd = double(getCfg(cfg, 'SensorPositionStd', 0));
    radialStd = double(getCfg(cfg, 'SensorRadialPositionStd', 0));
    angularPositionStdDeg = double(getCfg(cfg, 'SensorAngularPositionStdDeg', 0));
    angleStdDeg = double(getCfg(cfg, 'SensorAngleStdDeg', 0));
    if ~(isfinite(positionStd) && positionStd >= 0)
        error('PATBox:InvalidSensorPositionStd', ...
            'SensorPositionStd must be a finite nonnegative value in metres.');
    end
    if ~(isfinite(radialStd) && radialStd >= 0)
        error('PATBox:InvalidSensorRadialPositionStd', ...
            'SensorRadialPositionStd must be finite and nonnegative.');
    end
    if ~(isfinite(angularPositionStdDeg) && angularPositionStdDeg >= 0)
        error('PATBox:InvalidSensorAngularPositionStd', ...
            'SensorAngularPositionStdDeg must be finite and nonnegative.');
    end
    if ~(isfinite(angleStdDeg) && angleStdDeg >= 0)
        error('PATBox:InvalidSensorAngleStd', ...
            'SensorAngleStdDeg must be a finite nonnegative value.');
    end

    pos = pos0;
    normals = normals0;
    tangents = tangents0;
    positionError = zeros(size(pos0));
    angleErrorDeg = zeros(size(pos0,1),1);
    radialError = zeros(size(pos0,1),1);
    angularPositionErrorDeg = zeros(size(pos0,1),1);
    if positionStd > 0 || radialStd > 0 || angularPositionStdDeg > 0 || angleStdDeg > 0
        previousState = rng;
        cleaner = onCleanup(@() rng(previousState)); %#ok<NASGU>
        seed = round(double(getCfg(cfg, 'RandomSeed', 1))) + 1009;
        rng(seed, 'twister');
        positionError = positionStd .* randn(size(pos0));
        radialError = radialStd .* randn(size(pos0,1),1);
        angularPositionErrorDeg = angularPositionStdDeg .* randn(size(pos0,1),1);
        angleErrorDeg = angleStdDeg .* randn(size(pos0,1),1);
        pos = pos0 + positionError - radialError .* normals0;
        if angularPositionStdDeg > 0
            centre = [double(getCfg(cfg,'ArrayCenterX',0)),double(getCfg(cfg,'ArrayCenterY',0))];
            relative = pos - centre;
            ap = deg2rad(angularPositionErrorDeg);
            cap = cos(ap); sap = sin(ap);
            relative = [cap.*relative(:,1)-sap.*relative(:,2), ...
                        sap.*relative(:,1)+cap.*relative(:,2)];
            pos = relative + centre;
            normals0 = [cap.*normals0(:,1)-sap.*normals0(:,2), ...
                        sap.*normals0(:,1)+cap.*normals0(:,2)];
            tangents0 = [cap.*tangents0(:,1)-sap.*tangents0(:,2), ...
                         sap.*tangents0(:,1)+cap.*tangents0(:,2)];
        end
        angle = deg2rad(angleErrorDeg);
        ca = cos(angle);
        sa = sin(angle);
        normals = [ca.*normals0(:,1) - sa.*normals0(:,2), ...
                   sa.*normals0(:,1) + ca.*normals0(:,2)];
        tangents = [ca.*tangents0(:,1) - sa.*tangents0(:,2), ...
                    sa.*tangents0(:,1) + ca.*tangents0(:,2)];
    end
    meta = struct( ...
        'position_std_m', positionStd, ...
        'radial_position_std_m', radialStd, ...
        'angular_position_std_deg', angularPositionStdDeg, ...
        'angle_std_deg', angleStdDeg, ...
        'position_error_m', positionError, ...
        'radial_position_error_m', radialError, ...
        'angular_position_error_deg', angularPositionErrorDeg, ...
        'angle_error_deg', angleErrorDeg, ...
        'random_seed', round(double(getCfg(cfg, 'RandomSeed', 1))) + 1009);
end

function spacing = effectiveElementSpacing(pos, type, requestedPitch)
    if size(pos,1) < 2
        spacing = requestedPitch;
        return;
    end
    if strcmp(type, 'circular')
        neighbour = pos([2:end,1],:) - pos;
        spacing = median(sqrt(sum(neighbour.^2,2)));
    else
        neighbour = diff(pos,1,1);
        distances = sqrt(sum(neighbour.^2,2));
        distances = distances(isfinite(distances) & distances > 0);
        if isempty(distances), spacing = requestedPitch; else, spacing = median(distances); end
    end
end

function assertElementsInsideGrid(pos, tangents, width, kgrid)
    endpoints = [pos - 0.5*width.*tangents; pos + 0.5*width.*tangents];
    outside = endpoints(:,1)<min(kgrid.x_vec) | endpoints(:,1)>max(kgrid.x_vec) | ...
              endpoints(:,2)<min(kgrid.y_vec) | endpoints(:,2)>max(kgrid.y_vec);
    if any(outside)
        error('PATBox:SensorOutsideGrid', ...
            'One or more finite sensor elements extend outside the grid.');
    end
end

function assertFiniteGeometry(pos, normals, tangents)
    if any(~isfinite(pos(:))) || any(~isfinite(normals(:))) || any(~isfinite(tangents(:)))
        error('PATBox:InvalidSensorGeometry', 'Sensor geometry contains non-finite values.');
    end
    if any(abs(sum(normals.*tangents,2)) > 1e-8)
        error('PATBox:InvalidSensorBasis', 'Sensor normal and tangent vectors must be orthogonal.');
    end
end

function out = rowNormalise(in)
    lengths = sqrt(sum(in.^2,2));
    if any(lengths <= eps), error('PATBox:InvalidSensorNormal','Zero sensor normal.'); end
    out = in ./ lengths;
end
function c = gridCentre(kgrid)
    c = [mean(double(kgrid.x_vec)), mean(double(kgrid.y_vec))];
end
function r = rangeOf(v)
    r = max(double(v(:))) - min(double(v(:)));
end
function validateScalar(v, name, lowerBound, upperBound)
    if ~(isnumeric(v) && isscalar(v) && isfinite(v) && v >= lowerBound && v <= upperBound)
        error('PATBox:InvalidParameter', '%s is outside its valid range.', name);
    end
end
function margin = resolveBoundaryClearance(kgrid,width,configuredMargin)
    if ~(isnumeric(configuredMargin)&&isscalar(configuredMargin)&&isfinite(configuredMargin)&&configuredMargin>=0)
        error('PATBox:InvalidSensorMargin','SensorMargin must be finite and nonnegative.');
    end
    if configuredMargin>0
        margin=configuredMargin;
    else
        margin=max([2*double(kgrid.dx),2*double(kgrid.dy),0.5*double(width)]);
    end
end

function value = getCfg(cfg,name,defaultValue)
    if isfield(cfg,name) && ~isempty(cfg.(name)), value=cfg.(name); else, value=defaultValue; end
end
