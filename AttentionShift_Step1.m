function p = AttentionShift_Step1

%% load participant information
s             = input('Enter Subject Number: ');
startingBlock = input('Enter Version Number (1=SHHS, 2=HSSH, 3=SHSH, 4=HSHS): ');
block_orders  = {'SHHS', 'HSSH', 'SHSH', 'HSHS'};
p.block_order = block_orders{startingBlock};

p.Exp     = 'AttentionShift_ImagePriming';
p.PID     = s;
p.Date    = datetime;
p.Version = startingBlock;
p.Seed    = ClockRandSeed();

diary(['Diaries/' num2str(s) 'diary.txt'])

%% 为4个block各生成一个seq（长度61）
% seq(1)       = 第一个trial的fix点（概念上trial-0的correct_side）
% seq(2:61)    = 60个trial的correct_side，同时决定图片L/R
% 1=左(前120图片)，2=右(后120图片)
% diff(seq)~=0 → shift trial；diff(seq)==0 → hold trial
p.AllSeqs = cell(1, 4);
for blk = 1:4
    start_pt = randi(2);   % 随机起始点1或2
    if p.block_order(blk) == 'S'
        p.AllSeqs{blk} = GenerateSeqFast_S(start_pt);  % 48 shift, 12 hold
    else
        p.AllSeqs{blk} = GenerateSeqFast_H(start_pt);  % 12 shift, 48 hold
    end
end

%%  assign imaging
p = AssignImages(p);
%   p.imagePool         : 120张图片编号（本session使用）
%   p.imageSet          : struct，seta/b/c/d各30张
%   p.imageInfo         : 每张图片的完整信息（condition/BI等）
%   p.blockImages{1..4} : 每个block按seq顺序排列的60张图片编号

%%  PTB初始化
KbName('UnifyKeyNames');
whichScreen = 0;
background  = [0 0 0];

[window, windowRect] = Screen('OpenWindow', whichScreen, background);
HideCursor(window);
p.hz    = Screen('FrameRate', window);
p.slack = Screen('GetFlipInterval', window) / 2;

% stimulus location
p.Cx = windowRect(3) / 2;
p.Cy = windowRect(4) / 2;

% loc1=左 left，loc2=右 right
p.loc1   = [p.Cx-300 p.Cy p.Cx-300 p.Cy];
p.loc2   = [p.Cx+300 p.Cy p.Cx+300 p.Cy];
p.center = [p.Cx p.Cy p.Cx p.Cy];

Screen('TextFont', window, 'Monaco');

%% 图片尺寸配置
p.stimSize = 256;
half       = p.stimSize / 2;
p.dstRect1 = [p.loc1(1)-half, p.loc1(2)-half, p.loc1(1)+half, p.loc1(2)+half];
p.dstRect2 = [p.loc2(1)-half, p.loc2(2)-half, p.loc2(1)+half, p.loc2(2)+half];

%% 载入noise图片 N=240
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

    % 载入本run的cue图片texture
    p = LoadCueTextures(p, run, window);

    % trial setup
    p = TrialSetup(p, run);

    % initialize
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

    while KbCheck; end
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

    %% trial loop
    for trial = 1:p.NumTrials
        p.trial = trial;
        p = PreStim(window, p);

        [p, exitTask] = PresentStream(window, p);

        if exitTask == 1
            Screen('CloseAll');
            break
        end
    end

    %% run结束
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

    p_save = rmfield(p, {'noiseTextures', 'cueTextures', 'noisePool', 'noisePoolIdx'});
    save(['Data/S' num2str(s) 'Within_run' num2str(run) '.mat'], 'p_save');
    datestr(clock);
    fprintf('Accuracy: %d\n', acc);
    fprintf('Data Saved!\n');

    diary off;
    KbQueueRelease(p.ind);

    if run < 4
        p = TakeBreak(window, p);
        KbQueueCreate(p.ind, keyList);
    end
end

Screen('CloseAll');
ShowCursor;
ListenChar(0);
end


% =========================================================================
function seq = GenerateSeqFast_S(start_pt)
% 生成S多序列：48 shift, 12 hold, 30个1, 30个2
% 48个游程，start_pt与第一游程值不同，额外长度12随机分配到48个游程
n_runs  = 48;
n_extra = 12;   % 60 - 48

extra = zeros(1, n_runs);
extra(randperm(n_runs, n_extra)) = 1;
run_lengths = 1 + extra;

first_val = 3 - start_pt;   % 第一游程与start_pt不同
seq_vals  = zeros(1, 60);
ptr = 1;
for r = 1:n_runs
    if mod(r, 2) == 1
        v = first_val;
    else
        v = 3 - first_val;
    end
    seq_vals(ptr : ptr+run_lengths(r)-1) = v;
    ptr = ptr + run_lengths(r);
