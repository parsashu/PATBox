%% ============================================================
% STEP 02A AUDIT
% Ideal homogeneous full-view acquisition
%
% IMPORTANT:
% simIdeal must already exist in the MATLAB workspace.
% ============================================================

close all;

assert(exist('simIdeal','var') == 1, ...
    ['simIdeal is not available in the workspace. ' ...
     'Run revision_step02A_ideal_forward first.']);

%% ============================================================
% PATHS
% ============================================================

patboxRoot = ...
    'C:\Users\asus\Documents\GitHub\PATBox';

outputDir = fullfile( ...
    patboxRoot, ...
    'revision', ...
    'outputs', ...
    'step02');

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

%% ============================================================
% EXTRACT RF DATA
% ============================================================

rfClean = double(simIdeal.sensor_data_clean.p);
rfSystem = double(simIdeal.sensor_data_system.p);
rfMeasured = double(simIdeal.sensor_data.p);

[nChannels, NtRF] = size(rfClean);

dt = double(simIdeal.kgrid.dt);

t = (0:NtRF-1) * dt;
t_us = t * 1e6;

fs = 1/dt;

%% ============================================================
% BASIC STRUCTURE AUDIT
% ============================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('STEP 02A AUDIT: IDEAL BASELINE\n');
fprintf('=============================================\n');

fprintf('\nRF dimensions\n');
fprintf('---------------------------------------------\n');

fprintf('Channels             = %d\n',nChannels);
fprintf('RF time samples      = %d\n',NtRF);
fprintf('kgrid Nt             = %d\n',simIdeal.kgrid.Nt);

fprintf('\nTemporal sampling\n');
fprintf('---------------------------------------------\n');

fprintf('dt                   = %.6f ns\n',dt*1e9);
fprintf('Sampling frequency   = %.3f MHz\n',fs/1e6);
fprintf('Time duration        = %.6f us\n',t(end)*1e6);

%% ============================================================
% SPATIAL SAMPLING AUDIT
% ============================================================

dx = double(simIdeal.kgrid.dx);
dy = double(simIdeal.kgrid.dy);

cMin = min(double(simIdeal.medium.sound_speed(:)));
cMax = max(double(simIdeal.medium.sound_speed(:)));

fDesign = 6e6;

ppwX = cMin/(dx*fDesign);
ppwY = cMin/(dy*fDesign);

ppwAchieved = min(ppwX,ppwY);

fprintf('\nSpatial sampling\n');
fprintf('---------------------------------------------\n');

fprintf('dx                   = %.3f um\n',dx*1e6);
fprintf('dy                   = %.3f um\n',dy*1e6);

fprintf('c min                = %.3f m/s\n',cMin);
fprintf('c max                = %.3f m/s\n',cMax);

fprintf('PPW @ 6 MHz          = %.4f\n',ppwAchieved);

assert(ppwAchieved >= 4, ...
    'Spatial sampling is below 4 PPW.');

%% ============================================================
% SENSOR GEOMETRY
% ============================================================

geom = simIdeal.sensor_geometry_actual;

sensorPos = double(geom.positions);

sensorRadius = hypot( ...
    sensorPos(:,1), ...
    sensorPos(:,2));

fprintf('\nReceiver geometry\n');
fprintf('---------------------------------------------\n');

fprintf('Sensor type          = %s\n', ...
    simIdeal.info.sensor_type);

fprintf('Sensor model         = %s\n', ...
    simIdeal.info.sensor_model);

fprintf('Number receivers     = %d\n', ...
    simIdeal.info.num_sensors);

fprintf('Angular aperture     = %.3f deg\n', ...
    simIdeal.info.aperture_deg);

fprintf('Mean sensor radius   = %.4f mm\n', ...
    mean(sensorRadius)*1e3);

fprintf('Std sensor radius    = %.6f mm\n', ...
    std(sensorRadius)*1e3);

%% ============================================================
% SOURCE CONTAINMENT
% ============================================================

audit = simIdeal.info.aperture_audit;

fprintf('\nSource containment\n');
fprintf('---------------------------------------------\n');

