%% Author: DJP
clear all;
close all;

%% Conversion
[files, origDataPath] = ... % crucial distinction: files vs file (current)
    uigetfile('*.rhd', 'Select an RHD2000 Data File', 'MultiSelect', 'on');
% [file,origDataPath] = concat_Intan_RHD2000_files;
% make folder containing that files
if iscell(files)
    ts_label = files{1};
else
    ts_label = files;
    files = {files};
end
ts_label = ts_label(1:end-4);
% if you are aggregating things for cell shape analysis, input depth,
% otherwise click enter/return

is_32 = input('is this a 32 channel recording? (''1'' for yes, ''0'' for no )\n');
is_stereo = input('does the microdrive use stereotrodes? (''1'' for yes, ''0'' for no ) \n');
    
    
dataPath = fullfile(origDataPath,[ts_label '_Kilosort']);
mkdir(dataPath)
addpath(dataPath)
%%
dataFileName = fullfile(dataPath, 'raw_filtered.dat'); % [dataPath '\Kilosort_alldata\raw.dat'] % make .dat file
% saving adc data, too
board_adc = [];
% open raw.dat to write
fid1a = fopen(dataFileName, 'w'); % open .dat file for writing

filearray = [];
for i = 1:length(files)
    filearray = [filearray dir(char(files(i)))];
end
[~, idx] = sort({filearray.date});
files = files(idx);

% make a waitbar!
f = waitbar(0, 'loading');
for i=1:length(files)
    
    read_Intan_RHD2000_file_MML_DJP(fullfile(filearray(i).folder,filearray(i).name),0);
    
    % bandpass filter
    datr = filter_datr(amplifier_data, frequency_parameters);

    fwrite(fid1a, datr(:),'int16'); % append to .dat files
    %     fwrite(fid1a, amplifier_data(:),'int16'); % append to .dat file
    if size(board_adc_data, 1) == 2
        board_adc_data = [NaN(1, size(board_adc_data, 2)); board_adc_data];
    end
    board_adc = [board_adc board_adc_data];
    
    waitbar(i/length(files), f, 'loading Intan data')
    
end

fclose(fid1a);
close(f); % close waitbar

adc_sr=frequency_parameters.board_adc_sample_rate;
save(fullfile(dataPath, 'adc_data'), 'board_adc', 'adc_sr', '-v7.3')
%% make params.py
fid2 = fopen(fullfile(dataPath, 'params.py'),'w');

dat_path = 'raw_filtered.dat';
n_channels_dat = string(length(amplifier_channels));
dtype = 'int16';
offset = 0;
sample_rate = string(frequency_parameters.amplifier_sample_rate);
hp_filtered = 'True';

fprintf(fid2, 'dat_path = r''%s''\n', dat_path);
fprintf(fid2, 'n_channels_dat = %s\n', n_channels_dat); %2d means two digit
fprintf(fid2, 'dtype = ''%s''\n', dtype);
fprintf(fid2, 'offset = 0\n');
fprintf(fid2, 'sample_rate = %s.\n', sample_rate);
fprintf(fid2, 'hp_filtered = %s\n', hp_filtered);

fclose(fid2);
clear fid2 dat_path dtype offset hp_filtered 
clear amplifier_channels amplifier_data aux_input_channels aux_input_data ...
        board_dig_in_data board_dig_in_channels filename frequency_parameters ...
        notes reference_channel spike_triggers supply_voltage_channels supply_voltage_data ...
        t_amplifier t_aux_input t_dig t_supply_voltage
%% Figure out which standard config is neede dhere
% copy master file example and  standard config and then edit them
working_dir = 'C:\Users\Healey Lab\Documents\MATLAB\KS-analysis';
if      is_32 && ~is_stereo % if 32 chan tetrode
    ChannelMapFile_orig      = fullfile(working_dir, 'createChannelMapFile32.m');
elseif ~is_32 &&  is_stereo % 16 chan stereotrode
    ChannelMapFile_orig      = fullfile(working_dir, 'createChannelMapFile16stereo.m');
elseif  is_32 &&  is_stereo % 32 chan stereotrode
    % TODO
elseif ~is_32 && ~is_stereo % 16 chan tetrode
    ChannelMapFile_orig      = fullfile(working_dir, 'createChannelMapFile.m');    
end
master_file_example_orig = fullfile(working_dir, 'master_file_example_MOVEME.m');
StandardConfig_orig      = fullfile(working_dir, 'StandardConfig_MOVEME.m');

copyfile(ChannelMapFile_orig,       dataPath)
copyfile(master_file_example_orig,  dataPath)
copyfile(StandardConfig_orig,       dataPath)

if      is_32 && ~is_stereo % if 32 chan tetrode
    ChannelMapFile_pasted      = fullfile(dataPath, 'createChannelMapFile32.m');
elseif ~is_32 &&  is_stereo % 16 chan stereotrode
    ChannelMapFile_pasted      = fullfile(dataPath, 'createChannelMapFile16stereo.m');
elseif  is_32 &&  is_stereo % 32 chan stereotrode
    % TODO
elseif  ~is_32 && ~is_stereo% 16 chan tetrode
    ChannelMapFile_pasted      = fullfile(dataPath, 'createChannelMapFile.m');
end
master_file_example_pasted = fullfile(dataPath, 'master_file_example_MOVEME.m');
StandardConfig_pasted      = fullfile(dataPath, 'StandardConfig_MOVEME.m');

