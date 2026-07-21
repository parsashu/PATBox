function value = getBenchmarkMetricValue(metric_name, metrics, info)
%GETBENCHMARKMETRICVALUE Map a benchmark metric name to a numeric value.

    switch upper(metric_name)
        case 'COMPTIME'
            value = info.elapsed_seconds;
        case 'MSE'
            value = metrics.mse;
        case 'RMSE'
            value = metrics.rmse;
        case 'PSNR'
            value = metrics.psnr;
        case 'SSIM'
            value = metrics.ssim;
        case 'SNR'
            value = metrics.snr;
        case 'SHARPNESS'
            value = metrics.sharpness;
        case 'UIQI'
            value = metrics.uiqi;
        case 'CNR'
            value = metrics.cnr;
        case 'SBR'
            value = metrics.sbr;
        otherwise
            error('PATBox:UnknownMetric', 'Unknown metric: %s', metric_name);
    end
end
