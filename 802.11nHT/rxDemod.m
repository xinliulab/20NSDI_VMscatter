function [rxPSDU, rxDataSubcarrier, detectionError, diagnostics] = rxDemod( ...
    rx, cfgHT, varargin)
%RXDEMOD Synchronize and recover an HT packet using R2024b public APIs.

parser = inputParser;
addParameter(parser, 'EqualizationMethod', 'ZF', ...
    @(x) any(strcmpi(x, {'ZF', 'MMSE'})));
parse(parser, varargin{:});
equalizationMethod = upper(string(parser.Results.EqualizationMethod));

rxPSDU = [];
rxDataSubcarrier = [];
detectionError = true;
diagnostics = struct('reason', "", 'packetOffset', NaN, ...
    'coarseFrequencyOffset', NaN, 'fineFrequencyOffset', NaN, ...
    'noiseVariance', NaN, 'equalizationMethod', equalizationMethod, ...
    'dataSubcarrierReliability', []);

coarsePacketOffset = wlanPacketDetect(rx, cfgHT.ChannelBandwidth);
if isempty(coarsePacketOffset)
    diagnostics.reason = "L-STF packet detection failed.";
    return;
end

sampleRate = wlanSampleRate(cfgHT);
ind = wlanFieldIndices(cfgHT);
if coarsePacketOffset + ind.LSIG(2) > size(rx, 1)
    diagnostics.reason = "The detected packet is truncated before L-SIG.";
    return;
end

lstf = rx(coarsePacketOffset + (ind.LSTF(1):ind.LSTF(2)), :);
diagnostics.coarseFrequencyOffset = ...
    wlanCoarseCFOEstimate(lstf, cfgHT.ChannelBandwidth);
rx = frequencyOffset(rx, sampleRate, -diagnostics.coarseFrequencyOffset);

nonHTFields = rx(coarsePacketOffset + (ind.LSTF(1):ind.LSIG(2)), :);
finePacketOffset = wlanSymbolTimingEstimate(nonHTFields, cfgHT.ChannelBandwidth);
packetOffset = coarsePacketOffset + finePacketOffset;
diagnostics.packetOffset = packetOffset;
if packetOffset + ind.LLTF(1) < 1 || packetOffset + ind.HTData(2) > size(rx, 1)
    diagnostics.reason = "The synchronized packet is outside the received buffer.";
    return;
end

lltf = rx(packetOffset + (ind.LLTF(1):ind.LLTF(2)), :);
diagnostics.fineFrequencyOffset = wlanFineCFOEstimate(lltf, cfgHT.ChannelBandwidth);
rx = frequencyOffset(rx, sampleRate, -diagnostics.fineFrequencyOffset);

lltf = rx(packetOffset + (ind.LLTF(1):ind.LLTF(2)), :);
lltfDemod = wlanLLTFDemodulate(lltf, cfgHT.ChannelBandwidth);
diagnostics.noiseVariance = max(wlanLLTFNoiseEstimate(lltfDemod), eps);

htltf = rx(packetOffset + (ind.HTLTF(1):ind.HTLTF(2)), :);
htltfDemod = wlanHTLTFDemodulate(htltf, cfgHT);
channelEstimate = wlanHTLTFChannelEstimate(htltfDemod, cfgHT);
diagnostics.dataSubcarrierReliability = ...
    calculateSubcarrierReliability(channelEstimate, cfgHT);
htdata = rx(packetOffset + (ind.HTData(1):ind.HTData(2)), :);

[rxPSDU, rxDataSubcarrier] = wlanHTDataRecover( ...
    htdata, channelEstimate, diagnostics.noiseVariance, cfgHT, ...
    'EqualizationMethod', char(equalizationMethod), ...
    'PilotPhaseTracking', 'None', ...
    'PilotAmplitudeTracking', 'None');

detectionError = false;
diagnostics.reason = "";
end

function reliability = calculateSubcarrierReliability(channelEstimate, cfgHT)
% A low minimum singular value identifies a tone on which ZF strongly
% amplifies noise. Normalize the weights so their mean is one.
info = wlanHTOFDMInfo('HT-Data', cfgHT);
dataChannel = channelEstimate(info.DataIndices, :, :);
numDataTones = size(dataChannel, 1);
reliability = zeros(numDataTones, 1);
for toneIndex = 1:numDataTones
    channel = squeeze(dataChannel(toneIndex, :, :));
    singularValues = svd(channel);
    reliability(toneIndex) = min(singularValues).^2;
end
reliability = reliability ./ max(mean(reliability), eps);
reliability = min(max(reliability, 1e-3), 10);
end