%% Edit standard config
% https://www.mathworks.com/matlabcentral/answers/62986-how-to-change-a-specific-line-in-a-text-file
fid3 = fopen(StandardConfig_pasted,'r');
i = 1;
tline = fgetl(fid3);
A{i} = tline;
while ischar(tline)
    i = i+1;
    tline = fgetl(fid3);
    A{i} = tline;
end
fclose(fid3);
% Change lines of .m file
A{1}  = sprintf('ops.GPU=1;');
A{2}  = sprintf('ops.parfor=1;');
A{7}  = sprintf('ops.fbinary = ''%s'';', dataFileName); % dataFileName = 'C:\Users\danpo\Documents\sorting\mdx 10 8 18\filename'
A{8}  = sprintf('ops.fproc = ''%s'';', fullfile(dataPath,'temp_wh.dat')); % dataPath = 'C:\Users\danpo\Documents\sorting\mdx 10 8 18\'
A{9}  = sprintf('ops.root = ''%s'';',dataPath);
A{11} = sprintf('ops.fs = %s;',sample_rate);
A{12} = sprintf('ops.NchanTOT = %s;', n_channels_dat);
A{14} = sprintf('ops.Nfilt = 32;');
A{47} = sprintf('ops.mergeT           = .08;');
A{48} = sprintf('ops.splitT           = .12;');


A{51} = sprintf('ops.initialize      = ''fromData'';');
A{52} = sprintf('ops.spkTh           = -5;');

if is_32
    num_active_chan = 32;
else
    num_active_chan = 16;
end

A{13} = sprintf('ops.Nchan = %s;', string(num_active_chan)); % it's here. This is ground zero.
A{14} = sprintf('ops.Nfilt = %s;',  string(str2num(n_channels_dat) * 2));% number of clusters to use (2-4 times more than Nchan, should be a multiple of 32)   
A{15} = sprintf('ops.nNeighPC = %s; % visualization only (Phy): number of channnels to mask the PCs, leave empty to skip (12)', string(12));
A{16} = sprintf('ops.nNeigh = %s; % visualization only (Phy): number of neighboring templates to retain projections of (16)', string(num_active_chan));

A{24} = sprintf('ops.chanMap = ''%s'';',  fullfile(dataPath, 'chanMap.mat'));

% Write cell A into txt
fid3 = fopen(StandardConfig_pasted, 'w');
for i = 1:numel(A)
    if A{i+1} == -1
        fprintf(fid3,'%s', A{i});
        break
    else
        fprintf(fid3,'%s\n', A{i});
    end
end
fclose(fid3);
%% Edit Channelmap 
fid4 = fopen(ChannelMapFile_pasted,'r');
i = 1;
tline = fgetl(fid4);
B{i} = tline;
while ischar(tline)
    i = i+1;
    tline = fgetl(fid4);
    B{i} = tline;
end
fclose(fid4);
B{3} = sprintf('Nchannels = %s;', n_channels_dat);
B{6} = sprintf('pathToYourConfigFile = ''%s'';', dataPath);
B{11} = sprintf('fs = %s;', sample_rate);
if strcmp(n_channels_dat, '16')
    B{17} = sprintf('connected = logical(ones(16,1));');
    if is_stereo % if using stereotrodes,
        B{39} = sprintf('all_stereos = all_stereos-8;');
    else
        B{39} = sprintf('all_tetrodes = all_tetrodes-8;');
    end
end
B{48} = sprintf('save(''%s'', ...',  fullfile(dataPath, 'chanMap.mat'));

% Write cell B into .txt
fid4 = fopen(ChannelMapFile_pasted, 'w');
for i = 1:numel(B)
    if B{i+1} == -1
        fprintf(fid4,'%s', B{i});
        break
    else
        fprintf(fid4,'%s\n', B{i});
    end
end
fclose(fid4);
%% Edit the master file
fid5 = fopen(master_file_example_pasted,'r');
i = 1;
tline = fgetl(fid5);
C{i} = tline;
while ischar(tline)
    i = i+1;
    tline = fgetl(fid5);
    C{i} = tline;
end
fclose(fid5);
C{3} = sprintf('addpath(genpath(''C:\\KiloSort-master''))'); % path to LOCAL kilosort folder

C{6} = sprintf('pathToYourConfigFile = ''%s''; ', dataPath);

% Write cell C into txt
fid5 = fopen(master_file_example_pasted, 'w');
for i = 1:numel(C)
    if C{i+1} == -1
        fprintf(fid5,'%s', C{i});
        break
    else
        fprintf(fid5,'%s\n', C{i});
    end
end
fclose(fid5);
%%
fclose('all');
%% Go
run(ChannelMapFile_pasted)
run(master_file_example_pasted) % master_file_example_MOVEME
%% 
% % If you run into this error, it's because of the line that changes NChan
% % in the config file to 32 or 16. It should be dynamic. NChanTOT is
% % always 32 though. (search 'ground zero' to find it)
% Error using  + 
% Matrix dimensions must agree.
% 
% Error in preprocessData (line 163)
%             CC        = CC + (datr' * datr)/NT;
% 
% Error in master_file_example_MOVEME (line 19)
% [rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
%%

pushBulletDriver(strjoin(['done sorting ' string(pwd)]));
beep
toc

