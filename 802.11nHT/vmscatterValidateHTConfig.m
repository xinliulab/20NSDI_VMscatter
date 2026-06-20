function vmscatterValidateHTConfig(cfgHT, numTag)
%VMSCATTERVALIDATEHTCONFIG Validate the supported VMScatter HT profile.

validateattributes(cfgHT, {'wlanHTConfig'}, {'scalar'}, mfilename, 'cfgHT');
validateattributes(numTag, {'numeric'}, {'scalar', 'integer', 'positive'}, ...
    mfilename, 'numTag');

if ~strcmp(cfgHT.ChannelBandwidth, 'CBW20')
    error('VMScatter:UnsupportedBandwidth', ...
        'This release supports HT20 (CBW20) only.');
end
if cfgHT.NumTransmitAntennas ~= 2 || cfgHT.NumSpaceTimeStreams ~= 2 || ...
        ~ismember(numTag, [2 4])
    error('VMScatter:UnsupportedDimensions', ...
        'This release supports two transmit streams and either two or four tag antennas.');
end
if ~strcmp(cfgHT.SpatialMapping, 'Direct')
    error('VMScatter:UnsupportedSpatialMapping', ...
        'This release supports Direct spatial mapping only.');
end
if ~ismember(cfgHT.MCS, 8:15) || ~strcmp(cfgHT.ChannelCoding, 'BCC')
    error('VMScatter:UnsupportedPHY', ...
        'The supported profile is HT20, two-stream MCS 8 through 15, BCC.');
end
end
