function AttentionShift_Practice
% AttentionShift_Practice
%
% 单一 block，30 trials，15 shift + 15 hold 随机穿插
%
% Trial 1-6  固定顺序 [S H S H S H]
%            shift 依次用 cue_A1/A2/A3，hold 依次用 cue_N1/N2/N3
%            每个 trial 做完 → 详细分步反馈 → 按空格继续
%
% Trial 7-30 12 shift + 12 hold 随机穿插
%            shift 从 cue_A4~A10 池随机抽（with replacement）
%            hold  从 cue_N4~N10 池随机抽（with replacement）
%            做完 → 简单 Correct/Incorrect 反馈（1 秒自动继续）
%
% Fix 点位置规则（与主任务一致）：
%   - Trial 1：随机左/右
%   - Trial t：fix_side(t) = correct_side(t-1)
%   - cue 出现在 fix 点那侧
%   - shift → correct_side 翻到对侧；hold → correct_side 留在同侧
%
% 按键：z = 奇数，m = 偶数，q = 随时退出

%% =========================================================
%  被试编号
%% =========================================================
s = input('Enter Subject Number: ');

%% =========================================================
%  参数
%% =========================================================
N_TRIALS      = 30;
N_GUIDED      = 6;
img_size      = 256;
FRAME_RATE    = 4;
FRAME_TIME_MS = 1000 / FRAME_RATE;   % 250 ms
CUE_FRAME_MS  = 250;                 % ms

%% =========================================================
%  路径
%% =========================================================
cue_dir   = fullfile('stimulus', 'cue');
noise_dir = fullfile('stimulus', 'noise');

%% =========================================================
%  构建 trial 序列
%% =========================================================

% --- Trial 1-6：固定 [S H S H S H] ---
guided_cue_type    = [2 1 2 1 2 1];   % 2=shift, 1=hold
guided_shift_files = {'cue_A1.png', 'cue_A2.png', 'cue_A3.png'};
guided_hold_files  = {'cue_N1.png', 'cue_N2.png', 'cue_N3.png'};

guided_files = cell(1, N_GUIDED);
sp = 1; hp = 1;
for t = 1:N_GUIDED
    if guided_cue_type(t) == 2
        guided_files{t} = guided_shift_files{sp}; sp = sp + 1;
    else
        guided_files{t} = guided_hold_files{hp};  hp = hp + 1;
    end
end

% --- Trial 7-30：12 shift + 12 hold 随机穿插 ---
n_remain_shift = 15 - 3;   % 12
n_remain_hold  = 15 - 3;   % 12

shift_pool = arrayfun(@(n) sprintf('cue_A%d.png', n), 4:10, 'UniformOutput', false); % 7张
hold_pool  = arrayfun(@(n) sprintf('cue_N%d.png', n), 4:10, 'UniformOutput', false); % 7张

% with replacement 随机抽取
shift_pick = shift_pool(mod(Shuffle(0:n_remain_shift-1), numel(shift_pool)) + 1);
hold_pick  = hold_pool( mod(Shuffle(0:n_remain_hold-1),  numel(hold_pool))  + 1);

remain_cue_type = Shuffle([ones(1, n_remain_shift)*2, ones(1, n_remain_hold)]);
remain_files    = cell(1, N_TRIALS - N_GUIDED);
sp = 1; hp = 1;
for t = 1:(N_TRIALS - N_GUIDED)
    if remain_cue_type(t) == 2
        remain_files{t} = shift_pick{sp}; sp = sp + 1;
    else
        remain_files{t} = hold_pick{hp};  hp = hp + 1;
    end
end

% --- 合并 ---
all_cue_type  = [guided_cue_type,  remain_cue_type];   % 1×30
all_cue_files = [guided_files,     remain_files];       % 1×30 cell

%% =========================================================
%  Fix 点 / cue 侧 / correct 侧
%  规则：fix_side(1) 随机
%        fix_side(t) = correct_side(t-1)   t>=2
%        cue 出现在 fix_side 那侧
%        shift → correct_side = 对侧，hold → correct_side = 同侧
%% =========================================================
fix_side     = zeros(1, N_TRIALS);
cue_side     = zeros(1, N_TRIALS);
correct_side = zeros(1, N_TRIALS);

