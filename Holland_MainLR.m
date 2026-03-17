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


function seq = GenerateSeqFast_S(start_pt)
% 48个游程，奇数24个，偶数24个
% 额外12个长度：各6个分配给奇数游程，6个分配给偶数游程
% 这样奇数游程总长=24+6=30，偶数游程总长=24+6=30

n_runs   = 48;
odd_runs  = 24;   % 奇数游程
even_runs = 24;   % 偶数游程
n_extra_each = 6; % 奇/偶各分6个额外

extra_odd  = zeros(1, odd_runs);
extra_odd(randperm(odd_runs, n_extra_each)) = 1;

extra_even = zeros(1, even_runs);
extra_even(randperm(even_runs, n_extra_each)) = 1;

% 交织回48个游程
run_lengths = zeros(1, n_runs);
run_lengths(1:2:end) = 1 + extra_odd;    % 奇数位
run_lengths(2:2:end) = 1 + extra_even;   % 偶数位

first_val = 3 - start_pt;
seq_vals  = zeros(1, 60);
ptr = 1;
for r = 1:n_runs
    if mod(r,2) == 1
        v = first_val;
    else
        v = 3 - first_val;
    end
    seq_vals(ptr : ptr+run_lengths(r)-1) = v;
    ptr = ptr + run_lengths(r);
end
seq = [start_pt, seq_vals];
end


function seq = GenerateSeqFast_H(start_pt)
% 12个游程，奇数6个，偶数6个
% 额外48个长度：各24个分配给奇数游程，24个分配给偶数游程

n_runs    = 12;
odd_runs  = 6;
even_runs = 6;
n_extra_each = 24;  % 奇/偶各分24个额外

% stars-and-bars分别给奇/偶游程
cuts_odd  = sort(randperm(n_extra_each + odd_runs - 1,  odd_runs - 1));
cuts_odd  = [0, cuts_odd,  n_extra_each + odd_runs];
len_odd   = diff(cuts_odd);   % 6个奇数游程长度，总和=30

cuts_even = sort(randperm(n_extra_each + even_runs - 1, even_runs - 1));
cuts_even = [0, cuts_even, n_extra_each + even_runs];
len_even  = diff(cuts_even);  % 6个偶数游程长度，总和=30

run_lengths = zeros(1, n_runs);
run_lengths(1:2:end) = len_odd;
run_lengths(2:2:end) = len_even;

first_val = 3 - start_pt;
seq_vals  = zeros(1, 60);
ptr = 1;
for r = 1:n_runs
    if mod(r,2) == 1
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


n_total_each = 120;
block_types  = p.block_order;

% 打乱前120(L)和后120(R)作为供应池
all_L = Shuffle(1:n_total_each);
all_R = Shuffle((n_total_each+1):(n_total_each*2));
L_ptr = 1;
R_ptr = 1;

blockImgs = cell(1, 4);

% ---- block1/2：各抽30L+30R，按seq(2:61)的L/R顺序排列 ----
for blk = 1:2
    imgs_L = Shuffle(all_L(L_ptr : L_ptr+29));   L_ptr = L_ptr + 30;
    imgs_R = Shuffle(all_R(R_ptr : R_ptr+29));   R_ptr = R_ptr + 30;

    lr_seq = p.AllSeqs{blk}(2:end);   % 长度60，1=L，2=R
    lp = 1;  rp = 1;
    imgs = zeros(1, 60);
    for t = 1:60
        if lr_seq(t) == 1
            imgs(t) = imgs_L(lp);  lp = lp + 1;
        else
            imgs(t) = imgs_R(rp);  rp = rp + 1;
        end
    end
    blockImgs{blk} = imgs;
end

% block3/4：15L from blk1 ++ 15L from blk2，R the same
b1_L = Shuffle(blockImgs{1}(blockImgs{1} <= n_total_each));
b1_R = Shuffle(blockImgs{1}(blockImgs{1} >  n_total_each));
b2_L = Shuffle(blockImgs{2}(blockImgs{2} <= n_total_each));
b2_R = Shuffle(blockImgs{2}(blockImgs{2} >  n_total_each));

pools_L = {Shuffle([b1_L(1:15),  b2_L(1:15)]), ...
           Shuffle([b1_L(16:30), b2_L(16:30)])};
pools_R = {Shuffle([b1_R(1:15),  b2_R(1:15)]), ...
           Shuffle([b1_R(16:30), b2_R(16:30)])};

for blk = 3:4
    lr_seq = p.AllSeqs{blk}(2:end);
    pool_L = pools_L{blk-2};
    pool_R = pools_R{blk-2};
    lp = 1;  rp = 1;
    imgs = zeros(1, 60);
    for t = 1:60
        if lr_seq(t) == 1
            imgs(t) = pool_L(lp);  lp = lp + 1;
        else
            imgs(t) = pool_R(rp);  rp = rp + 1;
        end
    end
    blockImgs{blk} = imgs;
end

p.blockImages = blockImgs;

% ---- imageInfo：记录每张图片的基本信息 ----
all_enc_imgs = [blockImgs{1}, blockImgs{2}];
n_total      = length(all_enc_imgs);

info(n_total) = struct('stimNum', 0, 'cueType', 0, ...
                       'firstBlock', 0, 'reexpBlock', 0, ...
                       'condition', '', 'BI', 0);

for entry = 1:n_total
    stim_num = all_enc_imgs(entry);
    enc_blk  = 1 + (entry > 60);

    if any(blockImgs{3} == stim_num)
        reex_blk = 3;
    else
        reex_blk = 4;
    end

    info(entry).stimNum    = stim_num;
    info(entry).cueType    = 1 + (stim_num > n_total_each);
    info(entry).firstBlock = enc_blk;
    info(entry).reexpBlock = reex_blk;
    info(entry).condition  = [block_types(enc_blk), block_types(reex_blk)];
    info(entry).BI         = reex_blk - enc_blk - 1;
end

p.imageInfo = info;
end

% 
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

% -
seq = p.AllSeqs{run};              % 长度61

% trial t的fix点 = seq(t)（即上一trial的correct_side）
p.StartingLocations = seq(1:60);   % seq(1)~seq(60)

% trial t的correct_side = seq(t+1)
correct_side = seq(2:61);          % seq(2)~seq(61)

% ShiftCues：shift(2)，hold(1)
p.ShiftCues = ones(1, 60);
p.ShiftCues(diff(seq) ~= 0) = 2;

% seq 2:61
block_imgs       = p.blockImages{run};
p.StimulusNumber = block_imgs;

% <120 L ; >120 R
p.CueType = 1 + (block_imgs > 120);

% imageLocation = correct_side（
imageLocation = correct_side;

% Exposure/retrevial or not
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

% Response odd/even
p.Response    = Shuffle([ones(1,p.NumTrials/2) ones(1,p.NumTrials/2)*2]); %odd or even for this trial
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

    if imageLocation(t) == 1   % L cue
        while noise_cue == loc2(n_pre)
            [p, noise_cue] = GetNoiseTex(p);
        end
        loc1(cue_frame) = cue_tex;
        loc2(cue_frame) = noise_cue;
    else                       % R cue
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