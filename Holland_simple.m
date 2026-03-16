function p = AttentionShift_Step1

%% load participant information
s = input('Enter Subject Number: ');

p.Exp  = 'AttentionShift_ImagePriming';
p.PID  = s;
p.Date = datetime;
p.Seed = ClockRandSeed();

diary(['Diaries/' num2str(s) 'diary.txt'])

%% random Block

cong_type = randi(2);   % 1=SS, 2=HH
incong_type = randi(2); % 1=SH, 2=HS


% random each pair SS HH SH HS
if cong_type == 1       % SS
    cong_pair = {'S','S'};
else                    % HH
    cong_pair = {'H','H'};
end
if incong_type == 1     % SH
    incong_pair = {'S','H'};
else                    % HS
    incong_pair = {'H','S'};
end

% random pair order
if randi(2) == 1
    pairs = {cong_pair, incong_pair};
else
    pairs = {incong_pair, cong_pair};
end

p.block_order = [pairs{1}{1}, pairs{1}{2}, pairs{2}{1}, pairs{2}{2}];
p.Version = p.block_order;


%% generate all Shiftcues/ Trail type
% 2=shift，1=hold
p.NumTrials       = 60;
p.FrameRate       = 4;
p.AllDistInterval = cell(1, 4);
p.AllShiftCues    = cell(1, 4);

for blk = 1:4
    dist = Shuffle([ones(1,20) ones(1,20)*3 ones(1,20)*5]);
    sc   = zeros(1, p.NumTrials);
    if p.block_order(blk) == 'S'
        sc(dist==1) = Shuffle([ones(1,16)*2 ones(1,4)]);
        sc(dist==3) = Shuffle([ones(1,16)*2 ones(1,4)]);
        sc(dist==5) = Shuffle([ones(1,16)*2 ones(1,4)]);
    else
        sc(dist==1) = Shuffle([ones(1,4)*2 ones(1,16)]);
        sc(dist==3) = Shuffle([ones(1,4)*2 ones(1,16)]);
        sc(dist==5) = Shuffle([ones(1,4)*2 ones(1,16)]);
    end
    p.AllDistInterval{blk} = dist; % distraction???
    p.AllShiftCues{blk}    = sc;
end

%%  assign imaging
p = AssignImages(p);


%%  PTB 
KbName('UnifyKeyNames');
whichScreen = 0;
background  = [0 0 0];

[window, windowRect] = Screen('OpenWindow', whichScreen, background);
HideCursor(window);
p.hz    = Screen('FrameRate', window);
p.slack = Screen('GetFlipInterval', window) / 2;

% stimlus location
p.Cx = windowRect(3) / 2;
p.Cy = windowRect(4) / 2;

% loc1= left，loc2= right，
p.loc1   = [p.Cx-300 p.Cy p.Cx-300 p.Cy];
p.loc2   = [p.Cx+300 p.Cy p.Cx+300 p.Cy];
p.center = [p.Cx p.Cy p.Cx p.Cy];
% delete all loc3-8

Screen('TextFont', window, 'Monaco');

%% picture size markker!!!!
% 如需修改呈现尺寸只改这一行 Here Holland
p.stimSize = 256;   % !!!!! must be consist of generate_stimuli.m中img_size一致
half       = p.stimSize / 2;
p.dstRect1 = [p.loc1(1)-half, p.loc1(2)-half, p.loc1(1)+half, p.loc1(2)+half];
p.dstRect2 = [p.loc2(1)-half, p.loc2(2)-half, p.loc2(1)+half, p.loc2(2)+half];

%% load noise N=240
p = LoadNoiseTextures(p, window);

%% keyboard setup
keyList = zeros(1, 256);
keyList([KbName('z') KbName('m') KbName('q')]) = 1;
ind  = GetKeyboardIndices;
p.ind = ind(length(ind)-1);
KbQueueCreate(p.ind, keyList);

