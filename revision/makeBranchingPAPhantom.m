function [p0, meta] = makeBranchingPAPhantom(kgrid, cfg)
%MAKEBRANCHINGPAPHANTOM
% Reproducible branching vascular-like photoacoustic source phantom.
%
% p0 is an initial-pressure map, not an acoustic medium.
%
% No additional toolbox is required.

    oldState = rng;
    cleaner = onCleanup(@() rng(oldState)); %#ok<NASGU>

    rng(cfg.randomSeed, 'twister');

    x = single(kgrid.x_vec(:));
    y = single(kgrid.y_vec(:));

    [X,Y] = ndgrid(x,y);

    p0 = zeros(kgrid.Nx, kgrid.Ny, 'single');

    halfX = max(abs(x));
    halfY = max(abs(y));

    safeRadius = 0.62 * min(halfX, halfY);

    nTrees       = cfg.nTrees;
    maxDepth     = cfg.maxDepth;
    trunkLength  = cfg.trunkLength;
    trunkWidth   = cfg.trunkWidth;

    segmentCount = 0;

    for tree = 1:nTrees

        % Root position
        rootR = 0.12 * safeRadius * sqrt(rand);
        rootPhi = 2*pi*rand;

        p1 = [ ...
            rootR*cos(rootPhi), ...
            rootR*sin(rootPhi)];

        theta0 = 2*pi*rand;

        queue = {
            p1, ...
            theta0, ...
            trunkLength*(0.85 + 0.30*rand), ...
            trunkWidth*(0.85 + 0.30*rand), ...
            1, ...
            0.8 + 0.4*rand ...
            };

        while ~isempty(queue)

            node = queue(1,:);
            queue(1,:) = [];

            startPoint = node{1};
            theta      = node{2};
            segLength  = node{3};
            segWidth   = node{4};
            depth      = node{5};
            amplitude  = node{6};

            endPoint = startPoint + ...
                segLength .* [cos(theta), sin(theta)];

            % Keep source comfortably inside receiver circle
            rEnd = hypot(endPoint(1), endPoint(2));

            if rEnd > safeRadius
                endPoint = endPoint .* ...
                    (safeRadius / rEnd);
            end

            % ----------------------------------------------------
            % Distance from every pixel to current line segment
            % ----------------------------------------------------
            vx = endPoint(1) - startPoint(1);
            vy = endPoint(2) - startPoint(2);

            denom = vx^2 + vy^2 + eps;

            t = ((X-startPoint(1))*vx + ...
                 (Y-startPoint(2))*vy) ./ denom;

            t = min(max(t,0),1);

            closestX = startPoint(1) + t*vx;
            closestY = startPoint(2) + t*vy;

            d2 = (X-closestX).^2 + ...
                 (Y-closestY).^2;

            % segWidth is interpreted approximately as FWHM
            sigma = segWidth / 2.355;

            vessel = exp( ...
                -0.5 * d2 ./ (sigma^2 + eps));

            p0 = max( ...
                p0, ...
                single(amplitude) .* single(vessel));

            segmentCount = segmentCount + 1;

            % ----------------------------------------------------
            % Branch
            % ----------------------------------------------------
            if depth < maxDepth

                childLength = segLength * ...
                    (0.68 + 0.12*rand);

                childWidth = max( ...
                    cfg.minVesselWidth, ...
                    segWidth * (0.68 + 0.10*rand));

                branchAngle = deg2rad( ...
                    cfg.branchAngleDeg * ...
                    (0.75 + 0.50*rand));

                jitter1 = deg2rad( ...
                    cfg.angleJitterDeg*(2*rand-1));

                jitter2 = deg2rad( ...
                    cfg.angleJitterDeg*(2*rand-1));

                amp1 = amplitude * ...
                    (0.72 + 0.20*rand);

                amp2 = amplitude * ...
                    (0.72 + 0.20*rand);

                queue(end+1,:) = { ...
                    endPoint, ...
                    theta + branchAngle + jitter1, ...
                    childLength, ...
                    childWidth, ...
                    depth+1, ...
                    amp1};

                queue(end+1,:) = { ...
                    endPoint, ...
                    theta - branchAngle + jitter2, ...
                    childLength, ...
                    childWidth, ...
                    depth+1, ...
                    amp2};
            end
        end
    end

    % ------------------------------------------------------------
    % Normalize to physically traceable peak pressure
    % ------------------------------------------------------------
    peak = max(p0(:));

    if peak > 0
        p0 = p0 ./ peak;
    end

    p0 = p0 .* single(cfg.peakPressurePa);

    % ------------------------------------------------------------
    % Metadata
    % ------------------------------------------------------------
    meta = struct();

    meta.randomSeed = cfg.randomSeed;
    meta.nTrees = nTrees;
    meta.maxDepth = maxDepth;
    meta.segmentCount = segmentCount;
    meta.peakPressurePa = cfg.peakPressurePa;
    meta.safeRadius_m = double(safeRadius);
end