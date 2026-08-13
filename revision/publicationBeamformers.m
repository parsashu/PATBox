function [recons, info] = publicationBeamformers(sim, varargin)
%PUBLICATIONBEAMFORMERS
% Audited beamforming implementations for PATBox manuscript revision.
%
% Publication methods:
%   DAS
%   CF-DAS
%   SCF-DAS
%   DMAS
%   DS-DMAS
%
% Design principles:
%   - Uses ordered physical receiver centres directly.
%   - Uses the SAME delayed-channel data for all five methods.
%   - Straight-line scalar-speed travel-time model.
%   - Linear temporal interpolation by default.
%   - No envelope.
%   - No negative-value clipping.
%   - No reconstruction-stage bandpass filter.
%   - Active-aperture normalization for DAS.
%   - Pair-count normalization for DMAS.
%   - Triangular two-stage DS-DMAS.
%
% This function is intentionally separate from the legacy PATBox
% beamformer implementations so that manuscript equations and code
% remain exactly aligned.

    %% =========================================================
    % OPTIONS
    % ==========================================================

    p = inputParser;

    addParameter(p, ...
        'SoundSpeed', ...
        1500, ...
        @(x) isnumeric(x) && isscalar(x) && x > 0);

    addParameter(p, ...
        'Interpolation', ...
        'linear', ...
        @(x) ischar(x) || isstring(x));

    addParameter(p, ...
        'CFPower', ...
        1.0, ...
        @(x) isnumeric(x) && isscalar(x) && x > 0);

    addParameter(p, ...
        'SCFPower', ...
        1.5, ...
        @(x) isnumeric(x) && isscalar(x) && x > 0);

    parse(p,varargin{:});

    cRef = double(p.Results.SoundSpeed);
    interpMethod = char(p.Results.Interpolation);

    pCF = double(p.Results.CFPower);
    pSCF = double(p.Results.SCFPower);

    %% =========================================================
    % INPUT VALIDATION
    % ==========================================================

    assert(isfield(sim,'sensor_data'), ...
        'sim.sensor_data missing.');

    assert(isfield(sim.sensor_data,'p'), ...
        'sim.sensor_data.p missing.');

    assert(isfield(sim,'sensor_geometry'), ...
        'sim.sensor_geometry missing.');

    assert(isfield(sim.sensor_geometry,'positions'), ...
        'Physical receiver positions missing.');

    assert(isfield(sim,'kgrid'), ...
        'sim.kgrid missing.');

    %% =========================================================
    % RF
    % ==========================================================

    rf = sim.sensor_data.p;

    if isa(rf,'gpuArray')
        rf = gather(rf);
    end

    rf = double(rf);

    receiverPositions = ...
        double(sim.sensor_geometry.positions);

    nSensors = size(receiverPositions,1);

    Nt = sim.kgrid.Nt;
    dt = double(sim.kgrid.dt);

    assert(size(rf,1)==nSensors, ...
        'RF channels do not match receiver count.');

    assert(size(rf,2)==Nt, ...
        'RF temporal dimension does not match kgrid.Nt.');

    %% =========================================================
    % GRID
    % ==========================================================

    Nx = sim.kgrid.Nx;
    Ny = sim.kgrid.Ny;

    xVec = double(sim.kgrid.x_vec(:));
    yVec = double(sim.kgrid.y_vec(:));

    [X,Y] = ndgrid(xVec,yVec);

    tArray = (0:Nt-1)*dt;

    %% =========================================================
    % SHARED DELAYED CHANNEL TENSOR
    %
    % delayed(:,:,m) = x_m(r)
    % ==========================================================

    fprintf('\n');
    fprintf('=============================================\n');
    fprintf('PUBLICATION BEAMFORMING ENGINE\n');
    fprintf('=============================================\n');

    fprintf('Grid                 = %d x %d\n',Nx,Ny);
    fprintf('Receivers            = %d\n',nSensors);
    fprintf('Reference c          = %.3f m/s\n',cRef);
    fprintf('Interpolation        = %s\n',interpMethod);
    fprintf('CF power             = %.3f\n',pCF);
    fprintf('SCF power            = %.3f\n',pSCF);

    delayed = zeros( ...
        Nx, ...
        Ny, ...
        nSensors, ...
        'single');

    active = false( ...
        Nx, ...
        Ny, ...
        nSensors);

    tDelayStart = tic;

    for m = 1:nSensors

        rx = receiverPositions(m,1);
        ry = receiverPositions(m,2);

        distance = sqrt( ...
            (X-rx).^2 + ...
            (Y-ry).^2);

        tau = distance/cRef;

        activeM = ...
            tau >= tArray(1) & ...
            tau <= tArray(end);

        contribution = interp1( ...
            tArray, ...
            rf(m,:), ...
            tau, ...
            interpMethod, ...
            0);

        delayed(:,:,m) = ...
            single(contribution);

        active(:,:,m) = activeM;
    end

    delayRuntime = toc(tDelayStart);

    fprintf('Delay preparation     = %.3f s\n', ...
        delayRuntime);

    %% =========================================================
    % ACTIVE APERTURE
    % ==========================================================

    Ma = sum(active,3);

    assert(all(Ma(:) >= 2), ...
        'Some pixels have fewer than two active channels.');

    MaSafe = max(double(Ma),1);

    %% =========================================================
    % SHARED BASIC SUMS
    % ==========================================================

    Xd = double(delayed);

    sumX = sum(Xd,3);

    sumX2 = sum(Xd.^2,3);

    %% =========================================================
    % 1. DAS
    %
    % uniform weights:
    %
    % P_DAS = sum(x_m) / M_a
    % ==========================================================

    tStart = tic;

    DAS = ...
        sumX ./ ...
        (MaSafe + eps);

    runtimeDAS = toc(tStart);

    %% =========================================================
    % 2. CF-DAS
    %
    % CF = |sum x|^2 / (M_a sum |x|^2)
    % ==========================================================

    tStart = tic;

    CF = ...
        abs(sumX).^2 ./ ...
        ( ...
        MaSafe .* sumX2 + ...
        eps);

    CF = min(max(CF,0),1);

    CFDAS = ...
        (CF.^pCF) .* DAS;

    runtimeCF = toc(tStart);

    %% =========================================================
    % 3. SCF-DAS
    %
    % q_m = sign(x_m)
    %
    % mu_q = mean(q_m)
    %
    % v_q = mean(q_m^2) - mu_q^2
    %
    % SCF = max(0,1-sqrt(v_q))^p
    % ==========================================================

    tStart = tic;

    Q = sign(Xd);

    sumQ = sum(Q,3);
    sumQ2 = sum(Q.^2,3);

    muQ = ...
        sumQ ./ ...
        MaSafe;

    vQ = ...
        sumQ2 ./ MaSafe - ...
        muQ.^2;

    vQ = max(vQ,0);

    SCF = ...
        max(0,1-sqrt(vQ)).^pSCF;

    SCFDAS = ...
        SCF .* DAS;

    runtimeSCF = toc(tStart);

    %% =========================================================
    % 4. DMAS
    %
    % z_m = sign(x_m)*sqrt(|x_m|)
    %
    % D = 1/2 [ (sum z)^2 - sum |x| ]
    %
    % pair-count normalized.
    % ==========================================================

    tStart = tic;

    Z = ...
        sign(Xd) .* ...
        sqrt(abs(Xd));

    sumZ = sum(Z,3);

    sumAbsX = sum(abs(Xd),3);

    dmasRaw = ...
        0.5 .* ...
        (sumZ.^2 - sumAbsX);

    nPairs = ...
        MaSafe .* ...
        (MaSafe-1) ./ 2;

    DMAS = ...
        dmasRaw ./ ...
        (nPairs + eps);

    runtimeDMAS = toc(tStart);

    %% =========================================================
    % 5. TRIANGULAR DS-DMAS
    %
    % Stage 1:
    %
    % T_i = sum_{j=i+1}^M z_i z_j
    %
    % We normalize each T_i by the number of active pairs
    % available to that triangular row.
    %
    % Stage 2:
    %
    % sign-preserving DMAS among T_i values, followed by
    % second-stage pair-count normalization.
    % ==========================================================

    tStart = tic;

    nStage1 = nSensors-1;

    T = zeros( ...
        Nx, ...
        Ny, ...
        nStage1, ...
        'single');

    for i = 1:nStage1

        zi = Z(:,:,i);

        stage1Sum = ...
            zeros(Nx,Ny);

        stage1Count = ...
            zeros(Nx,Ny);

        for j = i+1:nSensors

            pairActive = ...
                active(:,:,i) & ...
                active(:,:,j);

            term = ...
                zi .* Z(:,:,j);

            stage1Sum = ...
                stage1Sum + ...
                term .* double(pairActive);

            stage1Count = ...
                stage1Count + ...
                double(pairActive);
        end

        T(:,:,i) = single( ...
            stage1Sum ./ ...
            (stage1Count + eps));
    end

    % Sign-preserving transform for second stage
    TZ = ...
        sign(double(T)) .* ...
        sqrt(abs(double(T)));

    sumTZ = sum(TZ,3);

    sumAbsT = ...
        sum(abs(double(T)),3);

    dsRaw = ...
        0.5 .* ...
        (sumTZ.^2 - sumAbsT);

    % Number of stage-2 triangular pairs
    nPairsStage2 = ...
        nStage1*(nStage1-1)/2;

    DSDMAS = ...
        dsRaw ./ ...
        (nPairsStage2 + eps);

    runtimeDS = toc(tStart);

    %% =========================================================
    % OUTPUT
    % ==========================================================

    recons = struct();

    recons.DAS = DAS;
    recons.CFDAS = CFDAS;
    recons.SCFDAS = SCFDAS;
    recons.DMAS = DMAS;
    recons.DSDMAS = DSDMAS;

    %% =========================================================
    % INFO
    % ==========================================================

    info = struct();

    info.reference_sound_speed = cRef;
    info.interpolation = interpMethod;

    info.cf_power = pCF;
    info.scf_power = pSCF;

    info.active_aperture_normalization = true;

    info.dmas_pair_normalization = true;

    info.ds_dmas_formulation = ...
        'triangular_two_stage';

    info.use_physical_receiver_centres = true;

    info.delay_runtime_s = delayRuntime;

    info.runtime_DAS_s = runtimeDAS;
    info.runtime_CFDAS_s = runtimeCF;
    info.runtime_SCFDAS_s = runtimeSCF;
    info.runtime_DMAS_s = runtimeDMAS;
    info.runtime_DSDMAS_s = runtimeDS;

    fprintf('\nAlgorithm runtimes after shared delays:\n');

    fprintf('DAS       = %.4f s\n',runtimeDAS);
    fprintf('CF-DAS    = %.4f s\n',runtimeCF);
    fprintf('SCF-DAS   = %.4f s\n',runtimeSCF);
    fprintf('DMAS      = %.4f s\n',runtimeDMAS);
    fprintf('DS-DMAS   = %.4f s\n',runtimeDS);

    fprintf('\nPublication beamforming: COMPLETE\n');
    fprintf('=============================================\n');

end