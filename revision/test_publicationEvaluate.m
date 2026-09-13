clear;
clc;

fprintf('\n=============================================\n');
fprintf('PUBLICATION EVALUATOR TEST\n');
fprintf('=============================================\n');

%% ------------------------------------------------------------
% Synthetic reference
% ------------------------------------------------------------

[X,Y] = ndgrid( ...
    linspace(-1,1,128), ...
    linspace(-1,1,128));

pRef = ...
    exp(-((X+0.25).^2 + Y.^2)/(2*0.10^2)) + ...
    0.6*exp(-((X-0.30).^2 + (Y-0.20).^2)/(2*0.14^2));

%% ------------------------------------------------------------
% Case 1:
% Perfect reconstruction
% ------------------------------------------------------------

m1 = publicationEvaluate(pRef,pRef);

fprintf('\nCASE 1: perfect reconstruction\n');

fprintf('SI-NRMSE   = %.12g\n',m1.si_nrmse);
fprintf('Correlation= %.12g\n',m1.correlation);
fprintf('SSIM       = %.12g\n',m1.ssim);

assert(m1.si_nrmse < 1e-10);
assert(abs(m1.correlation-1) < 1e-10);
assert(abs(m1.ssim-1) < 1e-10);

%% ------------------------------------------------------------
% Case 2:
% Pure global amplitude change
%
% SI metrics should be unchanged.
% ------------------------------------------------------------

pScaled = 7.3*pRef;

m2 = publicationEvaluate(pScaled,pRef);

fprintf('\nCASE 2: global amplitude scaling x7.3\n');

fprintf('Raw NRMSE  = %.6f\n',m2.raw_nrmse);
fprintf('Scale factor= %.6f\n',m2.scale_factor);
fprintf('SI-NRMSE   = %.12g\n',m2.si_nrmse);
fprintf('Correlation= %.12g\n',m2.correlation);
fprintf('SSIM       = %.12g\n',m2.ssim);

assert(m2.raw_nrmse > 1);
assert(m2.si_nrmse < 1e-10);
assert(abs(m2.correlation-1) < 1e-10);
assert(abs(m2.ssim-1) < 1e-10);

%% ------------------------------------------------------------
% Case 3:
% Background clutter
% ------------------------------------------------------------

rng(10);

pClutter = ...
    pRef + ...
    0.10*randn(size(pRef));

m3 = publicationEvaluate(pClutter,pRef);

fprintf('\nCASE 3: added clutter\n');

fprintf('SI-NRMSE   = %.6f\n',m3.si_nrmse);
fprintf('Correlation= %.6f\n',m3.correlation);
fprintf('SSIM       = %.6f\n',m3.ssim);
fprintf('CNR        = %.6f\n',m3.cnr);
fprintf('SBR        = %.6f dB\n',m3.sbr_db);

assert(m3.si_nrmse > 0);
assert(m3.correlation < 1);
assert(m3.ssim < 1);

%% ------------------------------------------------------------
% Case 4:
% Sparse thresholded reconstruction
%
% This is important for interpreting coherence weighting.
% ------------------------------------------------------------

pSparse = pRef;

threshold = ...
    0.25*max(pSparse(:));

pSparse(pSparse < threshold) = 0;

m4 = publicationEvaluate(pSparse,pRef);

fprintf('\nCASE 4: sparse / weak-signal suppressed\n');

fprintf('SI-NRMSE   = %.6f\n',m4.si_nrmse);
fprintf('Correlation= %.6f\n',m4.correlation);
fprintf('SSIM       = %.6f\n',m4.ssim);
fprintf('CNR        = %.6f\n',m4.cnr);
fprintf('SBR        = %.6f dB\n',m4.sbr_db);

fprintf('\n=============================================\n');
fprintf('PUBLICATION EVALUATOR TEST: PASS\n');
fprintf('=============================================\n');