function p = AttentionShift_Step1


s             = input('Enter Subject Number: ');
startingBlock = input('Enter Version Number (1=SHHS, 2=HSSH, 3=SHSH, 4=HSHS): ');

% 
block_orders = {'SHHS', 'HSSH', 'SHSH', 'HSHS'};
p.block_order = block_orders{startingBlock};

p.Exp     = 'AttentionShift_ImagePriming';
p.PID     = s;
p.Date    = datetime;
p.Version = startingBlock;
p.Seed    = ClockRandSeed();

diary(['Diaries/' num2str(s) 'diary.txt'])


p = AssignImages(p);


KbName('UnifyKeyNames');
whichScreen = 0;
background  = [0 0 0];

[window, windowRect] = Screen('OpenWindow', whichScreen, background);
HideCursor(window);
p.hz    = Screen('FrameRate', window);
p.slack = Screen('GetFlipInterval', window) / 2;

% 刺激位置
p.Cx = windowRect(3) / 2;
p.Cy = windowRect(4) / 2;

% loc1=左，loc2=右，格式[cx cy cx cy]
p.loc1   = [p.Cx-300 p.Cy p.Cx-300 p.Cy];
p.loc2   = [p.Cx+300 p.Cy p.Cx+300 p.Cy];
p.center = [p.Cx p.Cy p.Cx p.Cy];


Screen('TextFont', window, 'Monaco');

% 替代原来的p.stim{1-68}stim
% 
p.stimSize = 256;   % 像素，与generate_stimuli.m中img_size一致
half       = p.stimSize / 2;
p.dstRect1 = [p.loc1(1)-half, p.loc1(2)-half, p.loc1(1)+half, p.loc1(2)+half];
p.dstRect2 = [p.loc2(1)-half, p.loc2(2)-half, p.loc2(1)+half, p.loc2(2)+half];

% -noise 240
p = LoadNoiseTextures(p, window);


keyList = zeros(1, 256);
keyList([KbName('z') KbName('m') KbName('q')]) = 1;
ind  = GetKeyboardIndices;
p.ind = ind(length(ind)-1);
KbQueueCreate(p.ind, keyList);

%% 4 run 
for run = 1:4
    p.run = run;

    % load cue texture ----
    p = LoadCueTextures(p, run, window);

    % TrialSetup(p)，add more run
    p = TrialSetup(p, run);

    % all initial(but still need more fro analyse convenience.) MMMMark
    % here!!!
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

    % same for starting
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

    %% for trail
    for trial = 1:p.NumTrials
        p.trial = trial;
        fprintf('Run %d | Begin Trial %d', run, trial);

        %  PreStim不变（星号）
        p = PreStim(window, p);

        %  PresentStream use DrawTexture to show the noise
        [p, exitTask] = PresentStream(window, p);

        if exitTask == 1
            break
        end
    end

    %% for accuracey
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

    % clear some data 
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


% =========================================================================
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

% use 2 stragegy
switch p.block_order
    case {'SHHS', 'HSSH'}
        assign = [1 4; 1 3; 2 3; 2 4];
    case {'SHSH', 'HSHS'}
        assign = [1 3; 1 4; 2 3; 2 4];
    otherwise
        error('AssignImages: 未知block_order: %s', p.block_order);
end

sets       = {p.imageSet.a, p.imageSet.b, p.imageSet.c, p.imageSet.d};
block_types = p.block_order;   % 'S' or 'H' for trail type

% information for picturee
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
        info(idx).cueType     = 1 + (stim_num > n_total_each);  % 1=前120, 2=后120(animal or object)
        info(idx).encodeBlock = enc_blk;
        info(idx).reexpBlock  = reex_blk;
        info(idx).condition   = cond;
        info(idx).BI          = bi;
    end
end
p.imageInfo = info;

% block1/2：encoding ；block3/4：retreival
p.blockImages = cell(1, 4);
for blk = 1:4
    enc_imgs       = [info([info.encodeBlock] == blk).stimNum];
    reex_imgs      = [info([info.reexpBlock]  == blk).stimNum];
    p.blockImages{blk} = [enc_imgs, reex_imgs];
