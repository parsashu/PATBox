%% ========================================================================
%
% Publication figure from EXISTING vascular-generalization outputs.
%
% Layout:
%
%          Reference | DAS | CF-DAS | SCF-DAS | DMAS | DS-DMAS | TR
% Row 1:  Branching + clutter
% Row 2:  Same branching geometry + fluence surrogate
%
% IMPORTANT
% ---------
% 1) NO forward simulation is performed.
% 2) NO reconstruction is performed.
% 3) Only previously saved MAT outputs are read.
% 4) Each panel is independently normalized for DISPLAY ONLY.
% 5) Replicate is fixed BEFORE visual inspection.
%
% MATLAB: R2024b compatible
% ========================================================================

clear;
clc;
close all;

%% ========================================================================
% 0) USER SETTINGS
% ========================================================================

projectRoot = ...
    'C:\Users\asus\Documents\GitHub\PATBox';

revisionDir = fullfile(projectRoot,'revision');
outputsRoot = fullfile(revisionDir,'outputs');

% ------------------------------------------------------------------------
% IMPORTANT:
% Point this to the folder containing the completed vascular-generalization
% outputs. It is OK to point to the general revision outputs folder because
% the script searches recursively.
% ------------------------------------------------------------------------
cfg.searchRoot = outputsRoot;

% Fixed, non-visually-selected case.
cfg.replicate = 1;

% Reference acquisition used for the main qualitative figure.
cfg.numReceivers       = 128;
cfg.centerFrequencyHz  = 2e6;
cfg.fractionalBandwidth = 0.80;
cfg.elementWidthM      = 0.20e-3;
cfg.snrDb              = 20;

% Rows of the figure.
cfg.rowFamilies = { ...
    'clutter', ...
    'fluence'};

cfg.rowLabels = { ...
    'Branching + clutter', ...
    'Branching + fluence surrogate'};

% Columns.
cfg.methods = { ...
    'DAS', ...
    'CF-DAS', ...
    'SCF-DAS', ...
    'DMAS', ...
    'DS-DMAS', ...
    'TR'};

cfg.columnLabels = { ...
    'Reference', ...
    'DAS', ...
    'CF-DAS', ...
    'SCF-DAS', ...
    'DMAS', ...
    'DS-DMAS', ...
    'TR'};

% Figure/export.
cfg.figureName = 'Fig_Vascular_Reconstruction_2x7';

cfg.outDir = fullfile( ...
    revisionDir, ...
    'outputs', ...
    'publication_figures');

if ~exist(cfg.outDir,'dir')
    mkdir(cfg.outDir);
end

cfg.pngDPI = 600;

% Display only.
cfg.useAbsoluteValue = true;
cfg.displayPercentile = 99.8;

% Set true only if the saved arrays need transpose for the desired
% x/y visual orientation.
cfg.transposeImages = false;

% Colormap.
cfg.colormapName = 'hot';

fprintf('\n============================================================\n');
fprintf(' VASCULAR 2 x 7 PUBLICATION FIGURE\n');
fprintf(' Existing outputs only -- no reconstruction\n');
fprintf('============================================================\n');
fprintf('Replicate          : %d\n',cfg.replicate);
fprintf('Receivers          : %d\n',cfg.numReceivers);
fprintf('Center frequency   : %.1f MHz\n',cfg.centerFrequencyHz/1e6);
fprintf('Fractional BW      : %.0f %%\n',100*cfg.fractionalBandwidth);
fprintf('Element width      : %.3f mm\n',1e3*cfg.elementWidthM);
fprintf('SNR                : %.1f dB\n',cfg.snrDb);
fprintf('Search root        : %s\n\n',cfg.searchRoot);


%% ========================================================================
% 1) FIND ALL SAVED MAT FILES
% ========================================================================

allMat = dir(fullfile(cfg.searchRoot,'**','*.mat'));

assert(~isempty(allMat), ...
    'No MAT files were found under:\n%s',cfg.searchRoot);

fprintf('Found %d MAT files under the output tree.\n',numel(allMat));


%% ========================================================================
% 2) INDEX CANDIDATE VASCULAR OUTPUTS
% ========================================================================

