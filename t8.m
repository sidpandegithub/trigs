%% PARAMETERS
addpath('C:\MAGIC-master')
DIR = 'C:\Users\neuro\Desktop\t_trigs';
MAGPRO_WAIT         = 0.5;      % seconds to wait after setting amplitude
PULSES_PER_BLOCK    = 25;       % number of pulses per block
INTERPULSE_INTERVAL = 2.5;      % base interval between pulses
JITTER              = 0.5;      % jitter as fraction of INTERPULSE_INTERVAL (±25%)
BREAK_TIME          = 60;       % break time in seconds
BLOCKS              = 9;        % total number of blocks per run
FIXED_RMT_PERCENT   = 1.2;      % fixed intensity (e.g., 120% RMT)

%% ANGLES 
%change manually per subject
A = [0, 67.5, 90, 22.5, -22.5, 135, 45, -45, 112.5];
B = [-22.5, 135, 0, 22.5, -45, 45, 67.5, 112.5, 90];
C = [67.5, 135, -22.5, 45, 90, 22.5, 112.5, -45, 0];
D = [22.5, 67.5, -22.5, 0, 112.5, -45, 90, 135, 45];

%% CONNECT TO MAGPRO 
port_id = upper(input('Enter Port ID (e.g. COM3): ', 's'));
magventureObject = magventure(port_id);
magventureObject.connect();
magventureObject.arm();

%% INPUT PARTICIPANT INFO 
PARTICIPANT_ID = input('Enter participant ID: ', 's');
RMT = input('Enter resting motor threshold (1-100): ');
while ~(isnumeric(RMT) && RMT >= 1 && RMT <= 100)
    RMT = input('   Please enter a valid RMT (1-100): ');
end

fixed_mso = round(FIXED_RMT_PERCENT * RMT);
if fixed_mso > 100
    error('Stimulation intensity exceeds machine limit (>100%).')
end

%% LOAD OR INIT DATA STRUCTURE 
filename = fullfile(DIR, strcat(PARTICIPANT_ID, '_session.mat'));

if isfile(filename)
    % Load existing data
    load(filename, 'exp_output');
    total_pulse = length(exp_output);
    last_block = max([exp_output.block]);
    new_block_start = last_block + 1;
    disp(['Loaded existing session. Starting from block ', num2str(new_block_start)]);
else
    % Start fresh
    exp_output = struct();
    total_pulse = 0;
    new_block_start = 1;
    disp('No previous session found. Starting from block 1.');
end

%% BEGIN TMS BLOCKS 
pulse_count = total_pulse;

for block = new_block_start : new_block_start + BLOCKS - 1
    disp(['Press any key to start Block ', num2str(block)]);
    waitforbuttonpress;
    
    % Determine angle for this block
    group_idx = floor((block - 1) / 9) + 1;  % A=1, B=2, C=3, D=4
    angle_idx = mod(block - 1, 9) + 1;
    
    switch group_idx
        case 1
            current_angle = A(angle_idx);
        case 2
            current_angle = B(angle_idx);
        case 3
            current_angle = C(angle_idx);
        case 4
            current_angle = D(angle_idx);
        otherwise
            error('Block number exceeds predefined angle groups.');
    end
    
    disp(['Starting Block ', num2str(block), ' with angle ', num2str(current_angle)]);

    for p = 1:PULSES_PER_BLOCK
        pulse_count = pulse_count + 1;

        % Set amplitude and fire
        magventureObject.setAmplitude(fixed_mso);
        pause(MAGPRO_WAIT);
        magventureObject.fire();

        % Log pulse time
        pulse_exact_time = datestr(now, 'HH:MM:SS.FFF');
        disp(['  Block ', num2str(block), ' - Delivered Pulse ', num2str(pulse_count)]);

        % Calculate the inter-pulse interval with jitter before storing pulse info
        if p < PULSES_PER_BLOCK
            jitter_offset = (rand() * 2 * JITTER - JITTER) * INTERPULSE_INTERVAL;
            pause_time = INTERPULSE_INTERVAL + jitter_offset - MAGPRO_WAIT; % total time for the next pulse
            pause(pause_time);
        else
            pause_time = 0; % No pause after last pulse in the block
        end
        
        % Store pulse info including angle and duration (total duration including jitter)
        exp_output(pulse_count).pid     = PARTICIPANT_ID;
        exp_output(pulse_count).block   = block;
        exp_output(pulse_count).pulse   = pulse_count;
        exp_output(pulse_count).mso_lvl = fixed_mso;
        exp_output(pulse_count).timing  = pulse_exact_time;
        exp_output(pulse_count).angle   = current_angle; 
        exp_output(pulse_count).dur     = pause_time + MAGPRO_WAIT; % total duration per pulse including jitter
    end

    if block < new_block_start + BLOCKS - 1
        disp('  Taking a break... Press any key to start next block');
        waitforbuttonpress;
    end
end


%% save 
save(filename, 'exp_output');
disp(['Experiment data saved to ', filename]);
%% disconnect 
magventureObject.disarm();
magventureObject.disconnect();

