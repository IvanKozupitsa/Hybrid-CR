function EnergyDetector
threshold = 30; %Порог определения
FrameLength = 20;
Fs = 100;
movrmsWin = dsp.MovingRMS(20);
scope  = timescope('SampleRate',Fs,...
    'TimeSpanOverrunAction','Scroll',...
    'TimeSpanSource','Property','TimeSpan',100,...
    'ShowGrid',true,'LayoutDimensions',[3 1],'NumInputPorts',3);
scope.ActiveDisplay = 1;
scope.YLimits = [0 5];
scope.Title = 'Input Signal';
scope.ActiveDisplay = 2;
scope.YLimits = [0 350];
scope.Title = 'Compare Signal Energy with a Threshold';
scope.ActiveDisplay = 3;
scope.YLimits = [0 2];
scope.PlotType = 'Stairs';
scope.Title = 'Detect When Signal Energy Is Greater Than the Threshold';

for index = 1:length(rxSig)
    V = rxSig(index);
    for i = 1:90
        x = V + 0.1 * randn(FrameLength,1);
        y1 = movrmsWin(x);
        y1ener = (y1(end)^2)*FrameLength;
        event = (y1ener>threshold);
        if event == 1
            counter = counter + 1
        end
        scope(y1,[y1ener.*ones(FrameLength,1),...
            threshold.*ones(FrameLength,1)],event.*ones(FrameLength,1));
    end
end
end