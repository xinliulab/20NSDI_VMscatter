function [basisOperators, diagnostics] = vmscatterEstimateBasisOperators( ...
    txSC, rxSC, schedule, referenceBlock, varargin)
%VMSCATTERESTIMATEBASISOPERATORS Joint LS over repeated reference symbols.

parser = inputParser;
addParameter(parser, 'SubcarrierWeights', [], ...
    @(x) isempty(x) || (isnumeric(x) && isvector(x) && ...
    all(isfinite(x)) && all(x >= 0)));
parse(parser, varargin{:});

numTag = schedule.numTag;
numStreams = size(txSC, 1);
basisOperators = nan(numStreams, numStreams, numTag);
diagnostics = struct('success', false, 'reason', "", ...
    'referenceConditions', [0, inf(1, numTag - 1)], ...
    'referenceResiduals', [0, inf(1, numTag - 1)], ...
    'stateMatrixCondition', cond(schedule.designStateMatrix), ...
    'baselineOperator', eye(numStreams), ...
    'baselineSource', schedule.baselineSource);

if ndims(txSC) ~= 3 || ndims(rxSC) ~= 3 || ...
        ~isequal(size(txSC), size(rxSC))
    diagnostics.reason = "TX/RX subcarrier arrays must have equal 3-D sizes.";
    return;
end
if referenceBlock < 1 || referenceBlock > schedule.numReferenceBlocks
    diagnostics.reason = "Reference block index is outside the schedule.";
    return;
end

weights = validateWeights(parser.Results.SubcarrierWeights, size(txSC, 2));
sqrtWeights = sqrt(weights.');
referenceOperators = zeros(numStreams, numStreams, numTag);
referenceOperators(:, :, 1) = eye(numStreams);

for stateIndex = 1:schedule.numExplicitReferenceStates
    symbolIndices = schedule.referenceGroups{referenceBlock, stateIndex};
    txJoint = zeros(numStreams, 0);
    rxJoint = zeros(numStreams, 0);
    for repeatIndex = 1:numel(symbolIndices)
        symbolIndex = symbolIndices(repeatIndex);
        txJoint = [txJoint, txSC(:, :, symbolIndex) .* sqrtWeights]; %#ok<AGROW>
        rxJoint = [rxJoint, rxSC(:, :, symbolIndex) .* sqrtWeights]; %#ok<AGROW>
    end
    gram = txJoint * txJoint';
    diagnosticIndex = stateIndex + 1;
    diagnostics.referenceConditions(diagnosticIndex) = cond(gram);
    if ~isfinite(diagnostics.referenceConditions(diagnosticIndex)) || ...
            diagnostics.referenceConditions(diagnosticIndex) > 1e10
        diagnostics.reason = ...
            "A repeated reference group is rank deficient or ill-conditioned.";
        return;
    end
    operator = (rxJoint * txJoint') / gram;
    referenceOperators(:, :, diagnosticIndex) = operator;
    residual = rxJoint - operator * txJoint;
    diagnostics.referenceResiduals(diagnosticIndex) = ...
        norm(residual, 'fro')^2 / max(norm(rxJoint, 'fro')^2, eps);
end

stateMatrix = schedule.designStateMatrix;
if rank(stateMatrix) ~= numTag
    diagnostics.reason = "Reference state matrix is not full rank.";
    return;
end
for rowIndex = 1:numStreams
    for columnIndex = 1:numStreams
        observed = squeeze(referenceOperators(rowIndex, columnIndex, :));
        coefficients = stateMatrix.' \ observed;
        basisOperators(rowIndex, columnIndex, :) = reshape( ...
            coefficients, 1, 1, numTag);
    end
end

diagnostics.success = true;
diagnostics.reason = "";
end

function weights = validateWeights(weights, numTones)
if isempty(weights)
    weights = ones(numTones, 1);
elseif numel(weights) ~= numTones
    error('VMScatter:InvalidSubcarrierWeights', ...
        'Expected one weight for each of the %d data tones.', numTones);
else
    weights = weights(:);
    if ~any(weights > 0)
        error('VMScatter:InvalidSubcarrierWeights', ...
            'At least one subcarrier weight must be positive.');
    end
    weights = weights ./ max(mean(weights), eps);
end
end
