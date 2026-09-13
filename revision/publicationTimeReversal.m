function [p0Recon, info] = publicationTimeReversal(sim, varargin)
%PUBLICATIONTIMEREVERSAL
% Auditable time-reversal reconstruction for PATBox manuscript revision.
%
% Key design choices:
%   1. Uses the full sound-speed AND density maps stored in sim.medium.
%   2. Uses physical receiver-element centres as Cartesian TR boundary
%      locations, preserving physical channel order.
%   3. Finite-aperture element traces are therefore represented using an
%      equivalent-centre approximation.
%   4. Acoustic attenuation is intentionally NOT reversed/compensated.
%   5. The detector frequency response is NOT deconvolved.
%   6. No envelope, clipping, independent normalization, or bandpass
%      post-processing is applied.
%   7. CPU single precision is the default publication setting.

    %% ---------------------------------------------------------
    % Options
    % ----------------------------------------------------------

    p = inputParser;

    addParameter(p, ...
        'DataCast', ...
        'single', ...
        @(x) ischar(x) || isstring(x));

    addParameter(p, ...
        'PMLSize', ...
        20, ...
        @(x) isnumeric(x) && isscalar(x) && x > 0);

    addParameter(p, ...
        'PlotSimulation', ...
        false, ...
        @(x) islogical(x) || isnumeric(x));

    parse(p,varargin{:});

    dataCast = char(p.Results.DataCast);
    pmlSize = round(p.Results.PMLSize);
    plotSimulation = logical(p.Results.PlotSimulation);

    %% ---------------------------------------------------------
    % Validate simulation record
    % ----------------------------------------------------------

    requiredFields = { ...
        'sensor_data', ...
        'sensor_geometry', ...
        'kgrid', ...
        'medium'};

    for k = 1:numel(requiredFields)

        assert(isfield(sim,requiredFields{k}), ...
            'Simulation record missing field: %s', ...
            requiredFields{k});
    end

    assert(isfield(sim.sensor_data,'p'), ...
        'sim.sensor_data.p is missing.');

    assert(isfield(sim.sensor_geometry,'positions'), ...
        'Receiver-centre coordinates are missing.');

    assert(isfield(sim.medium,'sound_speed'), ...
        'Sound-speed map is missing.');

    assert(isfield(sim.medium,'density'), ...
        'Density map is missing.');

    %% ---------------------------------------------------------
    % RF data
    % ----------------------------------------------------------

    sensorSignals = sim.sensor_data.p;

    if isa(sensorSignals,'gpuArray')
        sensorSignals = gather(sensorSignals);
    end

    sensorSignals = single(sensorSignals);

    %% ---------------------------------------------------------
    % Receiver locations
    %
    % IMPORTANT:
    % physical-element traces remain in the same order as
    % sensor_geometry.positions.
    %
    % k-Wave supports Cartesian sensor coordinates for time reversal,
    % preserving this ordering.
    % ----------------------------------------------------------

    receiverPositions = ...
        double(sim.sensor_geometry.positions);

    assert(size(receiverPositions,2)==2, ...
        'Expected receiver positions [N x 2].');

    nReceivers = size(receiverPositions,1);

    assert(size(sensorSignals,1)==nReceivers, ...
        ['RF channel count and receiver-coordinate count ' ...
         'do not agree.']);

    %% ---------------------------------------------------------
    % Time grid
    % ----------------------------------------------------------

    kgrid = sim.kgrid;

    Nt = kgrid.Nt;

    assert(size(sensorSignals,2)==Nt, ...
        'RF time dimension does not match kgrid.Nt.');

    if ischar(kgrid.t_array) && ...
            strcmp(kgrid.t_array,'auto')

        kgrid.t_array = ...
            (0:Nt-1)*kgrid.dt;
    end

    %% ---------------------------------------------------------
    % Reconstruction medium
    %
    % Use heterogeneous c(x,y) and rho(x,y), but deliberately omit
    % alpha_coeff and alpha_power.
    %
    % Thus attenuation is NOT compensated during time reversal.
    % ----------------------------------------------------------

    reconMedium = struct();

    reconMedium.sound_speed = ...
        sim.medium.sound_speed;

    reconMedium.density = ...
        sim.medium.density;

    %% ---------------------------------------------------------
    % Time-reversal sensor
    %
    % Cartesian coordinate convention:
    % [2 x N], x positions followed by y positions.
    % ----------------------------------------------------------

    sensorTR = struct();

    sensorTR.mask = ...
        receiverPositions.';

    sensorTR.time_reversal_boundary_data = ...
        sensorSignals;

    %% ---------------------------------------------------------
    % Empty source
    % ----------------------------------------------------------

    sourceTR = struct();

    %% ---------------------------------------------------------
    % Audit finite-aperture approximation
    % ----------------------------------------------------------

    sensorModel = '';

    if isfield(sim,'info') && ...
            isfield(sim.info,'sensor_model')

        sensorModel = ...
            char(sim.info.sensor_model);
    end

    elementWidth = NaN;

    if isfield(sim,'info') && ...
            isfield(sim.info,'element_width_m')

        elementWidth = ...
            double(sim.info.element_width_m);
    end

    equivalentCenterApproximation = ...
        contains(lower(sensorModel),'kwave_array') || ...
        contains(lower(sensorModel),'rasterized');

    %% ---------------------------------------------------------
    % Run TR
    % ----------------------------------------------------------

    fprintf('\n');
    fprintf('=============================================\n');
    fprintf('PUBLICATION TIME REVERSAL\n');
    fprintf('=============================================\n');

    fprintf('Receivers              = %d\n', ...
        nReceivers);

    fprintf('Sensor model           = %s\n', ...
        sensorModel);

    fprintf('Element width          = %.4f mm\n', ...
        elementWidth*1e3);

    fprintf('Equivalent-center TR   = %d\n', ...
        equivalentCenterApproximation);

    fprintf('Use heterogeneous c    = %d\n', ...
        ~isscalar(reconMedium.sound_speed));

    fprintf('Use heterogeneous rho  = %d\n', ...
        ~isscalar(reconMedium.density));

    fprintf('Attenuation compensation = 0\n');
    fprintf('Detector deconvolution   = 0\n');
    fprintf('DataCast               = %s\n', ...
        dataCast);

    tStart = tic;

    p0Recon = kspaceFirstOrder2D( ...
        kgrid, ...
        reconMedium, ...
        sourceTR, ...
        sensorTR, ...
        ...
        'PMLInside',false, ...
        'PMLSize',pmlSize, ...
        'PlotPML',false, ...
        'Smooth',false, ...
        'PlotSim',plotSimulation, ...
        'DataCast',dataCast, ...
        'DataRecast',true);

    elapsed = toc(tStart);

    if isa(p0Recon,'gpuArray')
        p0Recon = gather(p0Recon);
    end

    p0Recon = double(p0Recon);

    assert( ...
        isequal(size(p0Recon), ...
        [kgrid.Nx kgrid.Ny]), ...
        'Unexpected TR reconstruction dimensions.');

    assert(all(isfinite(p0Recon(:))), ...
        'TR reconstruction contains NaN or Inf.');

    %% ---------------------------------------------------------
    % Metadata
    % ----------------------------------------------------------

    info = struct();

    info.algorithm = 'TR';
    info.elapsed_seconds = elapsed;

    info.sensor_model = sensorModel;
    info.element_width_m = elementWidth;

    info.receiver_count = nReceivers;

    info.boundary_geometry = ...
        'cartesian_element_centres';

    info.equivalent_center_approximation = ...
        equivalentCenterApproximation;

    info.used_sound_speed_map = true;
    info.used_density_map = true;

    info.attenuation_compensated = false;
    info.detector_response_deconvolved = false;

    info.data_cast = dataCast;

    fprintf('Runtime                 = %.3f s\n', ...
        elapsed);

    fprintf('TR reconstruction finite: PASS\n');

    fprintf('=============================================\n');
end