fix_side(1) = randi(2);   % Trial 1 随机
for t = 1:N_TRIALS
    cue_side(t) = fix_side(t);               % cue 出现在 fix 那侧
    if all_cue_type(t) == 2                  % shift：翻转
        correct_side(t) = 3 - fix_side(t);
    else                                     % hold：保持
        correct_side(t) = fix_side(t);
    end
    if t < N_TRIALS
        fix_side(t+1) = correct_side(t);     % 下一个 trial 的 fix = 本 trial correct_side
    end
end

%% =========================================================
%  dist interval / 奇偶分配
%% =========================================================
dist_interval = randi(3, 1, N_TRIALS);
resp_parity   = Shuffle([ones(1, N_TRIALS/2), ones(1, N_TRIALS/2)*2]);  % 1=奇(z), 2=偶(m)

%% =========================================================
%  PTB 初始化
%% =========================================================
KbName('UnifyKeyNames');
[window, windowRect] = Screen('OpenWindow', 0, [128 128 128]);
HideCursor(window);
slack = Screen('GetFlipInterval', window) / 2;

Cx = windowRect(3) / 2;
Cy = windowRect(4) / 2;
loc1   = [Cx-300, Cy, Cx-300, Cy];
loc2   = [Cx+300, Cy, Cx+300, Cy];
center = [Cx, Cy, Cx, Cy];

half     = img_size / 2;
dstRect1 = [loc1(1)-half, loc1(2)-half, loc1(1)+half, loc1(2)+half];
dstRect2 = [loc2(1)-half, loc2(2)-half, loc2(1)+half, loc2(2)+half];
Screen('TextFont', window, 'Monaco');

%% =========================================================
%  键盘
%% =========================================================
keyList = zeros(1, 256);
keyList([KbName('z') KbName('m') KbName('q')]) = 1;
ind_list = GetKeyboardIndices;
kb_ind   = ind_list(length(ind_list) - 1);
KbQueueCreate(kb_ind, keyList);

%% =========================================================
%  载入 noise textures
%% =========================================================
noise_exts  = {'*.png', '*.jpg', '*.jpeg'};
noise_files = [];
for e = 1:numel(noise_exts)
    noise_files = [noise_files; dir(fullfile(noise_dir, noise_exts{e}))]; %#ok<AGROW>
end
if isempty(noise_files)
    Screen('CloseAll'); error('No noise images in %s', noise_dir);
end
N_NOISE = numel(noise_files);
fprintf('Loading %d noise textures...\n', N_NOISE);
noiseTex = zeros(1, N_NOISE);
for i = 1:N_NOISE
    img = imread(fullfile(noise_files(i).folder, noise_files(i).name));
    if size(img,3) == 1, img = repmat(img, [1 1 3]); end
    noiseTex(i) = Screen('MakeTexture', window, img);
end
noisePool    = Shuffle(1:N_NOISE);
noisePoolIdx = 1;

%% =========================================================
%  载入 cue textures
%% =========================================================
cueTex = zeros(1, N_TRIALS);
for t = 1:N_TRIALS
    fpath = fullfile(cue_dir, all_cue_files{t});
    if ~exist(fpath, 'file')
        Screen('CloseAll');
        error('Cue file not found: %s', fpath);
    end
    img = imread(fpath);
    if size(img,3) == 1, img = repmat(img, [1 1 3]); end
    cueTex(t) = Screen('MakeTexture', window, img);
end

%% =========================================================
%  构建每个 trial 的 Location 流（与主任务逻辑一致）
%% =========================================================
correct_digit = zeros(1, N_TRIALS);
Location1     = cell(1, N_TRIALS);
Location2     = cell(1, N_TRIALS);
CueStart      = zeros(1, N_TRIALS);
TargStart     = zeros(1, N_TRIALS);

