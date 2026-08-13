function [p0,meta] = ...
    makePublicationThreeLinePhantom(Nx,Ny,dx,dy)
%MAKEPUBLICATIONTHREELINEPHANTOM
% Canonical fixed three-line source for the revised PATBox
% expanded Monte Carlo study.
%
% Geometry:
%   length              = 3.0 mm
%   nominal widths      = 0.125, 0.250, 0.500 mm
%   center separation   = 1.5 mm
%
% The rectangles are sampled using subpixel area averaging so
% that the narrowest 0.125-mm structure is not represented by
% an arbitrary integer number of 50-um pixels.
%
% No random number is used here. The source is identical for
% every Monte Carlo realization.

%% ============================================================
% VALIDATION
% ============================================================

validateattributes(Nx,{'numeric'}, ...
    {'scalar','integer','positive'});

validateattributes(Ny,{'numeric'}, ...
    {'scalar','integer','positive'});

validateattributes(dx,{'numeric'}, ...
    {'scalar','positive','finite'});

validateattributes(dy,{'numeric'}, ...
    {'scalar','positive','finite'});

%% ============================================================
% PHYSICAL GRID
% ============================================================

x = ...
    ((0:Nx-1) - (Nx-1)/2) * dx;

y = ...
    ((0:Ny-1) - (Ny-1)/2) * dy;

[X,Y] = ndgrid(x,y);

%% ============================================================
% GEOMETRY
% ============================================================

lineLength_m = ...
    3.0e-3;

lineWidths_m = [ ...
    0.125e-3, ...
    0.250e-3, ...
    0.500e-3];

lineCentersY_m = [ ...
    -1.5e-3, ...
     0.0e-3, ...
    +1.5e-3];

lineCentersX_m = ...
    [0 0 0];

amplitudes = ...
    [1 1 1];

nLines = ...
    numel(lineWidths_m);

%% ============================================================
% SUBPIXEL AREA SAMPLING
%
% 8 x 8 samples / pixel gives stable geometric representation
% without requiring an enlarged acoustic grid.
% ============================================================

subsamples = 8;

offsetX = ...
    (((1:subsamples)-0.5)/subsamples - 0.5) * dx;

offsetY = ...
    (((1:subsamples)-0.5)/subsamples - 0.5) * dy;

p0 = ...
    zeros(Nx,Ny,'single');

componentMaps = ...
    zeros(Nx,Ny,nLines,'single');

for k = 1:nLines

    occupancy = ...
        zeros(Nx,Ny,'single');

    halfLength = ...
        lineLength_m/2;

    halfWidth = ...
        lineWidths_m(k)/2;

    for ix = 1:subsamples

        for iy = 1:subsamples

            Xs = ...
                X + offsetX(ix);

            Ys = ...
                Y + offsetY(iy);

            inside = ...
                abs(Xs-lineCentersX_m(k)) <= halfLength & ...
                abs(Ys-lineCentersY_m(k)) <= halfWidth;

            occupancy = ...
                occupancy + single(inside);
        end
    end

    occupancy = ...
        occupancy / ...
        single(subsamples^2);

    componentMaps(:,:,k) = ...
        single(amplitudes(k)) .* occupancy;

    p0 = ...
        max( ...
        p0, ...
        componentMaps(:,:,k));
end

%% ============================================================
% NORMALIZATION
% ============================================================

peak = ...
    max(p0(:));

assert(peak > 0, ...
    'Three-line phantom is empty.');

p0 = ...
    p0 / peak;

%% ============================================================
% SOURCE-SUPPORT AUDIT
% ============================================================

support = ...
    p0 > 0;

[Xsupport,Ysupport] = ...
    ndgrid(x,y);

supportRadius = ...
    sqrt( ...
    Xsupport(support).^2 + ...
    Ysupport(support).^2);

maxSupportRadius_m = ...
    max(supportRadius);

%% ============================================================
% METADATA
% ============================================================

meta = struct();

meta.name = ...
    'canonical_three_line_revision';

meta.profile = ...
    'subpixel-area-averaged rectangular absorbers';

meta.orientation = ...
    'parallel_to_x_axis';

meta.line_length_m = ...
    lineLength_m;

meta.nominal_widths_m = ...
    lineWidths_m;

meta.center_x_m = ...
    lineCentersX_m;

meta.center_y_m = ...
    lineCentersY_m;

meta.center_to_center_separation_m = ...
    1.5e-3;

meta.amplitudes = ...
    amplitudes;

meta.subsamples_per_dimension = ...
    subsamples;

meta.dx_m = dx;
meta.dy_m = dy;

meta.max_support_radius_m = ...
    maxSupportRadius_m;

meta.component_maps = ...
    componentMaps;

meta.randomized = false;

end