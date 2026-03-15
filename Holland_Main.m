function p = AttentionShift_Step1

%% load participant information
s             = input('Enter Subject Number: ');
startingBlock = input('Enter Version Number (1=SHHS, 2=HSSH, 3=SHSH, 4=HSHS): ');% We have 4 condition this time
block_orders = {'SHHS', 'HSSH', 'SHSH', 'HSHS'};
p.block_order = block_orders{startingBlock};

p.Exp     = 'AttentionShift_ImagePriming';
p.PID     = s;
p.Date    = datetime;
p.Version = startingBlock;
p.Seed    = ClockRandSeed();

diary(['Diaries/' num2str(s) 'diary.txt'])

%%  assign imaging
p = AssignImages(p);
%   p.imagePool         : 120 number for this session
%   p.imageSet          : struct for seta setb setc setd
%   p.imageInfo         : for each image information(I aslo caculate the conditon and BI here)
%   p.blockImages{1..4} : 每个block要呈现的图片编号

%%  PTB初始化
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

% loc1=左 left，loc2=右 right，格式[cx cy cx cy]
p.loc1   = [p.Cx-300 p.Cy p.Cx-300 p.Cy];
p.loc2   = [p.Cx+300 p.Cy p.Cx+300 p.Cy];
p.center = [p.Cx p.Cy p.Cx p.Cy];
% delete all loc3-8

Screen('TextFont', window, 'Monaco');

%% 图片尺寸配置 picture size markker!!!!
% 如需修改呈现尺寸只改这一行 Here Holland
p.stimSize = 256;   % !!!!! must be consist of generate_stimuli.m中img_size一致
half       = p.stimSize / 2;
p.dstRect1 = [p.loc1(1)-half, p.loc1(2)-half, p.loc1(1)+half, p.loc1(2)+half];
p.dstRect2 = [p.loc2(1)-half, p.loc2(2)-half, p.loc2(1)+half, p.loc2(2)+half];

%% load 载入noise图片 N=240
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

    % -载入本run的cue图片texture 
    p = LoadCueTextures(p, run, window);

    % trial setup
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
% AssignImages  从240张图片中抽取120张，根据block_order分配至4个block


n_total_each = 120;   % 前/后各120张（编号1-120和121-240）
n_pick_each  = 60;    % 各随机抽60张
n_per_set    = 30;    % 每个set 30张

% 从前120和后120各随机抽60张
pool_front = Shuffle(1:n_total_each);
pool_back  = Shuffle((n_total_each+1):(n_total_each*2));

picked_front = pool_front(1:n_pick_each);
picked_back  = pool_back(1:n_pick_each);
p.imagePool  = [picked_front, picked_back];

% 120张随机shuffle后均分为4个set
shuffled     = Shuffle(p.imagePool);
p.imageSet.a = shuffled(1             : n_per_set);
p.imageSet.b = shuffled(n_per_set+1   : n_per_set*2);
p.imageSet.c = shuffled(n_per_set*2+1 : n_per_set*3);
p.imageSet.d = shuffled(n_per_set*3+1 : n_per_set*4);

% ---- 根据block_order确定每个set的分配 ----
% [encode_block, reexp_block]，行对应seta/b/c/d
% SHHS/HSSH：回文结构
% SHSH/HSHS：交替结构
switch p.block_order
    case {'SHHS', 'HSSH'}
        assign = [1 4; 1 3; 2 3; 2 4];
    case {'SHSH', 'HSHS'}
        assign = [1 3; 1 4; 2 3; 2 4];
end

sets       = {p.imageSet.a, p.imageSet.b, p.imageSet.c, p.imageSet.d};
block_types = p.block_order;   % 第k个字符='S'或'H'

% 生成每张图片的完整信息
n_total = n_per_set * 4;
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

    for j = 1:n_per_set
        idx              = (s-1)*n_per_set + j;
        stim_num         = sets{s}(j);
        info(idx).stimNum     = stim_num;
        info(idx).cueType     = 1 + (stim_num > n_total_each);  % 1=前120, 2=后120
        info(idx).encodeBlock = enc_blk;
        info(idx).reexpBlock  = reex_blk;
        info(idx).condition   = cond;
        info(idx).BI          = bi;
    end
end
p.imageInfo = info;


% block1/2：encoding图片；block3/4：re-exposure图片
p.blockImages = cell(1, 4);
for blk = 1:4
    enc_imgs       = [info([info.encodeBlock] == blk).stimNum]; % encoding only could be 1 or 2 here
    reex_imgs      = [info([info.reexpBlock]  == blk).stimNum]; % encoding only could be 3 or 4 here
    % info(0,0,0...1,1,).stimNum a array for imaging
    p.blockImages{blk} = [enc_imgs, reex_imgs];
end
end

% =========================================================================
function p = LoadNoiseTextures(p, window)
% LoadNoiseTextures  载入全部240张noise图片texture
stim_root = 'stimuli';
noise_dir = fullfile(stim_root, 'noise_images');
N_NOISE   = 240;  
% ----------------------------------------------

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


% =========================================================================
function p = LoadCueTextures(p, run, window)
% LoadCueTextures  载入当前run所需的60张cue图片texture
stim_root = 'stimuli';
cue_dir   = fullfile(stim_root, 'cue_images');

