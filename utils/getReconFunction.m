function recon_func = getReconFunction(algo_name)
%GETRECONFUNCTION Map algorithm name to reconstruction function handle.

    switch upper(strrep(algo_name, '_', '-'))
        case 'DAS'
            recon_func = @das;
        case 'CF-DAS'
            recon_func = @cfdas;
        case 'DMAS'
            recon_func = @dmas;
        case 'DS-DMAS'
            recon_func = @ds_dmas;
        case 'MV-DAS'
            recon_func = @mv_das;
        case 'VDAS'
            recon_func = @vdas;
        case 'SCF-DAS'
            recon_func = @scf_das;
        case 'CFMV-DAS'
            recon_func = @cfmv_das;
        case 'FBP'
            recon_func = @fbp;
        case 'UBP'
            recon_func = @ubp;
        case 'DMAS-UBP'
            recon_func = @dmas_ubp;
        case 'VDAS-UBP'
            recon_func = @vdas_ubp;
        case 'TR'
            recon_func = @time_reversal;
        case 'ITERATIVE-DAS'
            recon_func = @(varargin) iterative(varargin{:}, 'UpdateMethod', 'DAS', 'InitialGuess', 'DMAS_UBP');
        case 'ITERATIVE-TR'
            recon_func = @(varargin) iterative(varargin{:}, 'UpdateMethod', 'TR', 'InitialGuess', 'TR');
        otherwise
            supported = patListAlgorithms();
            error('PATBox:UnknownAlgorithm', ...
                'Algorithm ''%s'' is not supported. Use one of: %s', ...
                algo_name, strjoin(supported, ', '));
    end
end
