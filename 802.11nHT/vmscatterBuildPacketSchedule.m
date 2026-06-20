function [tagStates, tagBits, schedule] = vmscatterBuildPacketSchedule( ...
    numTag, numCodewords, referenceRepeats, varargin)
%VMSCATTERBUILDPACKETSCHEDULE Build reference blocks and tag data symbols.

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

mode = validatestring(parser.Results.Mode, {'LowBER', 'HighThroughput'});
if strcmpi(mode, 'LowBER')
    symbolsPerCodeword = numTag;
else
    % The prototype holds one tag state for an 8-us tag time slot, equal
    % to two 4-us HT OFDM symbols. This gives the measured raw-rate scale:
    % 1/2/4 tag antennas -> 125/250/500 kbps.
    symbolsPerCodeword = 2;
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
dataSymbolIndices = zeros(numCodewords, symbolsPerCodeword);
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
        if strcmpi(mode, 'LowBER')
            code = iterativeSTC(tagBits(codewordIndex, :));
        else
            state = vmscatterHighThroughputMap( ...
                tagBits(codewordIndex, :)).';
            code = repmat(state, 1, symbolsPerCodeword);
        end
        firstDataSymbol = size(tagStates, 2) + 1;
        tagStates = [tagStates, code]; %#ok<AGROW>
        dataSymbolIndices(codewordIndex, :) = ...
            firstDataSymbol:(firstDataSymbol + symbolsPerCodeword - 1);
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
schedule.symbolsPerCodeword = symbolsPerCodeword;
schedule.numDataSymbols = numCodewords * symbolsPerCodeword;
schedule.numSymbols = size(tagStates, 2);
schedule.rawBitsPerDataSymbol = numTag / symbolsPerCodeword;
schedule.mode = string(mode);
schedule.referenceOverheadFraction = ...
    schedule.numReferenceSymbols / schedule.numSymbols;
end
