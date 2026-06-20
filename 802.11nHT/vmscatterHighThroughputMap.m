function states = vmscatterHighThroughputMap(bits)
%VMSCATTERHIGHTHROUGHPUTMAP Map K information bits to one tag state.
%   For each two-bit pair [a b], the transmitted states are
%   [exp(j*pi*(a+b)); exp(j*pi*a)]. This is the binary form of the
%   sum/difference mapping illustrated in Fig. 4 of the VMscatter paper.
%   K=4 uses two independent copies of the documented K=2 mapping. This
%   pairwise extension is bijective over all 16 four-antenna BPSK states.

validateattributes(bits, {'numeric'}, {'2d', 'finite', 'nonempty'}, ...
    mfilename, 'bits');
if ~ismember(size(bits, 2), [2 4]) || any(bits(:) ~= 0 & bits(:) ~= 1)
    error('VMScatter:InvalidHighThroughputBits', ...
        'Bits must be an N-by-2 or N-by-4 binary matrix.');
end

numWords = size(bits, 1);
numTag = size(bits, 2);
states = zeros(numWords, numTag);
for pairStart = 1:2:numTag
    a = bits(:, pairStart);
    b = bits(:, pairStart + 1);
    states(:, pairStart) = 1 - 2 * mod(a + b, 2);
    states(:, pairStart + 1) = 1 - 2 * a;
end
end