%% Main Loop
for run = 1:4
    p.run = run;

    % load the cue texture in this run
    p = LoadCueTextures(p, run, window);

    % trial setup for this run
    p = TrialSetup(p, run);

    % inistialize
    p.CueDeadline              = zeros(1, p.NumTrials);
    p.TargetDeadline           = zeros(1, p.NumTrials);
    p.CueOnset.VBLOn           = zeros(1, p.NumTrials);
    p.CueOnset.StimOn          = zeros(1, p.NumTrials);
    p.CueOnset.FlipTime        = zeros(1, p.NumTrials);
    p.CueMissed                = zeros(1, p.NumTrials);
    p.TargetOnset.VBLOn        = zeros(1, p.NumTrials);
    p.TargetOnset.StimOn       = zeros(1, p.NumTrials);
    p.TargetOnset.FlipTime     = zeros(1, p.NumTrials);
    p.TargetMissed             = zeros(1, p.NumTrials);
    p.ResponseButton           = zeros(1, p.NumTrials);
    p.ResponseTimes.Raw        = zeros(1, p.NumTrials);
    p.ResponseTimes.Subtracted = zeros(1, p.NumTrials);
    p.Accurate                 = zeros(1, p.NumTrials);

    % begin
    Screen('TextSize', window, 40);
    DrawFormattedText(window, 'Press the SPACE bar to Begin the Task', 'center', 'center', [255 255 255]);
    Screen('Flip', window);

    while KbCheck; end  % 先等所有按键松开，防止之前按着的键被误读
    while 1
        [keyIsDown, ~, keyCode] = KbCheck;
        keyCode = find(keyCode, 1);
        if keyIsDown && keyCode == KbName('space')
            p.StartOfExp = Screen('Flip', window);
            break;
        end
    end
    p.prevFlip = p.StartOfExp;
    p.trial    = 0;

    %% trial loop for PTB
    for trial = 1:p.NumTrials
        p.trial = trial;
        p = PreStim(window, p);


        [p, exitTask] = PresentStream(window, p);

        if exitTask == 1
            Screen('CloseAll');
            break
        end
    end

    %% run end
    Screen('Flip', window);
    WaitSecs(0.5);
    Screen('TextSize', window, 40);

    if trial == p.NumTrials
        acc = ceil(mean(p.Accurate) * 100);
    else
        acc = 0;
    end

    DrawFormattedText(window, ['Your Accuracy Was ' num2str(acc) '%'], 'center', 'center', [255 255 255]);
    Screen('Flip', window);
    WaitSecs(4);

    %
    p_save = rmfield(p, {'noiseTextures', 'cueTextures', 'noisePool', 'noisePoolIdx'});
    save(['Data/S' num2str(s) 'Within_run' num2str(run) '.mat'], 'p_save');
    datestr(clock);
    fprintf('Accuracy: %d\n', acc);
    fprintf('Data Saved!\n');

    diary off;
    KbQueueRelease(p.ind);

    % break
    if run < 4
        p = TakeBreak(window, p);
        KbQueueCreate(p.ind, keyList);
    end
end

Screen('CloseAll');
ShowCursor;
ListenChar(0);
end



function p = AssignImages(p)

n_total_each   = 120;
n_priming      = 24;    % priming test per retrieval block
n_priming_each = 12;    % 12 shift + 12 hold per retrieval block
n_priming_all  = n_priming * 2;   % 48 priming images total, strictly reserved

block_types = p.block_order;

%% save 48张priming pictue，and rest go to the filler pool
priming_pool_front = Shuffle(1:n_total_each);
priming_pool_back  = Shuffle((n_total_each+1):(n_total_each*2));
% grab 24 for priming
reserved_front = priming_pool_front(1:n_priming_all/2);   % 24张shift priming专用
reserved_back  = priming_pool_back(1:n_priming_all/2);    % 24张hold priming专用

% rest of them go to the filler pool
filler_pool_front = priming_pool_front(n_priming_all/2+1:end);  % 96张shift filler
filler_pool_back  = priming_pool_back(n_priming_all/2+1:end);   % 96张hold filler

% priming pointer???
priming_front_ptr = 1;
priming_back_ptr  = 1;

blockImgs       = cell(1, 4);
primingTrialIdx = cell(1, 4);

