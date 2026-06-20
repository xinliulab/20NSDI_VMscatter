function antennaSC = vmscatterHTStreamsToAntennas(streamSC, cfgHT)
%VMSCATTERHTSTREAMSTOANTENNAS Apply HT cyclic shifts to equalized streams.
%   The validated Direct-mapping 2x2 profile has cyclic shifts [0 -8]
%   samples. Applying their frequency-domain phase rotations converts the
%   equalized spatial-stream symbols to the antenna coordinate system.

vmscatterValidateHTConfig(cfgHT, 2);
validateattributes(streamSC, {'double'}, {'3d', 'finite', 'nonempty'}, ...
    mfilename, 'streamSC');
if size(streamSC, 3) ~= 2
    error('VMScatter:InvalidStreamDimensions', ...
        'Equalized HT symbols must have dimensions Nsd-by-Nsym-by-2.');
end

info = wlanHTOFDMInfo('HT-Data', cfgHT);
if size(streamSC, 1) ~= numel(info.DataIndices)
    error('VMScatter:InvalidSubcarrierCount', ...
        'Expected %d HT data subcarriers, received %d.', ...
        numel(info.DataIndices), size(streamSC, 1));
end

dataFFTIndices = info.ActiveFFTIndices(info.DataIndices);
k = dataFFTIndices - info.FFTLength / 2 - 1;
cyclicShiftSamples = [0; -8]; % IEEE 802.11 HT/VHT per-STS shifts at 20 MHz

shifted = streamSC;
for streamIndex = 1:2
    phase = exp(-1i * 2 * pi * cyclicShiftSamples(streamIndex) .* ...
        k / info.FFTLength);
    shifted(:, :, streamIndex) = streamSC(:, :, streamIndex) .* phase;
end

% Direct spatial mapping is the identity for the validated 2x2 profile.
antennaSC = permute(shifted, [3 1 2]);
end