% 释放上一个run的cue texture
if isfield(p, 'cueTextures') && ~isempty(p.cueTextures)
    for i = 1:length(p.cueTextures)
        if p.cueTextures(i) > 0
            Screen('Close', p.cueTextures(i));
        end
    end
end

% 重置noise池（每个run独立随机）
p.noisePool    = Shuffle(1:length(p.noiseTextures));
p.noisePoolIdx = 1;

image_ids     = p.blockImages{run};   % 本run的60张图片编号
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
% GetNoiseTex  从noise索引池取下一张noise texture，池耗尽时自动reshuffle
% 保证收尾衔接不重复

if p.noisePoolIdx > length(p.noisePool)
    last_idx = p.noisePool(end);   % 记录上一轮最后一个索引

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


% =========================================================================
function p = TrialSetup(p, run)
% TrialSetup  为当前run生成所有trial参数，预填Location序列

p.NumTrials = 60;

% ---- 时间参数 ----
p.DistInterval = Shuffle([ones(1,20) ones(1,20)*3 ones(1,20)*5]);
p.FrameRate    = 4;
p.FrameTime    = 1000 / p.FrameRate;   % ms

% cue picuture time
p.CueFrameTime = 250;   % ms

% ShiftCues：由当前block类型决定80/20比例 

p.ShiftCues = zeros(1, p.NumTrials); %2 for shiftl; 1 for hold
if p.block_order(run) == 'S'
    p.ShiftCues(p.DistInterval==1) = Shuffle([ones(1,16)*2 ones(1,4)]);
    p.ShiftCues(p.DistInterval==3) = Shuffle([ones(1,16)*2 ones(1,4)]);
    p.ShiftCues(p.DistInterval==5) = Shuffle([ones(1,16)*2 ones(1,4)]);
else   % 'H'
    p.ShiftCues(p.DistInterval==1) = Shuffle([ones(1,4)*2 ones(1,16)]);
    p.ShiftCues(p.DistInterval==3) = Shuffle([ones(1,4)*2 ones(1,16)]);
    p.ShiftCues(p.DistInterval==5) = Shuffle([ones(1,4)*2 ones(1,16)]);
end




block_imgs = Shuffle(p.blockImages{run});   %
p.StimulusNumber = block_imgs;

% encoding（block1/2）， retreival（block3/4）
if run <= 2
    p.Exposure = ones(1, p.NumTrials);   
else
    p.Exposure = ones(1, p.NumTrials)*2;  
end

% Condition：encoding block全为空，re-exposure block SS/HH/SH/HS
p.Condition = repmat({''}, 1, p.NumTrials);
if run > 2
    for t = 1:p.NumTrials
        idx = find([p.imageInfo.stimNum] == block_imgs(t), 1);
        p.Condition{t} = p.imageInfo(idx).condition;
    end
end


p.CueType = 1 + (block_imgs > 120);   % 前120→1，后120→2


%   cueType=1（前120）对应左侧，cueType=2（后120）对应右侧
%   H trial（hold）：cue图片出现在cueType指示的那侧
%   S trial（shift）：cue图片出现在cueType指示的对侧
%   cue图片、fix点（星号）、response window全奇/偶stream → 全在imageLocation那侧
%   另一侧 → 随机数字stream

imageLocation = zeros(1, p.NumTrials);
for t = 1:p.NumTrials
    if p.ShiftCues(t) == 1   % hold trial：和cueType指示侧一致
        imageLocation(t) = p.CueType(t);
    else                      % shift trial：cueType指示的对侧
        imageLocation(t) = 3 - p.CueType(t);   % 1→2, 2→1
    end
end

% StartingLocations：trial t开始时fix点位置（即本trial的imageLocation）
% Cues：本trial的cue方向（同imageLocation）
p.Cues              = imageLocation;
p.StartingLocations = imageLocation;
p.StartingLocations(2:60) = imageLocation(1:59);  % 保留原代码结构

% ---- Response（奇/偶）：随机，与cueType无关 ----
p.Response    = Shuffle([ones(1,p.NumTrials/2) ones(1,p.NumTrials/2)*2]);
p.TargetStart = zeros(1, p.NumTrials);
p.CueStart    = zeros(1, p.NumTrials);

% ---- 初始化Location序列 ----
p.Location1 = cell(1, p.NumTrials);
p.Location2 = cell(1, p.NumTrials);

% ---- 逐trial填充 ----
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

    % 全奇/偶stream出现在imageLocation那侧，另一侧随机数字1-8
    % imageLocation(t)已在上方计算，与Cues(t)一致
    if imageLocation(t) == 1   % 目标在左
        loc1(resp_start:resp_end) = ShufDig;
        loc2(resp_start:resp_end) = randi(8, 1, 8);
    else                        % 目标在右
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


% =========================================================================
function [p, exitTask] = PresentStream(window, p)
% PresentStream  呈现RSVP stream


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
        % cue帧：目标侧是实验图片，干扰侧是noise 
        Screen('DrawTexture', window, val1, [], p.dstRect1);
        Screen('DrawTexture', window, val2, [], p.dstRect2);

    else
        % response window：数字判断
        DrawFormattedText(window, num2str(val1), 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.loc1);
        DrawFormattedText(window, num2str(val2), 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.loc2);
    end

    DrawFormattedText(window, ' + ', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.center);

    % ---- flip时序 ----
    % [修改] cue帧用CueFrameTime，其余帧用FrameTime
    % [保留] TargetOnset记录逻辑不变
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