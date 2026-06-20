function report = run_reference_profile_comparison(varargin)
%RUN_REFERENCE_PROFILE_COMPARISON Run one named VMScatter reference profile.
%   Profiles use the LTF all-ones baseline plus K-1 explicit states:
%     Minimal: one observation per explicit state (222=1, 244=3)
%     Default: two observations per explicit state (222=2, 244=6)
%     Robust:  four observations per explicit state (222=4, 244=12)

parser = inputParser;
addParameter(parser, 'Profile', 'Default', ...
    @(x) any(strcmpi(string(x), ["Minimal", "Default", "Robust"])));
addParameter(parser, 'SNR', 2:10, @(x) isnumeric(x) && isvector(x));
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
addParameter(parser, 'Seed', 2020, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x));
addParameter(parser, 'Plot', true, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'SaveResults', false, ...
    @(x) islogical(x) && isscalar(x));
addParameter(parser, 'OutputDirectory', '', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
parse(parser, varargin{:});
options = parser.Results;

profile = validatestring(options.Profile, {'Minimal', 'Default', 'Robust'});
repeats = profileRepeats(profile);
report = run_vmscatter_paper_comparison( ...
    'SNR', options.SNR, ...
    'ReferenceRepeats', repeats, ...
    'MinBits', options.MinBits, ...
    'MaxBits', options.MaxBits, ...
    'TargetErrors', options.TargetErrors, ...
    'PSDULength', options.PSDULength, ...
    'MCS', options.MCS, ...
    'Seed', options.Seed, ...
    'Plot', options.Plot);

report.profile = string(profile);
report.referenceRepeats = repeats;
report.explicitReferences222 = repeats;
report.explicitReferences244 = 3 * repeats;
report.strictWinAtSNR = report.results244.ConditionalBERUpper95 < ...
    report.results222.ConditionalBERLower95;

if options.SaveResults
    outputDirectory = string(options.OutputDirectory);
    if strlength(outputDirectory) == 0
        versionRoot = fileparts(fileparts(mfilename('fullpath')));
        outputDirectory = fullfile(versionRoot, 'results');
    end
    saveProfile(report, char(outputDirectory));
end
end

function repeats = profileRepeats(profile)
switch lower(profile)
    case 'minimal'
        repeats = 1;
    case 'default'
        repeats = 2;
    case 'robust'
        repeats = 4;
end
end

function saveProfile(report, outputDirectory)
if ~exist(outputDirectory, 'dir')
    mkdir(outputDirectory);
end
stem = lower(char(report.profile));
writetable(report.comparison, ...
    fullfile(outputDirectory, ['comparison_' stem '.csv']));
writetable(report.rateTable, ...
    fullfile(outputDirectory, ['rates_' stem '.csv']));
save(fullfile(outputDirectory, ['report_' stem '.mat']), 'report');
if report.settings.Plot && ~isempty(get(groot, 'CurrentFigure'))
    figureHandle = gcf;
    savefig(figureHandle, fullfile(outputDirectory, ['ber_' stem '.fig']));
    exportgraphics(figureHandle, ...
        fullfile(outputDirectory, ['ber_' stem '.png']), ...
        'Resolution', 180);
end
end
