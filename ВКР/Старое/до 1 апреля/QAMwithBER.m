% DEFINE SIMULATION PARAMETERS:

M = 16;      % Modulation order
k = log2(M); % Number of bits per symbol
n = 30000;   % Number of symbols per frame
numBits = k*2.5e5; % Bits to process
sps = 4;     % Number of samples per symbol (oversampling factor)
rng default  % Use default random number generator
dataIn = randi([0 1],numBits,1); % Generate vector of binary data

% CREATE RRC FILTER:

filtlen = 10; %Filter length in symbols
rolloff = 0.25; %Filter rolloff factor

% Use impz to display the RRC filter impulse response.:

impz(rrcFilter)

% APPLY CONVOLUTIONAL ENCODING (СВЕРТОЧНЫЙ КОД):

constrlen = [5 4];          % Code constraint length
genpoly = [23 35 0; 0 5 13] % Generator polynomials

tPoly = poly2trellis(constrlen,genpoly);
codeRate = 2/3;

% Encode input data:

dataEnc = convenc(dataIn,tPoly);

% MODULATE DATA:

dataSymbolsIn = bit2int(dataIn,k); %Use the bit2int function to convert k-tuple binary words into integer symbols.

figure;  % Create new figure window.
stem(dataSymbolsIn(1:10));
title('Random Symbols');
xlabel('Symbol Index');
ylabel('Integer Value');

dataMod = qammod(dataSymbolsIn,M); % 16 QAM modulation

% APPLY RAISED COSINE FILTERING: 

rrcFilter = rcosdesign(rolloff,filtlen,sps); %rcosdesign function to create an RRC filter: 

% upsample the signal by the oversampling factor and apply the RRC filter.
% The upfirdn function pads the upsampled signal with zeros at the end to 
% flush the filter. Then, the function applies the filter

txFiltSignal = upfirdn(dataMod,rrcFilter,sps,1);

% APPLY AWGN CHANNEL:

EbNo = 10;
snr = convertSNR(EbNo,'ebno', ...
    samplespersymbol=sps, ...
    bitspersymbol=k);

% Pass the filtered signal through an AWGN channel

receivedSignal = awgn(txFiltSignal,snr,'measured');

% RECEIVE AND DEMODULATE SIGNAL:

% Remove the first filtlen symbols in the decimated signal to account
% for the cumulative delay of the transmit and receive filtering operations.
% Remove the last filtlen symbols in the decimated signal to ensure the 
% number of samples in the demodulator output matches the number of 
% samples in the modulator input

rxFiltSignal = upfirdn(receivedSignal,rrcFilter,1,sps); % Downsample and filter

rxFiltSignal = rxFiltSignal(filtlen + 1: end - filtlen); % Account for delay

% demodulate the received filtered signal

dataSymbolsOut = qamdemod(rxFiltSignal,M);     % Gray-coded data symbols

dataOut = int2bit(dataSymbolsOut,k);

% Determine the number of errors and the associated BER 
% by using the biterr function

[numErrors,ber] = biterr(dataIn,dataOut);
fprintf(['\nFor an EbNo setting of %3.1f dB, ' ...
    'the bit error rate is %5.2e, based on %d errors.\n'], ...
    EbNo,ber,numErrors)

% Visualize Filter Effects

%To visualize the filter effects in an eye diagram,
% reduce the Eb/No setting and regenerate the received data.
% Visualizing a high SNR signal with no other multipath effects,
% you can use eye diagrams to highlight the intersymbol interference
% (ISI) reduction at the output for the pair of pulse shaping RRC filters. 
% The RRC filter does not have zero-ISI until it is paired with the second 
% RRC filter to form in cascade a raised cosine filter.

EbNo = 20;
snr = convertSNR(EbNo,'ebno', ...
    samplespersymbol=sps, ...
    bitspersymbol=k);
rxSignal = awgn(txFiltSignal,snr,'measured');
rxFiltSignal = ...
    upfirdn(rxSignal,rrcFilter,1,sps);       % Downsample and filter
rxFiltSignal = ...
    rxFiltSignal(filtlen + 1:end - filtlen); % Account for delay

%Create an eye diagram

eyediagram(txFiltSignal(1:2000),sps*2);
eyediagram(rxSignal(1:2000),sps*2);
eyediagram(rxFiltSignal(1:2000),2);

%Create a constellation diagram of the received signal 
% before and after filtering.

scatplot = scatterplot(sqrt(sps)*...
    rxSignal(1:sps*5e3),...
    sps,0);
hold on;
scatterplot(rxFiltSignal(1:5e3),1,0,'bx',scatplot);
title('Received Signal, Before and After Filtering');
legend('Before Filtering','After Filtering');
axis([-5 5 -5 5]); % Set axis ranges
hold off;