function p0_recon = iterative(sensor_data, sensor_mask, kgrid, sound_speed, varargin)
    % RECONSTRUCT_ITERATIVE Performs Iterative Back-Projection PAT reconstruction.

    p = inputParser;
    addParameter(p, 'InitialGuess', 'DMAS', @(x) ischar(x) || isstring(x));
    addParameter(p, 'NumIterations', 5, @isnumeric);
    addParameter(p, 'StepSize', 0.25, @isnumeric);
    addParameter(p, 'UpdateMethod', 'TR', @(x) ischar(x) || isstring(x)); 
    addParameter(p, 'envelope_signal', false, @islogical);
    addParameter(p, 'remove_negatives', true, @islogical);
    parse(p, varargin{:});
    
    method_type = p.Results.InitialGuess;
    num_iterations = p.Results.NumIterations;
    step_size = p.Results.StepSize;
    update_method = p.Results.UpdateMethod;
    envelope_signal_flag = p.Results.envelope_signal;
    remove_negatives_flag = p.Results.remove_negatives;
    
    % Extract pressure data safely
    if isstruct(sensor_data) && isfield(sensor_data, 'p')
        sensor_data_measured = sensor_data.p;
    else
        sensor_data_measured = sensor_data;
    end
    
    fprintf('\n--- Starting Iterative Reconstruction ---\n');
    fprintf('Initial Guess: %s | Update Step: %s\n', upper(method_type), upper(update_method));
    
    medium.sound_speed = sound_speed;
    medium.density = 1000;
    
    % Exact arguments
    PML_size = 20;
    kwave_args = {
        'PMLInside', false, ...
        'PMLSize', PML_size, ...
        'PlotPML', false, ...
        'Smooth', false, ...
        'PlotSim', false
    };

    % --- Set up Initial Guess Function ---
    switch upper(method_type)
        case 'DAS'
            recon_func = @das;
        case 'QDAS'
            recon_func = @qdas;
        case 'DMAS'
            recon_func = @dmas;
        case {'MV-DAS', 'MV_DAS'}
            recon_func = @mv_das;
        case 'DMAS_UBP'
            recon_func = @dmas_ubp;
        case 'TR'
            recon_func = @time_reversal;
        otherwise
            error('Unknown Initial Guess type. Supported: DAS, QDAS, DMAS, MV-DAS.');
    end

    % --- Set up Update Step (Adjoint) Function ---
    switch upper(update_method)
        case 'DAS'
            update_func = @(err) das(err, sensor_mask, kgrid, sound_speed, 'remove_negatives', false);
        case 'TR'
            % Envelope is OFF for gradients
            update_func = @(err) time_reversal(err, sensor_mask, kgrid, sound_speed, 'remove_negatives', false);
        otherwise
            error('Unknown Update Method. Supported: DAS, TR.');
    end

    fprintf('Calculating %s for warm start...\n', upper(method_type));
    p0_guess = recon_func(sensor_data_measured, sensor_mask, kgrid, sound_speed, ...
        'envelope_signal', false, 'remove_negatives', false);
    
    % Force dimensions to exactly match kgrid to prevent source.p0 errors
    if size(p0_guess, 1) ~= kgrid.Nx || size(p0_guess, 2) ~= kgrid.Ny
        p0_guess = reshape(p0_guess, kgrid.Nx, kgrid.Ny);
    end
    
    % Normalize
    max_guess = max(p0_guess(:));
    if max_guess > 0
        p0_guess = p0_guess * (max(sensor_data_measured(:)) / max_guess);
    end

    sensor.mask = sensor_mask;
    sensor.record = {'p'};

    % Ensure time array exists
    if isempty(kgrid.t_array)
        kgrid.makeTime(medium.sound_speed);
    end

    for i = 1:num_iterations
        fprintf('Iteration %d/%d...\n', i, num_iterations);
        
        % Forward Simulation ( $A * x$ )
        source.p0 = p0_guess;
        sim_data = kspaceFirstOrder2D(kgrid, medium, source, sensor, kwave_args{:}, 'DataCast', 'gpuArray-single');

        % Extract data
        if isstruct(sim_data) && isfield(sim_data, 'p')
            sim_p = sim_data.p;
        else
            sim_p = sim_data;
        end
        
        % Calculate Error ( $A*x - y$ )
        data_error = sim_p - sensor_data_measured;
        current_loss = mean(data_error(:).^2);
        fprintf('   Loss: %e\n', current_loss);
        
        % Back-Projection Update ( $A^T * error$ ) using chosen method
        adjoint_update = update_func(data_error);
        
        % Normalize gradient to make step_size consistent
        max_update = max(abs(adjoint_update(:)));
        if max_update > 0
            adjoint_update = adjoint_update / max_update;
        end
        
        % Update ($x_{k+1} = x_k - \alpha * A^T(error)$)
        p0_guess = p0_guess - (step_size * max(p0_guess(:))) * adjoint_update;
        
        % Enforce non-negativity
        p0_guess(p0_guess < 0) = 0; 
    end
    
    p0_recon = p0_guess;
    p0_recon = finalizeReconImage(p0_recon, envelope_signal_flag, remove_negatives_flag);
    fprintf('Iterative Reconstruction Complete.\n');
end
