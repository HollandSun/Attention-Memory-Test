function AttentionShift_Practice
% AttentionShift_Practice
% 30 trials: S-block (15 trials) + H-block (15 trials)
% Cue images from stimulus/cue/  named  cue_A<n>.png (animal=shift) and cue_N<n>.png (inanimate=hold)
% Trial 1-6: detailed step-by-step feedback (3 shift + 3 hold, interleaved)
% Trial 7-30: correct / incorrect feedback only
% Response keys: z = odd, m = even  (same as main task)

%% =========================================================
%  Settings
%% =========================================================
SSNR           = 0.4;           % not used here, just for reference
N_TRIALS       = 30;            % total practice trials
N_GUIDED       = 6;             % first N trials get detailed feedback
N_PER_BLOCK    = 15;            % trials per block
SHIFT_RATE_S   = 0.70;          % S-block shift ratio
HOLD_RATE_H    = 0.70;          % H-block hold ratio  (70% hold in H-block)
img_size       = 256;
FRAME_RATE     = 4;             % frames per second
FRAME_TIME     = 1000/FRAME_RATE; % ms per frame
CUE_FRAME_TIME = 250;           % ms for cue frame

%% =========================================================
%  Paths
%% =========================================================
cue_dir   = fullfile('stimulus', 'cue');
noise_dir = fullfile('stimulus', 'noise');

%% =========================================================
%  PTB init
%% =========================================================
KbName('UnifyKeyNames');
whichScreen = 0;
background  = [128 128 128];

[window, windowRect] = Screen('OpenWindow', whichScreen, background);
HideCursor(window);
hz    = Screen('FrameRate', window);  %#ok<NASGU>
slack = Screen('GetFlipInterval', window) / 2;

Cx = windowRect(3) / 2;
Cy = windowRect(4) / 2;

loc1   = [Cx-300, Cy, Cx-300, Cy];   % left
loc2   = [Cx+300, Cy, Cx+300, Cy];   % right
center = [Cx, Cy, Cx, Cy];

half     = img_size / 2;
dstRect1 = [loc1(1)-half, loc1(2)-half, loc1(1)+half, loc1(2)+half];
dstRect2 = [loc2(1)-half, loc2(2)-half, loc2(1)+half, loc2(2)+half];

Screen('TextFont', window, 'Monaco');

%% =========================================================
%  Keyboard
%% =========================================================
keyList = zeros(1, 256);
keyList([KbName('z') KbName('m') KbName('q')]) = 1;
ind_list = GetKeyboardIndices;
kb_ind   = ind_list(length(ind_list)-1);
KbQueueCreate(kb_ind, keyList);

%% =========================================================
%  Load noise textures from stimulus/noise/
%% =========================================================
noise_exts  = {'*.png','*.jpg','*.jpeg'};
noise_files = [];
for e = 1:numel(noise_exts)
    noise_files = [noise_files; dir(fullfile(noise_dir, noise_exts{e}))]; %#ok<AGROW>
end
if isempty(noise_files)
    Screen('CloseAll');
    error('No noise images found in %s', noise_dir);
end
N_NOISE = numel(noise_files);
fprintf('Loading %d noise textures...\n', N_NOISE);
noiseTextures = zeros(1, N_NOISE);
for i = 1:N_NOISE
    img = imread(fullfile(noise_files(i).folder, noise_files(i).name));
    if size(img,3) == 1, img = repmat(img,[1 1 3]); end
    noiseTextures(i) = Screen('MakeTexture', window, img);
end
noisePool    = Shuffle(1:N_NOISE);
noisePoolIdx = 1;

%% =========================================================
%  Discover cue images: cue_A*.png = animal(shift), cue_N*.png = inanimate(hold)
%% =========================================================
animal_files   = dir(fullfile(cue_dir, 'cue_A*.png'));
inanimate_files= dir(fullfile(cue_dir, 'cue_N*.png'));