%% pari by pair
for pair = 1:2
    enc_blk = (pair-1)*2 + 1;   % 1 或 3
    ret_blk = (pair-1)*2 + 2;   % 2 或 4

    enc_sc = p.AllShiftCues{enc_blk};
    ret_sc = p.AllShiftCues{ret_blk};

    %% encoding block：从filler pool随机取
    enc_imgs = zeros(1, p.NumTrials);
    for t = 1:p.NumTrials
        if enc_sc(t) == 2   % shift for filler_pool_front
            enc_imgs(t) = filler_pool_front(randi(length(filler_pool_front)));
        else                 % hold  from filler_pool_back
            enc_imgs(t) = filler_pool_back(randi(length(filler_pool_back)));
        end
    end
    blockImgs{enc_blk} = enc_imgs;

    %% retrieval block：12 shift priming + 12 hold priming + filler
    priming_shift = reserved_front(priming_front_ptr : priming_front_ptr + n_priming_each - 1);
    priming_hold  = reserved_back(priming_back_ptr   : priming_back_ptr  + n_priming_each - 1);
    priming_front_ptr = priming_front_ptr + n_priming_each;
    priming_back_ptr  = priming_back_ptr  + n_priming_each;

    % filler get from the filler pool
    n_ret_shift  = sum(ret_sc == 2);
    n_ret_hold   = sum(ret_sc == 1);
    n_fill_shift = n_ret_shift - n_priming_each;
    n_fill_hold  = n_ret_hold  - n_priming_each;

    % shift filler
    available_front = filler_pool_front(~ismember(filler_pool_front, priming_shift));
    filler_shift    = available_front(randi(length(available_front), 1, n_fill_shift));
    % hold filler
    available_back = filler_pool_back(~ismember(filler_pool_back, priming_hold));
    filler_hold    = available_back(randi(length(available_back), 1, n_fill_hold));

    % 合并priming和filler，shuffle， track priming location
    all_shift_pool   = [priming_shift, filler_shift];
    all_hold_pool    = [priming_hold,  filler_hold];
    is_priming_shift = [true(1,n_priming_each), false(1,n_fill_shift)];
    is_priming_hold  = [true(1,n_priming_each), false(1,n_fill_hold)];

    perm_shift       = randperm(length(all_shift_pool));
    perm_hold        = randperm(length(all_hold_pool)); % get a random seed index
    all_shift_pool   = all_shift_pool(perm_shift);
    is_priming_shift = is_priming_shift(perm_shift);
    all_hold_pool    = all_hold_pool(perm_hold);
    is_priming_hold  = is_priming_hold(perm_hold);

    ret_imgs   = zeros(1, p.NumTrials);
    is_priming = false(1, p.NumTrials);
    shift_ptr2 = 1;
    hold_ptr2  = 1;
    % fullfill trial by trial and track
    for t = 1:p.NumTrials
        if ret_sc(t) == 2
            ret_imgs(t)  = all_shift_pool(shift_ptr2);
            is_priming(t)= is_priming_shift(shift_ptr2);
            shift_ptr2   = shift_ptr2 + 1;
        else
            ret_imgs(t)  = all_hold_pool(hold_ptr2);
            is_priming(t)= is_priming_hold(hold_ptr2);
            hold_ptr2    = hold_ptr2 + 1;
        end
    end

    blockImgs{ret_blk}       = ret_imgs;
    primingTrialIdx{ret_blk} = find(is_priming);
end

p.blockImages     = blockImgs;
p.primingTrialIdx = primingTrialIdx;

%% generate imageInfo
n_priming_total = n_priming * 2;   % 48 priming test
info(n_priming_total) = struct('stimNum', 0, 'cueType', 0, ...
                              'encodeBlock', 0, 'retrievalBlock', 0, ...
                              'condition', '', 'BI', 1);

entry = 1;
for pair = 1:2
    enc_blk = (pair-1)*2 + 1;
    ret_blk = (pair-1)*2 + 2;
    enc_type = block_types(enc_blk);
    ret_type = block_types(ret_blk);
    priming_trials = primingTrialIdx{ret_blk};

    for i = 1:length(priming_trials)
        t        = priming_trials(i);
        stim_num = blockImgs{ret_blk}(t);
        info(entry).stimNum     = stim_num;
        info(entry).cueType     = 1 + (stim_num > n_total_each);  % 1=shift, 2=hold
        info(entry).encodeBlock = enc_blk;
        info(entry).retrievalBlock  = ret_blk;
        info(entry).condition   = [enc_type, ret_type];
        info(entry).BI          = 1;   % 相邻block，BI固定=1 
        entry = entry + 1;
    end
end
p.imageInfo = info(1:entry-1);
end



function p = LoadNoiseTextures(p, window)
% LoadNoiseTextures  load all 240 noise
stim_root = fullfile('material', 'stimuli');
noise_dir = fullfile(stim_root, 'noise_images');
N_NOISE   = 240;  


fprintf('Loading noise textures (%d images)...\n', N_NOISE);
p.noiseTextures = zeros(1, N_NOISE);
for i = 1:N_NOISE
    img = imread(fullfile(noise_dir, sprintf('noise_%03d.png', i)));
    p.noiseTextures(i) = Screen('MakeTexture', window, img);
