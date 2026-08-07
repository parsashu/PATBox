function [source, meta] = buildInitialPressure2D(inputPath, targetSize, cfg)
%BUILDINITIALPRESSURE2D Build a traceable initial-pressure source map.
%
% SourceModel:
%   normalized_image     image contrast scaled by P0Scale (legacy/default)
%   initial_pressure_mat MAT variable in pascals, without independent scaling
%   absorption_fluence   p0 = Gruneisen .* mu_a .* fluence
%
% For absorption_fluence, mu_a is in 1/m and fluence is in J/m^2, so the
% resulting absorbed energy density and initial pressure are in Pa.

    model=lower(strrep(char(getCfg(cfg,'SourceModel','normalized_image')),'-','_'));
    path=char(getCfg(cfg,'SourceMapPath',''));
    if isempty(path), path=char(inputPath); else, path=resolvePatboxPath(path); end
    scale=double(getCfg(cfg,'SourceScale',1));
    if ~(isscalar(scale)&&isfinite(scale)&&scale>0)
        error('PATBox:InvalidSourceScale','SourceScale must be finite and positive.');
    end

    switch model
        case {'normalized_image','image','legacy_image'}
            if ~isfile(path), error('PATBox:ImageNotFound','Could not find image: %s',path); end
            p0=loadImage(path);
            p0=resize(p0,targetSize);
            if logical(getCfg(cfg,'SmoothInitialPressure',true))
                p0=smooth(p0,true);
            end
            p0=single(p0);
            p0=p0-min(p0(:));
            peak=max(p0(:));
            if peak>0, p0=p0./peak; end
            p0=p0.*single(getCfg(cfg,'P0Scale',2)).*single(scale);
            units='user-scaled pressure (treated as Pa by k-Wave)';
            quantitative=false;
            variables=struct('image_path',path);

        case {'initial_pressure_mat','pressure_mat','p0_mat'}
            loaded=loadRequiredMat(path);
            name=char(getCfg(cfg,'InitialPressureVariable','p0'));
            p0=selectNumericMap(loaded,name,{'p0','initial_pressure','pressure'},targetSize);
            p0=single(p0).*single(scale);
            units='Pa';
            quantitative=true;
            variables=struct('source_path',path,'initial_pressure_variable',name);

        case {'absorption_fluence','optical_maps','thermoelastic'}
            loaded=loadRequiredMat(path);
            muName=char(getCfg(cfg,'AbsorptionVariable','mu_a'));
            fluenceName=char(getCfg(cfg,'FluenceVariable','fluence'));
            mu=selectNumericMap(loaded,muName,{'mu_a','absorption','absorption_coefficient'},targetSize);
            fluence=selectNumericMap(loaded,fluenceName,{'fluence','optical_fluence','phi'},targetSize);
            if any(mu(:)<0)||any(fluence(:)<0)
                error('PATBox:InvalidOpticalSource', ...
                    'Absorption and fluence maps must be nonnegative.');
            end
            if isfield(loaded,'gruneisen')
                gamma=loaded.gruneisen;
            elseif isfield(loaded,'Gamma')
                gamma=loaded.Gamma;
            else
                gamma=getCfg(cfg,'Gruneisen',0.12);
            end
            gamma=expandPhysicalMap(gamma,targetSize,'Gruneisen');
            if any(gamma(:)<0)||any(~isfinite(gamma(:)))
                error('PATBox:InvalidGruneisen','Gruneisen must be finite and nonnegative.');
            end
            p0=single(gamma).*single(mu).*single(fluence).*single(scale);
            units='Pa';
            quantitative=true;
            variables=struct('source_path',path,'absorption_variable',muName, ...
                'fluence_variable',fluenceName,'absorption_units','1/m', ...
                'fluence_units','J/m^2');

        otherwise
            error('PATBox:InvalidSourceModel','Unknown SourceModel: %s',model);
    end

    if any(~isfinite(double(p0(:))))
        error('PATBox:InvalidInitialPressure','Initial pressure contains non-finite values.');
    end
    if ~logical(getCfg(cfg,'AllowNegativeInitialPressure',false)) && any(p0(:)<0)
        error('PATBox:NegativeInitialPressure', ...
            'Initial pressure is negative. Set AllowNegativeInitialPressure=true only intentionally.');
    end
    if ~any(abs(p0(:))>0)
        warning('PATBox:ZeroInitialPressure','The initial-pressure map is identically zero.');
    end
    source=struct('p0',single(p0));
    meta=struct('model',model,'units',units,'quantitative_units',quantitative, ...
        'source_scale',scale,'minimum',double(min(p0(:))), ...
        'maximum',double(max(p0(:))),'variables',variables);
end

function loaded=loadRequiredMat(path)
    if ~isfile(path), error('PATBox:SourceMapNotFound','Could not find source map: %s',path); end
    [~,~,ext]=fileparts(path);
    if ~strcmpi(ext,'.mat')
        error('PATBox:SourceMapMustBeMat','Physical source models require a MAT file.');
    end
    loaded=load(path);
end

function map=selectNumericMap(loaded,requested,candidates,targetSize)
    names=[{requested},candidates];
    map=[];
    for i=1:numel(names)
        name=names{i};
        if ~isempty(name)&&isfield(loaded,name)&&isnumeric(loaded.(name))
            map=loaded.(name);
            break;
        end
    end
    if isempty(map)
        error('PATBox:MissingSourceVariable', ...
            'No requested source-map variable was found in the MAT file.');
    end
    map=expandPhysicalMap(map,targetSize,requested);
end

function map=expandPhysicalMap(value,targetSize,name)
    if ~(isnumeric(value)&&~isempty(value)&&all(isfinite(double(value(:)))))
        error('PATBox:InvalidSourceMap','%s must be finite and numeric.',name);
    end
    if isscalar(value)
        map=repmat(single(value),targetSize);
    elseif isequal(size(value),targetSize)
        map=single(value);
    else
        error('PATBox:SourceMapSizeMismatch', ...
            '%s must be scalar or [%d x %d]; physical maps are not silently resized.', ...
            name,targetSize(1),targetSize(2));
    end
end

function value=getCfg(cfg,name,defaultValue)
    if isfield(cfg,name)&&~isempty(cfg.(name)),value=cfg.(name);else,value=defaultValue;end
end
