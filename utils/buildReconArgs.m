function args = buildReconArgs(p, recon_params, algo_name)
%BUILDRECONARGS Build name-value args for a reconstruction algorithm.

    args = {};
    patbox_only = {'AlgorithmName', 'SaveOutput', 'SaveMat', 'SavePng', 'OutputDir', 'OutputSuffix'};
    iterative_only = {'InitialGuess', 'NumIterations', 'StepSize', 'UpdateMethod'};
    standard_only = {'bandpass_filter', 'frequency_low', 'frequency_high', 'interp_method'};
    is_iterative = isIterativeAlgorithm(algo_name);

    for i = 1:size(recon_params, 1)
        name = recon_params{i, 1};
        if any(strcmpi(name, patbox_only))
            continue;
        end
        if is_iterative && any(strcmpi(name, standard_only))
            continue;
        end
        if ~is_iterative && any(strcmpi(name, iterative_only))
            continue;
        end
        if isfield(p.Results, name)
            value = p.Results.(name);
            if any(strcmpi(name, {'envelope_signal', 'remove_negatives', 'bandpass_filter'}))
                value = coerceLogical(value);
            end
            args(end + 1:end + 2) = {name, value}; %#ok<AGROW>
        end
    end
end

function tf = isIterativeAlgorithm(algo_name)
    tf = contains(upper(strrep(char(algo_name), '_', '-')), 'ITERATIVE');
end