end


% Initialize noise pool
p.noisePool    = Shuffle(1:N_NOISE);
p.noisePoolIdx = 1;
end


function p = LoadCueTextures(p, run, window)
% LoadCueTextures  60 picture
stim_root = fullfile('material', 'stimuli');
cue_dir   = fullfile(stim_root, 'cue_images');

% 释放上一个run的cue texture
if isfield(p, 'cueTextures') && ~isempty(p.cueTextures)
    for i = 1:length(p.cueTextures)
        if p.cueTextures(i) > 0
            Screen('Close', p.cueTextures(i));
        end
    end
end

% rondom the noise pool
p.noisePool    = Shuffle(1:length(p.noiseTextures));
p.noisePoolIdx = 1;

image_ids     = p.blockImages{run};   % 60 number in this run
n_cue         = length(image_ids);


p.cueTextures = zeros(1, n_cue);
p.cueImageIDs = image_ids;

for i = 1:n_cue
    img = imread(fullfile(cue_dir, sprintf('cue_%03d.png', image_ids(i))));
    p.cueTextures(i) = Screen('MakeTexture', window, img);
end
end



function [p, tex] = GetNoiseTex(p)
% GetNoiseTex  从noise索引池取下一张noise texture，池耗尽时自动reshuffle
% 保证收尾衔接不重复

if p.noisePoolIdx > length(p.noisePool)
    last_idx = p.noisePool(end);   % 记录上一轮最后一个

    new_pool = Shuffle(1:length(p.noiseTextures));

    % 如果新池第一个和上一轮最后一个相同，随机找一个位置交换
    if new_pool(1) == last_idx
        swap_idx              = randi([2, length(new_pool)]);
        new_pool([1 swap_idx]) = new_pool([swap_idx 1]);
    end

    p.noisePool    = new_pool;
    p.noisePoolIdx = 1;
end

tex            = p.noiseTextures(p.noisePool(p.noisePoolIdx));
p.noisePoolIdx = p.noisePoolIdx + 1;
end



function p = TrialSetup(p, run)


p.NumTrials = 60;

% we generate those first, so just read them
p.DistInterval = p.AllDistInterval{run};
p.FrameRate    = 4;
p.FrameTime    = 1000 / p.FrameRate;   % ms
p.CueFrameTime = 250;   % ms Here Holland!!!!!!
p.ShiftCues = p.AllShiftCues{run};   % 2=shift, 1=hold


% we have generated it first
block_imgs       = p.blockImages{run};
p.StimulusNumber = block_imgs;

% encoding（奇数block）， retrieval（偶数block）
if mod(run, 2) == 1   % encoding block
    p.Exposure = ones(1, p.NumTrials);          % 1=encoding
else                   % retrieval block
    p.Exposure = ones(1, p.NumTrials) * 3;      % 3=filler/new image（默认）
    priming_trials = p.primingTrialIdx{run};
    p.Exposure(priming_trials) = 2;               % 2=priming test
end

% Condition：encoding block全为空，retrieval block的priming test trial填SS/HH/SH/HS
p.Condition = repmat({''}, 1, p.NumTrials);
if mod(run, 2) == 0   % retrieval block
    priming_trials = p.primingTrialIdx{run};
    for i = 1:length(priming_trials)
        t   = priming_trials(i);
        idx = find([p.imageInfo.stimNum] == block_imgs(t), 1);
        if ~isempty(idx)
            p.Condition{t} = p.imageInfo(idx).condition;
        end
    end
end


p.CueType = 1 + (block_imgs > 120);   % 前120(shift指令)→1，后120(hold指令)→2


startingPosition = randi(2);
imageLocation    = zeros(1, p.NumTrials);
correct_side     = zeros(1, p.NumTrials);
prev_Loc         = startingPosition;

for w = 1:p.NumTrials
    imageLocation(w) = prev_Loc;        % cue图片出现在fix点那侧
    if p.CueType(w) == 2                % hold：correct_side同侧，prev_Loc不变
        correct_side(w) = prev_Loc;
    elseif p.CueType(w) == 1            % shift：correct_side对侧，prev_Loc翻转
        if prev_Loc == 1
            correct_side(w) = 2;
            prev_Loc = 2;
        else
            correct_side(w) = 1;
            prev_Loc = 1;
        end
    end
end