end

% 调
fprintf('AssignImages: block_order=%s\n', p.block_order);
cond_list = {'SS','HH','SH','HS'};
for c = 1:4
    mask   = strcmp({info.condition}, cond_list{c});
    bi_val = unique([info(mask).BI]);
    fprintf('  for %s: %d picture, BI=%d\n', cond_list{c}, sum(mask), bi_val);
end
end


% =========================================================================
function p = LoadNoiseTextures(p, window)
% LoadNoiseTextures  载入全部240张noise图片texture（整个实验共用）
%

stim_root = 'stimuli';
noise_dir = fullfile(stim_root, 'noise_images');
N_NOISE   = 240;   % noise图片总数，与generate_stimuli.m中n_noise一致

fprintf('Loading noise textures (%d images)...\n', N_NOISE);
p.noiseTextures = zeros(1, N_NOISE);
for i = 1:N_NOISE
    img = imread(fullfile(noise_dir, sprintf('noise_%03d.png', i)));
    p.noiseTextures(i) = Screen('MakeTexture', window, img);
end
fprintf('Noise textures loaded.\n');


p.noisePool    = Shuffle(1:N_NOISE);
p.noisePoolIdx = 1;
end


% =========================================================================
function p = LoadCueTextures(p, run, window)
% LoadCueTextures  载入当前run所需的60张cue图片texture

stim_root = 'stimuli';
cue_dir   = fullfile(stim_root, 'cue_images');
% ------------------

% releas cue texture
if isfield(p, 'cueTextures') && ~isempty(p.cueTextures)
    for i = 1:length(p.cueTextures)
        if p.cueTextures(i) > 0
            Screen('Close', p.cueTextures(i));
        end
    end
end

% use a new noise pool（每个run独立随机）
p.noisePool    = Shuffle(1:length(p.noiseTextures));
p.noisePoolIdx = 1;

image_ids     = p.blockImages{run};   % 本run的60张图片编号
n_cue         = length(image_ids);

fprintf('Loading cue textures for run %d (%d images)...\n', run, n_cue);
p.cueTextures = zeros(1, n_cue);
p.cueImageIDs = image_ids;

for i = 1:n_cue
    img = imread(fullfile(cue_dir, sprintf('cue_%03d.png', image_ids(i))));
    p.cueTextures(i) = Screen('MakeTexture', window, img);
end
fprintf('Cue textures loaded for run %d.\n', run);
end


% =========================================================================
function [p, tex] = GetNoiseTex(p)
% GetNoiseTex  从noise pool to call new noise texture 

if p.noisePoolIdx > length(p.noisePool)
    p.noisePool    = Shuffle(1:length(p.noiseTextures));
    p.noisePoolIdx = 1;
end
tex            = p.noiseTextures(p.noisePool(p.noisePoolIdx));
p.noisePoolIdx = p.noisePoolIdx + 1;
end


% =========================================================================
function p = TrialSetup(p, run)
% TrialSetup  为当前run生成所有trial参数， add more Location序列


p.NumTrials = 60;

% time
p.DistInterval = Shuffle([ones(1,20) ones(1,20)*3 ones(1,20)*5]);
p.FrameRate    = 4;
p.FrameTime    = 1000 / p.FrameRate;   % ms

% for the picute time !!!!!!!!!!!!!!!!! Markkkkkkkkkkk here
p.CueFrameTime = 250;   % ms

% hiftCues：
p.ShiftCues = zeros(1, p.NumTrials);
if p.block_order(run) == 'S'
    p.ShiftCues(p.DistInterval==1) = Shuffle([ones(1,16)*2 ones(1,4)]);
    p.ShiftCues(p.DistInterval==3) = Shuffle([ones(1,16)*2 ones(1,4)]);
    p.ShiftCues(p.DistInterval==5) = Shuffle([ones(1,16)*2 ones(1,4)]);
else   % 'H'
    p.ShiftCues(p.DistInterval==1) = Shuffle([ones(1,4)*2 ones(1,16)]);
    p.ShiftCues(p.DistInterval==3) = Shuffle([ones(1,4)*2 ones(1,16)]);
    p.ShiftCues(p.DistInterval==5) = Shuffle([ones(1,4)*2 ones(1,16)]);
