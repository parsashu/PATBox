function [measured, meta, systemImpaired] = applyAcquisitionModel(cleanData, dt, cfg)
%APPLYACQUISITIONMODEL Simulate a reproducible PAT receive chain.
%
% Input and outputs use [channels x time]. The function distinguishes:
%   cleanData       ideal pressure after spatial sensor integration
%   systemImpaired  deterministic/stochastic hardware response before noise
%   measured        final digitised acquisition
%
% NoiseModel: none | awgn | colored | measured | hybrid
% NoiseScaling: global | per_channel
%
% A measured-noise MAT file should preferably contain variables noise and fs.
% Other numeric variable names remain supported for backwards compatibility.

    if isa(cleanData,'gpuArray'), cleanData=gather(cleanData); end
    if ~(isnumeric(cleanData) && ismatrix(cleanData) && ~isempty(cleanData))
        error('PATBox:InvalidAcquisitionData', ...
            'cleanData must be a non-empty [channels x time] numeric matrix.');
    end
    cleanData=single(cleanData);
    if ~(isscalar(dt)&&isfinite(dt)&&dt>0)
        error('PATBox:InvalidSamplingInterval','dt must be positive.');
    end

    baseSeed=round(getCfg(cfg,'RandomSeed',1));
    seed=baseSeed+2003;
    previousRng=rng;
    rngCleanup=onCleanup(@()rng(previousRng)); %#ok<NASGU>
    rng(seed,'twister');
    [nCh,nT]=size(cleanData);
    systemImpaired=cleanData;

    validateNonnegative(getCfg(cfg,'LaserEnergyStd',0),'LaserEnergyStd');
    validateNonnegative(getCfg(cfg,'ChannelGainStd',0),'ChannelGainStd');
    validateNonnegative(getCfg(cfg,'TimeJitterStd',0),'TimeJitterStd');
    validateNonnegative(getCfg(cfg,'TriggerJitterStd',0),'TriggerJitterStd');
    validateFraction(getCfg(cfg,'DeadChannelFraction',0),'DeadChannelFraction');
    validateFraction(getCfg(cfg,'ImpulseNoiseProbability',0),'ImpulseNoiseProbability');
    validateFraction(getCfg(cfg,'MeasuredNoiseFraction',0.7),'MeasuredNoiseFraction');
    validateNonnegative(getCfg(cfg,'BaselineDriftLevel',0),'BaselineDriftLevel');
    validateNonnegative(getCfg(cfg,'ImpulseNoiseScale',10),'ImpulseNoiseScale');
    validateNonnegative(getCfg(cfg,'SaturationLevel',0),'SaturationLevel');

    % Pulse-to-pulse laser energy variation is common to all channels.
    laserStd=double(getCfg(cfg,'LaserEnergyStd',0));
    laserGain=1;
    if laserStd>0
        laserGain=exp(laserStd*randn-0.5*laserStd^2);
        systemImpaired=systemImpaired.*single(laserGain);
    end

    % Lognormal element sensitivity variation keeps gains positive.
    gainStd=double(getCfg(cfg,'ChannelGainStd',0));
    gains=ones(nCh,1,'single');
    if gainStd>0
        gains=single(exp(gainStd.*randn(nCh,1)-0.5*gainStd^2));
        systemImpaired=systemImpaired.*gains;
    end

    % Symmetric nearest-neighbour electrical/acoustic crosstalk.
    crosstalk=double(getCfg(cfg,'CrosstalkFraction',0));
    if ~(isfinite(crosstalk) && crosstalk >= 0 && crosstalk < 0.5)
        error('PATBox:InvalidCrosstalk', ...
            'CrosstalkFraction must lie in [0, 0.5).');
    end
    if crosstalk>0
        wrap=logical(getCfg(cfg,'CrosstalkWrap',false));
        left=[zeros(1,nT,'single');systemImpaired(1:end-1,:)];
        right=[systemImpaired(2:end,:);zeros(1,nT,'single')];
        if wrap && nCh>1
            left(1,:)=systemImpaired(end,:);
            right(end,:)=systemImpaired(1,:);
        end
        systemImpaired=(1-2*crosstalk).*systemImpaired+crosstalk.*(left+right);
    end

    % Static channel skew plus common trigger offset.
    jitterStd=double(getCfg(cfg,'TimeJitterStd',0));
    commonTriggerStd=double(getCfg(cfg,'TriggerJitterStd',0));
    delays=zeros(nCh,1,'single');
    commonDelay=0;
    if commonTriggerStd>0, commonDelay=commonTriggerStd*randn; end
    if jitterStd>0 || commonDelay~=0
        delays=single(commonDelay+jitterStd.*randn(nCh,1));
        t=(0:nT-1).*double(dt);
        for ch=1:nCh
            systemImpaired(ch,:)=single(interp1(t,double(systemImpaired(ch,:)), ...
                t-double(delays(ch)),'linear',0));
        end
    end

    % Electro-acoustic impulse response. A file can contain impulse_response
    % (preferred), ir, h, or any single numeric vector.
    irPath=char(getCfg(cfg,'ImpulseResponsePath',''));
    impulseResponse=[];
    if ~isempty(irPath)
        impulseResponse=loadNumericVector(resolvePatboxPath(irPath), ...
            char(getCfg(cfg,'ImpulseResponseVariable','')));
        impulseResponse=double(impulseResponse(:).');
        impulseResponse=impulseResponse./max(sqrt(sum(impulseResponse.^2)),eps);
        for ch=1:nCh
            systemImpaired(ch,:)=single(conv(double(systemImpaired(ch,:)), ...
                impulseResponse,'same'));
        end
    end

    model=lower(strrep(char(getCfg(cfg,'NoiseModel','awgn')),'-','_'));
    targetSNR=double(getCfg(cfg,'TargetSNRdB',20));
    if ~(isscalar(targetSNR) && isfinite(targetSNR))
        error('PATBox:InvalidTargetSNR','TargetSNRdB must be finite.');
    end
    [noise,noiseInfo]=generateNoise(model,cfg,nCh,nT,dt);

    driftLevel=double(getCfg(cfg,'BaselineDriftLevel',0));
    if driftLevel>0
        x=linspace(-1,1,nT);
        basis=single([ones(1,nT);x;x.^2;x.^3]);
        drift=randn(nCh,4,'single')*basis;
        noise=noise+single(driftLevel).*normaliseRmsGlobal(drift);
    end

    impulseProb=double(getCfg(cfg,'ImpulseNoiseProbability',0));
    if impulseProb>0
        spikes=rand(nCh,nT,'single')<impulseProb;
        noise=noise+spikes.*randn(nCh,nT,'single').* ...
            single(getCfg(cfg,'ImpulseNoiseScale',10));
    end

    [toneNoise,toneMeta]=coherentInterference(nCh,nT,dt,cfg);
    noise=noise+toneNoise;

    preNoise=systemImpaired;
    calibrationMode=lower(strrep(char(getCfg(cfg,'NoiseCalibrationMode','target_snr')),'-','_'));
    appliedNoiseScale=1;
    if strcmp(model,'none') && ~any(noise(:))
        scaledNoise=zeros(size(noise),'single');
        appliedNoiseScale=0;
    else
        switch calibrationMode
            case {'target_snr','snr'}
                scaling=lower(strrep(char(getCfg(cfg,'NoiseScaling','global')),'-','_'));
                switch scaling
                    case 'global'
                        signalRms=rmsValue(preNoise);
                        noiseRms=max(rmsValue(noise),eps);
                        desired=signalRms/(10^(targetSNR/20));
                        appliedNoiseScale=desired/noiseRms;
                        scaledNoise=noise.*single(appliedNoiseScale);
                    case {'per_channel','channel'}
                        signalRms=sqrt(mean(double(preNoise).^2,2));
                        noiseRms=sqrt(mean(double(noise).^2,2));
                        desired=signalRms./(10^(targetSNR/20));
                        appliedNoiseScale=desired./max(noiseRms,eps);
                        scaledNoise=noise.*single(appliedNoiseScale);
                    otherwise
                        error('PATBox:InvalidNoiseScaling', ...
                            'NoiseScaling must be global or per_channel.');
                end
            case {'preserve','absolute','calibrated'}
                appliedNoiseScale=double(getCfg(cfg,'NoiseScale',1));
                if ~(isscalar(appliedNoiseScale) && isfinite(appliedNoiseScale) && appliedNoiseScale>=0)
                    error('PATBox:InvalidNoiseScale','NoiseScale must be finite and nonnegative.');
                end
                scaledNoise=noise.*single(appliedNoiseScale);
            otherwise
                error('PATBox:InvalidNoiseCalibrationMode', ...
                    'NoiseCalibrationMode must be target_snr or preserve.');
        end
    end
    measured=preNoise+scaledNoise;

    % Dead channels are a hardware failure, not additive noise.
    deadFraction=double(getCfg(cfg,'DeadChannelFraction',0));
    deadMask=false(nCh,1);
    if deadFraction>0
        nDead=round(deadFraction*nCh);
        if nDead>0
            dead=randperm(nCh,nDead);
            deadMask(dead)=true;
            measured(dead,:)=0;
        end
    end

    % Symmetric ADC clipping and mid-tread quantisation.
    saturation=double(getCfg(cfg,'SaturationLevel',0));
    if saturation>0
        measured=max(min(measured,saturation),-saturation);
    end
    bits=round(getCfg(cfg,'ADCBitDepth',0));
    if bits>0
        if bits<2 || bits>32
            error('PATBox:InvalidADCBitDepth','ADCBitDepth must be 0 or 2..32.');
        end
        if saturation<=0
            saturation=max(abs(double(measured(:))));
            warning('PATBox:AutoADCFullScale', ...
                ['ADCBitDepth is enabled without SaturationLevel; full scale is ' ...
                 'adapted to this acquisition instead of using a fixed calibrated range.']);
        end
        if saturation>0
            levels=2^bits-1;
            measured=single(round((double(measured)+saturation)./(2*saturation).*levels) ...
                ./levels.*(2*saturation)-saturation);
        end
    end

    additiveSNR=snrDb(preNoise,scaledNoise);
    totalErrorSNR=snrDb(cleanData,measured-cleanData);
    channelSNR=20*log10(max(sqrt(mean(double(preNoise).^2,2)),eps) ./ ...
        max(sqrt(mean(double(scaledNoise).^2,2)),eps));

    meta=struct();
    meta.base_random_seed=baseSeed;
    meta.random_seed=seed;
    meta.noise_model=model;
    meta.noise_calibration_mode=calibrationMode;
    meta.noise_scaling=char(getCfg(cfg,'NoiseScaling','global'));
    meta.applied_noise_scale=appliedNoiseScale;
    meta.target_snr_db=targetSNR;
    meta.achieved_additive_snr_db=additiveSNR;
    meta.achieved_snr_db=additiveSNR; % backwards compatibility
    meta.total_error_snr_db=totalErrorSNR;
    meta.channel_snr_db=channelSNR;
    meta.channel_gains=gains;
    meta.laser_energy_gain=laserGain;
    meta.channel_delays_s=delays;
    meta.common_trigger_delay_s=commonDelay;
    meta.crosstalk_fraction=crosstalk;
    meta.dead_channels=find(deadMask);
    meta.adc_bits=bits;
    meta.saturation_level=saturation;
    meta.impulse_response_length=numel(impulseResponse);
    meta.measured_noise=noiseInfo;
    meta.interference=toneMeta;
end

function [noise,info]=generateNoise(model,cfg,nCh,nT,dt)
    noise=zeros(nCh,nT,'single');
    info=struct('source','synthetic','sample_rate_hz',1/dt,'start_sample',1);
    switch model
        case 'none'
        case 'awgn'
            noise=randn(nCh,nT,'single');
        case {'colored','power_law'}
            noise=coloredNoise(nCh,nT,double(getCfg(cfg,'NoiseColorBeta',1)));
        case 'measured'
            [noise,info]=measuredNoise(cfg,nCh,nT,dt);
        case 'hybrid'
            [measuredPart,info]=measuredNoise(cfg,nCh,nT,dt);
            syntheticPart=coloredNoise(nCh,nT,double(getCfg(cfg,'NoiseColorBeta',1)));
            mix=double(getCfg(cfg,'MeasuredNoiseFraction',0.7));
            noise=single(mix).*normaliseRmsGlobal(measuredPart)+ ...
                single(1-mix).*normaliseRmsGlobal(syntheticPart);
            info.source='hybrid_measured_and_colored';
            info.measured_fraction=mix;
        otherwise
            error('PATBox:InvalidNoiseModel','Unknown NoiseModel: %s',model);
    end
end

function [noise,info]=measuredNoise(cfg,nCh,nT,dt)
    path=char(getCfg(cfg,'NoiseDataPath',''));
    if isempty(path)
        error('PATBox:MissingNoiseData', ...
            'NoiseModel measured/hybrid requires NoiseDataPath.');
    end
    path=resolvePatboxPath(path);
    variable=char(getCfg(cfg,'MeasuredNoiseVariable',''));
    [matrix,sourceFs,varName]=loadNoiseMatrix(path,variable);
    targetFs=1/dt;

    if size(matrix,1)~=nCh && size(matrix,2)==nCh, matrix=matrix.'; end
    if size(matrix,1)==1, matrix=repmat(matrix,nCh,1); end
    if size(matrix,1)~=nCh
        error('PATBox:NoiseChannelMismatch', ...
            'Measured noise must have 1 or %d channels.',nCh);
    end

    configuredFs=double(getCfg(cfg,'MeasuredNoiseSampleRate',0));
    if configuredFs>0, sourceFs=configuredFs; end
    if sourceFs<=0
        warning('PATBox:UnknownMeasuredNoiseSampleRate', ...
            ['Measured noise has no sample-rate metadata. It is assumed to ' ...
             'already match the simulation sample rate %.6g Hz.'],targetFs);
    end
    if sourceFs>0 && abs(sourceFs-targetFs)/targetFs>1e-9
        matrix=resampleRows(matrix,sourceFs,targetFs);
    end

    matrix=detrendRows(matrix,char(getCfg(cfg,'MeasuredNoiseDetrend','constant')));
    if size(matrix,2)<nT
        if logical(getCfg(cfg,'MeasuredNoiseAllowTiling',false))
            repeats=ceil(nT/size(matrix,2));
            matrix=repmat(matrix,1,repeats);
        else
            error('PATBox:MeasuredNoiseTooShort', ...
                'Measured noise has %d samples; %d are required.',size(matrix,2),nT);
        end
    end
    maxStart=size(matrix,2)-nT+1;
    requestedStart=round(double(getCfg(cfg,'MeasuredNoiseStartSample',0)));
    if requestedStart==0
        start=randi(maxStart);
    elseif requestedStart>=1 && requestedStart<=maxStart
        start=requestedStart;
    else
        error('PATBox:InvalidMeasuredNoiseStart', ...
            'MeasuredNoiseStartSample must be 0 or lie between 1 and %d.',maxStart);
    end
    noise=single(matrix(:,start:start+nT-1));
    info=struct('source',path,'variable',varName,'sample_rate_hz',targetFs, ...
        'original_sample_rate_hz',sourceFs,'start_sample',start);
end

function [tone,meta]=coherentInterference(nCh,nT,dt,cfg)
    frequencies=double(getCfg(cfg,'InterferenceFrequenciesHz',[]));
    amplitudes=double(getCfg(cfg,'InterferenceRelativeAmplitudes',[]));
    tone=zeros(nCh,nT,'single');
    if isempty(frequencies)
        meta=struct('frequencies_hz',[],'relative_amplitudes',[]);
        return;
    end
    frequencies=frequencies(:).';
    if isempty(amplitudes), amplitudes=ones(size(frequencies)); end
    if isscalar(amplitudes), amplitudes=repmat(amplitudes,size(frequencies)); end
    if numel(amplitudes)~=numel(frequencies)
        error('PATBox:InterferenceSizeMismatch', ...
            'Interference amplitudes and frequencies must have equal lengths.');
    end
    if any(frequencies<=0 | frequencies>=0.5/dt)
        error('PATBox:InvalidInterferenceFrequency', ...
            'Interference frequencies must lie between 0 and Nyquist.');
    end
    t=(0:nT-1)*dt;
    phases=2*pi*rand(nCh,numel(frequencies));
    for f=1:numel(frequencies)
        tone=tone+single(amplitudes(f).*sin(2*pi*frequencies(f).*t+phases(:,f)));
    end
    meta=struct('frequencies_hz',frequencies,'relative_amplitudes',amplitudes);
end

function x=coloredNoise(nCh,nT,beta)
    if ~isfinite(beta), error('PATBox:InvalidNoiseBeta','NoiseColorBeta must be finite.'); end
    white=randn(nCh,nT,'single');
    f=(0:nT-1); f=min(f,nT-f); f(1)=1;
    shape=1./(f.^(beta/2)); shape(1)=0;
    x=real(ifft(fft(white,[],2).*shape,[],2));
    x=single(x);
end

function [matrix,fs,varName]=loadNoiseMatrix(path,requested)
    if ~isfile(path), error('PATBox:DataFileNotFound','Could not find: %s',path); end
    s=load(path);
    fs=0;
    for name={'fs','sample_rate','sampling_frequency'}
        if isfield(s,name{1}) && isscalar(s.(name{1}))
            fs=double(s.(name{1})); break;
        end
    end
    candidates={requested,'noise','noise_data','laser_off','rf_noise'};
    matrix=[]; varName='';
    for i=1:numel(candidates)
        name=candidates{i};
        if ~isempty(name) && isfield(s,name) && isnumeric(s.(name)) && ~isscalar(s.(name))
            matrix=double(s.(name)); varName=name; break;
        end
    end
    if isempty(matrix)
        names=fieldnames(s);
        for i=1:numel(names)
            if isnumeric(s.(names{i})) && ~isscalar(s.(names{i}))
                matrix=double(s.(names{i})); varName=names{i}; break;
            end
        end
    end
    if isempty(matrix), error('PATBox:NoNumericData','No noise matrix found in %s.',path); end
end

function vector=loadNumericVector(path,requested)
    s=load(path);
    names={requested,'impulse_response','ir','h'};
    vector=[];
    for i=1:numel(names)
        name=names{i};
        if ~isempty(name)&&isfield(s,name)&&isnumeric(s.(name))&&isvector(s.(name))
            vector=s.(name); break;
        end
    end
    if isempty(vector)
        fields=fieldnames(s);
        for i=1:numel(fields)
            if isnumeric(s.(fields{i}))&&isvector(s.(fields{i}))
                vector=s.(fields{i}); break;
            end
        end
    end
    if isempty(vector), error('PATBox:NoNumericVector','No numeric vector found in %s.',path); end
end

function y=resampleRows(x,sourceFs,targetFs)
    if exist('resample','file')==2
        [p,q]=rat(targetFs/sourceFs,1e-12);
        y=zeros(size(x,1),ceil(size(x,2)*p/q));
        for ch=1:size(x,1), y(ch,:)=resample(x(ch,:),p,q); end
    else
        oldT=(0:size(x,2)-1)/sourceFs;
        newT=0:1/targetFs:oldT(end);
        y=interp1(oldT,x.',newT,'linear',0).';
    end
end
function y=detrendRows(x,mode)
    switch lower(mode)
        case {'none','off'}, y=x;
        case {'constant','mean'}, y=x-mean(x,2);
        case {'linear','detrend'}
            y=zeros(size(x));
            for ch=1:size(x,1), y(ch,:)=detrend(x(ch,:)); end
        otherwise, error('PATBox:InvalidNoiseDetrend','Unknown MeasuredNoiseDetrend: %s',mode);
    end
end
function x=normaliseRmsGlobal(x), x=x./max(rmsValue(x),eps); end
function value=rmsValue(x), value=sqrt(mean(double(x(:)).^2)); end
function value=snrDb(signal,errorSignal)
    value=20*log10(max(rmsValue(signal),eps)/max(rmsValue(errorSignal),eps));
end
function validateNonnegative(value,name)
    value=double(value);
    if ~(isscalar(value)&&isfinite(value)&&value>=0)
        error('PATBox:InvalidAcquisitionParameter','%s must be finite and nonnegative.',name);
    end
end
function validateFraction(value,name)
    value=double(value);
    if ~(isscalar(value)&&isfinite(value)&&value>=0&&value<=1)
        error('PATBox:InvalidAcquisitionParameter','%s must lie in [0,1].',name);
    end
end
function value=getCfg(cfg,name,defaultValue)
    if isfield(cfg,name)&&~isempty(cfg.(name)),value=cfg.(name);else,value=defaultValue;end
end
