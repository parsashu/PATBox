function sim = forward_simulation_physical(img_path, cfg)
%FORWARD_SIMULATION_PHYSICAL Physics-aware 2-D PAT acquisition simulation.
%
% The returned RF matrices are always [physical elements x time]. Finite
% elements are combined using kWaveArray weights when available. Ideal
% pressure, system-impaired pressure, and final measured pressure are kept
% separately to make noise and calibration studies auditable.

    cDesign = gridDesignSoundSpeed(cfg);
    [Nx,Ny,dx,dy] = forwardGrid(cfg,cDesign);
    kgrid = kWaveGrid(Nx,dx,Ny,dy);

    [medium,mediumMeta] = buildAcousticMedium2D(kgrid,cfg);
    validatePhysicalSampling(kgrid,medium,cfg);
    [sensor,sensorGeomActual,sensorKWave] = buildSensorGeometry2D(kgrid,cfg);
    sensorGeomNominal = nominalGeometry(sensorGeomActual);
    geometryMode = lower(strrep(char(getCfg(cfg,'ReconstructionGeometryMode','calibrated')),'-','_'));
    switch geometryMode
        case {'calibrated','actual','true'}
            sensorGeomRecon = sensorGeomActual;
        case {'nominal','uncalibrated'}
            sensorGeomRecon = sensorGeomNominal;
        otherwise
            error('PATBox:InvalidGeometryKnowledgeMode', ...
                'ReconstructionGeometryMode must be calibrated or nominal.');
    end
    [source,sourceMeta] = buildInitialPressure2D(img_path,[Nx,Ny],cfg);
    apertureAudit = validateSourceAperture2D(source.p0,sensorGeomActual,kgrid, ...
        'SupportThreshold',double(getCfg(cfg,'SourceSupportThreshold',1e-3)), ...
        'RequireInside',logical(getCfg(cfg,'RequireSourceInsideClosedAperture',true)));

    cMax = max(double(medium.sound_speed(:)));
    cfl = double(getCfg(cfg,'CFL',0.2));
    tEnd = double(getCfg(cfg,'SimulationEndTime',0));
    if tEnd > 0
        kgrid.makeTime(cMax,cfl,tEnd);
    else
        kgrid.makeTime(cMax,cfl);
    end

    dataCast = char(getCfg(cfg,'DataCast','gpuArray-single'));
    if startsWith(lower(dataCast),'gpu') && ~hasUsableGpu()
        warning('PATBox:GPUUnavailable', ...
            'GPU unavailable; using single-precision CPU simulation.');
        dataCast='single';
    end

    inputArgs = {'PMLInside',false, ...
        'PMLSize',round(getCfg(cfg,'PMLSize',20)), ...
        'PlotPML',false, ...
        'Smooth',[false,false,false], ...
        'PlotSim',logical(getCfg(cfg,'PlotSimulation',false)), ...
        'DataCast',dataCast, ...
        'DataRecast',true};
    if strcmp(sensorGeomActual.combine_mode,'cartesian_point')
        inputArgs(end+1:end+2)={'CartInterp','linear'};
    end

    raw = kspaceFirstOrder2D(kgrid,medium,source,sensorKWave,inputArgs{:});
    if isstruct(raw), pointData=raw.p; else, pointData=raw; end
    pointData = ensureChannelsByTime(pointData,sensorGeomActual.num_simulation_points,kgrid.Nt);
    idealElementData = combinePhysicalElements(pointData,sensorGeomActual,kgrid);
    % kWaveArray is a runtime helper and is not required after traces have
    % been combined. Removing the handle keeps saved simulation structs
    % portable across k-Wave installations.
    sensorGeomActual.array_object=[];
    sensorGeomNominal.array_object=[];
    sensorGeomRecon.array_object=[];

    [measured,acqMeta,systemImpaired] = applyAcquisitionModel( ...
        idealElementData,kgrid.dt,cfg);

    sim = struct();
    sim.sensor_data = struct('p',measured);
    sim.sensor_data_clean = struct('p',idealElementData);
    sim.sensor_data_system = struct('p',systemImpaired);
    sim.sensor = sensor;
    sim.sensor_geometry = sensorGeomRecon;
    sim.sensor_geometry_actual = sensorGeomActual;
    sim.sensor_geometry_nominal = sensorGeomNominal;
    sim.kgrid = kgrid;
    sim.source = source;
    sim.medium = medium;
    sim.sound_speed = medium.sound_speed; % backwards compatibility
    sim.p0_reference = source.p0;
    sim.noisy_p0 = source.p0; % deprecated compatibility alias
    sim.info = struct( ...
        'sensor_type',sensorGeomActual.type, ...
        'sensor_model',sensorGeomActual.model, ...
        'aperture_deg',sensorGeomActual.aperture_deg, ...
        'sensor_start_angle_deg',sensorGeomActual.start_angle_deg, ...
        'array_center_m',sensorGeomActual.array_center, ...
        'element_width_m',double(sensorGeomActual.element_width(1)), ...
        'center_frequency_hz',sensorGeomActual.center_frequency_hz, ...
        'fractional_bandwidth_percent',sensorGeomActual.fractional_bandwidth_percent, ...
        'use_directivity',logical(sensorGeomActual.use_directivity), ...
        'directivity_pattern',sensorGeomActual.directivity_pattern, ...
        'num_sensors',sensorGeomActual.num_elements, ...
        'num_simulation_points',sensorGeomActual.num_simulation_points, ...
        'reconstruction_geometry_mode',geometryMode, ...
        'geometry_error',sensorGeomActual.geometry_error, ...
        'source',sourceMeta, ...
        'medium',mediumMeta, ...
        'aperture_audit',apertureAudit, ...
        'acquisition',acqMeta, ...
        'random_seed',getCfg(cfg,'RandomSeed',1), ...
        'image_path',char(img_path), ...
        'data_layout','physical_elements_by_time', ...
        'patbox_physics_version',patVersion(), ...
        'created_utc',utcNowText());
