function Face_FT()   %[ output_args ] = Face_FT( input_args )
%Flicker faces/gray at 6Hz (~83 ms?) ~sinusoidal
%   xxx

%No Adapt:
%V 100|      _FaceA    _FaceB    _FaceA
%i    |     . .       . .       . .
%s    |    .   .     .   .     .   .
%i  50|   .     .   .     .   .     .
%b    |  .       . .       . .
%i    | .  Gray   .   Gray  .
%l   0|___________________________
%i               1/6       2/6
%t               Time
%y
%
%Adapt: replace FaceB with FaceA
%Either: 30s of no adapt, or 10s adapt, 20s no adapt, measure EEG during final 20s

clear
sca
close all
Screen('Preference','SkipSyncTests',1);     %Suppress sync errors. May wish to comment out
Screen('Preference','VisualDebugLevel', 0); %   in final version
KbName('UnifyKeyNames');
space = KbName('space');
esc = KbName('Escape');
responded = false; %#ok<NASGU>

nTrials = 1;
EEG = false               %EEG present
EEGt = lower('biosemi');
jitter = true;
TTL_pulse_dur = 0.005; %Prevent overlapping triggers
ISI = 3;
scaling = 1.5;            %1 = actual size, 0.5 = half size, etc.

c = computer;                             %Type of system
slash = '\';
if strcmp(c,'PCWIN64') || strcmp(c,'PCWIN32') || strcmp(c,'PCWIN')   %Windows
    slash = '\';
    screennumber = 1;
    monitor = 2;
elseif strcmp(c,'MACI64')
    slash = '/';
    screennumber = 0;
    monitor = 0;
elseif strcmp(c,'GLNXA64') || strcmp(c,'GLNX32') || strcmp(c,'GLNX86')
    disp('Untested in Linux')
    slash = '/';
    monitor = 0;
else
    disp('Computer type undetermined.')
    monitor = 0;
end
if EEG
    monitor = 2;               %#ok<UNRCH>
else
    monitor = 2;               %0 = span, 1 = primary, 2 = secondary, etc.
end

bkgd = [183 183 183];       %Of image set, otherwise use 128

%Collect subject info
fprintf('SET OPTIONS: Hit enter for any of these to choose defaults\n\n')
initials = input('Enter initials/number:   ','s');
flickerRate = input('Enter rate (default 6 Hz):   ');
adapttime = input('Enter adapt time (default 10 s):   ');
showtime = input('Enter test time (default 20 s):   ');

%Choose defaults
if isempty(flickerRate); flickerRate = 6; end
if isempty(adapttime); adapttime = 10; end
if isempty(showtime); showtime = 20; end

%PTB Setup
displayTime =  adapttime;
[w,rect] = Screen('OpenWindow',monitor,bkgd);
Screen('BlendFunction', w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);   %Transparency
Hz=Screen('NominalFrameRate', w);
Hz = round(Hz);
% if Hz == 59; Hz = 60; end;
xc = rect(3)/2; yc = rect(4)/2;     %Center of monitor x,y
xs = 191*scaling; ys = 250*scaling;                 %Face image size

%Fixation cross info
fixwidth = 2;
fixcolor = [0 0 0];
fixlength = 10;
fixX = [0, 0, -fixlength, fixlength];
fixY = [-fixlength, fixlength, 0, 0];
fix = [fixX;fixY];
destrect = [xc-xs/2, yc-ys/2, xc+xs/2, yc+ys/2];

%Choose EEG system based on above
if EEG && strcmp(EEGt,'biosemi')
    s = daq.createSession('ni');
    ch = addDigitalChannel(s,'Dev1','Port1/Line0:7','OutputOnly');
elseif EEG && strcmp(EEGt,'egi')
    Initialize_EEG()
end

%Duty cycle for sinusoidal modulation
cycle = round(linspace(0,360,Hz));                  %round(1/(frames)*1000)));
cycle = repmat(cycle,[1,displayTime,1]);
trans = cosd(cycle*flickerRate+180)*0.5+0.5;        %Create sinusoidal levels for pixel level
trans(end) = [];                                    %Remove last element (as first is the same)
%180 = shift phase; *0.5+0.5 = Transparency level 0-1
face = 2;                                           %Will immediately switch to 1
%mins = findminima(trans);
flipped = 1 - trans;
[peaks,locs]=findpeaks(flipped);      %Flip then find troughs
mins = locs;

