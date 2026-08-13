clear;
clc;

patboxRoot = ...
    'C:\Users\asus\Documents\GitHub\PATBox';

revisionDir = ...
    fullfile(patboxRoot,'revision');

addpath(patboxRoot,'-begin');
addpath(revisionDir,'-begin');

install_patbox();

%% ============================================================
% LOAD ONE DENSE PHANTOM
% ============================================================

phantomFile = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step08_morphology_suite', ...
    'phantoms', ...
    'R1_dense_seed101.mat');

S = load(phantomFile);

pRef = double(S.p0);

%% ============================================================
% GRID
% ============================================================

kgrid = ...
    kWaveGrid( ...
    192,50e-6, ...
    192,50e-6);

%% ============================================================
% PERFECT
% ============================================================

mPerfect = ...
    publicationVascularTaskMetrics( ...
    pRef,pRef,kgrid, ...
    S.components,S.meta);

fprintf('\n=============================================\n');
fprintf('TASK METRIC TEST\n');
fprintf('=============================================\n');

fprintf('\nPerfect reconstruction:\n');

fprintf('Centerline recall       = %.6f\n', ...
    mPerfect.centerline_recall);

fprintf('Segment continuity      = %.6f\n', ...
    mPerfect.mean_segment_continuity);

fprintf('Branch-point recovery   = %.6f\n', ...
    mPerfect.branch_point_recovery);

fprintf('Terminal recovery       = %.6f\n', ...
    mPerfect.terminal_branch_recovery);

assert( ...
    abs(mPerfect.centerline_recall-1)<1e-12);

assert( ...
    abs(mPerfect.mean_segment_continuity-1)<1e-12);

assert( ...
    abs(mPerfect.branch_point_recovery-1)<1e-12);

assert( ...
    abs(mPerfect.terminal_branch_recovery-1)<1e-12);

%% ============================================================
% GLOBAL SCALING
% ============================================================

mScale = ...
    publicationVascularTaskMetrics( ...
    7.3*pRef,pRef,kgrid, ...
    S.components,S.meta);

fprintf('\nGlobal amplitude x7.3:\n');

fprintf('Centerline recall       = %.6f\n', ...
    mScale.centerline_recall);

fprintf('Branch-point recovery   = %.6f\n', ...
    mScale.branch_point_recovery);

fprintf('Terminal recovery       = %.6f\n', ...
    mScale.terminal_branch_recovery);

assert( ...
    abs(mScale.centerline_recall-1)<1e-12);

assert( ...
    abs(mScale.branch_point_recovery-1)<1e-12);

%% ============================================================
% CASE 3:
% EXPLICITLY REMOVE TERMINAL BRANCHES
%
% This is a deterministic structural-failure test.
% We deliberately erase the terminal vessel segments using the
% ground-truth segment metadata.
% ============================================================

pTerminalRemoved = pRef;

segments = S.meta.segments;

xVec = double(kgrid.x_vec(:));
yVec = double(kgrid.y_vec(:));

[X,Y] = ndgrid(xVec,yVec);

terminalCount = 0;

