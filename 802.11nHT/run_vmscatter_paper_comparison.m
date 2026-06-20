function report = run_vmscatter_paper_comparison(varargin)
%RUN_VMSCATTER_PAPER_COMPARISON Compare 2x2x2 and 2x4x4 VMscatter modes.
%   Both architectures occupy the same number of HT-Data OFDM symbols.
%   LowBER carries one tag bit per data symbol. HighThroughput carries K
%   tag bits per 8-us tag slot (two HT OFDM symbols), matching the
%   prototype's 125/250/500 kbps rate scale and T=0 in paper Eqn. 16.
%   ReferenceRepeats applies only to the K-1 explicit states. The all-ones
%   baseline operator is supplied by conventional HT-LTF equalization.

parser = inputParser;
addParameter(parser, 'SNR', 2:10, @(x) isnumeric(x) && isvector(x));
addParameter(parser, 'ReferenceRepeats', 4, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 1 && fix(x) == x);
addParameter(parser, 'MinBits', 1e5, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 256);
addParameter(parser, 'MaxBits', 2e6, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 256);
addParameter(parser, 'TargetErrors', 200, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(parser, 'PSDULength', 2000, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 1 && fix(x) == x);
addParameter(parser, 'MCS', 8, ...
    @(x) isnumeric(x) && isscalar(x) && ismember(x, 8:15));
addParameter(parser, 'Mode', 'LowBER', ...
    @(x) any(strcmpi(string(x), ["LowBER", "HighThroughput"])));
addParameter(parser, 'NumDataSymbols', 256, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 1 && fix(x) == x);
addParameter(parser, 'Seed', 2020, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x));
addParameter(parser, 'Plot', true, @(x) islogical(x) && isscalar(x));
parse(parser, varargin{:});
options = parser.Results;
options.Mode = validatestring(options.Mode, {'LowBER', 'HighThroughput'});

if options.MaxBits < options.MinBits
    error('VMScatter:InvalidBitBudget', ...
        'MaxBits must be greater than or equal to MinBits.');
end

config222 = architectureConfig(2, 2, options);
config244 = architectureConfig(4, 4, options);

results222 = simulateArchitecture(config222, options);
results244 = simulateArchitecture(config244, options);

comparison = table(results222.SNRdB, ...
    results222.ConditionalBER, results222.ConditionalBERLower95, ...
    results222.ConditionalBERUpper95, ...
    results244.ConditionalBER, results244.ConditionalBERLower95, ...
    results244.ConditionalBERUpper95, ...
    results222.EndToEndBER, results244.EndToEndBER, ...
    results222.AcquisitionFailureRate, results244.AcquisitionFailureRate, ...
    'VariableNames', {'SNRdB', ...
    'BER222', 'BER222Lower95', 'BER222Upper95', ...
    'BER244', 'BER244Lower95', 'BER244Upper95', ...
    'EndToEndBER222', 'EndToEndBER244', ...
    'AcquisitionFailure222', 'AcquisitionFailure244'});
comparison.BER222Percent = 100 * comparison.BER222;
comparison.BER244Percent = 100 * comparison.BER244;

rateTable = table( ...
    ["2x2x2"; "2x4x4"], ...
    [config222.numTag; config244.numTag], ...
    [config222.numCodewords; config244.numCodewords], ...
    [config222.numReferenceSymbols; config244.numReferenceSymbols], ...
    [config222.numDataSymbols; config244.numDataSymbols], ...
    [config222.referenceOverheadFraction; config244.referenceOverheadFraction], ...
    [config222.rawTagRateKbps; config244.rawTagRateKbps], ...
    [mean(results222.NetGoodputKbps); mean(results244.NetGoodputKbps)], ...
    'VariableNames', {'Architecture', 'TagAntennas', 'CodewordsPerPacket', ...
    'ReferenceSymbols', 'DataSymbols', 'ReferenceOverheadFraction', ...
    'RawTagRateKbps', 'MeanNetGoodputKbps'});

slope222 = estimateDiversitySlope(results222);
slope244 = estimateDiversitySlope(results244);
strictlyBetter = results244.ConditionalBERUpper95 < ...
    results222.ConditionalBERLower95;

