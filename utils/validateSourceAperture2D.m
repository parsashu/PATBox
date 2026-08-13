function report = validateSourceAperture2D(sourceP0, geometry, kgrid, varargin)
%VALIDATESOURCEAPERTURE2D Verify source support relative to receiver aperture.
%
% For a closed circular aperture, all significant source pixels must lie
% inside the receiver circle. This catches configurations where an absolute
% SensorMargin accidentally places receivers inside the phantom.

    p=inputParser;
    addParameter(p,'SupportThreshold',1e-3,@(x)isnumeric(x)&&isscalar(x)&&x>=0&&x<1);
    addParameter(p,'RequireInside',true,@(x)(islogical(x)||isnumeric(x))&&isscalar(x));
    parse(p,varargin{:});

    [x,y]=getKGridAxes2D(kgrid);
    if ~isequal(size(sourceP0),[numel(x),numel(y)])
        error('PATBox:SourceGridSizeMismatch', ...
            'source.p0 size must match the reconstruction grid.');
    end

    peak=max(abs(double(sourceP0(:))));
    if peak<=0
        report=struct('checked',false,'inside',true,'reason','zero_source');
        return;
    end
    support=abs(double(sourceP0))>=double(p.Results.SupportThreshold)*peak;
    [ix,iy]=find(support);
    sourcePoints=[x(ix),y(iy)];

    type='unknown';
    if isfield(geometry,'type'),type=lower(char(geometry.type));end
    positions=readPositions(geometry);
    centre=mean(positions,1);

    report=struct('checked',false,'inside',true,'type',type, ...
        'support_pixel_count',size(sourcePoints,1), ...
        'support_threshold',double(p.Results.SupportThreshold));

    switch type
        case 'circular'
            receiverRadius=median(hypot(positions(:,1)-centre(1),positions(:,2)-centre(2)));
            sourceRadius=hypot(sourcePoints(:,1)-centre(1),sourcePoints(:,2)-centre(2));
            maximumSourceRadius=max(sourceRadius);
            clearance=receiverRadius-maximumSourceRadius;
            inside=clearance>0;
            report.checked=true;
            report.inside=inside;
            report.receiver_radius_m=receiverRadius;
            report.maximum_source_radius_m=maximumSourceRadius;
            report.minimum_clearance_m=clearance;
            if ~inside
                message=sprintf(['Significant source support extends %.3g mm beyond the circular ' ...
                    'receiver aperture. Increase SensorRadius or reduce SensorMargin.'], ...
                    -clearance*1e3);
                if logical(p.Results.RequireInside)
                    error('PATBox:SourceOutsideClosedAperture','%s',message);
                else
                    warning('PATBox:SourceOutsideClosedAperture','%s',message);
                end
            end

        case 'square'
            xmin=min(positions(:,1)); xmax=max(positions(:,1));
            ymin=min(positions(:,2)); ymax=max(positions(:,2));
            inside=all(sourcePoints(:,1)>xmin & sourcePoints(:,1)<xmax & ...
                       sourcePoints(:,2)>ymin & sourcePoints(:,2)<ymax);
            report.checked=true;
            report.inside=inside;
            report.bounds_m=[xmin,xmax,ymin,ymax];
            if ~inside
                message='Significant source support extends outside the square receiver aperture.';
                if logical(p.Results.RequireInside)
                    error('PATBox:SourceOutsideClosedAperture','%s',message);
                else
                    warning('PATBox:SourceOutsideClosedAperture','%s',message);
                end
            end

        otherwise
            report.reason='aperture_not_closed';
    end
end

function positions=readPositions(geometry)
    if isfield(geometry,'positions')
        positions=double(geometry.positions);
    elseif isfield(geometry,'element_positions')
        positions=double(geometry.element_positions);
    else
        error('PATBox:MissingSensorPositions','Geometry has no explicit positions.');
    end
end
