function [rxTagBits, success, diagnostics] = VMscatterDeModPacket( ...
    txSC, rxSC, schedule, cfgHT, varargin)
%VMSCATTERDEMODPACKET Estimate once per reference block and batch-decode.

vmscatterValidateHTConfig(cfgHT, schedule.numTag);
parser = inputParser;
addParameter(parser, 'SubcarrierWeights', [], ...
    @(x) isempty(x) || (isnumeric(x) && isvector(x) && ...
    all(isfinite(x)) && all(x >= 0)));
parse(parser, varargin{:});
weights = parser.Results.SubcarrierWeights;

numTag = schedule.numTag;
numCodewords = schedule.numCodewords;
rxTagBits = nan(numCodewords, numTag);
success = false;
diagnostics = struct;
diagnostics.reason = "";
diagnostics.referenceBlocks = cell(schedule.numReferenceBlocks, 1);
diagnostics.codewordSuccess = false(numCodewords, 1);
diagnostics.codewordMinimumDistance = inf(numCodewords, 1);
diagnostics.codewordDecisionMargin = nan(numCodewords, 1);
diagnostics.candidateDistances = inf(numCodewords, 2^numTag);

for blockIndex = 1:schedule.numReferenceBlocks
    [basisOperators, referenceDiagnostics] = ...
        vmscatterEstimateBasisOperators(txSC, rxSC, schedule, blockIndex, ...
        'SubcarrierWeights', weights);
    diagnostics.referenceBlocks{blockIndex} = referenceDiagnostics;
    if ~referenceDiagnostics.success
        diagnostics.reason = referenceDiagnostics.reason;
        return;
    end

    codewordIndices = find(schedule.codewordReferenceBlock == blockIndex);
    for codewordIndex = reshape(codewordIndices, 1, [])
        [bits, codewordDiagnostics] = decodeOneCodeword( ...
            basisOperators, txSC, rxSC, ...
            schedule.dataSymbolIndices(codewordIndex, :), numTag, weights);
        if ~codewordDiagnostics.success
            diagnostics.reason = codewordDiagnostics.reason;
            return;
        end
        rxTagBits(codewordIndex, :) = bits;
        diagnostics.codewordSuccess(codewordIndex) = true;
        diagnostics.codewordMinimumDistance(codewordIndex) = ...
            codewordDiagnostics.minimumDistance;
        diagnostics.codewordDecisionMargin(codewordIndex) = ...
            codewordDiagnostics.decisionMargin;
        diagnostics.candidateDistances(codewordIndex, :) = ...
            codewordDiagnostics.candidateDistances;
    end
end

success = all(diagnostics.codewordSuccess);
end

function [bits, diagnostics] = decodeOneCodeword( ...
    basisOperators, txSC, rxSC, symbolIndices, numTag, weights)

diagnostics = struct('success', false, 'reason', "", ...
    'candidateDistances', inf(1, 2^numTag), ...
    'minimumDistance', Inf, 'decisionMargin', NaN);

if isempty(weights)
    weights = ones(size(txSC, 2), 1);
else
    weights = weights(:) ./ max(mean(weights), eps);
end
sqrtWeights = sqrt(weights.');

for candidateIndex = 1:2^numTag
    candidateBits = dec2bin(candidateIndex - 1, numTag) - '0';
    candidateCode = iterativeSTC(candidateBits);
    squaredError = 0;
    signalEnergy = 0;
    for symbolOffset = 1:numTag
        operator = zeros(size(txSC, 1));
        for tagIndex = 1:numTag
            operator = operator + candidateCode(tagIndex, symbolOffset) * ...
                basisOperators(:, :, tagIndex);
        end
        symbolIndex = symbolIndices(symbolOffset);
        tx = txSC(:, :, symbolIndex);
        rx = rxSC(:, :, symbolIndex);
        residual = (rx - operator * tx) .* sqrtWeights;
        squaredError = squaredError + norm(residual, 'fro')^2;
        signalEnergy = signalEnergy + ...
            norm(rx .* sqrtWeights, 'fro')^2;
    end
    diagnostics.candidateDistances(candidateIndex) = ...
        squaredError / max(signalEnergy, eps);
end

[sortedDistances, sortedIndices] = sort(diagnostics.candidateDistances);
diagnostics.minimumDistance = sortedDistances(1);
diagnostics.decisionMargin = sortedDistances(2) - sortedDistances(1);
bits = dec2bin(sortedIndices(1) - 1, numTag) - '0';
diagnostics.success = true;
end