fprintf('Checked              = %d\n',audit.checked);
fprintf('Inside aperture      = %d\n',audit.inside);

if isfield(audit,'receiver_radius_m')

    fprintf('Receiver radius      = %.4f mm\n', ...
        audit.receiver_radius_m*1e3);

    fprintf('Maximum source radius= %.4f mm\n', ...
        audit.maximum_source_radius_m*1e3);

    fprintf('Minimum clearance    = %.4f mm\n', ...
        audit.minimum_clearance_m*1e3);
end

assert(audit.inside, ...
    'Source support is not fully inside the receiver aperture.');

%% ============================================================
% ACQUISITION CHAIN AUDIT
% ============================================================

relativeCleanSystem = ...
    norm(rfSystem(:)-rfClean(:)) / ...
    (norm(rfClean(:))+eps);

relativeCleanMeasured = ...
    norm(rfMeasured(:)-rfClean(:)) / ...
    (norm(rfClean(:))+eps);

fprintf('\nAcquisition chain\n');
fprintf('---------------------------------------------\n');

fprintf('Noise model          = %s\n', ...
    simIdeal.info.acquisition.noise_model);

fprintf('Clean -> system diff = %.6e\n', ...
    relativeCleanSystem);

fprintf('Clean -> measured diff = %.6e\n', ...
    relativeCleanMeasured);

fprintf('Maximum |RF|         = %.6e\n', ...
    max(abs(rfClean(:))));

fprintf('RF RMS               = %.6e\n', ...
    sqrt(mean(rfClean(:).^2)));

fprintf('Finite RF fraction   = %.8f\n', ...
    mean(isfinite(rfClean(:))));

assert(all(isfinite(rfClean(:))), ...
    'RF data contain NaN or Inf.');

assert(any(abs(rfClean(:))>0), ...
    'RF data are identically zero.');

%% ============================================================
% SAVE SIMULATION RECORD NOW
% ============================================================

simFile = fullfile( ...
    outputDir, ...
    'sim_ideal_seed31.mat');

save( ...
    simFile, ...
    'simIdeal', ...
    '-v7.3');

fprintf('\nSimulation record saved:\n%s\n',simFile);

%% ============================================================
% FIGURE 1: RF CHANNEL-TIME MAP
% ============================================================

figure( ...
    'Color','w', ...
    'Position',[100 100 1150 620]);

imagesc( ...
    t_us, ...
    1:nChannels, ...
    rfClean);

axis xy;

xlabel('Time [\mus]');
ylabel('Receiver channel');

title( ...
    'Ideal homogeneous full-view RF data');

cb = colorbar;
ylabel(cb,'Pressure amplitude [a.u.]');

exportgraphics( ...
    gcf, ...
    fullfile(outputDir,'step02a_rf_map.png'), ...
    'Resolution',300);

%% ============================================================
% FIGURE 2: REPRESENTATIVE CHANNEL TRACES
% ============================================================

selectedChannels = [1 33 65 97];

figure( ...
    'Color','w', ...
    'Position',[100 100 1150 620]);

hold on;

for k = 1:numel(selectedChannels)

    ch = selectedChannels(k);

    plot( ...
        t_us, ...
        rfClean(ch,:), ...
        'LineWidth',1.15);
end

hold off;
grid on;

xlabel('Time [\mus]');
ylabel('Pressure amplitude [a.u.]');

title('Representative receiver traces');

legend( ...
    compose('Channel %d',selectedChannels), ...
    'Location','best');

exportgraphics( ...
    gcf, ...
    fullfile(outputDir, ...
    'step02a_representative_traces.png'), ...
    'Resolution',300);

%% ============================================================
% FIGURE 3: MEAN RF SPECTRUM
% ============================================================

% Remove channel-wise DC offsets.
rfForFFT = rfClean - mean(rfClean,2);

Nfft = 2^nextpow2(NtRF);

Y = fft(rfForFFT,Nfft,2);

nPositive = floor(Nfft/2)+1;

frequency = ...
    (0:nPositive-1) .* ...
    (fs/Nfft);

magnitudeSpectrum = ...
    abs(Y(:,1:nPositive));