for t = 1:N_TRIALS
    n_pre      = dist_interval(t) * FRAME_RATE;
    cue_frame  = n_pre + 1;
    resp_start = n_pre + 2;
    resp_end   = n_pre + 9;
    total_len  = n_pre + 9;

    L1 = zeros(1, total_len);
    L2 = zeros(1, total_len);

    % 预 cue noise 帧
    for f = 1:n_pre
        [noisePool, noisePoolIdx, L1(f)] = nextNoise(noiseTex, noisePool, noisePoolIdx);
        [noisePool, noisePoolIdx, L2(f)] = nextNoise(noiseTex, noisePool, noisePoolIdx);
    end

    % cue 帧：cue 在 cue_side 那侧，另一侧 noise（不与前一帧重复）
    [noisePool, noisePoolIdx, nc] = nextNoise(noiseTex, noisePool, noisePoolIdx);
    if cue_side(t) == 1
        while n_pre >= 1 && nc == L2(n_pre)
            [noisePool, noisePoolIdx, nc] = nextNoise(noiseTex, noisePool, noisePoolIdx);
        end
        L1(cue_frame) = cueTex(t);
        L2(cue_frame) = nc;
    else
        while n_pre >= 1 && nc == L1(n_pre)
            [noisePool, noisePoolIdx, nc] = nextNoise(noiseTex, noisePool, noisePoolIdx);
        end
        L2(cue_frame) = cueTex(t);
        L1(cue_frame) = nc;
    end

    % response window
    if resp_parity(t) == 1
        RDig = [1 3 5 7];
    else
        RDig = [2 4 6 8];
    end
    cd_val = RDig(randi(length(RDig)));
    dp     = setdiff(1:8, cd_val);
    dd     = dp(randi(length(dp)));
    correct_digit(t) = cd_val;

    if correct_side(t) == 1
        L1(resp_start:resp_end) = cd_val;
        L2(resp_start:resp_end) = dd;
    else
        L2(resp_start:resp_end) = cd_val;
        L1(resp_start:resp_end) = dd;
    end

    Location1{t} = L1;
    Location2{t} = L2;
    CueStart(t)  = cue_frame;
    TargStart(t) = resp_start;
end

%% =========================================================
%  指导语
%% =========================================================
Screen('TextSize', window, 34);
DrawFormattedText(window, ...
    ['PRACTICE BLOCK\n\n' ...
     'Rule:\n' ...
     '  ANIMAL image  (cue)  ->  SHIFT attention to the OTHER side\n' ...
     '  OBJECT image  (cue)  ->  HOLD attention on the SAME side\n\n' ...
     'Then judge the number on the attended side:\n' ...
     '  Z  =  ODD     M  =  EVEN\n\n' ...
     'The first 6 trials include detailed step-by-step feedback.\n' ...
     'Press SPACE to begin.'], ...
    'center', 'center', [0 0 0]);
Screen('Flip', window);
waitForSpace();

%% =========================================================
%  数据储存变量
%% =========================================================
Accurate      = zeros(1, N_TRIALS);
RespButton    = zeros(1, N_TRIALS);
RT_raw        = zeros(1, N_TRIALS);
RT_sub        = zeros(1, N_TRIALS);
CueOnset_VBL  = zeros(1, N_TRIALS);
TargOnset_VBL = zeros(1, N_TRIALS);

prevFlip   = Screen('Flip', window);
streamFlip = prevFlip;