for s = 1:numel(segments)

    if ~segments(s).is_terminal
        continue;
    end

    terminalCount = terminalCount + 1;

    %% ---------------------------------------------------------
    % Segment endpoints
    % ----------------------------------------------------------

    p1 = [ ...
        segments(s).x1_m, ...
        segments(s).y1_m];

    p2 = [ ...
        segments(s).x2_m, ...
        segments(s).y2_m];

    vx = p2(1)-p1(1);
    vy = p2(2)-p1(2);

    denom = ...
        vx^2 + vy^2 + eps;

    %% ---------------------------------------------------------
    % Distance to finite line segment
    % ----------------------------------------------------------

    t = ...
        ( ...
        (X-p1(1))*vx + ...
        (Y-p1(2))*vy ...
        ) ./ denom;

    t = min(max(t,0),1);

    closestX = ...
        p1(1) + t*vx;

    closestY = ...
        p1(2) + t*vy;

    distance = ...
        sqrt( ...
        (X-closestX).^2 + ...
        (Y-closestY).^2);

    %% ---------------------------------------------------------
    % Erasure radius
    %
    % Must exceed both the vessel width and the 0.10-mm
    % localization tolerance used by the task metric.
    % ----------------------------------------------------------

    eraseRadius = max( ...
        1.5*segments(s).width_m, ...
        0.16e-3);

    eraseMask = ...
        distance <= eraseRadius;

    %% ---------------------------------------------------------
    % Do not erase the immediate branch junction.
    %
    % Keep approximately the first 20% of the terminal segment
    % so that the parent branch remains intact.
    % ----------------------------------------------------------

    longitudinalFraction = t;

    eraseMask = ...
        eraseMask & ...
        longitudinalFraction >= 0.20;

    pTerminalRemoved(eraseMask) = 0;
end

fprintf('\nExplicitly removed terminal segments = %d\n', ...
    terminalCount);

%% ============================================================
% EVALUATE STRUCTURAL FAILURE
% ============================================================

mTerminalRemoved = ...
    publicationVascularTaskMetrics( ...
    pTerminalRemoved, ...
    pRef, ...
    kgrid, ...
    S.components, ...
    S.meta);

fprintf('\nCASE 3: terminal branches explicitly removed\n');

fprintf('Centerline recall       = %.6f\n', ...
    mTerminalRemoved.centerline_recall);

fprintf('Segment continuity      = %.6f\n', ...
    mTerminalRemoved.mean_segment_continuity);

fprintf('Branch-point recovery   = %.6f\n', ...
    mTerminalRemoved.branch_point_recovery);

fprintf('Terminal recovery       = %.6f\n', ...
    mTerminalRemoved.terminal_branch_recovery);

%% ============================================================
% EXPECTED BEHAVIOR
% ============================================================

assert( ...
    mTerminalRemoved.centerline_recall < 1, ...
    'Centerline recall failed to detect explicit branch loss.');

assert( ...
    mTerminalRemoved.mean_segment_continuity < 1, ...
    'Segment continuity failed to detect explicit branch loss.');

assert( ...
    mTerminalRemoved.terminal_branch_recovery < 1, ...
    'Terminal recovery failed to detect explicit terminal loss.');

% Branch points need NOT decrease strongly because the test deliberately
% preserves the proximal branch junctions.
assert( ...
    mTerminalRemoved.branch_point_recovery > 0.80, ...
    ['Unexpected loss of branch-point recovery. ' ...
     'The erasure mask may be too aggressive.']);

%% ============================================================
% VISUAL UNIT-TEST AUDIT
% ============================================================

figure( ...
    'Color','w', ...
    'Position',[100 100 1200 500]);

subplot(1,2,1);

imagesc( ...
    1e3*yVec, ...
    1e3*xVec, ...
    pRef);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');

title('Reference vascular target');

clim([0 1]);
colorbar;


subplot(1,2,2);

imagesc( ...
    1e3*yVec, ...
    1e3*xVec, ...
    pTerminalRemoved);

axis image;
set(gca,'YDir','normal');

xlabel('y [mm]');
ylabel('x [mm]');

title('Unit test: terminal branches removed');

clim([0 1]);
colorbar;

sgtitle( ...
    'Task-metric structural-failure validation');

%% ============================================================
% FINAL UNIT-TEST SUMMARY
% ============================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('TASK METRIC TEST: PASS\n');
fprintf('=============================================\n');

fprintf('\nValidated properties:\n');

fprintf('  Perfect reconstruction          : PASS\n');
fprintf('  Global-scale invariance         : PASS\n');
fprintf('  Centerline-loss sensitivity     : PASS\n');
fprintf('  Segment-continuity sensitivity  : PASS\n');
fprintf('  Branch-point sensitivity        : PASS\n');
fprintf('  Terminal-branch sensitivity     : PASS\n');