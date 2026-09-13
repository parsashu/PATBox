function [medium, meta] = makeRandomForwardMedium(kgrid, cfg)
%MAKERANDOMFORWARDMEDIUM
% Reproducible smooth heterogeneous acoustic medium.
%
% Generates independent smooth inclusion-like random fields for
% sound speed and density.
%
% Recommended publication configuration:
%   c0             = 1500 m/s
%   soundSpeedStd  = 20 m/s
%   rho0           = 1000 kg/m^3
%   densityStd     = 15 kg/m^3

    oldState = rng;
    cleaner = onCleanup(@() rng(oldState)); %#ok<NASGU>
    rng(cfg.randomSeed, 'twister');

    x = single(kgrid.x_vec(:));
    y = single(kgrid.y_vec(:));
    [X,Y] = ndgrid(x,y);

    halfX = max(abs(x));
    halfY = max(abs(y));

    % ============================================================
    % SOUND-SPEED PERTURBATION
    % ============================================================
    deltaC = makeBlobField( ...
        X, Y, halfX, halfY, cfg.nInclusionsRange);

    deltaC = deltaC - mean(deltaC(:));

    s = std(deltaC(:));
    if s > eps('single')
        deltaC = deltaC ./ s;
    end

    cMap = single(cfg.c0) + ...
        single(cfg.soundSpeedStd) .* deltaC;

    if isfield(cfg,'soundSpeedBounds') && ...
            ~isempty(cfg.soundSpeedBounds)

        cMap = min( ...
            max(cMap, single(cfg.soundSpeedBounds(1))), ...
            single(cfg.soundSpeedBounds(2)));
    end

    % ============================================================
    % INDEPENDENT DENSITY PERTURBATION
    % ============================================================
    deltaRho = makeBlobField( ...
        X, Y, halfX, halfY, cfg.nInclusionsRange);

    deltaRho = deltaRho - mean(deltaRho(:));

    s = std(deltaRho(:));
    if s > eps('single')
        deltaRho = deltaRho ./ s;
    end

    rhoMap = single(cfg.rho0) + ...
        single(cfg.densityStd) .* deltaRho;

    if isfield(cfg,'densityBounds') && ...
            ~isempty(cfg.densityBounds)

        rhoMap = min( ...
            max(rhoMap, single(cfg.densityBounds(1))), ...
            single(cfg.densityBounds(2)));
    end

    % ============================================================
    % OUTPUT
    % ============================================================
    medium = struct();

    medium.sound_speed = single(cMap);
    medium.density     = single(rhoMap);

    % Do NOT include attenuation here.
    % Attenuation will be activated separately in the sequential
    % physics experiment.

    % ============================================================
    % METADATA
    % ============================================================
    meta = struct();

    meta.randomSeed = cfg.randomSeed;

    meta.soundSpeedMean = double(mean(cMap(:)));
    meta.soundSpeedStd  = double(std(cMap(:)));
    meta.soundSpeedMin  = double(min(cMap(:)));
    meta.soundSpeedMax  = double(max(cMap(:)));

    meta.densityMean = double(mean(rhoMap(:)));
    meta.densityStd  = double(std(rhoMap(:)));
    meta.densityMin  = double(min(rhoMap(:)));
    meta.densityMax  = double(max(rhoMap(:)));

    meta.soundDensityCorrelation = corr( ...
        double(cMap(:)), ...
        double(rhoMap(:)));
end


function field = makeBlobField(X,Y,halfX,halfY,nRange)

    n = randi(nRange);

    field = zeros(size(X),'single');

    for k = 1:n

        cx = single((2*rand-1)*0.48*halfX);
        cy = single((2*rand-1)*0.48*halfY);

        sx = single((0.07 + 0.18*rand)*halfX);
        sy = single((0.07 + 0.18*rand)*halfY);

        theta = single(2*pi*rand);

        amp = single(randn);

        Xc = X-cx;
        Yc = Y-cy;

        Xr =  cos(theta).*Xc + sin(theta).*Yc;
        Yr = -sin(theta).*Xc + cos(theta).*Yc;

        blob = exp( ...
            -0.5*( ...
            Xr.^2./sx.^2 + ...
            Yr.^2./sy.^2 ));

        field = field + amp.*single(blob);
    end
end