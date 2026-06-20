function [tagStates, tagBits, schedule] = vmscatterBuildPacketSchedule( ...
    numTag, numCodewords, referenceRepeats, varargin)
%VMSCATTERBUILDPACKETSCHEDULE Build reference blocks and low-BER codewords.

validateattributes(numTag, {'numeric'}, ...
    {'scalar', 'integer', 'positive'}, mfilename, 'numTag');
validateattributes(numCodewords, {'numeric'}, ...
    {'scalar', 'integer', 'positive'}, mfilename, 'numCodewords');
validateattributes(referenceRepeats, {'numeric'}, ...
    {'scalar', 'integer', 'positive'}, mfilename, 'referenceRepeats');

parser = inputParser;
addParameter(parser, 'TagBits', [], @(x) isempty(x) || ...
    (isnumeric(x) && isequal(size(x), [numCodewords numTag]) && ...
    all(x(:) == 0 | x(:) == 1)));
addParameter(parser, 'ReferenceRefreshCodewords', Inf, ...
    @(x) isnumeric(x) && isscalar(x) && ...
    (isinf(x) || (x >= 1 && fix(x) == x)));
addParameter(parser, 'Mode', 'LowBER', ...
    @(x) any(strcmpi(x, {'LowBER', 'HighThroughput'})));
parse(parser, varargin{:});

if ~strcmpi(parser.Results.Mode, 'LowBER')
    error('VMScatter:HighThroughputNotImplemented', ...
        ['The packet interface reserves HighThroughput mode, but this ' ...
        'release implements the paper-aligned LowBER mode only.']);
end

if isempty(parser.Results.TagBits)
    tagBits = randi([0 1], numCodewords, numTag);
else
    tagBits = double(parser.Results.TagBits);
end

refreshInterval = parser.Results.ReferenceRefreshCodewords;
if isinf(refreshInterval)
    segmentStarts = 1;
else
    segmentStarts = 1:refreshInterval:numCodewords;
end

referenceStates = vmscatterReferenceStates(numTag);
designStateMatrix = [ones(numTag, 1), referenceStates];
numExplicitStates = size(referenceStates, 2);
tagStates = zeros(numTag, 0);
referenceGroups = cell(numel(segmentStarts), numExplicitStates);
dataSymbolIndices = zeros(numCodewords, numTag);
codewordReferenceBlock = zeros(numCodewords, 1);

for blockIndex = 1:numel(segmentStarts)
    for stateIndex = 1:numExplicitStates
        firstReference = size(tagStates, 2) + 1;
        tagStates = [tagStates, ...
            repmat(referenceStates(:, stateIndex), 1, referenceRepeats)]; %#ok<AGROW>
        referenceGroups{blockIndex, stateIndex} = ...
            firstReference:(firstReference + referenceRepeats - 1);
    end

    firstCodeword = segmentStarts(blockIndex);
    if blockIndex < numel(segmentStarts)
        lastCodeword = segmentStarts(blockIndex + 1) - 1;
    else
        lastCodeword = numCodewords;
    end
    for codewordIndex = firstCodeword:lastCodeword
        code = iterativeSTC(tagBits(codewordIndex, :));
        firstDataSymbol = size(tagStates, 2) + 1;
        tagStates = [tagStates, code]; %#ok<AGROW>
        dataSymbolIndices(codewordIndex, :) = ...
            firstDataSymbol:(firstDataSymbol + numTag - 1);
        codewordReferenceBlock(codewordIndex) = blockIndex;
    end
end

schedule = struct;
schedule.numTag = numTag;
schedule.numCodewords = numCodewords;
schedule.referenceRepeats = referenceRepeats;
schedule.referenceStates = referenceStates;
schedule.designStateMatrix = designStateMatrix;
schedule.numExplicitReferenceStates = numExplicitStates;
schedule.baselineState = ones(numTag, 1);
schedule.baselineSource = "HT-LTF conventional equalization";
schedule.referenceGroups = referenceGroups;
schedule.dataSymbolIndices = dataSymbolIndices;
schedule.codewordReferenceBlock = codewordReferenceBlock;
schedule.referenceRefreshCodewords = refreshInterval;
schedule.numReferenceBlocks = numel(segmentStarts);
schedule.numReferenceSymbols = ...
    numel(segmentStarts) * numExplicitStates * referenceRepeats;
schedule.numDataSymbols = numCodewords * numTag;
schedule.numSymbols = size(tagStates, 2);
schedule.rawBitsPerDataSymbol = numTag / numTag;
schedule.mode = "LowBER";
schedule.referenceOverheadFraction = ...
    schedule.numReferenceSymbols / schedule.numSymbols;
end