records = struct( ...
    'file','', ...
    'family','', ...
    'replicate',NaN, ...
    'numReceivers',NaN, ...
    'centerFrequencyHz',NaN, ...
    'fractionalBandwidth',NaN, ...
    'elementWidthM',NaN, ...
    'snrDb',NaN, ...
    'method','', ...
    'hasReference',false, ...
    'hasRecon',false);

records = repmat(records,0,1);

fprintf('\nIndexing candidate vascular MAT files...\n');

for k = 1:numel(allMat)

    f = fullfile(allMat(k).folder,allMat(k).name);

    % Fast first filter based on path/name.
    lowPath = lower(f);

    isPotentialVascular = ...
        contains(lowPath,'vascular') || ...
        contains(lowPath,'morph')    || ...
        contains(lowPath,'branch')   || ...
        contains(lowPath,'clutter')  || ...
        contains(lowPath,'fluence')  || ...
        contains(lowPath,'generalization');

    if ~isPotentialVascular
        continue;
    end

    try
        S = load(f);
    catch ME
        warning('Could not load %s\n%s',f,ME.message);
        continue;
    end

    rec = inspectSavedRecord(S,f);

    if rec.hasReference || rec.hasRecon
        records(end+1,1) = rec; %#ok<SAGROW>
    end
end

fprintf('Indexed %d candidate saved records.\n',numel(records));

if isempty(records)
    error([ ...
        'No vascular reconstruction records could be identified.\n' ...
        'The MAT files were found, but their variable names differ from\n' ...
        'the standard candidates used by this display script.\n']);
end


%% ========================================================================
% 3) SELECT THE TWO PAIRED CONDITIONS
% ========================================================================

selected = cell(2,1);

for r = 1:2

    familyWanted = cfg.rowFamilies{r};

    idx = false(numel(records),1);

    for k = 1:numel(records)

        familyOK = contains( ...
            canonicalText(records(k).family), ...
            canonicalText(familyWanted));

        repOK = ...
            isnan(records(k).replicate) || ...
            records(k).replicate == cfg.replicate;

        receiverOK = ...
            isnan(records(k).numReceivers) || ...
            records(k).numReceivers == cfg.numReceivers;

        freqOK = ...
            isnan(records(k).centerFrequencyHz) || ...
            relativeEqual( ...
                records(k).centerFrequencyHz, ...
                cfg.centerFrequencyHz, ...
                1e-3);

        bwOK = ...
            isnan(records(k).fractionalBandwidth) || ...
            relativeEqual( ...
                records(k).fractionalBandwidth, ...
                cfg.fractionalBandwidth, ...
                1e-3);

        widthOK = ...
            isnan(records(k).elementWidthM) || ...
            relativeEqual( ...
                records(k).elementWidthM, ...
                cfg.elementWidthM, ...
                1e-3);

        snrOK = ...
            isnan(records(k).snrDb) || ...
            abs(records(k).snrDb - cfg.snrDb) < 1e-6;

        idx(k) = ...
            familyOK && ...
            repOK && ...
            receiverOK && ...
            freqOK && ...
            bwOK && ...
            widthOK && ...
            snrOK;
    end

    candidates = records(idx);

    if isempty(candidates)
        fprintf('\nNo metadata-perfect match for row "%s".\n',familyWanted);
        fprintf('Trying filename/path matching for the fixed acquisition...\n');

        candidates = records(contains( ...
            lower(string({records.family})), ...
            lower(string(familyWanted))));
    end

    assert(~isempty(candidates), ...
        'Could not locate saved outputs for family "%s".',familyWanted);

    selected{r} = candidates;

    fprintf('\nRow %d: %s\n',r,cfg.rowLabels{r});
    fprintf('  candidate records = %d\n',numel(candidates));

    for q = 1:numel(candidates)
        fprintf('    %s\n',candidates(q).file);
    end
end


%% ========================================================================
% 4) LOAD REFERENCE + SIX RECONSTRUCTIONS
% ========================================================================

rowData = struct;
rowData = repmat(rowData,2,1);