if isempty(animal_files) || isempty(inanimate_files)
    Screen('CloseAll');
    error('Cannot find cue_A*.png or cue_N*.png in %s', cue_dir);
end

% sort by number in filename
animal_names   = sort({animal_files.name});
inanimate_names= sort({inanimate_files.name});

%% =========================================================
%  Build trial list
%% =========================================================
% S-block (block 1): 70% shift, 30% hold
n_shift_S = round(N_PER_BLOCK * SHIFT_RATE_S);          % 11 shift
n_hold_S  = N_PER_BLOCK - n_shift_S;                    % 4 hold
% H-block (block 2): 30% shift, 70% hold
n_shift_H = round(N_PER_BLOCK * (1 - HOLD_RATE_H));     % 5 shift  (30%)
n_hold_H  = N_PER_BLOCK - n_shift_H;                    % 10 hold

% cue type: 2=shift(animal), 1=hold(inanimate)
cue_type_S = Shuffle([ones(1,n_shift_S)*2, ones(1,n_hold_S)]);
cue_type_H = Shuffle([ones(1,n_shift_H)*2, ones(1,n_hold_H)]);

% For trials 1-6: 3 shift + 3 hold, INTERLEAVED (alternating SH pattern)
guided_cue_type = [2 1 2 1 2 1];   % trials 1-6: shift hold shift hold shift hold

% Override first 6 trials of block 1 with guided sequence
cue_type_S(1:N_GUIDED) = guided_cue_type;

% Full sequence: block S then block H
all_cue_type = [cue_type_S, cue_type_H];  % length = 30
all_block    = [ones(1,N_PER_BLOCK), ones(1,N_PER_BLOCK)*2];  % 1=S-block, 2=H-block

% Assign animal (shift) and inanimate (hold) cue images
n_animal    = numel(animal_names);
n_inanimate = numel(inanimate_names);
n_shift_total = sum(all_cue_type == 2);
n_hold_total  = sum(all_cue_type == 1);

% sample with replacement if not enough images
animal_pool    = animal_names(mod(Shuffle(0:n_shift_total-1), n_animal)+1);
inanimate_pool = inanimate_names(mod(Shuffle(0:n_hold_total-1), n_inanimate)+1);

cue_filenames = cell(1, N_TRIALS);
a_ptr = 1; n_ptr = 1;
for t = 1:N_TRIALS
    if all_cue_type(t) == 2
        cue_filenames{t} = animal_pool{a_ptr};
        a_ptr = a_ptr + 1;
    else
        cue_filenames{t} = inanimate_pool{n_ptr};
        n_ptr = n_ptr + 1;
    end
end

% Load cue textures
cueTextures = zeros(1, N_TRIALS);
for t = 1:N_TRIALS
    img = imread(fullfile(cue_dir, cue_filenames{t}));
    if size(img,3) == 1, img = repmat(img,[1 1 3]); end
    cueTextures(t) = Screen('MakeTexture', window, img);
end

%% =========================================================
%  DistInterval, fixation side, correct side, digit stream
%% =========================================================
dist_interval = randi(3, 1, N_TRIALS);   % 1/2/3 frames of noise before cue

% Starting fixation location (1=left, 2=right)
startingPos   = randi(2);
fix_side      = zeros(1, N_TRIALS);   % where fixation asterisk appears
cue_side      = zeros(1, N_TRIALS);   % cue appears on fix side
correct_side  = zeros(1, N_TRIALS);   % where correct digit will be

prev_loc = startingPos;
for t = 1:N_TRIALS
    fix_side(t) = prev_loc;
    cue_side(t) = prev_loc;              % cue always appears where fix was
    if all_cue_type(t) == 2             % SHIFT: move attention to other side
        correct_side(t) = 3 - prev_loc;
        prev_loc = correct_side(t);
    else                                 % HOLD: stay on same side
        correct_side(t) = prev_loc;
    end
