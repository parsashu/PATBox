% =========================================================================
% Project: Robust Multi-Wavelength Photoacoustic Imaging in Optically Heterogeneous Tissue
% 
% Component: Image Quality Assessment & Quantitative Evaluation Engine
% Authors:   Parsa Shahidi
% Date:      June 2026
%
% Description:
%   This function computes comprehensive statistical and structural image 
%   quality metrics for reconstructed photoacoustic images against a baseline 
%   ground truth. Evaluated metrics include MSE, RMSE, PSNR, SSIM, SNR, 
%   gradient-based Sharpness, Universal Image Quality Index (UIQI), Contrast-
%   to-Noise Ratio (CNR), and Signal-to-Background Ratio (SBR).
% =========================================================================

function metrics = patEvaluate(p0_recon, p0_ground_truth)
%PATEVALUATE Compute MSE, RMSE, PSNR, SSIM, SNR, sharpness, UIQI, CNR, and SBR.
%   metrics = patEvaluate(p0_recon, p0_ground_truth)

    p0_recon = double(gather(p0_recon));
    p0_ground_truth = double(gather(p0_ground_truth));

    recon_norm = mat2gray(p0_recon);
    gt_norm = mat2gray(p0_ground_truth);

    recon_flat = recon_norm(:);
    gt_flat = gt_norm(:);

    metrics.mse = mean((recon_flat - gt_flat).^2);
    metrics.rmse = sqrt(metrics.mse);

    peak_val = max(gt_flat);
    if peak_val <= 0
        peak_val = 1;
    end
    if metrics.mse > 0
        metrics.psnr = 10 * log10(peak_val^2 / metrics.mse);
    else
        metrics.psnr = Inf;
    end

    metrics.ssim = ssim(recon_norm, gt_norm, 'DynamicRange', 1);

    signal_power = sum(gt_flat.^2);
    noise_power = sum((recon_flat - gt_flat).^2);
    if noise_power > 0
        metrics.snr = 10 * log10(signal_power / noise_power);
    else
        metrics.snr = Inf;
    end

    metrics.sharpness = getSharpness(recon_norm);
    metrics.uiqi = getUIQI(recon_norm, gt_norm);
    metrics.cnr = computeCNR(p0_recon, p0_ground_truth);
    metrics.sbr = computeSBR(p0_recon, p0_ground_truth);
end

function s = getSharpness(img)
    img = double(gather(img));
    [Gx, Gy] = gradient(img);
    s = mean(sqrt(Gx.^2 + Gy.^2), 'all');
end

function q = getUIQI(img1, img2)
    x = double(gather(img1(:)));
    y = double(gather(img2(:)));

    mu_x = mean(x);
    mu_y = mean(y);
    sigma2_x = var(x, 1);
    sigma2_y = var(y, 1);
    sigma_xy = mean((x - mu_x) .* (y - mu_y));

    denom = (sigma2_x + sigma2_y) * (mu_x^2 + mu_y^2);
    if denom == 0
        q = 0;
    else
        q = (4 * sigma_xy * mu_x * mu_y) / denom;
    end
end

function cnr_val = computeCNR(rec, gt)
    gt_norm = mat2gray(gt);
    rec_norm = mat2gray(rec);

    signal_mask = gt_norm > 0.3;
    background_mask = gt_norm < 0.05;

    if ~any(signal_mask(:)) || ~any(background_mask(:))
        cnr_val = NaN;
        return;
    end

    signal_mean = mean(rec_norm(signal_mask));
    background_mean = mean(rec_norm(background_mask));
    background_std = std(rec_norm(background_mask));
    cnr_val = abs(signal_mean - background_mean) / (background_std + eps);
end

function sbr_val = computeSBR(rec, gt)
    gt_norm = mat2gray(gt);
    rec_norm = mat2gray(rec);

    signal_mask = gt_norm > 0.3;
    background_mask = gt_norm < 0.05;

    if ~any(signal_mask(:)) || ~any(background_mask(:))
        sbr_val = NaN;
        return;
    end

    signal_mean = mean(rec_norm(signal_mask));
    background_mean = mean(rec_norm(background_mask));
    if background_mean <= 0
        sbr_val = Inf;
    else
        sbr_val = 20 * log10(signal_mean / background_mean);
    end
end