for r = 1:2

    candidates = selected{r};

    % ---------------------------------------------------------------------
    % Reference image
    % ---------------------------------------------------------------------
    p0 = [];

    for k = 1:numel(candidates)

        S = load(candidates(k).file);

        p0tmp = extractReferenceImage(S);

        if ~isempty(p0tmp)
            p0 = p0tmp;
            break;
        end
    end

    assert(~isempty(p0), ...
        'Reference p0 could not be found for row %d (%s).', ...
        r,cfg.rowLabels{r});

    rowData(r).reference = single(p0);

    % ---------------------------------------------------------------------
    % Reconstruction images
    % ---------------------------------------------------------------------
    for m = 1:numel(cfg.methods)

        methodWanted = cfg.methods{m};
        imageFound = [];

        % --------------------------------------------------------------
        % A) Search records whose metadata explicitly names the method.
        % --------------------------------------------------------------
        for k = 1:numel(candidates)

            if strcmpi( ...
                    canonicalMethod(candidates(k).method), ...
                    canonicalMethod(methodWanted))

                S = load(candidates(k).file);

                imageFound = ...
                    extractReconstructionImage(S,methodWanted);

                if ~isempty(imageFound)
                    break;
                end
            end
        end

        % --------------------------------------------------------------
        % B) Some output files contain ALL methods in one MAT file.
        % --------------------------------------------------------------
        if isempty(imageFound)

            for k = 1:numel(candidates)

                S = load(candidates(k).file);

                imageFound = ...
                    extractReconstructionImage(S,methodWanted);

                if ~isempty(imageFound)
                    break;
                end
            end
        end

        assert(~isempty(imageFound), ...
            ['Could not locate saved reconstruction for %s, row %s.\n' ...
             'No reconstruction will be rerun automatically.'], ...
            methodWanted,cfg.rowLabels{r});

        safeName = matlab.lang.makeValidName(methodWanted);

        rowData(r).(safeName) = single(imageFound);
    end
end


%% ========================================================================
% 5) PAIRING AUDIT
% ========================================================================
% Clutter and fluence conditions should originate from the same branching
% vessel geometry within the selected replicate.
%
% We cannot reconstruct that fact from visual appearance. Therefore,
% explicitly report the selected condition and preserve the provenance.

fprintf('\n============================================================\n');
fprintf(' PAIRED-CONDITION AUDIT\n');
fprintf('============================================================\n');
fprintf('Replicate fixed before plotting: %d\n',cfg.replicate);
fprintf('Row 1: branching + clutter\n');
fprintf('Row 2: same-family fluence-surrogate condition\n');
fprintf(['Confirm from the Step-vascular run metadata that both rows share\n' ...
         'the same base vessel geometry for replicate %d.\n'],cfg.replicate);


%% ========================================================================
% 6) DIMENSION CONSISTENCY
% ========================================================================

expectedSize = size(rowData(1).reference);

for r = 1:2

    assert(isequal(size(rowData(r).reference),expectedSize), ...
        'Reference image sizes differ between rows.');

    for m = 1:numel(cfg.methods)

        fieldName = matlab.lang.makeValidName(cfg.methods{m});

        assert( ...
            isequal(size(rowData(r).(fieldName)),expectedSize), ...
            'Image size mismatch: row %d, method %s.', ...
            r,cfg.methods{m});
    end
end

fprintf('\nAll 14 displayed arrays have size %d x %d.\n', ...
    expectedSize(1),expectedSize(2));


%% ========================================================================
% 7) BUILD COMPACT 2 x 7 PUBLICATION FIGURE
%    Layout matched to the compact three-line montage
% ========================================================================

fig = figure( ...
    'Color','w', ...
    'Units','pixels', ...
    'Position',[40 80 2400 680], ...
    'Renderer','painters');

% Much more compact than the previous 2200 x 780 layout.
tl = tiledlayout(fig,2,7, ...
    'TileSpacing','compact', ...
    'Padding','compact');

colormap(fig,cfg.colormapName);