report = struct;
report.results222 = results222;
report.results244 = results244;
report.comparison = comparison;
report.rateTable = rateTable;
report.diversitySlope222 = slope222;
report.diversitySlope244 = slope244;
report.consecutiveStrictWins244 = longestRun(strictlyBetter);
report.meanGoodputGain244 = mean(results244.NetGoodputKbps) / ...
    max(mean(results222.NetGoodputKbps), eps);
if strcmpi(options.Mode, 'LowBER')
    report.successCriterion = report.consecutiveStrictWins244 >= 3 && ...
        slope244 < slope222;
else
    % High-throughput mode trades diversity for K bits per tag slot.
    % Its acceptance criterion is higher delivered goodput, not lower BER.
    report.successCriterion = report.meanGoodputGain244 > 1;
end
report.settings = options;
report.mode = string(options.Mode);

if options.Plot
    plotComparison(report);
end
end

function config = architectureConfig(numTag, numRx, options)
config = struct;
config.numTx = 2;
config.numTag = numTag;
config.numRx = numRx;
if strcmpi(options.Mode, 'LowBER')
    config.symbolsPerCodeword = numTag;
else
    config.symbolsPerCodeword = 2;
end
if mod(options.NumDataSymbols, config.symbolsPerCodeword) ~= 0
    error('VMScatter:InvalidDataSymbolBudget', ...
        'NumDataSymbols must be divisible by symbols per codeword.');
end
config.numCodewords = options.NumDataSymbols / config.symbolsPerCodeword;
config.bitsPerPacket = numTag * config.numCodewords;
config.numDataSymbols = options.NumDataSymbols;
config.numReferenceSymbols = (numTag - 1) * options.ReferenceRepeats;
config.referenceOverheadFraction = config.numReferenceSymbols / ...
    (config.numReferenceSymbols + config.numDataSymbols);
config.rawTagRateKbps = ...
    (numTag / config.symbolsPerCodeword) / 4e-6 / 1e3;
config.name = sprintf('2x%dx%d', numTag, numRx);
config.mode = string(options.Mode);
end

function results = simulateArchitecture(config, options)
snrValues = options.SNR(:);
numPoints = numel(snrValues);
conditionalErrors = zeros(numPoints, 1);
conditionalBits = zeros(numPoints, 1);
endToEndErrors = zeros(numPoints, 1);
transmittedBits = zeros(numPoints, 1);
packetCount = zeros(numPoints, 1);
acquisitionFailures = zeros(numPoints, 1);
decoderFailures = zeros(numPoints, 1);
codewordErrors = zeros(numPoints, 1);
referenceResidualSum = zeros(numPoints, 1);
referenceResidualCount = zeros(numPoints, 1);

cfgHT = wlanHTConfig( ...
    'ChannelBandwidth', 'CBW20', ...
    'NumTransmitAntennas', config.numTx, ...
    'NumSpaceTimeStreams', config.numTx, ...
    'PSDULength', options.PSDULength, ...
    'MCS', options.MCS, ...
    'ChannelCoding', 'BCC', ...
    'SpatialMapping', 'Direct');
vmscatterValidateHTConfig(cfgHT, config.numTag);
sampleRate = wlanSampleRate(cfgHT);
fieldIndices = wlanFieldIndices(cfgHT);

% Verify that the selected HT packet can carry the complete tag schedule.
[~, ~, templateSchedule] = vmscatterBuildPacketSchedule( ...
    config.numTag, config.numCodewords, options.ReferenceRepeats, ...
    'Mode', options.Mode);
ofdmInfo = wlanHTOFDMInfo('HT-Data', cfgHT);
availableSymbols = floor((fieldIndices.HTData(2) - fieldIndices.HTData(1) + 1) / ...
    (ofdmInfo.FFTLength + ofdmInfo.CPLength));
if availableSymbols < templateSchedule.numSymbols
    error('VMScatter:PacketTooShort', ...
        '%s needs %d HT-Data symbols, but PSDULength=%d provides %d.', ...
        config.name, templateSchedule.numSymbols, ...
        options.PSDULength, availableSymbols);
end