end

function nominal = nominalGeometry(actual)
    nominal = actual;
    nominal.positions = actual.nominal_positions;
    nominal.normals = actual.nominal_normals;
    nominal.tangents = actual.nominal_tangents;
    nominal.element_positions = nominal.positions;
    nominal.element_normals = nominal.normals;
    nominal.element_tangents = nominal.tangents;
    nominal.actual_positions = actual.actual_positions;
    nominal.actual_normals = actual.actual_normals;
    nominal.actual_tangents = actual.actual_tangents;
    nominal.model = [char(actual.model) '_nominal_reconstruction'];
end

function elementData = combinePhysicalElements(pointData, geom, kgrid)
    switch lower(char(geom.combine_mode))
        case 'cartesian_point'
            elementData=ensureChannelsByTime(pointData,geom.num_elements,size(pointData,2));

        case 'kwave_array'
            if isempty(geom.array_object)
                error('PATBox:MissingKWaveArray', ...
                    'Geometry combine mode requires array_object.');
            end
            elementData = geom.array_object.combineSensorData(kgrid, pointData);
            elementData = ensureChannelsByTime(elementData,geom.num_elements,size(pointData,2));

        case 'mapping'
            mapping = geom.point_to_element(:);
            if numel(mapping) ~= size(pointData,1)
                error('PATBox:InvalidElementMapping', ...
                    'point_to_element does not match k-Wave sensor output.');
            end
            elementData = zeros(geom.num_elements,size(pointData,2),'single');
            counts = zeros(geom.num_elements,1);
            for p=1:size(pointData,1)
                e=mapping(p);
                elementData(e,:)=elementData(e,:)+single(pointData(p,:));
                counts(e)=counts(e)+1;
            end
            if any(counts==0)
                error('PATBox:EmptyPhysicalElement', ...
                    'One or more physical elements contain no simulation points.');
            end
            elementData = elementData ./ single(counts);

        otherwise
            error('PATBox:InvalidCombineMode', ...
                'Unknown sensor combine mode: %s', geom.combine_mode);
    end
    elementData = single(elementData);