for r = 1:2

    % ================================================================
    % Column 1: reference
    % ================================================================
    ax = nexttile(tl,(r-1)*7 + 1);

    plotDisplayImageCompact( ...
        ax, ...
        rowData(r).reference, ...
        cfg);

    if r == 1
        title(ax,'Reference', ...
            'FontWeight','bold', ...
            'FontSize',15, ...
            'Units','normalized', ...
            'Position',[0.5 1.02 0]);
    end

    % ================================================================
    % Columns 2--7: reconstruction methods
    % ================================================================
    for m = 1:numel(cfg.methods)

        tileIndex = (r-1)*7 + 1 + m;

        ax = nexttile(tl,tileIndex);

        fieldName = matlab.lang.makeValidName(cfg.methods{m});

        plotDisplayImageCompact( ...
            ax, ...
            rowData(r).(fieldName), ...
            cfg);

        if r == 1
            title(ax,cfg.methods{m}, ...
                'FontWeight','bold', ...
                'FontSize',15, ...
                'Units','normalized', ...
                'Position',[0.5 1.02 0]);
        end
    end
end

%% ========================================================================
% 8) ADD COMPACT ROW LABELS
% ========================================================================

annotation(fig,'textbox', ...
    [0.002 0.665 0.035 0.06], ...
    'String','(a)', ...
    'EdgeColor','none', ...
    'FontWeight','bold', ...
    'FontSize',16, ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','middle');

annotation(fig,'textbox', ...
    [0.002 0.205 0.035 0.06], ...
    'String','(b)', ...
    'EdgeColor','none', ...
    'FontWeight','bold', ...
    'FontSize',16, ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','middle');

%% ========================================================================
% 9) EXPORT
% ========================================================================

pngFile = fullfile( ...
    cfg.outDir, ...
    [cfg.figureName '_compact.png']);

pdfFile = fullfile( ...
    cfg.outDir, ...
    [cfg.figureName '_compact.pdf']);

figFile = fullfile( ...
    cfg.outDir, ...
    [cfg.figureName '_compact.fig']);

exportgraphics( ...
    fig, ...
    pngFile, ...
    'Resolution',cfg.pngDPI);

exportgraphics( ...
    fig, ...
    pdfFile, ...
    'ContentType','vector');

savefig(fig,figFile);

fprintf('\nCompact vascular montage saved:\n');
fprintf('PNG : %s\n',pngFile);
fprintf('PDF : %s\n',pdfFile);
fprintf('FIG : %s\n',figFile);


%% ========================================================================
% LOCAL DISPLAY FUNCTION
% ========================================================================

function plotDisplayImageCompact(ax,img,cfg)

    img = double(img);

    if cfg.transposeImages
        img = img.';
    end

    if cfg.useAbsoluteValue
        img = abs(img);
    end

    finiteVals = img(isfinite(img));

    if isempty(finiteVals)
        error('Image contains no finite samples.');
    end

    if cfg.displayPercentile >= 100
        scale = max(finiteVals);
    else
        scale = localPercentile( ...
            finiteVals, ...
            cfg.displayPercentile);
    end

    if ~isfinite(scale) || scale <= 0
        scale = max(abs(finiteVals));
    end

    if ~isfinite(scale) || scale <= 0
        scale = 1;
    end

    % DISPLAY ONLY
    imgDisplay = img ./ scale;
    imgDisplay = max(0,min(1,imgDisplay));

    imagesc(ax,imgDisplay,[0 1]);

    axis(ax,'image');
    axis(ax,'tight');
    axis(ax,'off');

    set(ax, ...
        'YDir','normal', ...
        'Box','off', ...
        'LooseInset',[0 0 0 0]);
end

function rec = inspectSavedRecord(S,filePath)

    rec = struct( ...
        'file',filePath, ...
        'family','', ...
        'replicate',NaN, ...
        'numReceivers',NaN, ...
        'centerFrequencyHz',NaN, ...
        'fractionalBandwidth',NaN, ...
        'elementWidthM',NaN, ...
        'snrDb',NaN, ...
        'method','', ...
        'hasReference',false, ...
        'hasRecon',false);

    % ------------------------------------------------------------
    % Use both metadata and filename/path.
    % ------------------------------------------------------------
    rec.family = firstTextValue(S,{ ...
        'family', ...
        'source_family', ...
        'sourceFamily', ...
        'morphology', ...
        'phantom_type', ...
        'phantomType', ...
        'source_type'});

    if isempty(rec.family)
        rec.family = inferFamilyFromPath(filePath);
    end

    rec.method = firstTextValue(S,{ ...
        'method', ...
        'algorithm', ...
        'reconstruction_method', ...
        'reconstructionMethod'});

    if isempty(rec.method)
        rec.method = inferMethodFromPath(filePath);
    end

    rec.replicate = firstNumericValue(S,{ ...
        'replicate', ...
        'replicate_id', ...
        'replicateId', ...
        'realization', ...
        'realization_id'});

    if isnan(rec.replicate)
        rec.replicate = inferReplicateFromPath(filePath);
    end

    rec.numReceivers = firstNumericValue(S,{ ...
        'num_receivers', ...
        'numReceivers', ...
        'NumTransducers', ...
        'num_channels', ...
        'nChannels'});

    rec.centerFrequencyHz = firstNumericValue(S,{ ...
        'center_frequency_hz', ...
        'centerFrequencyHz', ...
        'CenterFrequency', ...
        'frequency_hz', ...
        'fc'});

    % If stored in MHz rather than Hz.
    if isfinite(rec.centerFrequencyHz) && ...
            rec.centerFrequencyHz > 0 && ...
            rec.centerFrequencyHz < 100
        rec.centerFrequencyHz = ...
            rec.centerFrequencyHz * 1e6;
    end

    rec.fractionalBandwidth = firstNumericValue(S,{ ...
        'fractional_bandwidth', ...
        'fractionalBandwidth', ...
        'FractionalBandwidth', ...
        'bandwidth_fraction'});

    if isfinite(rec.fractionalBandwidth) && ...
            rec.fractionalBandwidth > 1
        rec.fractionalBandwidth = ...
            rec.fractionalBandwidth / 100;
    end

    rec.elementWidthM = firstNumericValue(S,{ ...
        'element_width_m', ...
        'elementWidthM', ...
        'ElementWidth', ...
        'receiver_width_m'});

    rec.snrDb = firstNumericValue(S,{ ...
        'snr_db', ...
        'snrDb', ...
        'SNR_dB', ...
        'target_snr_db'});

    rec.hasReference = ...
        ~isempty(extractReferenceImage(S));

    if ~isempty(rec.method)
        rec.hasRecon = ...
            ~isempty(extractReconstructionImage(S,rec.method));
    else
        % A MAT file may contain all reconstructions in one structure.
        rec.hasRecon = ...
            hasAnyReconstruction(S);
    end
end


function img = extractReferenceImage(S)

    img = [];

    candidates = { ...
        'p0_reference', ...
        'p0Reference', ...
        'p0', ...
        'initial_pressure', ...
        'initialPressure', ...
        'reference', ...
        'reference_image', ...
        'ground_truth', ...
        'groundTruth'};

    img = searchNumericImageRecursive(S,candidates,0);

    if isempty(img) && isfield(S,'sim')
        img = searchNumericImageRecursive( ...
            S.sim,candidates,0);
    end
end


function img = extractReconstructionImage(S,method)

    img = [];

    methodCanon = canonicalMethod(method);

    % ------------------------------------------------------------
    % 1) Direct field names.
    % ------------------------------------------------------------
    aliases = methodAliases(methodCanon);

    for k = 1:numel(aliases)

        fld = aliases{k};

        if isfield(S,fld) && isImageArray(S.(fld))
            img = S.(fld);
            return;
        end
    end

    % ------------------------------------------------------------
    % 2) Common generic image variable, when this MAT represents
    %    one reconstruction method.
    % ------------------------------------------------------------
    storedMethod = firstTextValue(S,{ ...
        'method', ...
        'algorithm', ...
        'reconstruction_method', ...
        'reconstructionMethod'});

    if strcmpi( ...
            canonicalMethod(storedMethod), ...
            methodCanon)

        genericCandidates = { ...
            'image', ...
            'recon', ...
            'reconstruction', ...
            'recon_image', ...
            'reconImage', ...
            'p_recon', ...
            'result'};

        img = searchNumericImageRecursive( ...
            S,genericCandidates,0);

        if ~isempty(img)
            return;
        end
    end

    % ------------------------------------------------------------
    % 3) Structures such as:
    %       recons.DAS
    %       reconstructions.CF_DAS
    %       images.TR
    % ------------------------------------------------------------
    containerNames = { ...
        'recons', ...
        'reconstructions', ...
        'images', ...
        'results', ...
        'reconstructionImages'};

    for c = 1:numel(containerNames)

        if ~isfield(S,containerNames{c})
            continue;
        end

        C = S.(containerNames{c});

        if ~isstruct(C)
            continue;
        end

        fields = fieldnames(C);

        for q = 1:numel(fields)

            if strcmpi( ...
                    canonicalMethod(fields{q}), ...
                    methodCanon)

                val = C.(fields{q});

                if isImageArray(val)
                    img = val;
                    return;
                elseif isstruct(val)
                    img = searchNumericImageRecursive( ...
                        val, ...
                        {'image','recon','reconstruction','data'}, ...
                        0);

                    if ~isempty(img)
                        return;
                    end
                end
            end
        end
    end

    % ------------------------------------------------------------
    % 4) Last-resort recursive search for a field carrying method name.
    % ------------------------------------------------------------
    img = findMethodImageRecursive(S,methodCanon,0);