p.CuesAppearLocation                   = imageLocation;
p.StartingLocations       = startingPosition;
p.StartingLocations(2:60) = correct_side(1:59);  % trial t的fix = 上一trial的correct_side

% random odd/even Response stream
p.Response    = Shuffle([ones(1,p.NumTrials/2) ones(1,p.NumTrials/2)*2]); % correct stream is even or odd for this trial
p.TargetStart = zeros(1, p.NumTrials);
p.CueStart    = zeros(1, p.NumTrials);


p.Location1 = cell(1, p.NumTrials);
p.Location2 = cell(1, p.NumTrials);

% fullfill trail by tiral
for t = 1:p.NumTrials
    n_pre      = p.DistInterval(t) * p.FrameRate; % noise frame
    cue_frame  = n_pre + 1; % cue帧在序列中的位置
    resp_start = n_pre + 2; % response window第一帧
    resp_end   = n_pre + 9; % response window最后一帧（共8帧）
    total_len  = n_pre + 9; % 整个序列总长度

    loc1 = zeros(1, total_len);
    loc2 = zeros(1, total_len);

    % cue前noise帧
    for f = 1:n_pre
        [p, loc1(f)] = GetNoiseTex(p);
        [p, loc2(f)] = GetNoiseTex(p);
    end

    % cue帧：cue图片出现在imageLocation那侧，另一侧noise
    % 干扰侧noise不能和该侧前一帧（cue前最后一帧）相同
    cue_tex_pos = find(p.cueImageIDs == block_imgs(t), 1);
    cue_tex     = p.cueTextures(cue_tex_pos);
    [p, noise_cue] = GetNoiseTex(p);

    if imageLocation(t) == 1   % cue图片在左
        % 干扰侧是右侧，检查noise_cue不与loc2前一帧重复
        while noise_cue == loc2(n_pre)
            [p, noise_cue] = GetNoiseTex(p);
        end
        loc1(cue_frame) = cue_tex;
        loc2(cue_frame) = noise_cue;
    else                        % cue图片在右
        % 干扰侧是左侧，检查noise_cue不与loc1前一帧重复
        while noise_cue == loc1(n_pre)
            [p, noise_cue] = GetNoiseTex(p);
        end
        loc2(cue_frame) = cue_tex;
        loc1(cue_frame) = noise_cue;
    end

    % Response window 
    if p.Response(t) == 1
        RDig = [1 3 5 7];
    else
        RDig = [2 4 6 8];
    end

    while true
        done    = 1;
        ShufDig = Shuffle([RDig RDig]);
        for q = 2:length(ShufDig)
            if ShufDig(q) == ShufDig(q-1) % any repeat?
                done = 0;
            end
        end
        if done; break; end
    end

    % all odd or even number will be in the correct_side and the other is
    % the randi stream.
    if correct_side(t) == 1
        loc1(resp_start:resp_end) = ShufDig;
        loc2(resp_start:resp_end) = randi(8, 1, 8);
    else
        loc2(resp_start:resp_end) = ShufDig;
        loc1(resp_start:resp_end) = randi(8, 1, 8);
    end

    p.Location1{t} = loc1;
    p.Location2{t} = loc2;
    p.CueStart(t)    = cue_frame;
    p.TargetStart(t) = resp_start;
end
end



function p = PreStim(window, p)
% PreStim  asterisk

if p.StartingLocations(p.trial) == 1
    DrawFormattedText(window, ' * ', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.loc1);
elseif p.StartingLocations(p.trial) == 2
    DrawFormattedText(window, ' * ', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.loc2);
end
DrawFormattedText(window, ' + ', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.center);
p.prevFlip   = Screen('Flip', window, p.prevFlip + 0.5 - p.slack);
DrawFormattedText(window, ' + ', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.center);
p.prevFlip   = Screen('Flip', window, p.prevFlip + 0.25 - p.slack);
p.streamFlip = p.prevFlip + 0.25;
end


% 
function [p, exitTask] = PresentStream(window, p)

t        = p.trial;
exitTask = 0;

