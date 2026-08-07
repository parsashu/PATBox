function [x, y, t] = getKGridAxes2D(kgrid)
%GETKGRIDAXES2D Return canonical PATBox spatial axes and, when requested, time.
%
% [x,y]   = getKGridAxes2D(kgrid) validates only the spatial grid.
% [x,y,t] = getKGridAxes2D(kgrid) additionally requires a valid time grid.
%
% x indexes matrix rows, y indexes matrix columns, and t indexes RF samples.
% Spatial-only routines such as travel-time maps and aperture checks must not
% require kgrid.makeTime to have been called.

    spatialRequired = {'Nx','Ny','x_vec','y_vec'};
    spatialPresent = false(size(spatialRequired));
    for index = 1:numel(spatialRequired)
        if isstruct(kgrid)
            spatialPresent(index) = isfield(kgrid,spatialRequired{index});
        else
            spatialPresent(index) = isprop(kgrid,spatialRequired{index});
        end
    end
    if ~all(spatialPresent)
        error('PATBox:InvalidKGrid', ...
            'kgrid must contain Nx, Ny, x_vec, and y_vec.');
    end

    x = double(kgrid.x_vec(:));
    y = double(kgrid.y_vec(:));

    if numel(x) ~= double(kgrid.Nx) || numel(y) ~= double(kgrid.Ny)
        error('PATBox:GridAxisSizeMismatch', ...
            'x_vec/y_vec lengths must match Nx/Ny.');
    end
    if any(~isfinite(x)) || any(~isfinite(y)) || ...
            any(diff(x) <= 0) || any(diff(y) <= 0)
        error('PATBox:InvalidGridAxes', ...
            'x_vec and y_vec must be finite and strictly increasing.');
    end

    % A caller requesting only [x,y] is performing a spatial operation and
    % must not be forced to define Nt, dt, or t_array.
    if nargout < 3
        t = [];
        return;
    end

    timeRequired = {'dt','Nt'};
    timePresent = false(size(timeRequired));
    for index = 1:numel(timeRequired)
        if isstruct(kgrid)
            timePresent(index) = isfield(kgrid,timeRequired{index});
        else
            timePresent(index) = isprop(kgrid,timeRequired{index});
        end
    end
    if ~all(timePresent)
        error('PATBox:InvalidTimeGrid', ...
            'A requested time axis requires kgrid.dt and kgrid.Nt.');
    end

    dt = double(kgrid.dt);
    Nt = double(kgrid.Nt);
    if ~(isscalar(dt) && isfinite(dt) && dt > 0 && ...
            isscalar(Nt) && isfinite(Nt) && Nt >= 2 && Nt == round(Nt))
        error('PATBox:InvalidTimeGrid', ...
            'kgrid.dt must be positive and kgrid.Nt must be an integer >= 2.');
    end

    hasTimeArray = (isstruct(kgrid) && isfield(kgrid,'t_array')) || ...
        (~isstruct(kgrid) && isprop(kgrid,'t_array'));
    if hasTimeArray && ~isempty(kgrid.t_array)
        t = double(kgrid.t_array(:)).';
    else
        t = (0:Nt-1) .* dt;
    end

    if numel(t) ~= Nt
        error('PATBox:TimeAxisSizeMismatch', ...
            't_array length must match kgrid.Nt.');
    end
    if any(~isfinite(t)) || any(diff(t) <= 0)
        error('PATBox:InvalidTimeAxis', ...
            'The time axis must be finite and strictly increasing.');
    end

    dtObserved = median(diff(t));
    if abs(dtObserved-dt) > max(1e-12,1e-8*abs(dt))
        error('PATBox:TimeStepMismatch', ...
            'kgrid.dt is inconsistent with kgrid.t_array.');
    end
end