end

% Fix side for trial t = correct_side of trial t-1
fix_side(1)   = startingPos;
fix_side(2:N_TRIALS) = correct_side(1:N_TRIALS-1);

% Odd/even digit assignment: 1=odd→z, 2=even→m
response_parity = Shuffle([ones(1,N_TRIALS/2), ones(1,N_TRIALS/2)*2]);

% Build Location1/Location2 streams (same logic as main task)
Location1 = cell(1, N_TRIALS);
Location2 = cell(1, N_TRIALS);
CueStart  = zeros(1, N_TRIALS);
TargStart = zeros(1, N_TRIALS);
correct_digit = zeros(1, N_TRIALS);

for t = 1:N_TRIALS
    n_pre     = dist_interval(t) * FRAME_RATE;
    cue_frame = n_pre + 1;
    resp_start= n_pre + 2;
    resp_end  = n_pre + 9;
    total_len = n_pre + 9;

    loc1 = zeros(1, total_len);
    loc2 = zeros(1, total_len);

    % pre-cue noise frames
    for f = 1:n_pre
        [noisePool, noisePoolIdx, loc1(f)] = getNextNoise(noiseTextures, noisePool, noisePoolIdx);
        [noisePool, noisePoolIdx, loc2(f)] = getNextNoise(noiseTextures, noisePool, noisePoolIdx);
    end

    % cue frame
    cue_tex = cueTextures(t);
    [noisePool, noisePoolIdx, noise_cue] = getNextNoise(noiseTextures, noisePool, noisePoolIdx);

    if cue_side(t) == 1  % cue on left
        while n_pre >= 1 && noise_cue == loc2(n_pre)
            [noisePool, noisePoolIdx, noise_cue] = getNextNoise(noiseTextures, noisePool, noisePoolIdx);
        end
        loc1(cue_frame) = cue_tex;
        loc2(cue_frame) = noise_cue;
    else                 % cue on right
        while n_pre >= 1 && noise_cue == loc1(n_pre)
            [noisePool, noisePoolIdx, noise_cue] = getNextNoise(noiseTextures, noisePool, noisePoolIdx);
        end
        loc2(cue_frame) = cue_tex;
        loc1(cue_frame) = noise_cue;
    end

    % response window digits
    if response_parity(t) == 1
        RDig = [1 3 5 7];
    else
        RDig = [2 4 6 8];
    end
    single_correct  = RDig(randi(length(RDig)));
    distract_pool   = setdiff(1:8, single_correct);
    single_distract = distract_pool(randi(length(distract_pool)));

    correct_digit(t) = single_correct;

    if correct_side(t) == 1
        loc1(resp_start:resp_end) = single_correct;
        loc2(resp_start:resp_end) = single_distract;
    else
        loc2(resp_start:resp_end) = single_correct;
        loc1(resp_start:resp_end) = single_distract;
    end

    Location1{t} = loc1;
    Location2{t} = loc2;
    CueStart(t)  = cue_frame;
    TargStart(t) = resp_start;
end

%% =========================================================
%  Show instruction screen
%% =========================================================
Screen('TextSize', window, 36);
DrawFormattedText(window, ...
    ['PRACTICE BLOCK\n\n' ...
     'You will see 30 practice trials.\n\n' ...
     'When you see an ANIMAL image (cue): SHIFT attention to the other side.\n' ...
     'When you see an OBJECT image (cue): HOLD attention on the same side.\n\n' ...
     'Then respond to the number on the attended side:\n' ...
     '  Z = ODD number\n' ...
     '  M = EVEN number\n\n' ...
     'The first 6 trials will show you detailed step-by-step guidance.\n\n' ...
     'Press SPACE to begin.'], ...
    'center', 'center', [0 0 0]);
Screen('Flip', window);

while KbCheck; end
while 1
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown && find(keyCode,1) == KbName('space'), break; end
end