%% =========================================================
%  Trial 主循环
%% =========================================================
for trial = 1:N_TRIALS

    % --- PreStim：asterisk（上一个 correct 侧）+ 注视十字 ---
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

    % --- 呈现 stream ---
    L1 = Location1{trial};
    L2 = Location2{trial};
    for f = 1:length(L1)
        v1 = L1(f);
        v2 = L2(f);

        if f <= CueStart(trial)
            % noise 帧 & cue 帧：直接画 texture
            Screen('DrawTexture', window, v1, [], dstRect1);
            Screen('DrawTexture', window, v2, [], dstRect2);
        else
            % response window：noise 底层 + 数字叠加
            [noisePool, noisePoolIdx, n1] = nextNoise(noiseTex, noisePool, noisePoolIdx);
            [noisePool, noisePoolIdx, n2] = nextNoise(noiseTex, noisePool, noisePoolIdx);
            Screen('DrawTexture', window, n1, [], dstRect1);
            Screen('DrawTexture', window, n2, [], dstRect2);
            DrawFormattedText(window, num2str(v1), 'center', 'center', [0 0 0], 10, 0, 0, 1, 0, loc1);
            DrawFormattedText(window, num2str(v2), 'center', 'center', [0 0 0], 10, 0, 0, 1, 0, loc2);
        end
        DrawFormattedText(window, ' + ', 'center', 'center', [0 0 0], 10, 0, 0, 1, 0, center);

        % Flip timing
        if f == CueStart(trial)
            [CueOnset_VBL(trial),~,~,~] = Screen('Flip', window, streamFlip - slack);
            streamFlip = CueOnset_VBL(trial) + CUE_FRAME_MS * 0.001;
        elseif f == TargStart(trial)
            [TargOnset_VBL(trial),~,~,~] = Screen('Flip', window, streamFlip - slack);
            KbQueueStart(kb_ind);
            streamFlip = TargOnset_VBL(trial) + FRAME_TIME_MS * 0.001;
        else
            tmp        = Screen('Flip', window, streamFlip - slack);
            streamFlip = tmp + FRAME_TIME_MS * 0.001;
        end
    end

    % blank，收集反应
    DrawFormattedText(window, ' + ', 'center', 'center', [0 0 0], 10, 0, 0, 1, 0, center);
    prevFlip = Screen('Flip', window, streamFlip - slack);
    KbQueueStop(kb_ind);

    [Responded, firstpress] = KbQueueCheck(kb_ind);
    is_correct  = 0;
    pressed_key = 0;

    if Responded
        pressed_key = find(firstpress == min(firstpress(firstpress~=0)), 1);
        tSec        = min(firstpress(firstpress~=0));
        if pressed_key == KbName('q')
            cleanUp(window, kb_ind); return;
        end
        RespButton(trial) = pressed_key;
        RT_raw(trial)     = tSec;
        RT_sub(trial)     = tSec - TargOnset_VBL(trial);
        if (pressed_key == KbName('z') && resp_parity(trial) == 1) || ...
           (pressed_key == KbName('m') && resp_parity(trial) == 2)
            is_correct = 1;
        end
    end
    Accurate(trial) = is_correct;
    KbQueueFlush(kb_ind);

    WaitSecs(0.1);

    % ---- 反馈 ----
    if trial <= N_GUIDED
        % 详细分步反馈，按空格继续
        showDetailedFeedback(window, trial, ...
            fix_side(trial), cue_side(trial), all_cue_type(trial), all_cue_files{trial}, ...
            correct_side(trial), correct_digit(trial), resp_parity(trial), ...
            is_correct, Responded);
    else
        % 简单反馈，1 秒
        Screen('TextSize', window, 52);
        if ~Responded
            DrawFormattedText(window, 'No Response', 'center', 'center', [220 120 0]);
        elseif is_correct
            DrawFormattedText(window, 'Correct!',    'center', 'center', [0 180 0]);
        else
            DrawFormattedText(window, 'Incorrect',   'center', 'center', [210 0 0]);
        end
        Screen('Flip', window);
        WaitSecs(1.0);
    end

    prevFlip = Screen('Flip', window);
    WaitSecs(0.3);

    fprintf('Trial %2d | %s | fix=%d cue_side=%d correct_side=%d | %-14s | digit=%d | acc=%d\n', ...
        trial, ...
        ternary(all_cue_type(trial)==2, 'shift', 'hold '), ...
        fix_side(trial), cue_side(trial), correct_side(trial), ...
        all_cue_files{trial}, correct_digit(trial), is_correct);
end

%% =========================================================
%  结束画面
%% =========================================================
acc = ceil(mean(Accurate) * 100);
Screen('TextSize', window, 36);
DrawFormattedText(window, ...
    ['Practice complete!   Accuracy: ' num2str(acc) '%\n\n\n' ...
     'In the main task, there will be no step-by-step guidance.\n' ...
     'You will only see a brief Correct / Incorrect feedback after each trial.\n\n' ...
     'Press SPACE to continue to the main task.'], ...
    'center', 'center', [0 0 0]);
Screen('Flip', window);
waitForSpace();