meanSpectrum = mean(magnitudeSpectrum,1);

meanSpectrum = ...
    meanSpectrum ./ ...
    (max(meanSpectrum)+eps);

meanSpectrumDb = ...
    20*log10(meanSpectrum + eps);

figure( ...
    'Color','w', ...
    'Position',[100 100 1150 620]);

plot( ...
    frequency/1e6, ...
    meanSpectrumDb, ...
    'LineWidth',1.4);

grid on;

xlabel('Frequency [MHz]');
ylabel('Normalized magnitude [dB]');

title('Mean RF spectrum across 128 receivers');

xlim([0 10]);
ylim([-80 5]);

yline(-6,'--','-6 dB');

xline(6,'--','6 MHz design frequency');

exportgraphics( ...
    gcf, ...
    fullfile(outputDir, ...
    'step02a_mean_rf_spectrum.png'), ...
    'Resolution',300);

%% ============================================================
% SPECTRAL SUMMARY
% ============================================================

% Dominant frequency
[~,peakIndex] = max(meanSpectrum);

peakFrequencyMHz = ...
    frequency(peakIndex)/1e6;

% Approximate -6 dB occupied range around relevant spectrum.
idx6 = find(meanSpectrumDb >= -6);

if isempty(idx6)

    lower6MHz = NaN;
    upper6MHz = NaN;

else

    lower6MHz = frequency(idx6(1))/1e6;
    upper6MHz = frequency(idx6(end))/1e6;

end

fprintf('\nRF spectral summary\n');
fprintf('---------------------------------------------\n');

fprintf('Peak frequency       = %.4f MHz\n', ...
    peakFrequencyMHz);

fprintf('-6 dB lower freq     = %.4f MHz\n', ...
    lower6MHz);

fprintf('-6 dB upper freq     = %.4f MHz\n', ...
    upper6MHz);

%% ============================================================
% OPTIONAL: END-OF-RECORD ENERGY CHECK
% ============================================================

tailFraction = 0.05;

nTail = max(1,round(tailFraction*NtRF));

tailRms = sqrt( ...
    mean(rfClean(:,end-nTail+1:end).^2,'all'));

totalRms = sqrt( ...
    mean(rfClean.^2,'all'));

tailRatio = tailRms/(totalRms+eps);

fprintf('\nTemporal coverage audit\n');
fprintf('---------------------------------------------\n');

fprintf('Last 5%% RF RMS       = %.6e\n',tailRms);
fprintf('Total RF RMS         = %.6e\n',totalRms);
fprintf('Tail / total RMS     = %.6e\n',tailRatio);

%% ============================================================
% SAVE AUDIT NUMBERS
% ============================================================

auditSummary = struct();

auditSummary.nChannels = nChannels;
auditSummary.Nt = NtRF;

auditSummary.dt_s = dt;
auditSummary.fs_Hz = fs;
auditSummary.duration_s = t(end);

auditSummary.dx_m = dx;
auditSummary.dy_m = dy;

auditSummary.ppw_at_6MHz = ppwAchieved;

auditSummary.receiverRadius_m = ...
    mean(sensorRadius);

auditSummary.sourceInside = ...
    audit.inside;

if isfield(audit,'minimum_clearance_m')
    auditSummary.sourceClearance_m = ...
        audit.minimum_clearance_m;
end

auditSummary.cleanSystemRelativeDifference = ...
    relativeCleanSystem;

auditSummary.cleanMeasuredRelativeDifference = ...
    relativeCleanMeasured;

auditSummary.rfRms = ...
    sqrt(mean(rfClean(:).^2));

auditSummary.peakFrequency_MHz = ...
    peakFrequencyMHz;

auditSummary.lower6dB_MHz = ...
    lower6MHz;

auditSummary.upper6dB_MHz = ...
    upper6MHz;

auditSummary.tailToTotalRms = ...
    tailRatio;

save( ...
    fullfile(outputDir,'step02a_audit.mat'), ...
    'auditSummary');

fprintf('\n=============================================\n');
fprintf('STEP 02A AUDIT COMPLETE\n');
fprintf('=============================================\n');