%Trials columns:
%   1: Face number
%   2: 0 A<>B, 1 adapt A, 2 adapt B
%   3:

%Either randomize, or pick fixed trials based on existance of text file
if exist('randomization.txt','file')
    %1:8 = no adapt; 9:16 = n-8 adapt
    tOrder = str2num(fileread('randomization.txt'));      %#ok<ST2NM>
    if size(tOrder,1) > 1 || size(tOrder,2) > 1   %If matrix
        tOrder = reshape(tOrder.',[],1);
    end
    if (sum(sum(tOrder>16 )) > 0) || (sum(sum(tOrder<1)) > 0)   %If any values are out of range
        disp('randomization.txt must have values in range of 1:8')
        clear mex
        close all
        clear all
    end
else
    disp('Randomization file not found. Using [randperm(1:8), randperm(9:16)]')
    tOrder = [randperm(8) randperm(8)+8];
end

%Deprioritize Win/Mac functions
topPriority = MaxPriority(w);
Priority(topPriority);
waitframes = 1;

%10 second timer AFTER recording started, limits any artifacts from amp start
instr = 'Please wait for program to load.';
Screen('Flip',w);
HideCursor;
instSize = Screen('TextBounds',w,instr);
Screen('DrawText',w,instr,xc - instSize(3)/2,yc - instSize(4)/2);
for counter = 10:-1:1
    Screen('DrawText',w,num2str(counter),xc,yc - instSize(4)/2 + 30);
    Screen('Flip',w);
    WaitSecs(1);
end

%Instructions
isAdapt = true;
instr = 'Fixate on the cross. Press SPACE as soon as you see the cross turn green.';
instSize = Screen('TextBounds',w,instr);
Screen('DrawText',w,instr,xc - instSize(3)/2,yc - instSize(4)/2);
instr = 'Press any key to continue';
Screen('DrawText',w,instr,xc - instSize(3)/2,yc - instSize(4)/2 + 30);
Screen('Flip',w);
KbWait;

adapt_change = zeros(1,Hz*adapttime);
rand_change = zeros(1,Hz*showtime);

rxn = zeros(length(tOrder),3);           %Reaction times

%Trials
for cond = 1:length(tOrder)
    %Randomize user response times, but keep within certain parameters
    transitions = [0 0 0];
    adapt_change(:) = 0;
    first_rand = randi([1 round(length(adapt_change))-Hz]);
    adapt_change(first_rand:first_rand+Hz) = 1;
    transitions(1) = first_rand;
    rand_change(:) = 0;
    first_rand = randi([1 round(length(rand_change)/2)]);  %Get random index in first third of frames
    rand_change(first_rand:first_rand+Hz) = 1;            %Set (60) frames to show cross
    transitions(2) = first_rand;
    last_rand = randi([round(length(rand_change)/2) length(rand_change)-Hz]);
    rand_change(last_rand:last_rand+Hz) = 1;
    transitions(3) = last_rand;
    
    %If >8, is adapt condition, e.g. 9 = (9-8) = face 1, 15 = (15-8) = face 7
    if tOrder(cond) > 8
        %Adapt
        faceA = imread(sprintf('%s%s%s%s%d%s',pwd,slash,'Faces',slash,tOrder(cond)-8,'_1.jpg'));
        faceB = imread(sprintf('%s%s%s%s%d%s',pwd,slash,'Faces',slash,tOrder(cond)-8,'_2.jpg'));
        isAdapt = true;
    else
        %Paired
        % a=sprintf('%s%s%d%s',pwd,'\Faces\',cond,'_1.jpg');
        faceA = imread(sprintf('%s%s%s%s%d%s',pwd,slash,'Faces',slash,tOrder(cond),'_1.jpg'));
        faceB = imread(sprintf('%s%s%s%s%d%s',pwd,slash,'Faces',slash,tOrder(cond),'_2.jpg'));
        isAdapt = false;
    end
    
    phase = 0;              %Init: which display of the green cross is it on?
    for j = 1:2
        responded = false;
        if j == 1
            face = 1;       %Start with FaceA
            displayTime = adapttime;
            if EEG
                if ~isAdapt
                    if strcmp(EEGt,'biosemi')
                        outputSingleScan(s,dec2binvec(1,8));
                    elseif strcmp(EEGt,'egi')
                        DaqDOut(trigDevice,0,1);
                    end
                else
                    
                    if strcmp(EEGt,'biosemi')
                        outputSingleScan(s,dec2binvec(2,8));
                    elseif strcmp(EEGt,'egi')
                        DaqDOut(trigDevice,0,2);
                    end
                end
                
                WaitSecs(TTL_pulse_dur);
                
                if strcmp(EEGt,'biosemi')
                    outputSingleScan(s,[0 0 0 0 0 0 0 0]);
                elseif strcmp(EEGt,'egi')
                    DaqDOut(trigDevice,0,0);
                end
            end
            
            %Create textures
            if ~isAdapt
                tex(1) = Screen('MakeTexture',w,faceA);
                tex(2) = Screen('MakeTexture',w,faceB);
            else
                tex(1) = Screen('MakeTexture',w,faceA);
                tex(2) = Screen('MakeTexture',w,faceA);
            end
            cycle = round(linspace(0,360,Hz));       %round(1/(frames)*1000)));
            cycle = repmat(cycle,[1,displayTime,1]);
            trans = cosd(cycle*flickerRate+180)*0.5+0.5;        %Create sinusoidal levels 0<>1 for pixel level
            trans(end) = [];                                    %Remove last element (as first is the same)
            %mins = findminima(trans);
            flipped = 1 - trans;
            [peaks,locs]=findpeaks(flipped);      %Flip then find troughs
            mins = locs;
        else
            if face == 1; face = 2; else face = 1; end;     %Switch faces to prevent repeated frames on transition
            
            displayTime = showtime;
            tex(1) = Screen('MakeTexture',w,faceA);
            tex(2) = Screen('MakeTexture',w,faceB);
            if EEG
                if ~isAdapt
                    
                    if strcmp(EEGt,'biosemi')
                        outputSingleScan(s,dec2binvec(3,8));
                    elseif strcmp(EEGt,'egi')
                        DaqDOut(trigDevice,0,3);
                    end
                else
                    if strcmp(EEGt,'biosemi')
                        outputSingleScan(s,dec2binvec(4,8));
                    elseif strcmp(EEGt,'egi')
                        DaqDOut(trigDevice,0,16);
                    end
                end
                
                WaitSecs(TTL_pulse_dur);
                
                if strcmp(EEGt,'biosemi')
                    outputSingleScan(s,[0 0 0 0 0 0 0 0]);
                elseif strcmp(EEGt,'egi')
                    DaqDOut(trigDevice,0,0);
                end
            end
            
            cycle = round(linspace(0,360,Hz));       %round(1/(frames)*1000)));
            cycle = repmat(cycle,[1,displayTime,1]);
            trans = cosd(cycle*flickerRate+180)*0.5+0.5;        %Create sinusoidal levels for pixel level
            trans(end) = [];                                    %Remove last element (as first is the same)
            flipped = 1 - trans;
            [peaks,locs]=findpeaks(flipped);      %Flip then find troughs
            mins = locs;
        end
        
        ifi = Screen('GetFlipInterval',w);
        vbl = Screen('Flip',w);     %Get first flip
        tic
        for fr = 1:Hz * displayTime - 1      %full cycle, 1Hz
            fixstart = zeros(1,3);  %Initialize
            if j == 1
                if adapt_change(fr) == 1
                    fixcolor = [0 255 0];
                else
                    fixcolor = [0 0 0];
                end
                if fr == transitions(1)
                    %fixstart(1) = GetSecs;
                    phase = phase + 1;
                end
            else
                if rand_change(fr) == 1
                    fixcolor = [0 255 0];
                else
                    fixcolor = [0 0 0];
                end
                if fr == transitions(2)
                    %fixstart(2) = GetSecs;
                    phase = phase + 1;
                elseif fr == transitions(3)
                    %fixstart(3) = GetSecs;
                    phase = phase + 1;
                end
            end
            
            %Reaction, 1 = responded correctly, 0 = no response
            %             if adapt_change(fr) || rand_change(fr)    %If during green
            %                 xx adapt change is 1/3 rand change is 2/3 fr is 3/3 ... out of range
            
            [keyIsDown, secs, keycode] = KbCheck();
            if fixcolor(2) == 255
                if keycode(space)
                    responded = true; %#ok<NASGU>
                    rxn(cond,phase) = 1;       %Append response time
                elseif keycode(esc)
                    sca
                end
            end
            
            if sum(fr == mins) > 0        %If frame is a minima
                if jitter; scaling = (1.5*1.18) - rand()*0.36; end      %New random size
                xs = 191*scaling; ys = 250*scaling;                 %Face image size
                destrect = [xc-xs/2, yc-ys/2, xc+xs/2, yc+ys/2];
                if face == 1
                    face = 2;
                else
                    face = 1;
                end
            end
            
            Screen('DrawTexture',w,tex(face),[],destrect,[],[],trans(fr));
            Screen('DrawLines',w,fix,fixwidth,fixcolor,[xc yc]);
            vbl = Screen('Flip',w, vbl + (waitframes - 0.5) * ifi);
        end
        toc
    end
    Screen('FillRect',w,bkgd,rect);
    Screen('DrawLines',w,fix,fixwidth,[0 0 0],[xc yc]);
    Screen('Flip',w);
    
    WaitSecs(ISI);
