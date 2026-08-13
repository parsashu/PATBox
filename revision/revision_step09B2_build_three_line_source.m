clear;
close all;
clc;

%% ============================================================
% STEP 09B-2
% Build and freeze canonical three-line phantom
% ============================================================

patboxRoot = ...
    'C:\Users\asus\Documents\GitHub\PATBox';

revisionDir = ...
    fullfile(patboxRoot,'revision');

addpath(revisionDir,'-begin');

outDir = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step09_montecarlo');

if ~exist(outDir,'dir')
    mkdir(outDir);
end

%% ============================================================
% FIXED MONTE CARLO GRID
% ============================================================

Nx = 192;
Ny = 192;

dx = 50e-6;
dy = 50e-6;

sensorRadius_m = ...
    4.2e-3;

%% ============================================================
% GENERATE SOURCE
% ============================================================

[p0,meta] = ...
    makePublicationThreeLinePhantom( ...
    Nx,Ny,dx,dy);

%% ============================================================
% BASIC AUDIT
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 09B-2: CANONICAL THREE-LINE SOURCE\n');
fprintf('============================================================\n');

fprintf('Grid                  = %d x %d\n', ...
    Nx,Ny);

fprintf('dx / dy               = %.3f / %.3f um\n', ...
    dx*1e6,dy*1e6);

fprintf('Line length           = %.4f mm\n', ...
    meta.line_length_m*1e3);

fprintf('Nominal widths        = ');
fprintf('%.3f ',meta.nominal_widths_m*1e3);
fprintf('mm\n');

fprintf('Line-center y         = ');
fprintf('%.3f ',meta.center_y_m*1e3);
fprintf('mm\n');

fprintf('Center separation     = %.4f mm\n', ...
    meta.center_to_center_separation_m*1e3);

fprintf('Subpixel sampling     = %d x %d\n', ...
    meta.subsamples_per_dimension, ...
    meta.subsamples_per_dimension);

fprintf('Source peak           = %.6f\n', ...
    max(p0(:)));

fprintf('Nonzero support       = %d pixels\n', ...
    nnz(p0>0));

fprintf('Max support radius    = %.4f mm\n', ...
    meta.max_support_radius_m*1e3);

fprintf('Sensor radius         = %.4f mm\n', ...
    sensorRadius_m*1e3);

clearance_m = ...
    sensorRadius_m - ...
    meta.max_support_radius_m;

fprintf('Source/sensor clearance = %.4f mm\n', ...
    clearance_m*1e3);

assert(clearance_m > 1e-3, ...
    'Source is too close to the receiver array.');

assert(abs(max(p0(:))-1) < 1e-7);

%% ============================================================
% SAMPLE PROFILE AUDIT
% ============================================================

x = ...
    ((0:Nx-1) - (Nx-1)/2)*dx;

y = ...
    ((0:Ny-1) - (Ny-1)/2)*dy;

[~,ixCenter] = ...
    min(abs(x));

fprintf('\n');
fprintf('TRANSVERSE PROFILE AUDIT\n');
fprintf('------------------------------------------------------------\n');

measuredWidths_m = ...
    nan(1,3);

for k = 1:3

    yc = ...
        meta.center_y_m(k);

    local = ...
        abs(y-yc) < 0.65e-3;

    yy = ...
        y(local);

    profile = ...
        double(p0(ixCenter,local));

    measuredWidths_m(k) = ...
        estimateFWHM1D(yy,profile);

    fprintf( ...
        ['Line %d | nominal %.4f mm | ' ...
         'sampled FWHM %.4f mm\n'], ...
        k, ...
        meta.nominal_widths_m(k)*1e3, ...
        measuredWidths_m(k)*1e3);
end

widthError_m = ...
    abs( ...
    measuredWidths_m - ...
    meta.nominal_widths_m);

fprintf('\nMaximum sampled FWHM error = %.4f um\n', ...
    max(widthError_m)*1e6);

% With 50-um pixels and subpixel averaging, require the
% sampled half-maximum width to be accurate within one pixel.
assert( ...
    all(widthError_m <= dx + 1e-12), ...
    'Rasterized width audit failed.');

%% ============================================================
% LONGITUDINAL LENGTH AUDIT
% ============================================================

fprintf('\n');
fprintf('LONGITUDINAL PROFILE AUDIT\n');
fprintf('------------------------------------------------------------\n');

measuredLengths_m = ...
    nan(1,3);

for k = 1:3

    [~,iy] = ...
        min(abs(y-meta.center_y_m(k)));

    profile = ...
        double(p0(:,iy)).';

    measuredLengths_m(k) = ...
        estimateFWHM1D(x,profile);

    fprintf( ...
        'Line %d | nominal %.4f mm | sampled %.4f mm\n', ...
        k, ...
        meta.line_length_m*1e3, ...
        measuredLengths_m(k)*1e3);
end

assert( ...
    all( ...
    abs(measuredLengths_m-meta.line_length_m) ...
    <= dx + 1e-12), ...
    'Rasterized line-length audit failed.');

%% ============================================================
% SAVE FROZEN SOURCE
% ============================================================

sourceFile = fullfile( ...
    outDir, ...
    'canonical_three_line_192x192.mat');

save( ...
    sourceFile, ...
    'p0', ...
    'meta', ...
    '-v7.3');

%% ============================================================
% FIGURE
% ============================================================

fig = figure( ...
    'Color','w', ...
    'Position',[100 100 1050 700]);

imagesc( ...
    y*1e3, ...
    x*1e3, ...
    p0);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');

title( ...
    'Canonical three-line Monte Carlo source');

colorbar;

hold on;

for k = 1:3

    text( ...
        meta.center_y_m(k)*1e3, ...
        -1.72, ...
        sprintf('w = %.3f mm', ...
        meta.nominal_widths_m(k)*1e3), ...
        'HorizontalAlignment','center', ...
        'FontWeight','bold');
end

exportgraphics( ...
    fig, ...
    fullfile( ...
    outDir, ...
    'canonical_three_line_source.png'), ...
    'Resolution',300);

%% ============================================================
% FINAL
% ============================================================

fprintf('\nFrozen source:\n%s\n', ...
    sourceFile);

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 09B-2: PASS\n');
fprintf('============================================================\n');


%% ============================================================
% LOCAL FUNCTION
% ============================================================

function width = estimateFWHM1D(coord,profile)

coord = double(coord(:));
profile = double(profile(:));

if isempty(profile) || max(profile)<=0
    width = NaN;
    return;
end

profile = ...
    profile/max(profile);

above = ...
    profile >= 0.5;

idx = ...
    find(above);

if isempty(idx)
    width = NaN;
    return;
end

iL = idx(1);
iR = idx(end);

%% left crossing

if iL > 1

    x1 = coord(iL-1);
    x2 = coord(iL);

    y1 = profile(iL-1);
    y2 = profile(iL);

    left = ...
        x1 + ...
        (0.5-y1)*(x2-x1)/(y2-y1+eps);

else
    left = coord(iL);
end

%% right crossing

if iR < numel(profile)

    x1 = coord(iR);
    x2 = coord(iR+1);

    y1 = profile(iR);
    y2 = profile(iR+1);

    right = ...
        x1 + ...
        (0.5-y1)*(x2-x1)/(y2-y1+eps);

else
    right = coord(iR);
end

width = ...
    right-left;

end