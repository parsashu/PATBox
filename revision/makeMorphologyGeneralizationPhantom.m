function [p0, components, meta] = ...
    makeMorphologyGeneralizationPhantom(kgrid,cfg)
%MAKEMORPHOLOGYGENERALIZATIONPHANTOM
%
% Controlled morphology suite for PATBox reviewer-response experiments.
%
% Families:
%   sparse
%   dense
%   cluttered
%   fluence
%
% Important design:
%   dense, cluttered, and fluence use EXACTLY the same underlying
%   vascular geometry for a given randomSeed.
%
% cluttered:
%   p0 = vessel + nuisance absorbers
%
% fluence:
%   p0 = vessel .* Phi
%
% Phi is a controlled depth-dependent fluence surrogate, NOT a full
% optical-transport solution.
%
% Outputs:
%   p0
%
%   components.vessel_map
%   components.clutter_map
%   components.fluence_map
%   components.vessel_mask
%   components.clutter_mask
%
%   meta.segments
%   meta.branch_points_xy_m
%   meta.terminal_points_xy_m
%   ...

    %% =========================================================
    % RNG
    % ==========================================================

    oldState = rng;
    cleaner = onCleanup(@() rng(oldState)); %#ok<NASGU>

    rng(cfg.randomSeed,'twister');

    %% =========================================================
    % GRID
    % ==========================================================

    x = single(kgrid.x_vec(:));
    y = single(kgrid.y_vec(:));

    [X,Y] = ndgrid(x,y);

    halfX = max(abs(x));
    halfY = max(abs(y));

    safeRadius = ...
        single(0.58 * min(halfX,halfY));

    family = lower(string(cfg.family));

    %% =========================================================
    % MORPHOLOGY PROFILE
    % ==========================================================

    switch family

        case "sparse"

            profile.nTrees = 1;
            profile.maxDepth = 4;

            profile.trunkLength = 1.35e-3;
            profile.trunkWidth = 0.30e-3;

            profile.minVesselWidth = 0.080e-3;

            profile.branchAngleDeg = 31;
            profile.angleJitterDeg = 8;

            profile.lengthDecayRange = [0.66 0.78];
            profile.widthDecayRange  = [0.68 0.80];
            profile.amplitudeDecayRange = [0.76 0.92];

        case {"dense","cluttered","fluence"}

            % IMPORTANT:
            % same profile and same seed -> same vascular geometry
            profile.nTrees = 2;
            profile.maxDepth = 5;

            profile.trunkLength = 1.20e-3;
            profile.trunkWidth = 0.32e-3;

            profile.minVesselWidth = 0.075e-3;

            profile.branchAngleDeg = 28;
            profile.angleJitterDeg = 10;

            profile.lengthDecayRange = [0.66 0.79];
            profile.widthDecayRange  = [0.68 0.81];
            profile.amplitudeDecayRange = [0.72 0.90];

        otherwise

            error( ...
                'Unknown morphology family: %s', ...
                family);
    end

    %% =========================================================
    % GENERATE VASCULAR GEOMETRY
    % ==========================================================

    vesselMap = ...
        zeros(kgrid.Nx,kgrid.Ny,'single');

    segments = struct( ...
        'tree',{}, ...
        'depth',{}, ...
        'x1_m',{}, ...
        'y1_m',{}, ...
        'x2_m',{}, ...
        'y2_m',{}, ...
        'width_m',{}, ...
        'amplitude',{}, ...
        'is_terminal',{});

    branchPoints = zeros(0,2);
    terminalPoints = zeros(0,2);

    segmentCount = 0;

    for tree = 1:profile.nTrees

        %% -----------------------------------------------------
        % Tree root
        % ------------------------------------------------------

        rootR = ...
            0.12 * double(safeRadius) * sqrt(rand);

        rootPhi = ...
            2*pi*rand;

        root = [ ...
            rootR*cos(rootPhi), ...
            rootR*sin(rootPhi)];

        theta0 = 2*pi*rand;

        rootNode = struct();

        rootNode.start = root;
        rootNode.theta = theta0;

        rootNode.length = ...
            profile.trunkLength * ...
            (0.90 + 0.20*rand);

        rootNode.width = ...
            profile.trunkWidth * ...
            (0.90 + 0.20*rand);

        rootNode.depth = 1;

        rootNode.amplitude = ...
            0.90 + 0.10*rand;

        queue = rootNode;

        %% -----------------------------------------------------
        % Breadth-first tree generation
        % ------------------------------------------------------

        while ~isempty(queue)

            node = queue(1);
            queue(1) = [];

            p1 = node.start;

            p2Requested = ...
                p1 + ...
                node.length .* ...
                [cos(node.theta),sin(node.theta)];

            rRequested = ...
                hypot( ...
                p2Requested(1), ...
                p2Requested(2));

            clipped = false;

            if rRequested > double(safeRadius)

                p2 = ...
                    p2Requested .* ...
                    (double(safeRadius) / ...
                    rRequested);

                clipped = true;

            else

                p2 = p2Requested;
            end

            %% -------------------------------------------------
            % Render Gaussian vessel segment
            % --------------------------------------------------

            vessel = renderSegment( ...
                X,Y, ...
                p1,p2, ...
                node.width);

            vesselMap = ...
                max( ...
                vesselMap, ...
                single(node.amplitude) .* vessel);

            %% -------------------------------------------------
            % Decide whether segment branches
            % --------------------------------------------------

            canBranch = ...
                node.depth < profile.maxDepth && ...
                ~clipped;

            segmentCount = ...
                segmentCount + 1;

            segments(segmentCount).tree = ...
                tree;

            segments(segmentCount).depth = ...
                node.depth;

            segments(segmentCount).x1_m = ...
                p1(1);

            segments(segmentCount).y1_m = ...
                p1(2);

            segments(segmentCount).x2_m = ...
                p2(1);

            segments(segmentCount).y2_m = ...
                p2(2);

            segments(segmentCount).width_m = ...
                node.width;

            segments(segmentCount).amplitude = ...
                node.amplitude;

            segments(segmentCount).is_terminal = ...
                ~canBranch;

            %% -------------------------------------------------
            % Branch / terminal metadata
            % --------------------------------------------------

            if canBranch

                branchPoints(end+1,:) = p2; %#ok<AGROW>

                branchAngle = ...
                    deg2rad( ...
                    profile.branchAngleDeg * ...
                    (0.78 + 0.44*rand));

                jitter1 = ...
                    deg2rad( ...
                    profile.angleJitterDeg * ...
                    (2*rand-1));

                jitter2 = ...
                    deg2rad( ...
                    profile.angleJitterDeg * ...
                    (2*rand-1));

                childLength1 = ...
                    node.length * ...
                    randomRange( ...
                    profile.lengthDecayRange);

                childLength2 = ...
                    node.length * ...
                    randomRange( ...
                    profile.lengthDecayRange);

                childWidth1 = ...
                    max( ...
                    profile.minVesselWidth, ...
                    node.width * ...
                    randomRange( ...
                    profile.widthDecayRange));

                childWidth2 = ...
                    max( ...
                    profile.minVesselWidth, ...
                    node.width * ...
                    randomRange( ...
                    profile.widthDecayRange));

                amp1 = ...
                    node.amplitude * ...
                    randomRange( ...
                    profile.amplitudeDecayRange);

                amp2 = ...
                    node.amplitude * ...
                    randomRange( ...
                    profile.amplitudeDecayRange);

                child1 = struct();

                child1.start = p2;
                child1.theta = ...
                    node.theta + ...
                    branchAngle + ...
                    jitter1;

                child1.length = childLength1;
                child1.width = childWidth1;
                child1.depth = node.depth+1;
                child1.amplitude = amp1;

                child2 = struct();

                child2.start = p2;
                child2.theta = ...
                    node.theta - ...
                    branchAngle + ...
                    jitter2;

                child2.length = childLength2;
                child2.width = childWidth2;
                child2.depth = node.depth+1;
                child2.amplitude = amp2;

                queue(end+1) = child1; %#ok<AGROW>
                queue(end+1) = child2; %#ok<AGROW>

            else

                terminalPoints(end+1,:) = p2; %#ok<AGROW>
            end
        end
    end

    %% =========================================================
    % NORMALIZE UNMODULATED VASCULAR MAP
    % ==========================================================

    vesselPeak = max(vesselMap(:));

    assert(vesselPeak > 0, ...
        'Generated vessel map is empty.');

    vesselMap = ...
        vesselMap ./ vesselPeak;

    %% =========================================================
    % CLUTTER
    % ==========================================================

    clutterMap = ...
        zeros(size(vesselMap),'single');

    if family == "cluttered"

        % Separate deterministic clutter RNG.
        rng(cfg.randomSeed + 100000,'twister');

        if isfield(cfg,'nClutterRange')
            nClutter = randi(cfg.nClutterRange);
        else
            nClutter = randi([14 22]);
        end

        for k = 1:nClutter

            r = ...
                0.80 * double(safeRadius) * ...
                sqrt(rand);

            phi = ...
                2*pi*rand;

            cx = r*cos(phi);
            cy = r*sin(phi);

            sx = ...
                (0.055 + 0.100*rand)*1e-3;

            sy = ...
                (0.055 + 0.100*rand)*1e-3;

            theta = ...
                2*pi*rand;

            amplitude = ...
                0.05 + 0.22*rand;

            Xc = double(X)-cx;
            Yc = double(Y)-cy;

            Xr = ...
                cos(theta).*Xc + ...
                sin(theta).*Yc;

            Yr = ...
               -sin(theta).*Xc + ...
                cos(theta).*Yc;

            blob = exp( ...
                -0.5*( ...
                Xr.^2./sx.^2 + ...
                Yr.^2./sy.^2));

            clutterMap = ...
                max( ...
                clutterMap, ...
                single(amplitude.*blob));
        end
    end

    %% =========================================================
    % FLUENCE SURROGATE
    %
    % Illumination is assumed from the negative-y side.
    %
    % Phi(y) =
    %   Phi_floor +
    %   (1-Phi_floor) exp(-mu_eff * depth)
    %
    % This is NOT a coupled optical-transport simulation.
    % ==========================================================

    fluenceMap = ...
        ones(size(vesselMap),'single');

    if family == "fluence"

        if isfield(cfg,'fluenceMuEff_mmInv')
            muEff_mmInv = cfg.fluenceMuEff_mmInv;
        else
            muEff_mmInv = 0.25;
        end

        if isfield(cfg,'fluenceFloor')
            fluenceFloor = cfg.fluenceFloor;
        else
            fluenceFloor = 0.25;
        end

        muEff_mInv = ...
            muEff_mmInv * 1e3;

        depth = ...
            double(Y) - min(double(y));

        fluenceMap = single( ...
            fluenceFloor + ...
            (1-fluenceFloor) .* ...
            exp(-muEff_mInv .* depth));

        fluenceMap = ...
            fluenceMap ./ ...
            max(fluenceMap(:));
    end

    %% =========================================================
    % BUILD INITIAL PRESSURE
    % ==========================================================

    switch family

        case {"sparse","dense"}

            p0Raw = vesselMap;

        case "cluttered"

            p0Raw = ...
                vesselMap + ...
                clutterMap;

        case "fluence"

            p0Raw = ...
                vesselMap .* ...
                fluenceMap;
    end

    %% =========================================================
    % NORMALIZE GLOBAL PEAK
    % ==========================================================

    rawPeak = max(p0Raw(:));

    assert(rawPeak > 0);

    p0 = ...
        p0Raw ./ rawPeak;

    if isfield(cfg,'peakPressurePa')
        p0 = ...
            p0 .* ...
            single(cfg.peakPressurePa);
    end

    %% =========================================================
    % LABEL MASKS
    % ==========================================================

    vesselMask = ...
        vesselMap >= 0.08;

    if any(clutterMap(:)>0)

        clutterMask = ...
            clutterMap >= ...
            0.15*max(clutterMap(:));

    else

        clutterMask = ...
            false(size(clutterMap));
    end

    %% =========================================================
    % OUTPUT COMPONENTS
    % ==========================================================

    components = struct();

    components.vessel_map = ...
        vesselMap;

    components.clutter_map = ...
        clutterMap;

    components.fluence_map = ...
        fluenceMap;

    components.vessel_mask = ...
        vesselMask;

    components.clutter_mask = ...
        clutterMask;

    %% =========================================================
    % METADATA
    % ==========================================================

    meta = struct();

    meta.family = char(family);
    meta.randomSeed = cfg.randomSeed;

    meta.segmentCount = ...
        numel(segments);

    meta.branchPointCount = ...
        size(branchPoints,1);

    meta.terminalPointCount = ...
        size(terminalPoints,1);

    meta.segments = ...
        segments;

    meta.branch_points_xy_m = ...
        branchPoints;

    meta.terminal_points_xy_m = ...
        terminalPoints;

    meta.safeRadius_m = ...
        double(safeRadius);

    meta.peakPressurePa = ...
        double(max(p0(:)));

    meta.vesselSupportFraction = ...
        mean(vesselMask(:));

    meta.clutterSupportFraction = ...
        mean(clutterMask(:));

    vesselFluenceValues = ...
        double(fluenceMap(vesselMask));

    meta.fluenceMinOnVessels = ...
        min(vesselFluenceValues);

    meta.fluenceMeanOnVessels = ...
        mean(vesselFluenceValues);

    meta.fluenceMaxOnVessels = ...
        max(vesselFluenceValues);
end


% ===================================================================
% LOCAL FUNCTIONS
% ===================================================================

function vessel = ...
    renderSegment(X,Y,p1,p2,width)

    vx = p2(1)-p1(1);
    vy = p2(2)-p1(2);

    denom = ...
        vx^2 + vy^2 + eps;

    t = ...
        ( ...
        (double(X)-p1(1))*vx + ...
        (double(Y)-p1(2))*vy ...
        ) ./ denom;

    t = min(max(t,0),1);

    closestX = ...
        p1(1) + t*vx;

    closestY = ...
        p1(2) + t*vy;

    d2 = ...
        (double(X)-closestX).^2 + ...
        (double(Y)-closestY).^2;

    sigma = ...
        width/2.355;

    vessel = single( ...
        exp( ...
        -0.5*d2 ./ ...
        (sigma^2+eps)));
end


function value = randomRange(bounds)

    value = ...
        bounds(1) + ...
        rand*(bounds(2)-bounds(1));
end