end

%Shut down
save(sprintf('%s trial data',initials),'tOrder','rxn');
ListenChar(0);
instr = 'Program ended. Wait please.';
instSize = Screen('TextBounds',w,instr);
Screen('DrawText',w,instr,xc - instSize(3)/2,yc - instSize(4)/2);
Screen('Flip',w);
WaitSecs(10);
ShowCursor;
Priority(0)

%Close program
if strcmp(EEGt,'biosemi')
    sca
elseif strcmp(EEG,'egi')
    Close_EEG;
else
    sca
end
close all
end

function trigDevice = Initialize_EEG()
%Netstation initial communication parameters, experiment-generic
NS_host = '169.254.180.49';     %IP address for EEG computer
NS_port = 55513;
%Default port
%NS_synclimit = 0.9; % the maximum allowed difference in milliseconds between PTB and NetStation computer clocks (.m default is 2.5)
disp('Init')
%Detect and initialize the DAQ for ttl pulses
d=PsychHID('Devices');
numDevices=length(d);
trigDevice=[];
dev=1;
while isempty(trigDevice)
    if d(dev).vendorID==2523 && d(dev).productID==130 %if this is the first trigger device
        trigDevice=dev;
        %if you DO have the USB to the TTL pulse trigger attached
        disp('Found the trigger.');
    elseif dev==numDevices
        %if you do NOT have the USB to the TTL pulse trigger attached
        disp('Warning: trigger not found.');
        disp('Check out the USB devices by typing d=PsychHID(''Devices'').');
        break;
    end
    dev=dev+1;
end
%NOTE: The DAQ counts as 4 devices. The correct one to use is labeled 0 by
%   the DAQ, or likely the highest number of the 4 using PsychHID (other
%   non-DAQ devices, e.g. mouse/keyboard may be higher or lower in the list.

%trigDevice=4; %if this doesn't work, try 4
%Set port B to output, then make sure it's off
DaqDConfigPort(trigDevice,0,0);
DaqDOut(trigDevice,0,0);
TTL_pulse_dur = 0.005; % duration of TTL pulse to account for hardware lag

% Connect to the recording computer and start recording
NetStation('Connect', NS_host, NS_port)
NetStation('StartRecording');
end

function Close_EEG()
% Make sure to stop recording and disconnect from the recording computer
NetStation('StopRecording');
NetStation('Disconnect');
sca
close all
end