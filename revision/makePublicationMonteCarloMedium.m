function [medium,meta] = ...
    makePublicationMonteCarloMedium(Nx,Ny,dx,dy,baseSeed)
%MAKEPUBLICATIONMONTECARLOMEDIUM
% Frozen heterogeneous acoustic-medium generator for the
% expanded PATBox publication Monte Carlo study.
%
% Model
% -----
%   c(x)   = c0   + sigmaC   * Gc(x)
%   rho(x) = rho0 + sigmaRho * Grho(x)
%
% where Gc and Grho are independently generated, Gaussian-smoothed,
% zero-mean, unit-standard-deviation random fields.
%
% Frozen publication parameters
% -----------------------------
%   c0              = 1500 m/s
%   sigmaC          = 20 m/s
%   rho0            = 1000 kg/m^3
%   sigmaRho        = 15 kg/m^3
%   smoothing scale = 0.75 mm
%   alphaCoeff      = 0.75 dB/(MHz^y cm)
%   alphaPower      = 1.5
%
% Random-stream policy
% --------------------
% baseSeed identifies one paired Monte Carlo realization.
%
%   sound-speed field seed = baseSeed + 100000
%   density field seed     = baseSeed + 200000
%
% Noise uses a different deterministic offset elsewhere.
%
% No Statistics/Image Processing Toolbox is required.

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

validateattributes(baseSeed,{'numeric'}, ...
    {'scalar','integer','nonnegative'});

%% ============================================================
% FROZEN PHYSICAL PARAMETERS
% ============================================================

c0 = ...
    1500;

sigmaC = ...
    20;

rho0 = ...
    1000;

sigmaRho = ...
    15;

smoothingScale_m = ...
    0.75e-3;

alphaCoeff = ...
    0.75;

alphaPower = ...
    1.5;

%% ============================================================
% SMOOTHING SCALE
% ============================================================

pixelSize_m = ...
    min(dx,dy);

sigmaPixels = ...
    smoothingScale_m / ...
    pixelSize_m;

assert(abs(sigmaPixels-15) < 1e-10, ...
    'Expected 15-pixel smoothing scale for publication grid.');

%% ============================================================
% DETERMINISTIC RANDOM STREAMS
% ============================================================

seedSoundSpeed = ...
    baseSeed + 100000;

seedDensity = ...
    baseSeed + 200000;

%% ============================================================
% SOUND-SPEED RANDOM FIELD
% ============================================================

rng(seedSoundSpeed,'twister');

whiteC = ...
    randn(Nx,Ny);

Gc = ...
    gaussianSmoothPeriodic( ...
    whiteC, ...
    sigmaPixels);

Gc = ...
    standardizeField(Gc);

%% ============================================================
% DENSITY RANDOM FIELD
% ============================================================

rng(seedDensity,'twister');

whiteRho = ...
    randn(Nx,Ny);

Grho = ...
    gaussianSmoothPeriodic( ...
    whiteRho, ...
    sigmaPixels);

Grho = ...
    standardizeField(Grho);

%% ============================================================
% PHYSICAL MAPS
% ============================================================

cMap = ...
    c0 + ...
    sigmaC .* Gc;

rhoMap = ...
    rho0 + ...
    sigmaRho .* Grho;

%% ============================================================
% DEFENSIVE LOWER BOUNDS
%
% These should never activate for accepted realizations.
% ============================================================

cLowerBound = ...
    100;

rhoLowerBound = ...
    100;

cClipped = ...
    cMap < cLowerBound;

rhoClipped = ...
    rhoMap < rhoLowerBound;

cMap(cClipped) = ...
    cLowerBound;

rhoMap(rhoClipped) = ...
    rhoLowerBound;

%% ============================================================
% OUTPUT MEDIUM
% ============================================================

medium = struct();

medium.sound_speed = ...
    single(cMap);

medium.density = ...
    single(rhoMap);

medium.alpha_coeff = ...
    alphaCoeff;

medium.alpha_power = ...
    alphaPower;

%% ============================================================
% REALIZED STATISTICS
% ============================================================

cDouble = ...
    double(medium.sound_speed);

rhoDouble = ...
    double(medium.density);

realizedCorrelation = ...
    corr( ...
    cDouble(:), ...
    rhoDouble(:));

%% ============================================================
% METADATA
% ============================================================

meta = struct();

meta.schema_version = ...
    'revision_mc_medium_v1';

meta.base_seed = ...
    baseSeed;

meta.sound_speed_seed = ...
    seedSoundSpeed;

meta.density_seed = ...
    seedDensity;

meta.c0_mps = ...
    c0;

meta.sigma_c_target_mps = ...
    sigmaC;

meta.rho0_kgm3 = ...
    rho0;

meta.sigma_rho_target_kgm3 = ...
    sigmaRho;

meta.smoothing_scale_m = ...
    smoothingScale_m;

meta.smoothing_sigma_pixels = ...
    sigmaPixels;

meta.smoothing_boundary_condition = ...
    'periodic_fft';

meta.alpha_coeff = ...
    alphaCoeff;

meta.alpha_power = ...
    alphaPower;

meta.sound_speed_mean_mps = ...
    mean(cDouble(:));

meta.sound_speed_std_mps = ...
    std(cDouble(:));

meta.sound_speed_min_mps = ...
    min(cDouble(:));

meta.sound_speed_max_mps = ...
    max(cDouble(:));

meta.density_mean_kgm3 = ...
    mean(rhoDouble(:));

meta.density_std_kgm3 = ...
    std(rhoDouble(:));

meta.density_min_kgm3 = ...
    min(rhoDouble(:));

meta.density_max_kgm3 = ...
    max(rhoDouble(:));

meta.realized_c_rho_correlation = ...
    realizedCorrelation;

meta.sound_speed_clipped_pixels = ...
    nnz(cClipped);

meta.density_clipped_pixels = ...
    nnz(rhoClipped);

end


%% ============================================================
% LOCAL FUNCTION
% GAUSSIAN SMOOTHING USING PERIODIC FFT CONVOLUTION
% ============================================================

function out = ...
    gaussianSmoothPeriodic(in,sigmaPixels)

    [Nx,Ny] = ...
        size(in);

    %% --------------------------------------------------------
    % Periodic pixel-coordinate distances from origin
    % ---------------------------------------------------------

    ix = ...
        0:Nx-1;

    iy = ...
        0:Ny-1;

    ix = ...
        min(ix,Nx-ix);

    iy = ...
        min(iy,Ny-iy);

    [IX,IY] = ...
        ndgrid(ix,iy);

    %% --------------------------------------------------------
    % Gaussian kernel
    % ---------------------------------------------------------

    kernel = ...
        exp( ...
        -(IX.^2 + IY.^2) / ...
        (2*sigmaPixels^2));

    kernel = ...
        kernel / ...
        sum(kernel(:));

    %% --------------------------------------------------------
    % Circular convolution
    % ---------------------------------------------------------

    out = ...
        real( ...
        ifft2( ...
        fft2(double(in)) .* ...
        fft2(kernel)));

end


%% ============================================================
% LOCAL FUNCTION
% EXACT ZERO-MEAN / UNIT-SD STANDARDIZATION
% ============================================================

function out = ...
    standardizeField(in)

    out = ...
        double(in);

    out = ...
        out - ...
        mean(out(:));

    s = ...
        std(out(:));

    assert( ...
        isfinite(s) && s > 0, ...
        'Random field has zero or invalid standard deviation.');

    out = ...
        out / s;

end