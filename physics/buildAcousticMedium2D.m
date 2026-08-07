function [medium, meta] = buildAcousticMedium2D(kgrid, cfg)
%BUILDACOUSTICMEDIUM2D Build validated acoustic-property maps for k-Wave.
%
% MediumModel values:
%   homogeneous  scalar sound speed and density
%   gaussian     correlated random heterogeneity
%   mat          load sound_speed and density from a MAT file
%   segmented    convert label_map + tissue_properties into property maps
%
% k-Wave alpha_coeff units are dB/(MHz^alpha_power cm). PATBox stores this
% unit explicitly in metadata to avoid mixing it with Np/m conventions.

    model = lower(strrep(char(getCfg(cfg,'MediumModel','homogeneous')),'-','_'));
    nx = kgrid.Nx;
    ny = kgrid.Ny;
    baseSeed = round(getCfg(cfg,'RandomSeed',1));
    seed = baseSeed + 211;

    c0 = double(getCfg(cfg,'SoundSpeed',1500));
    rho0 = double(getCfg(cfg,'Density',1000));
    alphaCoeff = getCfg(cfg,'AlphaCoeff',0);
    alphaPower = double(getCfg(cfg,'AlphaPower',1.5));
    bonA = getCfg(cfg,'BonA',0);

    validatePositive(c0,'SoundSpeed');
    validatePositive(rho0,'Density');
    if ~(isfinite(alphaPower) && alphaPower > 0 && alphaPower < 3)
        error('PATBox:InvalidAlphaPower','AlphaPower must lie between 0 and 3.');
    end

    switch model
        case 'homogeneous'
            medium.sound_speed = c0;
            medium.density = rho0;

        case {'gaussian','gaussian_heterogeneous'}
            previousRng=rng;
            rngCleanup=onCleanup(@()rng(previousRng)); %#ok<NASGU>
            rng(seed,'twister');
            corrLength = double(getCfg(cfg,'CorrelationLength',1.0e-3));
            validatePositive(corrLength,'CorrelationLength');
            sigmaPixels = max(corrLength/max(min(kgrid.dx,kgrid.dy),eps),0.5);
            cStd = double(getCfg(cfg,'SoundSpeedStd',20));
            rhoStd = double(getCfg(cfg,'DensityStd',15));
            if cStd < 0 || rhoStd < 0
                error('PATBox:InvalidHeterogeneityStd', ...
                    'SoundSpeedStd and DensityStd must be nonnegative.');
            end
            cField = correlatedUnitField(nx,ny,sigmaPixels);
            rhoField = correlatedUnitField(nx,ny,sigmaPixels);
            medium.sound_speed = single(max(c0+cStd.*cField,100));
            medium.density = single(max(rho0+rhoStd.*rhoField,100));

        case {'mat','map','measured'}
            loaded = loadMediumFile(cfg);
            medium.sound_speed = requireMap(loaded,'sound_speed',[nx,ny]);
            medium.density = requireMap(loaded,'density',[nx,ny]);
            if isfield(loaded,'alpha_coeff'), alphaCoeff=loaded.alpha_coeff; end
            if isfield(loaded,'alpha_power'), alphaPower=double(loaded.alpha_power); end
            if isfield(loaded,'BonA'), bonA=loaded.BonA; end

        case {'segmented','label_map','tissue_map'}
            loaded = loadMediumFile(cfg);
            [medium,alphaCoeff,bonA,alphaPower] = segmentedMedium(loaded,[nx,ny],alphaPower);

        otherwise
            error('PATBox:InvalidMediumModel','Unknown MediumModel: %s',model);
    end

    if ~(isfinite(alphaPower) && isscalar(alphaPower) && alphaPower > 0 && alphaPower < 3)
        error('PATBox:InvalidAlphaPower','Loaded AlphaPower must lie between 0 and 3.');
    end
    medium.sound_speed = validateMap(medium.sound_speed,[nx,ny],'sound_speed',true);
    medium.density = validateMap(medium.density,[nx,ny],'density',true);

    if any(double(alphaCoeff(:)) > 0)
        medium.alpha_coeff = validateMap(alphaCoeff,[nx,ny],'alpha_coeff',false);
        medium.alpha_power = alphaPower;
        alphaMode = lower(char(getCfg(cfg,'AlphaMode','full')));
        switch alphaMode
            case 'full'
            case 'no_absorption'
                medium.alpha_mode = 'no_absorption';
            case 'no_dispersion'
                medium.alpha_mode = 'no_dispersion';
            otherwise
                error('PATBox:InvalidAlphaMode', ...
                    'AlphaMode must be full, no_absorption, or no_dispersion.');
        end
    end
    if any(double(bonA(:)) ~= 0)
        medium.BonA = validateMap(bonA,[nx,ny],'BonA',false);
    end

    medium = addCouplingLayer(medium,kgrid,cfg);

    cMap = double(expandToMap(medium.sound_speed,nx,ny));
    rhoMap = double(expandToMap(medium.density,nx,ny));
    meta = struct( ...
        'model',model, ...
        'base_random_seed',baseSeed, ...
        'random_seed',seed, ...
        'sound_speed_min_m_per_s',min(cMap(:)), ...
        'sound_speed_max_m_per_s',max(cMap(:)), ...
        'density_min_kg_per_m3',min(rhoMap(:)), ...
        'density_max_kg_per_m3',max(rhoMap(:)), ...
        'alpha_coeff_units','dB/(MHz^y cm)', ...
        'alpha_power',alphaPower, ...
        'has_absorption',isfield(medium,'alpha_coeff'), ...
        'has_nonlinearity',isfield(medium,'BonA'), ...
        'coupling_layer_thickness_m',double(getCfg(cfg,'CouplingLayerThickness',0)), ...
        'coupling_layer_side',char(getCfg(cfg,'CouplingLayerSide','xmin')), ...
        'coupling_alpha_coeff',double(getCfg(cfg,'CouplingAlphaCoeff',0)), ...
        'coupling_BonA',double(getCfg(cfg,'CouplingBonA',0)));
