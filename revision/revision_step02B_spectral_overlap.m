%% ============================================================
% STEP 02B
% Source / detector spectral-overlap audit
% ============================================================

close all;

assert(exist('simIdeal','var') == 1, ...
    'simIdeal must exist in the workspace.');

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

%% ------------------------------------------------------------
% RF data
% ------------------------------------------------------------

rf = double(simIdeal.sensor_data_clean.p);

dt = double(simIdeal.kgrid.dt);
fs = 1/dt;

[nCh,Nt] = size(rf);

% Remove channel-wise DC
rf = rf - mean(rf,2);

%% ------------------------------------------------------------
% FFT
% ------------------------------------------------------------

Nfft = 2^nextpow2(Nt);

Y = fft(rf,Nfft,2);

Npos = floor(Nfft/2)+1;

f = (0:Npos-1)*(fs/Nfft);

A = abs(Y(:,1:Npos));

% Mean amplitude spectrum across receivers
Amean = mean(A,1);

Amean = Amean ./ ...
    (max(Amean)+eps);

AdB = 20*log10(Amean+eps);

%% ============================================================
% Detector specifications
% =============================================================

fc = 2e6;
FBWpercent = 80;

fLow = fc*(1-FBWpercent/200);
fHigh = fc*(1+FBWpercent/200);

fprintf('\n');
fprintf('=============================================\n');
fprintf('STEP 02B: SOURCE-DETECTOR SPECTRAL AUDIT\n');
fprintf('=============================================\n');

fprintf('\nDetector specification\n');
fprintf('---------------------------------------------\n');

fprintf('Center frequency      = %.3f MHz\n',fc/1e6);
fprintf('Fractional bandwidth  = %.1f %%\n',FBWpercent);
fprintf('Approx. -6 dB band    = %.3f -- %.3f MHz\n', ...
    fLow/1e6,fHigh/1e6);

%% ============================================================
% Spectrum levels at important frequencies
% =============================================================

queryMHz = [ ...
    0.5 ...
    1.0 ...
    1.2 ...
    1.5 ...
    2.0 ...
    2.5 ...
    2.8 ...
    3.0 ...
    4.0 ...
    6.0];

fprintf('\nRelative RF spectrum\n');
fprintf('---------------------------------------------\n');

fprintf('%10s %14s\n', ...
    'f [MHz]', ...
    'Level [dB]');

fprintf('%10s %14s\n', ...
    '----------', ...
    '--------------');

levelsDb = zeros(size(queryMHz));

for k = 1:numel(queryMHz)

    fq = queryMHz(k)*1e6;

    [~,idx] = min(abs(f-fq));

    levelsDb(k) = AdB(idx);

    fprintf('%10.3f %14.3f\n', ...
        queryMHz(k), ...
        levelsDb(k));
end

%% ============================================================
% ENERGY-based analysis
% =============================================================

P = mean(abs(Y(:,1:Npos)).^2,1);

totalEnergy = trapz(f,P);

idxDetector = ...
    (f >= fLow) & ...
    (f <= fHigh);

detectorBandEnergy = ...
    trapz(f(idxDetector),P(idxDetector));

fractionDetectorBand = ...
    detectorBandEnergy / ...
    (totalEnergy + eps);

fprintf('\nSpectral energy\n');
fprintf('---------------------------------------------\n');

fprintf('Energy in 1.2--2.8 MHz band = %.4f %%\n', ...
    100*fractionDetectorBand);

%% ============================================================
% Energy below / within / above detector band
% =============================================================

idxLow = f < fLow;
idxHigh = f > fHigh;

energyLow = ...
    trapz(f(idxLow),P(idxLow)) / ...
    (totalEnergy+eps);

energyBand = ...
    fractionDetectorBand;

energyHigh = ...
    trapz(f(idxHigh),P(idxHigh)) / ...
    (totalEnergy+eps);

fprintf('Energy below 1.2 MHz         = %.4f %%\n', ...
    100*energyLow);

fprintf('Energy inside detector band  = %.4f %%\n', ...
    100*energyBand);

fprintf('Energy above 2.8 MHz         = %.4f %%\n', ...
    100*energyHigh);

%% ============================================================
% Cumulative spectral energy
% =============================================================

cumEnergy = cumtrapz(f,P);

cumEnergy = ...
    cumEnergy ./ ...
    (cumEnergy(end)+eps);

f10 = interp1( ...
    cumEnergy,f,0.10, ...
    'linear','extrap');

f50 = interp1( ...
    cumEnergy,f,0.50, ...
    'linear','extrap');

f90 = interp1( ...
    cumEnergy,f,0.90, ...
    'linear','extrap');

fprintf('\nCumulative spectral-energy frequencies\n');
fprintf('---------------------------------------------\n');

fprintf('f10 = %.4f MHz\n',f10/1e6);
fprintf('f50 = %.4f MHz\n',f50/1e6);
fprintf('f90 = %.4f MHz\n',f90/1e6);

%% ============================================================
% Plot
% =============================================================

figure( ...
    'Color','w', ...
    'Position',[100 100 1200 650]);

plot( ...
    f/1e6, ...
    AdB, ...
    'LineWidth',1.6);

hold on;

xline( ...
    fLow/1e6, ...
    '--', ...
    '1.2 MHz', ...
    'LineWidth',1.1);

xline( ...
    fc/1e6, ...
    '-', ...
    '2 MHz', ...
    'LineWidth',1.2);

xline( ...
    fHigh/1e6, ...
    '--', ...
    '2.8 MHz', ...
    'LineWidth',1.1);

xline( ...
    6, ...
    ':', ...
    '6 MHz design limit', ...
    'LineWidth',1.1);

yline(-6,'--');

hold off;

grid on;

xlabel('Frequency [MHz]');
ylabel('Normalized mean RF magnitude [dB]');

title( ...
    'Spectral overlap between vascular source RF and 2-MHz detector band');

xlim([0 8]);
ylim([-80 5]);

exportgraphics( ...
    gcf, ...
    fullfile( ...
        outputDir, ...
        'step02b_source_detector_spectral_overlap.png'), ...
    'Resolution',300);

%% ============================================================
% Save
% =============================================================

spectralAudit = struct();

spectralAudit.centerFrequency_Hz = fc;
spectralAudit.fractionalBandwidth_percent = ...
    FBWpercent;

spectralAudit.lower6dB_Hz = fLow;
spectralAudit.upper6dB_Hz = fHigh;

spectralAudit.queryFrequency_MHz = ...
    queryMHz;

spectralAudit.relativeLevel_dB = ...
    levelsDb;

spectralAudit.energyBelowBandFraction = ...
    energyLow;

spectralAudit.energyInsideBandFraction = ...
    energyBand;

spectralAudit.energyAboveBandFraction = ...
    energyHigh;

spectralAudit.f10_Hz = f10;
spectralAudit.f50_Hz = f50;
spectralAudit.f90_Hz = f90;

save( ...
    fullfile( ...
        outputDir, ...
        'step02b_spectral_audit.mat'), ...
    'spectralAudit');

fprintf('\n=============================================\n');
fprintf('STEP 02B COMPLETE\n');
fprintf('=============================================\n');