end

function [Nx,Ny,dx,dy]=forwardGrid(cfg,cDesign)
    Nx=round(getCfg(cfg,'GridSizeX',getCfg(cfg,'GridSize',512)));
    Ny=round(getCfg(cfg,'GridSizeY',getCfg(cfg,'GridSize',512)));
    if Nx < 16 || Ny < 16
        error('PATBox:GridTooSmall','Grid dimensions must be at least 16.');
    end
    dx=double(getCfg(cfg,'Dx',0));
    dy=double(getCfg(cfg,'Dy',0));
    if dx<=0
        ppw=double(getCfg(cfg,'PointsPerWavelength',4));
        fmax=double(getCfg(cfg,'MaxFrequency',5e6));
        if fmax<=0
            error('PATBox:InvalidMaxFrequency', ...
                'MaxFrequency must be positive when Dx is automatic.');
        end
        dx=cDesign/(ppw*fmax);
    end
    if dy<=0, dy=dx; end
end

function validatePhysicalSampling(kgrid,medium,cfg)
    fMax=double(getCfg(cfg,'MaxFrequency',0));
    ppwRequested=double(getCfg(cfg,'PointsPerWavelength',0));
    if fMax>0
        cMin=min(double(medium.sound_speed(:)));
        achievedX=cMin/(kgrid.dx*fMax);
        achievedY=cMin/(kgrid.dy*fMax);
        achieved=min(achievedX,achievedY);
        if ppwRequested>0 && achieved < 0.98*ppwRequested
            warning('PATBox:SpatialSamplingBelowTarget', ...
                ['The loaded/heterogeneous medium gives %.2f points per wavelength ' ...
                 'at MaxFrequency, below the requested %.2f. Set Dx/Dy explicitly ' ...
                 'or increase the grid dimensions.'],achieved,ppwRequested);
        end
    end

    centreFrequency=double(getCfg(cfg,'CenterFrequency',0));
    bandwidth=double(getCfg(cfg,'FractionalBandwidthPercent',0));
    if centreFrequency>0 && bandwidth>0 && fMax>0
        approximateUpper=centreFrequency*(1+bandwidth/200);
        if approximateUpper>fMax
            warning('PATBox:BandwidthAboveGridDesignFrequency', ...
                ['The nominal transducer upper -6 dB frequency (approximately %.3g Hz) ' ...
                 'exceeds MaxFrequency %.3g Hz used to design the grid.'], ...
                 approximateUpper,fMax);
        end
    end
end

function c = gridDesignSoundSpeed(cfg)
    c0 = double(getCfg(cfg,'SoundSpeed',1500));
    model = lower(char(getCfg(cfg,'MediumModel','homogeneous')));
    if any(strcmp(model,{'gaussian','gaussian_heterogeneous'}))
        c = max(100,c0 - 4*double(getCfg(cfg,'SoundSpeedStd',20)));
    else
        c = c0;
    end
end

function data=ensureChannelsByTime(data,nCh,nT)
    if isa(data,'gpuArray'), data=gather(data); end
    if size(data,1)==nCh && size(data,2)==nT
        return;
    end
    if size(data,2)==nCh && size(data,1)==nT
        data=data.';
        return;
    end
    error('PATBox:UnexpectedKWaveOutput', ...
        'Unexpected k-Wave data size [%d x %d], expected [%d x %d].', ...
        size(data,1),size(data,2),nCh,nT);
end

function tf=hasUsableGpu()
    tf=false;
    if exist('gpuDeviceCount','file')==2
        try
            tf=gpuDeviceCount>0;
        catch
            tf=false;
        end
    end
end
function text=utcNowText()
    text=char(datetime('now','TimeZone','UTC', ...
        'Format','yyyy-MM-dd''T''HH:mm:ss''Z'''));
end
function value=getCfg(cfg,name,defaultValue)
    if isfield(cfg,name)&&~isempty(cfg.(name)),value=cfg.(name);else,value=defaultValue;end
end