end

function loaded = loadMediumFile(cfg)
    path = char(getCfg(cfg,'MediumMapPath',''));
    if isempty(path)
        error('PATBox:MissingMediumMap', ...
            'The selected MediumModel requires MediumMapPath.');
    end
    path=resolvePatboxPath(path);
    if ~isfile(path)
        error('PATBox:MediumMapNotFound','Could not find medium map: %s',path);
    end
    loaded=load(path);
end

function [medium,alphaCoeff,bonA,alphaPower] = segmentedMedium(loaded,targetSize,defaultAlphaPower)
    if ~isfield(loaded,'label_map') || ~isfield(loaded,'tissue_properties')
        error('PATBox:InvalidSegmentedMedium', ...
            'Segmented MAT file must contain label_map and tissue_properties.');
    end
    labels=loaded.label_map;
    if ~isequal(size(labels),targetSize)
        error('PATBox:InvalidLabelMapSize', ...
            'label_map must be [%d x %d].',targetSize(1),targetSize(2));
    end
    props=loaded.tissue_properties;
    if ~isstruct(props)
        error('PATBox:InvalidTissueProperties','tissue_properties must be a struct array.');
    end

    c=zeros(targetSize,'single');
    rho=zeros(targetSize,'single');
    alphaCoeff=zeros(targetSize,'single');
    bonA=zeros(targetSize,'single');
    assigned=false(targetSize);
    for i=1:numel(props)
        required={'label','sound_speed','density'};
        if ~all(isfield(props(i),required))
            error('PATBox:InvalidTissueProperties', ...
                'Each tissue entry needs label, sound_speed, and density.');
        end
        mask=labels==props(i).label;
        c(mask)=single(props(i).sound_speed);
        rho(mask)=single(props(i).density);
        if isfield(props(i),'alpha_coeff'), alphaCoeff(mask)=single(props(i).alpha_coeff); end
        if isfield(props(i),'BonA'), bonA(mask)=single(props(i).BonA); end
        assigned=assigned|mask;
    end
    if any(~assigned(:))
        unknown=unique(labels(~assigned));
        error('PATBox:UnassignedTissueLabel', ...
            'No tissue property was provided for labels: %s',mat2str(unknown(:).'));
    end
    if isfield(loaded,'alpha_power')
        alphaPower=double(loaded.alpha_power);
    else
        alphaPower=defaultAlphaPower;
    end
    medium=struct('sound_speed',c,'density',rho);
end

function medium=addCouplingLayer(medium,kgrid,cfg)
    thickness=double(getCfg(cfg,'CouplingLayerThickness',0));
    if thickness<=0, return; end
    cCoupling=double(getCfg(cfg,'CouplingSoundSpeed',1480));
    rhoCoupling=double(getCfg(cfg,'CouplingDensity',1000));
    validatePositive(cCoupling,'CouplingSoundSpeed');
    validatePositive(rhoCoupling,'CouplingDensity');

    medium.sound_speed=expandToMap(medium.sound_speed,kgrid.Nx,kgrid.Ny);
    medium.density=expandToMap(medium.density,kgrid.Nx,kgrid.Ny);
    side=lower(char(getCfg(cfg,'CouplingLayerSide','xmin')));
    nx=max(1,round(thickness/kgrid.dx));
    ny=max(1,round(thickness/kgrid.dy));
    nx=min(nx,kgrid.Nx);
    ny=min(ny,kgrid.Ny);

    switch side
        case 'xmin'
            mask=false(kgrid.Nx,kgrid.Ny); mask(1:nx,:)=true;
        case 'xmax'
            mask=false(kgrid.Nx,kgrid.Ny); mask(end-nx+1:end,:)=true;
        case 'ymin'
            mask=false(kgrid.Nx,kgrid.Ny); mask(:,1:ny)=true;
        case 'ymax'
            mask=false(kgrid.Nx,kgrid.Ny); mask(:,end-ny+1:end)=true;
        case {'all','boundary'}
            mask=false(kgrid.Nx,kgrid.Ny);
            mask([1:nx,end-nx+1:end],:)=true;
            mask(:,[1:ny,end-ny+1:end])=true;
        otherwise
            error('PATBox:InvalidCouplingLayerSide', ...
                'CouplingLayerSide must be xmin, xmax, ymin, ymax, or all.');
    end
    medium.sound_speed(mask)=single(cCoupling);
    medium.density(mask)=single(rhoCoupling);

    couplingAlpha=double(getCfg(cfg,'CouplingAlphaCoeff',0));
    if ~(isfinite(couplingAlpha) && couplingAlpha >= 0)
        error('PATBox:InvalidCouplingAlpha','CouplingAlphaCoeff must be nonnegative.');
    end
    if isfield(medium,'alpha_coeff') || couplingAlpha>0
        if isfield(medium,'alpha_coeff')
            medium.alpha_coeff=expandToMap(medium.alpha_coeff,kgrid.Nx,kgrid.Ny);
        else
            medium.alpha_coeff=zeros(kgrid.Nx,kgrid.Ny,'single');
            medium.alpha_power=double(getCfg(cfg,'AlphaPower',1.5));
        end
        medium.alpha_coeff(mask)=single(couplingAlpha);
    end

    couplingBonA=double(getCfg(cfg,'CouplingBonA',0));
    if ~isfinite(couplingBonA)
        error('PATBox:InvalidCouplingBonA','CouplingBonA must be finite.');
    end
    if isfield(medium,'BonA') || couplingBonA~=0
        if isfield(medium,'BonA')
            medium.BonA=expandToMap(medium.BonA,kgrid.Nx,kgrid.Ny);
        else
            medium.BonA=zeros(kgrid.Nx,kgrid.Ny,'single');
        end
        medium.BonA(mask)=single(couplingBonA);
    end
end

function field=correlatedUnitField(nx,ny,sigmaPixels)
    field=randn(nx,ny,'single');
    if exist('imgaussfilt','file')==2
        field=imgaussfilt(field,sigmaPixels,'Padding','symmetric');
    else
        radius=max(1,ceil(3*sigmaPixels));
        x=-radius:radius;
        kernel=exp(-(x.^2)/(2*sigmaPixels^2));
        kernel=kernel/sum(kernel);
        field=conv2(conv2(field,kernel,'same'),kernel.','same');
    end
    field=field-mean(field(:));
    s=std(field(:));
    if s>0, field=field./s; end
end

function value=requireMap(loaded,name,targetSize)
    if ~isfield(loaded,name)
        error('PATBox:InvalidMediumMap','MAT file must contain variable "%s".',name);
    end
    value=validateMap(loaded.(name),targetSize,name,true);
end

function value=validateMap(value,targetSize,name,mustBePositive)
    if ~(isnumeric(value) && ~isempty(value))
        error('PATBox:InvalidMediumMap','%s must be numeric.',name);
    end
    if ~isscalar(value) && ~isequal(size(value),targetSize)
        error('PATBox:InvalidMediumMapSize', ...
            '%s must be scalar or [%d x %d].',name,targetSize(1),targetSize(2));
    end
    if any(~isfinite(double(value(:))))
        error('PATBox:InvalidMediumMap','%s contains non-finite values.',name);
    end
    if mustBePositive && any(double(value(:))<=0)
        error('PATBox:InvalidMediumMap','%s must be strictly positive.',name);
    end
    if ~mustBePositive && any(double(value(:))<0) && strcmp(name,'alpha_coeff')
        error('PATBox:InvalidMediumMap','alpha_coeff cannot be negative.');
    end
    if ~isscalar(value), value=single(value); end
end

function map=expandToMap(value,nx,ny)
    if isscalar(value), map=repmat(single(value),nx,ny); else, map=single(value); end
end
function validatePositive(v,name)
    if ~(isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>0)
        error('PATBox:InvalidParameter','%s must be a finite positive scalar.',name);
    end
end
function value=getCfg(cfg,name,defaultValue)
    if isfield(cfg,name)&&~isempty(cfg.(name)),value=cfg.(name);else,value=defaultValue;end
end
