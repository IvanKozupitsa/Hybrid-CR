k=4;
numBits = k*2.5e5;
randi([0 1],numBits,1);

captureBandwidths = [];
numPotentialSignals = 0;
for cf = centerFrequencies
    wsds = [hNRPSSDescriptorsInFrequencyBand(cf-bandwidth/2,cf+bandwidth/2),...
        hLTEPSSDescriptorsInFrequencyBand(cf-bandwidth/2,cf+bandwidth/2)];
    captureBandwidths = [captureBandwidths, struct(CenterFrequency=cf,Bandwidth=bandwidth,SignalDescriptors=wsds)];
    numPotentialSignals = numPotentialSignals+length(wsds);
end