end
seq = [start_pt, seq_vals];
end


% =========================================================================
function seq = GenerateSeqFast_H(start_pt)
% 生成H多序列：12 shift, 48 hold, 30个1, 30个2
% 12个游程，start_pt与第一游程值不同，额外长度48用stars-and-bars随机分配
n_runs  = 12;
n_extra = 48;   % 60 - 12

cuts        = sort(randperm(n_extra + n_runs - 1, n_runs - 1));
cuts        = [0, cuts, n_extra + n_runs];
run_lengths = diff(cuts);   % 每段长度>=1，总和=60

first_val = 3 - start_pt;
seq_vals  = zeros(1, 60);
ptr = 1;
for r = 1:n_runs
    if mod(r, 2) == 1
        v = first_val;
    else
        v = 3 - first_val;
    end
    seq_vals(ptr : ptr+run_lengths(r)-1) = v;
    ptr = ptr + run_lengths(r);
end
seq = [start_pt, seq_vals];
end


% =========================================================================
function p = AssignImages(p)
% AssignImages  根据AllSeqs为4个block分配图片
%
% seq(2:61)中：1→前120图片（左侧cue），2→后120图片（右侧cue）
% block1/2：encoding，按seq的L/R直接分配新图片
% block3/4：re-exposure，各取一半来自block1，一半来自block2
%           图片的L/R由block3/4自身的seq决定

n_total_each = 120;

% 从前120和后120各随机抽60张供本session使用
pool_front   = Shuffle(1:n_total_each);
pool_back    = Shuffle((n_total_each+1):(n_total_each*2));
picked_front = pool_front(1:60);
picked_back  = pool_back(1:60);
p.imagePool  = [picked_front, picked_back];

% 120张均分为4个set，每set 30张
shuffled     = Shuffle(p.imagePool);
p.imageSet.a = shuffled(1:30);
p.imageSet.b = shuffled(31:60);
p.imageSet.c = shuffled(61:90);
p.imageSet.d = shuffled(91:120);

% 根据block_order确定set分配（encode_block, reexp_block）
switch p.block_order
    case {'SHHS', 'HSSH'}
        assign = [1 4; 1 3; 2 3; 2 4];
    case {'SHSH', 'HSHS'}
        assign = [1 3; 1 4; 2 3; 2 4];
end

sets        = {p.imageSet.a, p.imageSet.b, p.imageSet.c, p.imageSet.d};
block_types = p.block_order;

% 生成imageInfo
n_total = 120;
info(n_total) = struct('stimNum', 0, 'cueType', 0, ...
                       'encodeBlock', 0, 'reexpBlock', 0, ...
                       'condition', '', 'BI', 0);
for s = 1:4
    enc_blk  = assign(s, 1);
    reex_blk = assign(s, 2);
    enc_type = block_types(enc_blk);
    rex_type = block_types(reex_blk);
    cond     = [enc_type, rex_type];
    bi       = reex_blk - enc_blk - 1;
    for j = 1:30
        idx                   = (s-1)*30 + j;
        stim_num              = sets{s}(j);
        info(idx).stimNum     = stim_num;
        info(idx).cueType     = 1 + (stim_num > n_total_each);
        info(idx).encodeBlock = enc_blk;
        info(idx).reexpBlock  = reex_blk;
        info(idx).condition   = cond;
        info(idx).BI          = bi;
    end
end
p.imageInfo = info;

% ---- block1/2：按seq的L/R从imagePool分配图片 ----
% seq(t+1)=1 → 该trial需要前120图片（左侧cue）
% seq(t+1)=2 → 该trial需要后120图片（右侧cue）
pool_L = Shuffle(p.imagePool(p.imagePool <= n_total_each));   % 前120中选出的
pool_R = Shuffle(p.imagePool(p.imagePool >  n_total_each));   % 后120中选出的
L_ptr  = 1;
R_ptr  = 1;

blockImgs = cell(1, 4);

for blk = 1:2
    seq    = p.AllSeqs{blk};
    lr_seq = seq(2:end);        % 长度60，每个trial的L/R
    imgs   = zeros(1, 60);
    for t = 1:60
        if lr_seq(t) == 1       % 需要前120图片（左侧）
            imgs(t) = pool_L(L_ptr);
            L_ptr   = L_ptr + 1;
        else                    % 需要后120图片（右侧）
            imgs(t) = pool_R(R_ptr);
            R_ptr   = R_ptr + 1;
        end
    end
    blockImgs{blk} = imgs;
end