for framenum = 1:length(p.Location1{t})

    val1 = p.Location1{t}(framenum);
    val2 = p.Location2{t}(framenum);

    if framenum < p.CueStart(t)
        % cue前noise帧 
        Screen('DrawTexture', window, val1, [], p.dstRect1);
        Screen('DrawTexture', window, val2, [], p.dstRect2);

    elseif framenum == p.CueStart(t)
        % cue帧目标侧是实验图片，干扰侧是noise 
        Screen('DrawTexture', window, val1, [], p.dstRect1);
        Screen('DrawTexture', window, val2, [], p.dstRect2);

    else
        % response window：数字判断
        DrawFormattedText(window, num2str(val1), 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.loc1);
        DrawFormattedText(window, num2str(val2), 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.loc2);
    end

    DrawFormattedText(window, ' + ', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.center);

    % flip
    % cue帧用CueFrameTime，其余帧用FrameTime

    if framenum == p.CueStart(t)
        p.CueDeadline(t) = p.streamFlip;
        [p.CueOnset.VBLOn(t), p.CueOnset.StimOn(t), p.CueOnset.FlipTime(t), p.CueMissed(t)] = ...
            Screen('Flip', window, p.streamFlip - p.slack);
        tmpFlip      = p.CueOnset.VBLOn(t);
        p.streamFlip = tmpFlip + p.CueFrameTime * 0.001;   %  cue帧用CueFrameTime

    elseif framenum == p.TargetStart(t)
        [p.TargetOnset.VBLOn(t), p.TargetOnset.StimOn(t), p.TargetOnset.FlipTime(t), p.TargetMissed(t)] = ...
            Screen('Flip', window, p.streamFlip - p.slack);
        KbQueueStart(p.ind);
        tmpFlip      = p.TargetOnset.VBLOn(t);
        p.streamFlip = tmpFlip + p.FrameTime * 0.001;

    else
        tmpFlip      = Screen('Flip', window, p.streamFlip - p.slack);
        p.streamFlip = tmpFlip + p.FrameTime * 0.001;
    end
end

DrawFormattedText(window, ' + ', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.center);
p.prevFlip = Screen('Flip', window, p.streamFlip - p.slack);
KbQueueStop(p.ind);

% 
[Responded, firstpress] = KbQueueCheck(p.ind);
if Responded
    keyCode       = find(firstpress == (min(firstpress(firstpress~=0))));
    TimeInSeconds = min(firstpress(firstpress~=0));
    if keyCode == KbName('z') || keyCode == KbName('m')
        p.ResponseButton(t)           = keyCode;
        p.ResponseTimes.Raw(t)        = TimeInSeconds;
        p.ResponseTimes.Subtracted(t) = TimeInSeconds - p.TargetOnset.VBLOn(t);
        if keyCode == KbName('z') && p.Response(t) == 1
            p.Accurate(t) = 1;
            fprintf(' | Press %s: Response Accurate\n', KbName(keyCode));
        elseif keyCode == KbName('m') && p.Response(t) == 2
            p.Accurate(t) = 1;
            fprintf(' | Press %s: Response Accurate\n', KbName(keyCode));
        else
            p.Accurate(t) = 0;
            fprintf(' | Press %s: Response Inaccurate\n', KbName(keyCode));
        end
    end
    if keyCode == KbName('q')
        exitTask = 1;
        return
    end
else
    fprintf(' | No Response\n');
end
KbQueueFlush(p.ind);
end



function p = TakeBreak(window, p)
% TakeBreak  

Screen('TextSize', window, 40);
acc = ceil(mean(p.Accurate) * 100);
DrawFormattedText(window, ['Take a Break \n Your Accuracy Was ' num2str(acc) '%'], 'center', 'center', [255 255 255]);
p.prevFlip = Screen('Flip', window, p.prevFlip - p.slack);
DrawFormattedText(window, 'Press the SPACE bar to Continue', 'center', 'center', [255 255 255]);
fprintf('Accuracy: %d\n', acc);
WaitSecs(29.5);
Screen('Flip', window, p.prevFlip + 30);
while KbCheck; end

while 1
    [keyIsDown, ~, keyCode] = KbCheck;
    keyCode = find(keyCode, 1);
    if keyIsDown && keyCode == KbName('space')
        break;
    end
end

WaitSecs(0.1);
Screen('TextSize', window, 40);
DrawFormattedText(window, 'Press the SPACE bar to Begin the Task', 'center', 'center', [255 255 255]);
Screen('TextSize', window, 80);
Screen('Flip', window);
while KbCheck; end

while 1
    [keyIsDown, ~, keyCode] = KbCheck;
    keyCode = find(keyCode, 1);
    if keyIsDown && keyCode == KbName('space')
        p.prevFlip = Screen('Flip', window);
        break;
    end
end
end


% ==================================================
% /\_/\\
%( o.o )    MATLAB is watching you...
% > ^ <
% ==================================================