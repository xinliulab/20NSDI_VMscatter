function antennaSC = vmscatterHTDataSubcarriers(waveform, cfgHT)
%VMSCATTERHTDATASUBCARRIERS Extract actual antenna-domain HT-Data tones.
%   Output dimensions are 2-by-Nsd-by-Nsym. The extraction is performed
%   from the generated time-domain waveform, after cyclic shift and direct
%   spatial mapping, so it is in the same antenna coordinate system in
%   which the tag applies its reflection coefficients.

vmscatterValidateHTConfig(cfgHT, 2);
validateattributes(waveform, {'double'}, {'2d', 'finite', 'nonempty'}, ...
    mfilename, 'waveform');
if size(waveform, 2) ~= 2
    error('VMScatter:InvalidWaveformDimensions', ...
        'The HT waveform must contain two transmit-antenna columns.');
end

ind = wlanFieldIndices(cfgHT);
if size(waveform, 1) < ind.HTData(2)
    error('VMScatter:ShortWaveform', 'The waveform does not contain a complete HT-Data field.');
end

info = wlanHTOFDMInfo('HT-Data', cfgHT);
symbolLength = info.FFTLength + info.CPLength;
htData = waveform(ind.HTData(1):ind.HTData(2), :);
numSymbols = floor(size(htData, 1) / symbolLength);
if numSymbols < 1
    error('VMScatter:NoHTDataSymbols', 'No complete HT-Data OFDM symbol was found.');
end
htData = htData(1:numSymbols * symbolLength, :);

fftGrid = ofdmdemod(htData, info.FFTLength, info.CPLength, info.CPLength);
dataFFTIndices = info.ActiveFFTIndices(info.DataIndices);
dataSC = fftGrid(dataFFTIndices, :, :);
% wlanWaveformGenerator scales HT-Data by Nfft/sqrt(Nsts*Ntones).
dataSC = dataSC / (info.FFTLength / sqrt(cfgHT.NumSpaceTimeStreams * info.NumTones));
antennaSC = permute(dataSC, [3 1 2]);
end
