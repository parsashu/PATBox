function [medium, meta] = makeRandomForwardMedium(kgrid, cfg)
%MAKERANDOMFORWARDMEDIUM
% Reproducible heterogeneous acoustic medium for PATBox revision studies.
%
% This function generates spatially smooth sound-speed inclusions and a
% mildly correlated density map. Randomness is explicitly controlled by
% cfg.randomSeed.
%
% IMPORTANT:
%   This is a FORWARD ACOUSTIC MEDIUM, not the photoacoustic source phantom.
%
% Required/typical cfg fields:
%   randomSeed
%   c0
%   soundSpeedBounds
%   heterogeneityMaxDelta
%   nInclusionsRange
%   rho0
%   densityFractionStd
%
% Optional:
%   randomizeBaselineSoundSpeed (default false)
%
% Outputs:
%   medium.sound_speed
%   medium.density
%   meta

    % ------------------------------------------------------------
    % Reproducible RNG
    % ------------------------------------------------------------
    oldState = rng;
    cleaner = onCleanup(@() rng(oldState)); %#ok<NASGU>

    rng(cfg.randomSeed, 'twister');

    % ------------------------------------------------------------
    % Coordinates
    % ------------------------------------------------------------
    x = single(kgrid.x_vec(:));
    y = single(kgrid.y_vec(:));

    [X, Y] = ndgrid(x, y);

    halfX = max(abs(x));
    halfY = max(abs(y));

    % ------------------------------------------------------------
    % Baseline sound speed
    % ------------------------------------------------------------
    if isfield(cfg, 'randomizeBaselineSoundSpeed') && ...
            cfg.randomizeBaselineSoundSpeed

        cBase = cfg.soundSpeedBounds(1) + ...
            rand * diff(cfg.soundSpeedBounds);

    else
        cBase = cfg.c0;
    end

    cMap = single(cBase * ones(kgrid.Nx, kgrid.Ny));

    % ------------------------------------------------------------
    % Smooth acoustic inclusions
    % ------------------------------------------------------------
    if isfield(cfg, 'nInclusionsRange')
        nInclusions = randi(cfg.nInclusionsRange);
    else
        nInclusions = randi([2 5]);
    end

    inclusionInfo = zeros(nInclusions, 5);

    for k = 1:nInclusions

        cx = single((2*rand - 1) * 0.45 * halfX);
        cy = single((2*rand - 1) * 0.45 * halfY);

        sx = single((0.08 + 0.16*rand) * halfX);
        sy = single((0.08 + 0.16*rand) * halfY);

        amp = single((2*rand - 1) * ...
            cfg.heterogeneityMaxDelta);

        blob = exp( ...
            -0.5 * ( ...
            (X-cx).^2 ./ sx.^2 + ...
            (Y-cy).^2 ./ sy.^2 ));

        cMap = cMap + amp .* single(blob);

        inclusionInfo(k,:) = ...
            [double(cx), double(cy), ...
             double(sx), double(sy), double(amp)];
    end

    % ------------------------------------------------------------
    % Enforce physical limits
    % ------------------------------------------------------------
    cMap = min( ...
        max(cMap, single(cfg.soundSpeedBounds(1))), ...
        single(cfg.soundSpeedBounds(2)));

    % ------------------------------------------------------------
    % Mild correlated density variation
    %
    % For the first revision experiment we intentionally correlate
    % rho with c. Later we can test independent rho heterogeneity.
    % ------------------------------------------------------------
    cDeviation = cMap - mean(cMap(:));
    cStd = std(cMap(:));

    if cStd > eps('single')

        rhoMap = single(cfg.rho0) .* ...
            (1 + single(cfg.densityFractionStd) .* ...
            cDeviation ./ cStd);

    else

        rhoMap = single(cfg.rho0) .* ...
            ones(size(cMap), 'single');

    end

    rhoMap = min( ...
        max(rhoMap, single(0.94*cfg.rho0)), ...
        single(1.06*cfg.rho0));

    % ------------------------------------------------------------
    % Output
    % ------------------------------------------------------------
    medium = struct();

    medium.sound_speed = single(cMap);
    medium.density     = single(rhoMap);

    % IMPORTANT:
    % Do NOT put attenuation into this MAT file for the sequential
    % degradation experiment. PATBox will add AlphaCoeff separately.
    %
    % This allows the SAME heterogeneity realization to be used for
    %
    %   heterogeneity only
    %
    % and
    %
    %   heterogeneity + attenuation.
    %

    % ------------------------------------------------------------
    % Metadata
    % ------------------------------------------------------------
    meta = struct();

    meta.randomSeed = cfg.randomSeed;
    meta.cBase = double(cBase);
    meta.soundSpeedMin = double(min(cMap(:)));
    meta.soundSpeedMax = double(max(cMap(:)));
    meta.soundSpeedMean = double(mean(cMap(:)));
    meta.soundSpeedStd = double(std(cMap(:)));

    meta.densityMin = double(min(rhoMap(:)));
    meta.densityMax = double(max(rhoMap(:)));
    meta.densityMean = double(mean(rhoMap(:)));
    meta.densityStd = double(std(rhoMap(:)));

    meta.nInclusions = nInclusions;
    meta.inclusions = inclusionInfo;
end