end


function tf = hasAnyReconstruction(S)

    methodList = { ...
        'DAS','CF-DAS','SCF-DAS', ...
        'DMAS','DS-DMAS','TR'};

    tf = false;

    for k = 1:numel(methodList)
        if ~isempty( ...
                extractReconstructionImage(S,methodList{k}))
            tf = true;
            return;
        end
    end
end


function value = firstTextValue(S,names)

    value = '';

    for k = 1:numel(names)

        found = findFieldRecursive(S,names{k},0);

        if isempty(found)
            continue;
        end

        if ischar(found)
            value = found;
            return;
        elseif isstring(found) && isscalar(found)
            value = char(found);
            return;
        elseif iscategorical(found) && isscalar(found)
            value = char(string(found));
            return;
        end
    end
end


function value = firstNumericValue(S,names)

    value = NaN;

    for k = 1:numel(names)

        found = findFieldRecursive(S,names{k},0);

        if isempty(found)
            continue;
        end

        if isnumeric(found) && isscalar(found)
            value = double(found);
            return;
        end
    end
end


function out = findFieldRecursive(S,targetName,depth)

    out = [];

    if depth > 4 || ~isstruct(S)
        return;
    end

    fields = fieldnames(S);

    for k = 1:numel(fields)

        fld = fields{k};

        if strcmpi(fld,targetName)
            out = S.(fld);
            return;
        end
    end

    for k = 1:numel(fields)

        val = S.(fields{k});

        if isstruct(val) && isscalar(val)

            out = findFieldRecursive( ...
                val,targetName,depth+1);

            if ~isempty(out)
                return;
            end
        end
    end