% ---- block3/4：各取一半来自block1，一半来自block2 ----
% 按block3/4自身seq的L/R需求，从block1/2对应的L/R图片池里各取一半
b1_L = blockImgs{1}(blockImgs{1} <= n_total_each);
b1_R = blockImgs{1}(blockImgs{1} >  n_total_each);
b2_L = blockImgs{2}(blockImgs{2} <= n_total_each);
b2_R = blockImgs{2}(blockImgs{2} >  n_total_each);

for blk = 3:4
    seq    = p.AllSeqs{blk};
    lr_seq = seq(2:end);

    n_L_needed = sum(lr_seq == 1);
    n_R_needed = sum(lr_seq == 2);

    % L图片：各取一半来自block1，一半来自block2
    x_L     = min(floor(n_L_needed / 2), length(b1_L));
    y_L     = n_L_needed - x_L;
    taken_L = [Shuffle(b1_L(1:x_L)), Shuffle(b2_L(1:y_L))];

    % R图片：同理
    x_R     = min(floor(n_R_needed / 2), length(b1_R));
    y_R     = n_R_needed - x_R;
    taken_R = [Shuffle(b1_R(1:x_R)), Shuffle(b2_R(1:y_R))];

    % 按seq顺序填入
    pool_L_blk = Shuffle(taken_L);
    pool_R_blk = Shuffle(taken_R);
    L_ptr_blk  = 1;
    R_ptr_blk  = 1;

    imgs = zeros(1, 60);
    for t = 1:60
        if lr_seq(t) == 1
            imgs(t)   = pool_L_blk(L_ptr_blk);
            L_ptr_blk = L_ptr_blk + 1;
        else
            imgs(t)   = pool_R_blk(R_ptr_blk);
            R_ptr_blk = R_ptr_blk + 1;
        end
    end
    blockImgs{blk} = imgs;
end

p.blockImages = blockImgs;
end


% =========================================================================
function p = LoadNoiseTextures(p, window)
stim_root = fullfile('material', 'stimuli');
noise_dir = fullfile(stim_root, 'noise_images');
N_NOISE   = 240;

fprintf('Loading noise textures (%d images)...\n', N_NOISE);
p.noiseTextures = zeros(1, N_NOISE);
for i = 1:N_NOISE
    img = imread(fullfile(noise_dir, sprintf('noise_%03d.png', i)));
    p.noiseTextures(i) = Screen('MakeTexture', window, img);
end

p.noisePool    = Shuffle(1:N_NOISE);
p.noisePoolIdx = 1;
end


% =========================================================================
function p = LoadCueTextures(p, run, window)
stim_root = fullfile('material', 'stimuli');
cue_dir   = fullfile(stim_root, 'cue_images');

if isfield(p, 'cueTextures') && ~isempty(p.cueTextures)
    for i = 1:length(p.cueTextures)
        if p.cueTextures(i) > 0
            Screen('Close', p.cueTextures(i));
        end
    end
end

p.noisePool    = Shuffle(1:length(p.noiseTextures));
p.noisePoolIdx = 1;

image_ids     = p.blockImages{run};
n_cue         = length(image_ids);

p.cueTextures = zeros(1, n_cue);
p.cueImageIDs = image_ids;

for i = 1:n_cue
    img = imread(fullfile(cue_dir, sprintf('cue_%03d.png', image_ids(i))));
    p.cueTextures(i) = Screen('MakeTexture', window, img);
end
end


% =========================================================================
function [p, tex] = GetNoiseTex(p)
if p.noisePoolIdx > length(p.noisePool)
    last_idx = p.noisePool(end);
    new_pool = Shuffle(1:length(p.noiseTextures));
    if new_pool(1) == last_idx
        swap_idx               = randi([2, length(new_pool)]);
        new_pool([1 swap_idx]) = new_pool([swap_idx 1]);
    end
    p.noisePool    = new_pool;
    p.noisePoolIdx = 1;
end
tex            = p.noiseTextures(p.noisePool(p.noisePoolIdx));
p.noisePoolIdx = p.noisePoolIdx + 1;
end


% =========================================================================
function p = TrialSetup(p, run)
% TrialSetup  从AllSeqs直接读取所有trial参数，不再需要ShiftCues生成和imageLocation计算

p.NumTrials = 60;

p.DistInterval = Shuffle([ones(1,20) ones(1,20)*3 ones(1,20)*5]);
p.FrameRate    = 4;
p.FrameTime    = 1000 / p.FrameRate;
p.CueFrameTime = 250;   % ms Here Holland!!!!!!

% ---- 从seq直接读取 ----
seq = p.AllSeqs{run};              % 长度61