end


block_imgs  = Shuffle(p.blockImages{run});   % 60张，随机顺序
enc_stims   = [p.imageInfo([p.imageInfo.encodeBlock] == run).stimNum];
is_encoding = ismember(block_imgs, enc_stims);


sides = Shuffle([ones(1,30) ones(1,30)*2]);   % 1=left, 2=right


p.Cues              = sides;
p.StartingLocations = sides;
p.StartingLocations(2:60) = sides(1:59);

%  trial-level 
p.StimulusNumber = block_imgs;
p.Exposure       = ones(1, p.NumTrials);         % 1=encoding
p.Exposure(~is_encoding) = 2;                    % 2=re-exposure
p.Condition      = repmat({''}, 1, p.NumTrials); % encoding时为空

for t = 1:p.NumTrials
    if ~is_encoding(t)
        idx = find([p.imageInfo.stimNum] == block_imgs(t), 1);
        p.Condition{t} = p.imageInfo(idx).condition;
    end
end

p.CueType = zeros(1, p.NumTrials);
for t = 1:p.NumTrials
    idx = find([p.imageInfo.stimNum] == block_imgs(t), 1);
    p.CueType(t) = p.imageInfo(idx).cueType;
end

%  Response（odd/even）：randomlized，not realted to the cueType
p.Response    = Shuffle([ones(1,p.NumTrials/2) ones(1,p.NumTrials/2)*2]);
p.TargetStart = zeros(1, p.NumTrials);
p.CueStart    = zeros(1, p.NumTrials);

p.Location1 = cell(1, p.NumTrials);
p.Location2 = cell(1, p.NumTrials);

% 逐trial填充
for t = 1:p.NumTrials
    n_pre      = p.DistInterval(t) * p.FrameRate;
    cue_frame  = n_pre + 1;
    resp_start = n_pre + 2;
    resp_end   = n_pre + 9;
    total_len  = n_pre + 9;

    loc1 = zeros(1, total_len);
    loc2 = zeros(1, total_len);

    % cue前noise
    for f = 1:n_pre
        [p, loc1(f)] = GetNoiseTex(p);
        [p, loc2(f)] = GetNoiseTex(p);
    end

    % cue
    cue_tex_pos = find(p.cueImageIDs == block_imgs(t), 1);
    cue_tex     = p.cueTextures(cue_tex_pos);
    [p, noise_cue] = GetNoiseTex(p);

    if p.StartingLocations(t) == 1
        loc1(cue_frame) = cue_tex;
        loc2(cue_frame) = noise_cue;
    else
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
            if ShufDig(q) == ShufDig(q-1)
                done = 0;
            end
        end
        if done; break; end
    end


    if p.Cues(t) == 1
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
% PreStim  星号
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
        % cue前noise
        % [修改] DrawTexture替代DrawFormattedTex        Screen('DrawTexture', window, val1, [], p.dstRect1);
        Screen('DrawTexture', window, val2, [], p.dstRect2);

    elseif framenum == p.CueStart(t)
        % cue帧：calulate which one is the cue ，and other is the noise 
   
        Screen('DrawTexture', window, val1, [], p.dstRect1);
        Screen('DrawTexture', window, val2, [], p.dstRect2);

    else
        DrawFormattedText(window, num2str(val1), 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.loc1);
        DrawFormattedText(window, num2str(val2), 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.loc2);
    end

    DrawFormattedText(window, ' + ', 'center', 'center', [255 255 255], 10, 0, 0, 1, 0, p.center);

    % flip
    if framenum == p.CueStart(t)
        p.CueDeadline(t) = p.streamFlip;
        [p.CueOnset.VBLOn(t), p.CueOnset.StimOn(t), p.CueOnset.FlipTime(t), p.CueMissed(t)] = ...
            Screen('Flip', window, p.streamFlip - p.slack);
        tmpFlip      = p.CueOnset.VBLOn(t);
        p.streamFlip = tmpFlip + p.CueFrameTime * 0.001;   % [修改] cue帧用CueFrameTime

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

% for key press time 
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