%% =========================================================
%  Data storage
%% =========================================================
Accurate       = zeros(1, N_TRIALS);
ResponseButton = zeros(1, N_TRIALS);
RT_raw         = zeros(1, N_TRIALS);
RT_sub         = zeros(1, N_TRIALS);
CueOnset_VBL   = zeros(1, N_TRIALS);
TargOnset_VBL  = zeros(1, N_TRIALS);

prevFlip   = Screen('Flip', window);
streamFlip = prevFlip;

%% =========================================================
%  Trial loop
%% =========================================================
for trial = 1:N_TRIALS

    % --- PreStim: asterisk + fixation cross ---
    if fix_side(trial) == 1
        DrawFormattedText(window, ' * ', 'center', 'center', [0 0 0], 10, 0, 0, 1, 0, loc1);
    else
        DrawFormattedText(window, ' * ', 'center', 'center', [0 0 0], 10, 0, 0, 1, 0, loc2);
    end
    DrawFormattedText(window, ' + ', 'center', 'center', [0 0 0], 10, 0, 0, 1, 0, center);
    prevFlip   = Screen('Flip', window, prevFlip + 0.5 - slack);
    DrawFormattedText(window, ' + ', 'center', 'center', [0 0 0], 10, 0, 0, 1, 0, center);
    prevFlip   = Screen('Flip', window, prevFlip + 0.25 - slack);
    streamFlip = prevFlip + 0.25;

    % --- Present stream ---
    loc1_stream = Location1{trial};
    loc2_stream = Location2{trial};
    n_frames    = length(loc1_stream);

    for framenum = 1:n_frames
        val1 = loc1_stream(framenum);
        val2 = loc2_stream(framenum);

        if framenum < CueStart(trial)
            % noise frames
            Screen('DrawTexture', window, val1, [], dstRect1);
            Screen('DrawTexture', window, val2, [], dstRect2);

        elseif framenum == CueStart(trial)
            % cue frame
            Screen('DrawTexture', window, val1, [], dstRect1);
            Screen('DrawTexture', window, val2, [], dstRect2);

        else
            % response window: noise background + digit overlay
            [noisePool, noisePoolIdx, n1] = getNextNoise(noiseTextures, noisePool, noisePoolIdx);
            [noisePool, noisePoolIdx, n2] = getNextNoise(noiseTextures, noisePool, noisePoolIdx);
            Screen('DrawTexture', window, n1, [], dstRect1);
            Screen('DrawTexture', window, n2, [], dstRect2);
            DrawFormattedText(window, num2str(val1), 'center', 'center', [0 0 0], 10, 0, 0, 1, 0, loc1);
            DrawFormattedText(window, num2str(val2), 'center', 'center', [0 0 0], 10, 0, 0, 1, 0, loc2);
        end

        DrawFormattedText(window, ' + ', 'center', 'center', [0 0 0], 10, 0, 0, 1, 0, center);

        if framenum == CueStart(trial)
            [CueOnset_VBL(trial), ~, ~, ~] = Screen('Flip', window, streamFlip - slack);
            tmpFlip    = CueOnset_VBL(trial);
            streamFlip = tmpFlip + CUE_FRAME_TIME * 0.001;

        elseif framenum == TargStart(trial)
            [TargOnset_VBL(trial), ~, ~, ~] = Screen('Flip', window, streamFlip - slack);
            KbQueueStart(kb_ind);
            tmpFlip    = TargOnset_VBL(trial);
            streamFlip = tmpFlip + FRAME_TIME * 0.001;

        else
            tmpFlip    = Screen('Flip', window, streamFlip - slack);
            streamFlip = tmpFlip + FRAME_TIME * 0.001;
        end
    end

    % blank + collect response
    DrawFormattedText(window, ' + ', 'center', 'center', [0 0 0], 10, 0, 0, 1, 0, center);
    prevFlip = Screen('Flip', window, streamFlip - slack);
    KbQueueStop(kb_ind);

    [Responded, firstpress] = KbQueueCheck(kb_ind);
    is_correct = 0;
    pressed_key = 0;
    if Responded
        keyCode_pressed = find(firstpress == min(firstpress(firstpress~=0)), 1);
        TimeInSec = min(firstpress(firstpress~=0));
        if keyCode_pressed == KbName('q')
            Screen('CloseAll'); ShowCursor; ListenChar(0);
            KbQueueRelease(kb_ind);
            return;
        end
        pressed_key = keyCode_pressed;
        RT_raw(trial) = TimeInSec;
        RT_sub(trial) = TimeInSec - TargOnset_VBL(trial);
        ResponseButton(trial) = keyCode_pressed;

        correct_z = (keyCode_pressed == KbName('z') && response_parity(trial) == 1);
        correct_m = (keyCode_pressed == KbName('m') && response_parity(trial) == 2);
        if correct_z || correct_m
            is_correct = 1;
        end
    end
    Accurate(trial) = is_correct;
    KbQueueFlush(kb_ind);

    % =========================================================
    %  FEEDBACK
    % =========================================================
    WaitSecs(0.1);

    if trial <= N_GUIDED
        % --- Detailed step-by-step feedback (trials 1-6) ---
        ShowDetailedFeedback(window, trial, ...
            fix_side(trial), all_cue_type(trial), cue_filenames{trial}, ...
            correct_side(trial), correct_digit(trial), response_parity(trial), ...
            is_correct, Responded, pressed_key, ...
            loc1, loc2, center, kb_ind, slack);
    else
        % --- Simple correct/incorrect feedback (trials 7-30) ---
        Screen('TextSize', window, 50);
        if ~Responded
            msg   = 'No Response - Too Slow!';
            color = [200 100 0];
        elseif is_correct
            msg   = 'Correct!';
            color = [0 180 0];
        else
            msg   = 'Incorrect';
            color = [200 0 0];
        end
        DrawFormattedText(window, msg, 'center', 'center', color);
        Screen('Flip', window);
        WaitSecs(1.0);
        Screen('Flip', window);
        WaitSecs(0.3);
    end

    prevFlip = Screen('Flip', window);
    WaitSecs(0.2);

    fprintf('Trial %2d | Block=%s | CueType=%s | CorrectSide=%d | CueFile=%s | Correct=%d\n', ...
        trial, ...
        ternary(all_block(trial)==1,'S','H'), ...
        ternary(all_cue_type(trial)==2,'shift','hold'), ...
        correct_side(trial), ...
        cue_filenames{trial}, ...
        is_correct);