for snrIndex = 1:numPoints
    rng(options.Seed + snrIndex * 10000 + config.numTag, 'twister');
    dataStream = RandStream('mt19937ar', ...
        'Seed', options.Seed + snrIndex * 10000);
    preChannel = makeChannel(config.numTx, config.numTag, sampleRate);
    postChannel = makeChannel(config.numTag, config.numRx, sampleRate);

    while transmittedBits(snrIndex) < options.MinBits || ...
            (endToEndErrors(snrIndex) < options.TargetErrors && ...
             transmittedBits(snrIndex) < options.MaxBits)
        reset(preChannel);
        reset(postChannel);
        txPSDU = randi(dataStream, [0 1], cfgHT.PSDULength * 8, 1);
        tagVector = randi(dataStream, [0 1], config.bitsPerPacket, 1);
        packetTagBits = reshape(tagVector, config.numTag, []).';
        tx = wlanWaveformGenerator(txPSDU, cfgHT, ...
            'WindowTransitionTime', 0);
        txSC = vmscatterHTDataSubcarriers(tx, cfgHT);
        preTagWaveform = preChannel([tx; zeros(64, config.numTx)]);
        [taggedWaveform, txTagBits, schedule] = VMscatterModPacket( ...
            preTagWaveform, fieldIndices, config.numTag, cfgHT, ...
            'NumCodewords', config.numCodewords, ...
            'ReferenceRepeats', options.ReferenceRepeats, ...
            'TagBits', packetTagBits, ...
            'Mode', options.Mode);
        rx = postChannel(taggedWaveform);
        rx = vmscatterAddMeasuredNoise(rx, snrValues(snrIndex));
        [~, rxStreams, detectionError, rxDiagnostics] = rxDemod( ...
            rx, cfgHT, 'EqualizationMethod', 'ZF');

        packetCount(snrIndex) = packetCount(snrIndex) + 1;
        transmittedBits(snrIndex) = transmittedBits(snrIndex) + ...
            config.bitsPerPacket;

        if detectionError || isempty(rxStreams)
            acquisitionFailures(snrIndex) = ...
                acquisitionFailures(snrIndex) + 1;
            endToEndErrors(snrIndex) = endToEndErrors(snrIndex) + ...
                config.bitsPerPacket;
            continue;
        end

        rxSC = vmscatterHTStreamsToAntennas(rxStreams, cfgHT);
        [rxTagBits, success, decodeDiagnostics] = VMscatterDeModPacket( ...
            txSC, rxSC, schedule, cfgHT, ...
            'SubcarrierWeights', ...
            rxDiagnostics.dataSubcarrierReliability);
        if ~success
            decoderFailures(snrIndex) = decoderFailures(snrIndex) + 1;
            endToEndErrors(snrIndex) = endToEndErrors(snrIndex) + ...
                config.bitsPerPacket;
            continue;
        end

        bitErrors = sum(txTagBits(:) ~= rxTagBits(:));
        wordErrors = sum(any(txTagBits ~= rxTagBits, 2));
        conditionalErrors(snrIndex) = conditionalErrors(snrIndex) + bitErrors;
        conditionalBits(snrIndex) = conditionalBits(snrIndex) + ...
            config.bitsPerPacket;
        endToEndErrors(snrIndex) = endToEndErrors(snrIndex) + bitErrors;
        codewordErrors(snrIndex) = codewordErrors(snrIndex) + wordErrors;

        for blockIndex = 1:numel(decodeDiagnostics.referenceBlocks)
            residuals = ...
                decodeDiagnostics.referenceBlocks{blockIndex}.referenceResiduals;
            % Entry one is the ideal LTF baseline operator I, not an
            % explicitly estimated HT-Data reference. Report only measured
            % explicit-reference residuals.
            residuals = residuals(2:end);
            referenceResidualSum(snrIndex) = ...
                referenceResidualSum(snrIndex) + sum(residuals);
            referenceResidualCount(snrIndex) = ...
                referenceResidualCount(snrIndex) + numel(residuals);
        end
    end
end

conditionalBER = conditionalErrors ./ max(conditionalBits, 1);
conditionalBER(conditionalBits == 0) = NaN;
endToEndBER = endToEndErrors ./ transmittedBits;
conditionalLower = nan(numPoints, 1);
conditionalUpper = nan(numPoints, 1);
endToEndLower = nan(numPoints, 1);
endToEndUpper = nan(numPoints, 1);
for index = 1:numPoints
    [conditionalLower(index), conditionalUpper(index)] = ...
        vmscatterBinomialCI(conditionalErrors(index), conditionalBits(index));
    [endToEndLower(index), endToEndUpper(index)] = ...
        vmscatterBinomialCI(endToEndErrors(index), transmittedBits(index));
end

