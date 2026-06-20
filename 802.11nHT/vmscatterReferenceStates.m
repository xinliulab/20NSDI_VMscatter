function states = vmscatterReferenceStates(numTag)
%VMSCATTERREFERENCESTATES Explicit VMScatter reference states.
%   The all-ones state is supplied by the LTF baseline and is therefore
%   not transmitted again in HT-Data. The returned matrix contains K-1
%   explicit states. Together, [ones(K,1), states] must have rank K.

validateattributes(numTag, {'numeric'}, ...
    {'scalar', 'integer', 'positive'}, mfilename, 'numTag');
if ~ismember(numTag, [2 4])
    error('VMScatter:UnsupportedTagCount', ...
        'Packet-level reference states currently support K=2 or K=4.');
end
states = VMscatterRef(numTag);
if rank([ones(numTag, 1), states]) ~= numTag
    error('VMScatter:RankDeficientReferenceDesign', ...
        'The LTF baseline plus explicit reference states must have rank K.');
end
end