end

%% =========================================================
%  End screen
%% =========================================================
acc = ceil(mean(Accurate) * 100);
Screen('TextSize', window, 40);
DrawFormattedText(window, ...
    ['Practice complete!\n\n' ...
     'Your accuracy: ' num2str(acc) '%\n\n' ...
     'Press SPACE to continue to the main task.'], ...
    'center', 'center', [0 0 0]);
Screen('Flip', window);

while KbCheck; end
while 1
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown && find(keyCode,1) == KbName('space'), break; end
end

%% =========================================================
%  Save
%% =========================================================
if ~exist('Data', 'dir'), mkdir('Data'); end
practice_data.Accurate        = Accurate;
practice_data.ResponseButton  = ResponseButton;
practice_data.RT_raw          = RT_raw;
practice_data.RT_sub          = RT_sub;
practice_data.CueType         = all_cue_type;   % 2=shift, 1=hold
practice_data.CorrectSide     = correct_side;
practice_data.FixSide         = fix_side;
practice_data.CueFilenames    = cue_filenames;
practice_data.ResponseParity  = response_parity;  % 1=odd, 2=even
practice_data.CorrectDigit    = correct_digit;
practice_data.Block           = all_block;
practice_data.Date            = datetime;
save('Data/practice_data.mat', 'practice_data');
fprintf('Practice saved. Accuracy = %d%%\n', acc);

