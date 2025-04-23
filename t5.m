%% Parameters
addpath('C:\MAGIC-master')
MAGPRO_WAIT         = 0.5;      % seconds to wait after setting amplitude
PULSES_PER_BLOCK    = 5;       % number of pulses per block
INTERPULSE_INTERVAL = 2.5;      % base interval between pulses
JITTER              = 0.5;      % jitter as fraction of INTERPULSE_INTERVAL (±25%)
BREAK_TIME          = 60;       % break time in seconds
BLOCKS              = 9;        % total number of blocks
FIXED_RMT_PERCENT   = 1.2;      % fixed intensity (e.g., 110% RMT)

%% Connect to MagPro
port_id = upper(input('Enter Port ID: ', 's')); % e.g., 'COM1'
magventureObject = magventure(port_id);
magventureObject.connect();
magventureObject.arm();

%% Input participant info
PARTICIPANT_ID = input('Enter participant ID: ', 's');
RMT = input('Enter resting motor threshold (1-100): ');
while ~(isnumeric(RMT) && RMT >= 1 && RMT <= 100)
    RMT = input('   Please enter a valid RMT (1-100): ');
end

% Compute the fixed stimulation level
fixed_mso = round(FIXED_RMT_PERCENT * RMT);
if fixed_mso > 100
    error('Stimulation intensity exceeds machine limit (>100%).')
end

%% Begin TMS blocks
exp_output = [];

for block = 1:BLOCKS
    % Reset pulse_count for each block to start from 1
    pulse_count = 0;
    
    % Wait for button press to start stimulation
    disp('Press any key to start Block...');
    waitforbuttonpress;  % Wait for user to press a button

    disp(['Starting Block ', num2str(block)]);
    
    for p = 1:PULSES_PER_BLOCK
        pulse_count = pulse_count + 1;

        % Set amplitude and fire
        magventureObject.setAmplitude(fixed_mso);
        pause(MAGPRO_WAIT);
        magventureObject.fire();

        % Log pulse
        pulse_exact_time = datestr(now, 'HH:MM:SS.FFF');
        disp(['  Block ', num2str(block), ' - Delivered Pulse ', num2str(pulse_count)]);

        % Store info
        exp_output(pulse_count).pid     = PARTICIPANT_ID;
        exp_output(pulse_count).block   = block;
        exp_output(pulse_count).pulse   = pulse_count;
        exp_output(pulse_count).mso_lvl = fixed_mso;
        exp_output(pulse_count).timing  = pulse_exact_time;

        % Pause with jitter unless it's the last pulse of block
        if p < PULSES_PER_BLOCK
            jitter_offset = (rand() * 2 * JITTER - JITTER) * INTERPULSE_INTERVAL;
            pause_time = INTERPULSE_INTERVAL + jitter_offset - MAGPRO_WAIT;
            pause(pause_time);
        end
    end

    % 60second break before next block or manual control to continue
    if block < BLOCKS
        disp('  Taking a break... Press any key to start next block');
        waitforbuttonpress;  
    end
end
