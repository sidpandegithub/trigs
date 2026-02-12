%% PARAMETERS
addpath('C:\MAGIC-master');
DIR = 'C:\Users\neuro\Desktop\SIPA_tests';
if exist(DIR,"dir")
    fprintf("directory exists");
else 
    mkdir(DIR)
end 
MAGPRO_WAIT = 0.5;
PULSES_PER_DELAY = 26;
BREAK_TIME = 10;          
FIXED_RMT_PERCENT = 1.2;
TOTAL_BLOCKS = 4;          % total blocks per session


%% PARTICIPANT ID & RMT
PARTICIPANT_ID = input('Enter participant ID: ','s');
RMT = input('Enter RMT (1-100): ');
while ~(isnumeric(RMT) && RMT >=0 && RMT <= 100)
    fprintf('Invalid value. Please enter a number between 0 and 100.\n');
    RMT = input('Enter RMT (0–100): ');
end
fixed_mso = round(RMT*FIXED_RMT_PERCENT);
if fixed_mso > 100
    error('Stimulation intensity exceeds machine limit (>100)');
else 
    display(fixed_mso)
end

%% CONNECT TO MAGVENTURE
port_id = upper(input('Enter Port ID (e.g. COM3): ', 's'));
magventureObject = magventure(port_id);
magventureObject.connect();
magventureObject.arm();
magventureObject.setAmplitude(fixed_mso);
%% LOAD OR INITIALIZE EXPERIMENT DATA
filename = fullfile(DIR, strcat(PARTICIPANT_ID, '_session.mat'));

if isfile(filename)
    load(filename, 'exp_output_pas');
    total_pulse = length(exp_output_pas);
    last_block = max([exp_output_pas.block]);
    next_block = last_block + 1;   
    disp(['Loaded existing session. Starting from block ', num2str(next_block)]);
else
    exp_output_pas = struct();
    total_pulse = 0;
    next_block = 1;
    disp('No previous session found. Starting from block 1.');
end

%% PULSE PARAMETERS
pulse_count = total_pulse;
% trigOutDelay = [0 10 20 30 40 50 60 70 80 90 100];
% trigOutDelay = [40 50 60 70 80 90 100];
trigOutDelay = [10 20 30 40 50 60];


trigInDelay = 0;
chargeDelay = 0;
pause_time = 5;  % seconds between paired pulses


%% BLOCK LOOP

previous_block_last_delay =[];

for log_block = next_block : TOTAL_BLOCKS
    display_block = log_block - next_block + 1;
    fprintf('Press any key to start Block %d\n', display_block);
    waitforbuttonpress;

   if isempty(previous_block_last_delay)
        randomDelays = trigOutDelay(randperm(length(trigOutDelay)));
   else 
       valid = false;
       while ~valid
           randomDelays = trigOutDelay(randperm(length(trigOutDelay)));
           if randomDelays(1) ~= previous_block_last_delay;
               valid = true;
           end 
       end
   end
   
fprintf('Order for this block: ');
disp(randomDelays);

    % Store last delay for next block constraint
    prev_last_delay = randomDelays(end);
    % Go through trigOutDelay IN ORDER
    for i = 1:length(randomDelays)
        delay = randomDelays(i);
        fprintf('\n=== Block %d | Delay = %d ms ===\n', display_block, delay);
        fprintf('Firing %d pulses...\n', PULSES_PER_DELAY);

        
        magventureObject.setTrig_ChargeDelay(trigInDelay, delay, chargeDelay);
        % PULSE LOOP
        for p = 1:PULSES_PER_DELAY

            pulse_count = pulse_count + 1;

            % Fire
            fprintf('  Pulse %d/%d\n', p, PULSES_PER_DELAY); % debug print
            magventureObject.fire();
            pause(pause_time);

            % Timestamp
            pulse_exact_time = datetime('now', 'Format', 'HH:mm:ss.SSS');

            % Burner pulse = first pulse only
            if p == 1
                pulse_label = 0;
            else
                pulse_label = pulse_count;
            end

            % Log pulse info
            exp_output_pas(pulse_count).pid     = PARTICIPANT_ID;
            exp_output_pas(pulse_count).block   = log_block;
            exp_output_pas(pulse_count).pulse   = pulse_label;
            exp_output_pas(pulse_count).mso_lvl = fixed_mso;
            exp_output_pas(pulse_count).timing  = pulse_exact_time;
            exp_output_pas(pulse_count).dur     = pause_time;
            exp_output_pas(pulse_count).delay = delay;

        end % pulse loop

        % Pause after finishing this delay
        fprintf('Finished delay %d ms. Waiting %d seconds...\n', delay, BREAK_TIME);
        pause(BREAK_TIME);

    end % delay loop

    % BLOCK BREAK
    if log_block < TOTAL_BLOCKS
        fprintf('\n--- Block %d finished. Press any key for next block ---\n', display_block);
        waitforbuttonpress;
    end

    % Save block
    save(filename, 'exp_output_pas');
    fprintf('Block %d saved.\n', display_block);

end % block loop