%% =========================================================
%  储存
%% =========================================================
if ~exist('Data', 'dir'), mkdir('Data'); end
prac.SubjectID      = s;
prac.Date           = datetime;
prac.N_TRIALS       = N_TRIALS;
prac.Accurate       = Accurate;          % 1×30 逐trial准确率
prac.ResponseButton = RespButton;        % 按键 keyCode
prac.RT_raw         = RT_raw;            % 绝对时间
prac.RT_subtracted  = RT_sub;            % 相对 target onset
prac.CueType        = all_cue_type;      % 2=shift, 1=hold
prac.CueFilenames   = all_cue_files;     % 实际使用的 cue 文件名
prac.FixSide        = fix_side;          % 1=left, 2=right
prac.CueSide        = cue_side;          % cue 出现侧
prac.CorrectSide    = correct_side;      % 正确反应侧
prac.ResponseParity = resp_parity;       % 1=odd(z), 2=even(m)
prac.CorrectDigit   = correct_digit;     % 正确数字
prac.DistInterval   = dist_interval;     % 1/2/3 frames
prac.CueOnset_VBL   = CueOnset_VBL;
prac.TargOnset_VBL  = TargOnset_VBL;

save(fullfile('Data', ['S' num2str(s) '_practice.mat']), 'prac');
fprintf('Saved: S%d_practice.mat   Accuracy = %d%%\n', s, acc);

cleanUp(window, kb_ind);
end


%% =========================================================
%  详细反馈（Trial 1-6）
%% =========================================================
function showDetailedFeedback(window, trial, ...
    fix_side, cue_side, cue_type, cue_fname, ...
    correct_side, correct_digit_val, resp_parity, ...
    is_correct, responded)

fix_str     = ternary(fix_side == 1,     'LEFT', 'RIGHT');
cue_str     = ternary(cue_side == 1,     'LEFT', 'RIGHT');
correct_str = ternary(correct_side == 1, 'LEFT', 'RIGHT');
parity_str  = ternary(resp_parity == 1,  'ODD',  'EVEN');
key_str     = ternary(resp_parity == 1,  'Z',    'M');

if cue_type == 2
    cue_label  = 'ANIMAL';
    action_str = ['-> ANIMAL cue: SHIFT attention to the ' correct_str ' side'];
else
    cue_label  = 'OBJECT';
    action_str = ['-> OBJECT cue: HOLD attention on the ' correct_str ' side'];
end

if is_correct
    result_str = 'CORRECT  :)';
    txt_color  = [0 150 0];
elseif ~responded
    result_str = 'No Response (too slow)';
    txt_color  = [200 110 0];
else
    result_str = 'INCORRECT  :(';
    txt_color  = [200 0 0];
end

msg = sprintf([...
    '[ Guided Trial %d / 6 ]\n\n'                                                          ...
    'Step 1  The fixation asterisk ( * ) appeared on the %s side.\n'                       ...
    '        -> Your attention started on the %s side.\n\n'                                ...
    'Step 2  The cue appeared on the %s side and it was an %s image  ( %s )\n'             ...
    '        %s\n\n'                                                                        ...
    'Step 3  On the %s side, the number was  %d  which is %s.\n'                           ...
    '        -> Correct key:  %s\n\n'                                                      ...
    'Result: %s\n\n'                                                                        ...
    'Press SPACE to continue.'], ...
    trial, ...
    fix_str, fix_str, ...
    cue_str, cue_label, cue_fname, action_str, ...
    correct_str, correct_digit_val, parity_str, key_str, ...
    result_str);

Screen('FillRect', window, [128 128 128]);
Screen('TextSize', window, 28);
DrawFormattedText(window, msg, 'center', 'center', txt_color);
Screen('Flip', window);

waitForSpace();
Screen('Flip', window);
WaitSecs(0.2);
end


%% =========================================================
%  Helpers
%% =========================================================
function [pool, idx, tex] = nextNoise(textures, pool, idx)
% 从 shuffle 池取下一张 noise，耗尽时自动 reshuffle（首尾不重复）
if idx > length(pool)
    last = pool(end);
    pool = Shuffle(1:length(textures));
    if pool(1) == last
        sw = randi([2, length(pool)]);
        pool([1 sw]) = pool([sw 1]);
    end
    idx = 1;
end
tex = textures(pool(idx));
idx = idx + 1;
end

function waitForSpace()
while KbCheck; end
while 1
    [down, ~, kc] = KbCheck;
    if down && find(kc, 1) == KbName('space'), break; end
end
end

function cleanUp(win, kb)
Screen('CloseAll'); ShowCursor; ListenChar(0); KbQueueRelease(kb);
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
