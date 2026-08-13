clear;
close all;
clc;

%% ============================================================
% STEP 09A
% Expanded paired Monte Carlo design
%
% Reviewer 2 -- Major Comment 5
% ============================================================

patboxRoot = ...
    'C:\Users\asus\Documents\GitHub\PATBox';

revisionDir = ...
    fullfile(patboxRoot,'revision');

addpath(patboxRoot,'-begin');
addpath(revisionDir,'-begin');

outputDir = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'step09_montecarlo');

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

%% ============================================================
% SAMPLE SIZE
% ============================================================

Nfinal = 50;

stabilityCheckpoints = ...
    [10 20 30 40 50];

assert(stabilityCheckpoints(end)==Nfinal);

%% ============================================================
% SNR LEVELS
%
% Exact target SNR levels used in the original manuscript.
% These are retained unchanged for the expanded Monte Carlo
% revision study.
% ============================================================

snrLevels_dB = [ ...
    5, ...
    10, ...
    15, ...
    20, ...
    30];

if any(isnan(snrLevels_dB))

    error([ ...
        'Fill snrLevels_dB with the exact SNR values ' ...
        'used in the original manuscript before proceeding.']);
end

nSNR = numel(snrLevels_dB);

%% ============================================================
% METHODS
% ============================================================

methods = [ ...
    "DAS", ...
    "CF-DAS", ...
    "SCF-DAS", ...
    "DMAS", ...
    "DS-DMAS", ...
    "TR"];

%% ============================================================
% METRICS
% ============================================================

metrics = [ ...
    "SI_NRMSE", ...
    "Correlation", ...
    "SSIM", ...
    "CNR", ...
    "SBR_dB"];

%% ============================================================
% PAIRED BASE-SEED DESIGN
%
% IMPORTANT:
% The original manuscript used base seeds 1--10.
% The revision extends EXACTLY the same sequence to 1--50.
%
% Seeds 1--10  = original study
% Seeds 11--50 = newly added realizations
%
% The source phantom is FIXED and is not randomized.
% The base seed controls stochastic medium/noise generation.
% ============================================================

realizationIndex = ...
    (1:Nfinal).';

baseSeed = ...
    realizationIndex;

sourceId = ...
    repmat( ...
    "three_line_fixed", ...
    Nfinal, ...
    1);

isOriginalSeed = ...
    baseSeed <= 10;

%% ============================================================
% BUILD MANIFEST
%
% The SAME base seed is reused at every SNR.
%
% This is essential:
%   - same heterogeneous medium
%   - same normalized Gaussian noise realization
%   - only noise amplitude changes with target SNR
% ============================================================

manifest = [];

for n = 1:Nfinal

    for s = 1:nSNR

        newRow = table( ...
            realizationIndex(n), ...
            baseSeed(n), ...
            sourceId(n), ...
            isOriginalSeed(n), ...
            s, ...
            snrLevels_dB(s), ...
            'VariableNames',{ ...
            'Realization', ...
            'BaseSeed', ...
            'SourceId', ...
            'OriginalSeedSubset', ...
            'SNRIndex', ...
            'SNR_dB'});

        manifest = ...
            [manifest;newRow]; %#ok<AGROW>
    end
end
%% ============================================================
% AUDIT
% ============================================================

expectedConditions = ...
    Nfinal*nSNR;

assert(height(manifest)==expectedConditions);

assert( ...
    numel(unique(manifest.Realization)) == ...
    Nfinal);

assert( ...
    numel(unique(manifest.BaseSeed)) == ...
    Nfinal);

%% ------------------------------------------------------------
% Original seeds must be preserved exactly
% ------------------------------------------------------------

originalSeeds = ...
    unique( ...
    manifest.BaseSeed( ...
    manifest.OriginalSeedSubset));

assert( ...
    isequal( ...
    originalSeeds(:), ...
    (1:10).'), ...
    'Original seeds 1--10 were not preserved.');

%% ------------------------------------------------------------
% Every base seed must appear once at every SNR
% ------------------------------------------------------------

for n = 1:Nfinal

    idx = ...
        manifest.BaseSeed == n;

    assert(nnz(idx)==nSNR);

    snrForSeed = ...
        sort(manifest.SNR_dB(idx));

    assert( ...
        isequal( ...
        snrForSeed(:), ...
        sort(snrLevels_dB(:))), ...
        'Incomplete SNR set for base seed %d.',n);
end

%% ------------------------------------------------------------
% Fixed source audit
% ------------------------------------------------------------

assert( ...
    all( ...
    manifest.SourceId == ...
    "three_line_fixed"));

fprintf('\nPairing audit:\n');

fprintf('Original seeds retained = 1--10\n');
fprintf('New seeds added          = 11--50\n');
fprintf('Source                   = fixed three-line phantom\n');
fprintf('Same BaseSeed across SNR = PASS\n');
%% ============================================================
% STATISTICAL DESIGN METADATA
% ============================================================

design = struct();

design.final_sample_size = ...
    Nfinal;

design.stability_checkpoints = ...
    stabilityCheckpoints;

design.snr_levels_dB = ...
    snrLevels_dB;

design.methods = ...
    methods;

design.metrics = ...
    metrics;

design.omnibus_test = ...
    'paired Friedman';

design.posthoc_test = ...
    'paired Wilcoxon signed-rank';

design.multiple_comparison_correction = ...
    'Holm';

design.effect_size = ...
    'matched-pairs rank-biserial correlation';

design.confidence_interval = ...
    'paired bootstrap 95 percent';

design.bootstrap_resamples = ...
    5000;

design.alpha = ...
    0.05;

design.original_seed_subset = ...
    1:10;

design.new_seed_subset = ...
    11:50;

design.source_policy = ...
    'fixed three-line phantom';

design.paired_block = ...
    'BaseSeed';

design.snr_pairing_policy = ...
    ['Same medium and normalized noise realization ' ...
     'within each BaseSeed; only noise amplitude changes'];

%% ============================================================
% SAVE
% ============================================================

writetable( ...
    manifest, ...
    fullfile( ...
    outputDir, ...
    'montecarlo_manifest.csv'));

save( ...
    fullfile( ...
    outputDir, ...
    'montecarlo_design.mat'), ...
    'manifest', ...
    'design', ...
    '-v7.3');

%% ============================================================
% CONSOLE
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 09A: EXPANDED MONTE CARLO DESIGN\n');
fprintf('============================================================\n');

fprintf('Paired realizations / SNR = %d\n', ...
    Nfinal);

fprintf('Number of SNR levels      = %d\n', ...
    nSNR);

fprintf('Total RF conditions       = %d\n', ...
    expectedConditions);

fprintf('Reconstruction methods    = %d\n', ...
    numel(methods));

fprintf('Total reconstruction outcomes = %d\n', ...
    expectedConditions*numel(methods));

fprintf('\nStability checkpoints:\n');

fprintf('  N = ');
fprintf('%d ',stabilityCheckpoints);
fprintf('\n');

fprintf('\nStatistical plan:\n');

fprintf('  Omnibus  : Friedman\n');
fprintf('  Post-hoc : paired Wilcoxon\n');
fprintf('  MC adjust: Holm\n');
fprintf('  Effect   : rank-biserial correlation\n');
fprintf('  CI       : paired bootstrap, 95%%\n');

fprintf('\n============================================================\n');
fprintf('STEP 09A COMPLETE\n');
fprintf('============================================================\n');