% trial t的fix点 = seq(t)（即上一trial的correct_side）
p.StartingLocations = seq(1:60);   % seq(1)~seq(60)

% trial t的correct_side = seq(t+1)
correct_side = seq(2:61);          % seq(2)~seq(61)

% ShiftCues：相邻值变化→shift(2)，不变→hold(1)
p.ShiftCues = ones(1, 60);
p.ShiftCues(diff(seq) ~= 0) = 2;

% 图片顺序：blockImages已在AssignImages中按seq的L/R顺序排好，直接使用
block_imgs       = p.blockImages{run};
p.StimulusNumber = block_imgs;

% CueType：前120→1（左），后120→2（右）
p.CueType = 1 + (block_imgs > 120);

% imageLocation = correct_side（图片出现在correct_side那侧）
imageLocation = correct_side;

% Exposure
if run <= 2
    p.Exposure = ones(1, p.NumTrials);
else
    p.Exposure = ones(1, p.NumTrials) * 2;
end

% Condition
p.Condition = repmat({''}, 1, p.NumTrials);
if run > 2
    for t = 1:p.NumTrials
        idx = find([p.imageInfo.stimNum] == block_imgs(t), 1);
        p.Condition{t} = p.imageInfo(idx).condition;
    end
end

p.Cues = imageLocation;

% ---- Response（奇/偶）----
p.Response    = Shuffle([ones(1,p.NumTrials/2) ones(1,p.NumTrials/2)*2]);
p.TargetStart = zeros(1, p.NumTrials);
p.CueStart    = zeros(1, p.NumTrials);

p.Location1 = cell(1, p.NumTrials);
p.Location2 = cell(1, p.NumTrials);

for t = 1:p.NumTrials
    n_pre      = p.DistInterval(t) * p.FrameRate;
    cue_frame  = n_pre + 1;
    resp_start = n_pre + 2;
    resp_end   = n_pre + 9;
    total_len  = n_pre + 9;

    loc1 = zeros(1, total_len);
    loc2 = zeros(1, total_len);

    for f = 1:n_pre
        [p, loc1(f)] = GetNoiseTex(p);
        [p, loc2(f)] = GetNoiseTex(p);
    end

    cue_tex_pos = find(p.cueImageIDs == block_imgs(t), 1);
    cue_tex     = p.cueTextures(cue_tex_pos);
    [p, noise_cue] = GetNoiseTex(p);

    if imageLocation(t) == 1   % cue图片在左
        while noise_cue == loc2(n_pre)
            [p, noise_cue] = GetNoiseTex(p);
        end
        loc1(cue_frame) = cue_tex;
        loc2(cue_frame) = noise_cue;
    else                       % cue图片在右
        while noise_cue == loc1(n_pre)
            [p, noise_cue] = GetNoiseTex(p);
        end
        loc2(cue_frame) = cue_tex;
        loc1(cue_frame) = noise_cue;
    end

    if p.Response(t) == 1
        RDig = [1 3 5 7];
    else
        RDig = [2 4 6 8];
    end

    while true
        done    = 1;
        ShufDig = Shuffle([RDig RDig]);
        for q = 2:length(ShufDig)
            if ShufDig(q) == ShufDig(q-1)
                done = 0;
            end
        end
        if done; break; end
    end

    if imageLocation(t) == 1
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


% =========================================================================
function p = PreStim(window, p)
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


% =========================================================================
function [p, exitTask] = PresentStream(window, p)
t        = p.trial;
exitTask = 0;

for framenum = 1:length(p.Location1{t})
    val1 = p.Location1{t}(framenum);
    val2 = p.Location2{t}(framenum);

    if framenum < p.CueStart(t)
        Screen('DrawTexture', window, val1, [], p.dstRect1);
        Screen('DrawTexture', window, val2, [], p.dstRect2);
    elseif framenum == p.CueStart(t)
        Screen('DrawTexture', window, val1, [], p.dstRect1);
        Screen('DrawTexture', window, val2, [], p.dstRect2);
    else
        DrawFormattedText(window, num2str(val1), 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.loc1);
        DrawFormattedText(window, num2str(val2), 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.loc2);
    end

    DrawFormattedText(window, ' + ', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.center);

    if framenum == p.CueStart(t)
        p.CueDeadline(t) = p.streamFlip;
        [p.CueOnset.VBLOn(t), p.CueOnset.StimOn(t), p.CueOnset.FlipTime(t), p.CueMissed(t)] = ...
            Screen('Flip', window, p.streamFlip - p.slack);
        tmpFlip      = p.CueOnset.VBLOn(t);
        p.streamFlip = tmpFlip + p.CueFrameTime * 0.001;

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


% =========================================================================
function p = TakeBreak(window, p)
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
