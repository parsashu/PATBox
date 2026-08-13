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
% PAIRED REALIZATION SEEDS
%
% One realization index defines:
%   - one source/phantom realization if randomized,
%   - one acoustic-medium realization,
%   - one noise base realization.
%
% Within one realization + SNR:
% every reconstruction algorithm receives EXACTLY the same
% measured RF dataset.
% ============================================================

baseSeed = 910000;

realizationIndex = ...
    (1:Nfinal).';

realizationSeed = ...
    baseSeed + realizationIndex;

%% ============================================================
% SEPARATE RANDOM STREAM LABELS
%
% Deterministic offsets make the complete stochastic experiment
% reconstructable from the realization seed.
% ============================================================

phantomSeed = ...
    realizationSeed + 100000;

mediumSeed = ...
    realizationSeed + 200000;

noiseSeedBase = ...
    realizationSeed + 300000;

%% ============================================================
% BUILD MANIFEST
% ============================================================

manifest = [];

for n = 1:Nfinal

    for s = 1:nSNR

        % Different SNRs should use paired underlying noise
        % realization where possible, with only amplitude changed.
        %
        % Store a deterministic per-realization/per-SNR seed even
        % if PATBox currently regenerates AWGN independently.
        noiseSeed = ...
            noiseSeedBase(n) + ...
            1000*s;

        newRow = table( ...
            realizationIndex(n), ...
            realizationSeed(n), ...
            phantomSeed(n), ...
            mediumSeed(n), ...
            noiseSeed, ...
            s, ...
            snrLevels_dB(s), ...
            'VariableNames',{ ...
            'Realization', ...
            'RealizationSeed', ...
            'PhantomSeed', ...
            'MediumSeed', ...
            'NoiseSeed', ...
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

assert(numel(unique(manifest.Realization))==Nfinal);

for s = 1:nSNR

    idx = manifest.SNRIndex==s;

    assert(nnz(idx)==Nfinal);

    assert( ...
        numel(unique(manifest.Realization(idx)))==Nfinal);
end

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