Screen('CloseAll');
ShowCursor;
ListenChar(0);
KbQueueRelease(kb_ind);
end


%% =========================================================
%  Detailed Feedback (trials 1-6)
%% =========================================================
function ShowDetailedFeedback(window, trial, ...
    fix_side, cue_type, cue_fname, ...
    correct_side, correct_digit_val, response_parity, ...
    is_correct, responded, pressed_key, ...
    loc1, loc2, center, kb_ind, slack) %#ok<INUSD>

% --- Build explanatory text ---
if fix_side == 1
    fix_str = 'LEFT';
else
    fix_str = 'RIGHT';
end

if cue_type == 2   % shift = animal
    cue_label  = 'ANIMAL';
    action_str = ['You saw an ANIMAL image  →  SHIFT attention to the ' ...
                  ternary(correct_side==1,'LEFT','RIGHT') ' side.'];
else               % hold = inanimate
    cue_label  = 'OBJECT';
    action_str = ['You saw an OBJECT image  →  HOLD attention on the ' ...
                  ternary(correct_side==1,'LEFT','RIGHT') ' side.'];
end

if response_parity == 1
    parity_str = 'ODD';
    key_str    = 'Z';
else
    parity_str = 'EVEN';
    key_str    = 'M';
end

if is_correct
    outcome_str = 'CORRECT';
    outcome_col = [0 180 0];
elseif ~responded
    outcome_str = 'No Response - Too Slow!';
    outcome_col = [200 100 0];
else
    outcome_str = 'INCORRECT';
    outcome_col = [200 0 0];
end

% --- Build the multi-line message ---
msg = sprintf( ...
    ['--- Trial %d / 6  (Guided Practice) ---\n\n' ...
     'Step 1:  The fixation asterisk ( * ) was on the %s side.\n' ...
     '         So your attention started on the %s side.\n\n' ...
     'Step 2:  The cue was a %s image  ( %s ).\n' ...
     '         %s\n\n' ...
     'Step 3:  The number on the %s side was  %d  which is %s.\n' ...
     '         So the correct key was  %s.\n\n' ...
     'Result:  %s\n\n' ...
     'Press SPACE to continue.'], ...
    trial, fix_str, fix_str, ...
    cue_label, cue_fname, action_str, ...
    ternary(correct_side==1,'LEFT','RIGHT'), correct_digit_val, parity_str, key_str, ...
    outcome_str);

Screen('TextSize', window, 28);
DrawFormattedText(window, msg, 'center', 'center', [0 0 0]);

% Tint background with outcome colour to make correct/incorrect obvious
Screen('FillRect', window, [outcome_col, 40], [0 0 windowWidth(window) windowHeight(window)]);
DrawFormattedText(window, msg, 'center', 'center', [0 0 0]);
Screen('Flip', window);

while KbCheck; end
while 1
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown && find(keyCode,1) == KbName('space'), break; end
end
Screen('Flip', window);
WaitSecs(0.2);
end


%% =========================================================
%  Helper: get next noise texture from shuffled pool
%% =========================================================
function [pool, idx, tex] = getNextNoise(textures, pool, idx)
if idx > length(pool)
    last = pool(end);
    pool = Shuffle(1:length(textures));
    if pool(1) == last
        swap = randi([2, length(pool)]);
        pool([1 swap]) = pool([swap 1]);
    end
    idx = 1;
end
tex = textures(pool(idx));
idx = idx + 1;
end


%% =========================================================
%  Helper: ternary operator
%% =========================================================
function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end


%% =========================================================
%  Helper: get window dimensions (workaround for nested function)
%% =========================================================
function w = windowWidth(win)
rect = Screen('Rect', win);
w = rect(3);
end

function h = windowHeight(win)
rect = Screen('Rect', win);
h = rect(4);
end