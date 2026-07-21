function p0_recon = finalizeReconImage(p0_recon, envelope_signal, remove_negatives, depth_dim)
%FINALIZERECONIMAGE Post-process a beamformed reconstruction image.
%
%   Envelope is applied after reconstruction along the depth axis (dim 1),
%   so beamforming stays on bipolar RF data and Hilbert is used for display.

    if nargin < 4 || isempty(depth_dim)
        depth_dim = 1;
    end

    if envelope_signal
        p0_recon = applyDepthEnvelope(p0_recon, depth_dim);
    end

    if remove_negatives
        p0_recon(p0_recon < 0) = 0;
    end
end

function img = applyDepthEnvelope(img, depth_dim)
    if depth_dim == 1
        for col = 1:size(img, 2)
            img(:, col) = abs(hilbert(img(:, col)));
        end
        return;
    end

    if depth_dim == 2
        for row = 1:size(img, 1)
            img(row, :) = abs(hilbert(img(row, :).')).';
        end
        return;
    end

    error('PATBox:InvalidDepthDim', 'depth_dim must be 1 or 2.');
end
