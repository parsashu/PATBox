function task = publicationVascularTaskMetrics( ...
    pRecon,pRef,kgrid,components,meta,varargin)
%PUBLICATIONVASCULARTASKMETRICS
%
% Task-oriented vascular evaluation for PATBox revision.
%
% Metrics:
%   centerline_recall
%   mean_segment_continuity
%   branch_point_recovery
%   terminal_branch_recovery
%   vessel_to_clutter_ratio_db
%
% Detection convention:
%   - one global least-squares amplitude alignment;
%   - NO independent min-max normalization;
%   - fixed threshold relative to reference peak;
%   - fixed spatial localization tolerance.
%
% These metrics supplement rather than replace the generic image metrics.

    %% =========================================================
    % OPTIONS
    % ==========================================================

    p = inputParser;

    addParameter(p, ...
        'ThresholdFraction',0.10, ...
        @(x) isnumeric(x) && isscalar(x) && x>0 && x<1);

    addParameter(p, ...
        'Tolerance_m',0.10e-3, ...
        @(x) isnumeric(x) && isscalar(x) && x>0);

    addParameter(p, ...
        'SegmentRecoveredFraction',0.60, ...
        @(x) isnumeric(x) && isscalar(x) && x>0 && x<=1);

    addParameter(p, ...
        'SamplesPerSegment',15, ...
        @(x) isnumeric(x) && isscalar(x) && x>=5);

    parse(p,varargin{:});

    thresholdFraction = ...
        p.Results.ThresholdFraction;

    tolerance_m = ...
        p.Results.Tolerance_m;

    recoveredFractionThreshold = ...
        p.Results.SegmentRecoveredFraction;

    nSamples = ...
        round(p.Results.SamplesPerSegment);

    %% =========================================================
    % INPUTS
    % ==========================================================

    pRecon = double(gather(pRecon));
    pRef   = double(gather(pRef));

    assert(isequal(size(pRecon),size(pRef)));

    %% =========================================================
    % GLOBAL SCALE ALIGNMENT
    % ==========================================================

    r = pRecon(:);
    g = pRef(:);

    aStar = ...
        dot(r,g) / ...
        (dot(r,r)+eps);

    pAligned = ...
        aStar .* pRecon;

    refPeak = ...
        max(abs(pRef(:)));

    threshold = ...
        thresholdFraction * refPeak;

    %% =========================================================
    % GRID / TOLERANCE
    % ==========================================================

    xVec = double(kgrid.x_vec(:));
    yVec = double(kgrid.y_vec(:));

    dx = double(kgrid.dx);
    dy = double(kgrid.dy);

    rx = ceil(tolerance_m/dx);
    ry = ceil(tolerance_m/dy);

    [OX,OY] = ndgrid(-rx:rx,-ry:ry);

    spatialDistance = ...
        sqrt( ...
        (OX*dx).^2 + ...
        (OY*dy).^2);

    validOffset = ...
        spatialDistance <= tolerance_m;

    offsets = ...
        [OX(validOffset),OY(validOffset)];

    %% =========================================================
    % SEGMENT CENTERLINE RECOVERY
    % ==========================================================

    segments = meta.segments;

    nSegments = numel(segments);

    segmentRecoveryFraction = ...
        nan(nSegments,1);

    segmentEligible = ...
        false(nSegments,1);

    segmentRecovered = ...
        false(nSegments,1);

    segmentMeanFluence = ...
        nan(nSegments,1);

    allEligiblePoints = 0;
    allRecoveredPoints = 0;

    for s = 1:nSegments

        seg = segments(s);

        tt = linspace(0.08,0.92,nSamples);

        xs = ...
            seg.x1_m + ...
            tt*(seg.x2_m-seg.x1_m);

        ys = ...
            seg.y1_m + ...
            tt*(seg.y2_m-seg.y1_m);

        recoveredFlags = [];
        fluenceValues = [];

        for q = 1:nSamples

            ix = nearestIndex(xVec,xs(q));
            iy = nearestIndex(yVec,ys(q));

            refLocal = ...
                localMaximum( ...
                abs(pRef), ...
                ix,iy,offsets);

            % Only evaluate locations that are actually above the
            % detection threshold in the reference p0.
            if refLocal >= threshold

                segmentEligible(s) = true;

                allEligiblePoints = ...
                    allEligiblePoints + 1;

                reconLocal = ...
                    localMaximum( ...
                    abs(pAligned), ...
                    ix,iy,offsets);

                detected = ...
                    reconLocal >= threshold;

                recoveredFlags(end+1) = detected; %#ok<AGROW>

                if detected
                    allRecoveredPoints = ...
                        allRecoveredPoints + 1;
                end

                if isfield(components,'fluence_map')

                    fluenceValues(end+1) = ...
                        double( ...
                        components.fluence_map(ix,iy)); %#ok<AGROW>
                end
            end
        end

        if ~isempty(recoveredFlags)

            segmentRecoveryFraction(s) = ...
                mean(recoveredFlags);

            segmentRecovered(s) = ...
                segmentRecoveryFraction(s) >= ...
                recoveredFractionThreshold;
        end

        if ~isempty(fluenceValues)

            segmentMeanFluence(s) = ...
                mean(fluenceValues);
        end
    end

    assert(allEligiblePoints > 0, ...
        'No eligible vessel-centerline points found.');

    task.centerline_recall = ...
        allRecoveredPoints / ...
        allEligiblePoints;

    eligibleValues = ...
        segmentRecoveryFraction(segmentEligible);

    task.mean_segment_continuity = ...
        mean(eligibleValues,'omitnan');

    task.median_segment_continuity = ...
        median(eligibleValues,'omitnan');

    %% =========================================================
    % BRANCH-POINT RECOVERY
    % ==========================================================

    branchPoints = ...
        meta.branch_points_xy_m;

    branchEligible = 0;
    branchRecovered = 0;

    for b = 1:size(branchPoints,1)

        ix = nearestIndex( ...
            xVec, ...
            branchPoints(b,1));

        iy = nearestIndex( ...
            yVec, ...
            branchPoints(b,2));

        refLocal = ...
            localMaximum( ...
            abs(pRef), ...
            ix,iy,offsets);

        if refLocal >= threshold

            branchEligible = ...
                branchEligible + 1;

            reconLocal = ...
                localMaximum( ...
                abs(pAligned), ...
                ix,iy,offsets);

            if reconLocal >= threshold

                branchRecovered = ...
                    branchRecovered + 1;
            end
        end
    end

    if branchEligible > 0

        task.branch_point_recovery = ...
            branchRecovered / ...
            branchEligible;

    else

        task.branch_point_recovery = NaN;
    end

    %% =========================================================
    % TERMINAL-BRANCH RECOVERY
    % ==========================================================

    terminalMask = ...
        [segments.is_terminal].';

    terminalEligibleMask = ...
        terminalMask & ...
        segmentEligible;

    nTerminalEligible = ...
        nnz(terminalEligibleMask);

    if nTerminalEligible > 0

        task.terminal_branch_recovery = ...
            nnz( ...
            segmentRecovered & ...
            terminalEligibleMask) / ...
            nTerminalEligible;

    else

        task.terminal_branch_recovery = NaN;
    end

    %% =========================================================
    % LOW-FLUENCE TERMINAL RECOVERY
    % ==========================================================

    task.low_fluence_terminal_recovery = NaN;
    task.high_fluence_terminal_recovery = NaN;

    validFluenceTerminal = ...
        terminalEligibleMask & ...
        isfinite(segmentMeanFluence);

    if nnz(validFluenceTerminal) >= 2

        values = ...
            segmentMeanFluence(validFluenceTerminal);

        medianFluence = ...
            median(values);

        lowMask = ...
            validFluenceTerminal & ...
            segmentMeanFluence <= medianFluence;

        highMask = ...
            validFluenceTerminal & ...
            segmentMeanFluence > medianFluence;

        if any(lowMask)

            task.low_fluence_terminal_recovery = ...
                nnz(segmentRecovered & lowMask) / ...
                nnz(lowMask);
        end

        if any(highMask)

            task.high_fluence_terminal_recovery = ...
                nnz(segmentRecovered & highMask) / ...
                nnz(highMask);
        end
    end

    %% =========================================================
    % VESSEL-TO-CLUTTER RATIO
    % ==========================================================

    task.vessel_to_clutter_ratio_db = NaN;

    if isfield(components,'clutter_mask') && ...
            any(components.clutter_mask(:))

        vesselMask = ...
            logical(components.vessel_mask);

        clutterMask = ...
            logical(components.clutter_mask);

        % Remove any overlap from the nuisance mask.
        clutterMask = ...
            clutterMask & ...
            ~vesselMask;

        if any(clutterMask(:))

            vesselRMS = ...
                sqrt( ...
                mean( ...
                abs(pAligned(vesselMask)).^2));

            clutterRMS = ...
                sqrt( ...
                mean( ...
                abs(pAligned(clutterMask)).^2));

            task.vessel_to_clutter_ratio_db = ...
                20*log10( ...
                (vesselRMS+eps) / ...
                (clutterRMS+eps));
        end
    end

    %% =========================================================
    % BOOKKEEPING
    % ==========================================================

    task.scale_factor = aStar;

    task.threshold_fraction = ...
        thresholdFraction;

    task.threshold_absolute = ...
        threshold;

    task.tolerance_m = ...
        tolerance_m;

    task.segment_recovered_fraction = ...
        recoveredFractionThreshold;

    task.n_segments = ...
        nSegments;

    task.n_eligible_segments = ...
        nnz(segmentEligible);

    task.n_branch_points_eligible = ...
        branchEligible;

    task.n_terminal_segments_eligible = ...
        nTerminalEligible;
end


% ===================================================================
% LOCAL FUNCTIONS
% ===================================================================

function index = nearestIndex(vec,value)

    [~,index] = ...
        min(abs(vec-value));
end


function value = ...
    localMaximum(image,ix,iy,offsets)

    nx = size(image,1);
    ny = size(image,2);

    values = zeros(size(offsets,1),1);

    nValid = 0;

    for k = 1:size(offsets,1)

        i = ix + offsets(k,1);
        j = iy + offsets(k,2);

        if i >= 1 && i <= nx && ...
                j >= 1 && j <= ny

            nValid = nValid+1;

            values(nValid) = ...
                image(i,j);
        end
    end

    if nValid == 0
        value = 0;
    else
        value = max(values(1:nValid));
    end
end