end


function img = searchNumericImageRecursive(S,names,depth)

    img = [];

    if depth > 4 || ~isstruct(S)
        return;
    end

    fields = fieldnames(S);

    for n = 1:numel(names)

        for k = 1:numel(fields)

            if strcmpi(fields{k},names{n})

                candidate = S.(fields{k});

                if isImageArray(candidate)
                    img = candidate;
                    return;
                end
            end
        end
    end

    for k = 1:numel(fields)

        val = S.(fields{k});

        if isstruct(val) && isscalar(val)

            img = searchNumericImageRecursive( ...
                val,names,depth+1);

            if ~isempty(img)
                return;
            end
        end
    end
end


function img = findMethodImageRecursive(S,methodCanon,depth)

    img = [];

    if depth > 4 || ~isstruct(S)
        return;
    end

    fields = fieldnames(S);

    for k = 1:numel(fields)

        fldCanon = canonicalMethod(fields{k});

        if strcmpi(fldCanon,methodCanon)

            val = S.(fields{k});

            if isImageArray(val)
                img = val;
                return;
            elseif isstruct(val)
                img = searchNumericImageRecursive( ...
                    val, ...
                    {'image','recon','reconstruction','data'}, ...
                    0);

                if ~isempty(img)
                    return;
                end
            end
        end
    end

    for k = 1:numel(fields)

        val = S.(fields{k});

        if isstruct(val) && isscalar(val)

            img = findMethodImageRecursive( ...
                val,methodCanon,depth+1);

            if ~isempty(img)
                return;
            end
        end
    end
end


function tf = isImageArray(x)

    tf = ...
        isnumeric(x) && ...
        ismatrix(x) && ...
        numel(x) >= 64 && ...
        size(x,1) > 4 && ...
        size(x,2) > 4;
end


