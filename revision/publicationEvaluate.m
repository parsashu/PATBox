function metrics = publicationEvaluate(pRecon, pRef)
%PUBLICATIONEVALUATE
% Quantitative evaluation used for PATBox manuscript revision.
%
% IMPORTANT:
%   - No independent image normalization.
%   - Stored reconstruction is never modified.
%   - SI-NRMSE uses one global least-squares scale.
%   - Correlation is computed directly from raw arrays.
%   - SSIM uses ONE common reference-based scale.
%   - CNR and SBR use masks defined only from the reference.
%
% Metrics:
%   raw_nrmse
%   si_nrmse
%   scale_factor
%   correlation
%   ssim
%   cnr
%   sbr_db
%
% This function intentionally differs from legacy patEvaluate.

    %% ---------------------------------------------------------
    % Input handling
    % ----------------------------------------------------------

    pRecon = double(gather(pRecon));
    pRef   = double(gather(pRef));

    assert(isequal(size(pRecon),size(pRef)), ...
        'Reconstruction and reference dimensions differ.');

    assert(all(isfinite(pRecon(:))), ...
        'Reconstruction contains NaN or Inf.');

    assert(all(isfinite(pRef(:))), ...
        'Reference contains NaN or Inf.');

    eps0 = eps('double');

    r = pRecon(:);
    g = pRef(:);

    %% ---------------------------------------------------------
    % Raw normalized RMSE
    % ----------------------------------------------------------

    metrics.raw_nrmse = ...
        norm(r-g,2) / ...
        (norm(g,2)+eps0);

    %% ---------------------------------------------------------
    % Scale-invariant NRMSE
    %
    % a* = <r,g>/<r,r>
    % ----------------------------------------------------------

    aStar = ...
        dot(r,g) / ...
        (dot(r,r)+eps0);

    rAligned = aStar .* r;

    metrics.scale_factor = aStar;

    metrics.si_nrmse = ...
        norm(rAligned-g,2) / ...
        (norm(g,2)+eps0);

    %% ---------------------------------------------------------
    % Pearson correlation
    % ----------------------------------------------------------

    rCentered = r - mean(r);
    gCentered = g - mean(g);

    denom = ...
        norm(rCentered,2) * ...
        norm(gCentered,2);

    if denom <= eps0
        metrics.correlation = NaN;
    else
        metrics.correlation = ...
            dot(rCentered,gCentered) / denom;
    end

    %% ---------------------------------------------------------
    % Reference-defined masks
    % ----------------------------------------------------------

    refAbs = abs(pRef);

    refPeak = max(refAbs(:));

    assert(refPeak > 0, ...
        'Reference image has zero peak.');

    signalMask = ...
        refAbs >= 0.30*refPeak;

    backgroundMask = ...
        refAbs <= 0.05*refPeak;

    backgroundMask = ...
        backgroundMask & ~signalMask;

    assert(any(signalMask(:)), ...
        'Signal mask is empty.');

    assert(any(backgroundMask(:)), ...
        'Background mask is empty.');

    %% ---------------------------------------------------------
    % CNR
    %
    % Uses RAW reconstruction values.
    % ----------------------------------------------------------

    signalValues = ...
        pRecon(signalMask);

    backgroundValues = ...
        pRecon(backgroundMask);

    muSignal = mean(signalValues);
    muBackground = mean(backgroundValues);

    sdSignal = std(signalValues,1);
    sdBackground = std(backgroundValues,1);

    metrics.cnr = ...
        abs(muSignal-muBackground) / ...
        sqrt( ...
            sdSignal^2 + ...
            sdBackground^2 + ...
            eps0);

    %% ---------------------------------------------------------
    % SBR
    %
    % RMS signal / RMS background
    % ----------------------------------------------------------

    signalRMS = ...
        sqrt(mean(abs(signalValues).^2));

    backgroundRMS = ...
        sqrt(mean(abs(backgroundValues).^2));

    metrics.sbr_db = ...
        20*log10( ...
        (signalRMS+eps0) / ...
        (backgroundRMS+eps0));

    %% ---------------------------------------------------------
    % SSIM
    %
    % Use the SAME physical/reference scale for both images.
    %
    % We first apply the SI least-squares coefficient to the
    % reconstruction, then divide BOTH images by the reference peak.
    %
    % No independent min-max scaling is performed.
    % ----------------------------------------------------------

    reconAligned = ...
        reshape(rAligned,size(pRecon));

    commonScale = refPeak;

    refSSIM = ...
        pRef ./ commonScale;

    reconSSIM = ...
        reconAligned ./ commonScale;

    % Reference is nonnegative, but reconstruction may contain
    % negative values. SSIM accepts real-valued arrays when a
    % fixed DynamicRange is specified.
    %
    % DynamicRange=1 corresponds to the reference peak scale.
    metrics.ssim = ...
        ssim( ...
        reconSSIM, ...
        refSSIM, ...
        'DynamicRange',1);

    %% ---------------------------------------------------------
    % Additional bookkeeping
    % ----------------------------------------------------------

    metrics.signal_pixel_count = ...
        nnz(signalMask);

    metrics.background_pixel_count = ...
        nnz(backgroundMask);

    metrics.reference_peak = ...
        refPeak;

    metrics.reconstruction_peak_abs = ...
        max(abs(pRecon(:)));

end