symbolDuration = 4e-6;
correctBits = transmittedBits - endToEndErrors;
totalSymbols = packetCount .* ...
    (config.numReferenceSymbols + config.numDataSymbols);
netGoodputKbps = correctBits ./ (totalSymbols * symbolDuration) / 1e3;

results = table(snrValues, packetCount, transmittedBits, ...
    conditionalBits, conditionalErrors, conditionalBER, ...
    conditionalLower, conditionalUpper, ...
    endToEndErrors, endToEndBER, endToEndLower, endToEndUpper, ...
    acquisitionFailures ./ packetCount, decoderFailures ./ packetCount, ...
    codewordErrors, ...
    referenceResidualSum ./ max(referenceResidualCount, 1), ...
    netGoodputKbps, ...
    'VariableNames', {'SNRdB', 'Packets', 'TransmittedBits', ...
    'DecodedBits', 'ConditionalBitErrors', 'ConditionalBER', ...
    'ConditionalBERLower95', 'ConditionalBERUpper95', ...
    'EndToEndBitErrors', 'EndToEndBER', ...
    'EndToEndBERLower95', 'EndToEndBERUpper95', ...
    'AcquisitionFailureRate', 'DecoderFailureRate', ...
    'CodewordErrors', 'MeanReferenceResidual', 'NetGoodputKbps'});
results.ConditionalBERPercent = 100 * results.ConditionalBER;
results.EndToEndBERPercent = 100 * results.EndToEndBER;
end

function channel = makeChannel(numTx, numRx, sampleRate)
channel = wlanTGnChannel( ...
    'DelayProfile', 'Model-A', ...
    'NumTransmitAntennas', numTx, ...
    'NumReceiveAntennas', numRx, ...
    'TransmitReceiveDistance', 3, ...
    'EnvironmentalSpeed', 0, ...
    'LargeScaleFadingEffect', 'None', ...
    'NormalizeChannelOutputs', false, ...
    'SampleRate', sampleRate, ...
    'RandomStream', 'Global stream');
end

function slope = estimateDiversitySlope(results)
effectiveBER = (results.ConditionalBitErrors + 0.5) ./ ...
    (results.DecodedBits + 1);
valid = results.DecodedBits > 0 & results.AcquisitionFailureRate < 0.2;
indices = find(valid);
if numel(indices) < 2
    slope = NaN;
    return;
end
startIndex = max(1, numel(indices) - 3);
indices = indices(startIndex:end);
fitResult = polyfit(results.SNRdB(indices), log10(effectiveBER(indices)), 1);
slope = fitResult(1);
end

function count = longestRun(values)
count = 0;
current = 0;
for index = 1:numel(values)
    if values(index)
        current = current + 1;
        count = max(count, current);
    else
        current = 0;
    end
end
end

function plotComparison(report)
comparison = report.comparison;
figure;
tiledlayout(2, 2);
modeLabel = char(report.mode);

nexttile;
semilogy(comparison.SNRdB, comparison.BER222Upper95, '-o', ...
    comparison.SNRdB, comparison.BER244Upper95, '-s');
grid on;
xlabel('Measured waveform SNR (dB)');
ylabel('Conditional tag BER / 95% upper bound');
legend('2x2x2', '2x4x4', 'Location', 'southwest');
title(sprintf('%s BER comparison', modeLabel));

nexttile;
semilogy(comparison.SNRdB, comparison.EndToEndBER222, '-o', ...
    comparison.SNRdB, comparison.EndToEndBER244, '-s');
grid on;
xlabel('Measured waveform SNR (dB)');
ylabel('End-to-end tag BER');
legend('2x2x2', '2x4x4', 'Location', 'southwest');

nexttile;
plot(comparison.SNRdB, 100 * comparison.AcquisitionFailure222, '-o', ...
    comparison.SNRdB, 100 * comparison.AcquisitionFailure244, '-s');
grid on;
xlabel('Measured waveform SNR (dB)');
ylabel('Acquisition failure (%)');
legend('2x2x2', '2x4x4', 'Location', 'northeast');

nexttile;
plot(report.results222.SNRdB, report.results222.NetGoodputKbps, '-o', ...
    report.results244.SNRdB, report.results244.NetGoodputKbps, '-s');
grid on;
xlabel('Measured waveform SNR (dB)');
ylabel('Amortized net goodput (kbps)');
legend('2x2x2', '2x4x4', 'Location', 'southeast');
end