function aliases = methodAliases(methodCanon)

    switch methodCanon

        case 'DAS'
            aliases = { ...
                'DAS','das', ...
                'recon_DAS','recon_das', ...
                'image_DAS','image_das'};

        case 'CF-DAS'
            aliases = { ...
                'CF_DAS','CFDAS','cf_das','cfdas', ...
                'recon_CF_DAS','image_CF_DAS'};

        case 'SCF-DAS'
            aliases = { ...
                'SCF_DAS','SCFDAS','scf_das','scfdas', ...
                'recon_SCF_DAS','image_SCF_DAS'};

        case 'DMAS'
            aliases = { ...
                'DMAS','dmas', ...
                'recon_DMAS','image_DMAS'};

        case 'DS-DMAS'
            aliases = { ...
                'DS_DMAS','DSDMAS','ds_dmas','dsdmas', ...
                'recon_DS_DMAS','image_DS_DMAS'};

        case 'TR'
            aliases = { ...
                'TR','tr', ...
                'TimeReversal','timeReversal', ...
                'time_reversal', ...
                'recon_TR','image_TR'};

        otherwise
            aliases = {methodCanon};
    end
end


function out = canonicalMethod(in)

    if isempty(in)
        out = '';
        return;
    end

    out = upper(char(string(in)));

    out = strrep(out,'_','');
    out = strrep(out,'-','');
    out = strrep(out,' ','');
    out = strrep(out,'RECON','');
    out = strrep(out,'IMAGE','');

    switch out
        case 'CFDAS'
            out = 'CF-DAS';
        case 'SCFDAS'
            out = 'SCF-DAS';
        case 'DSDMAS'
            out = 'DS-DMAS';
        case {'TIMEREVERSAL','TR'}
            out = 'TR';
        case 'DAS'
            out = 'DAS';
        case 'DMAS'
            out = 'DMAS';
    end
end


function family = inferFamilyFromPath(filePath)

    p = canonicalText(filePath);

    if contains(p,'clutter')
        family = 'clutter';

    elseif contains(p,'fluence')
        family = 'fluence';

    elseif contains(p,'branch')
        family = 'branching';

    elseif contains(p,'sparse')
        family = 'sparse';

    else
        family = '';
    end
end


function method = inferMethodFromPath(filePath)

    p = canonicalText(filePath);

    % Order matters: SCF-DAS and CF-DAS before DAS.
    if contains(p,'scfdas')
        method = 'SCF-DAS';

    elseif contains(p,'cfdas')
        method = 'CF-DAS';

    elseif contains(p,'dsdmas')
        method = 'DS-DMAS';

    elseif contains(p,'dmas')
        method = 'DMAS';

    elseif contains(p,'timereversal') || ...
            contains(p,'recontr') || ...
            contains(p,'_tr_')
        method = 'TR';

    elseif contains(p,'das')
        method = 'DAS';

    else
        method = '';
    end
end


function rep = inferReplicateFromPath(filePath)

    rep = NaN;

    p = lower(filePath);

    patterns = { ...
        'replicate[_\-]?(\d+)', ...
        'rep[_\-]?(\d+)', ...
        'realization[_\-]?(\d+)', ...
        'real[_\-]?(\d+)'};

    for k = 1:numel(patterns)

        token = regexp( ...
            p,patterns{k},'tokens','once');

        if ~isempty(token)
            rep = str2double(token{1});
            return;
        end
    end
end


function out = canonicalText(in)

    out = lower(char(string(in)));

    out = regexprep(out,'[^a-z0-9]','');
end


function tf = relativeEqual(a,b,tol)

    tf = ...
        abs(a-b) <= ...
        tol * max([abs(a),abs(b),1]);
end


function q = localPercentile(x,p)

    x = sort(double(x(:)));

    x = x(isfinite(x));

    if isempty(x)
        q = NaN;
        return;
    end

    if numel(x) == 1
        q = x;
        return;
    end

    p = max(0,min(100,p));

    pos = 1 + (numel(x)-1)*(p/100);

    lo = floor(pos);
    hi = ceil(pos);

    if lo == hi
        q = x(lo);
    else
        w = pos-lo;
        q = ...
            (1-w)*x(lo) + ...
            w*x(hi);
    end
end