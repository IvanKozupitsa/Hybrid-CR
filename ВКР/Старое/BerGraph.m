clc, clear, close all

%%%ПАРАМЕТРЫ СИСТЕМЫ:
numSymPerFrame = 2^12;  % Кол-во КАМ символов в кадре
M = 16;                 % Глубина модуляции
k = log2(M);
filtlen = 1024;         % Длина фильтра в символах
rolloff = 0.25;         % Коэффициент затухания фильтра
sps = 32;               % количества выборок на символ
fs = sps*4;             % частота дискретизации
fss1 = 0.2 * fs;        % Для управления смещением спм сигнала от 0 до 2pi
fss2 = 0.75 * fs; 
EbNoVec = (0:10);       % величина Eb/No (dB)
codeRate = 2/3;         % для кода со скоростью 2/3 с помощью функции poly2trellis. 
counter = 0;            % Счетчик для РУ
traceBack = 16;
%%ОСШ
snr = EbNoVec + 10*log10((k*codeRate)/sps); %k = BitsPerSymbol; sps = SamplesPerSymbol
%%%СИМУЛЯЦИЯ ВРЕМЕНИ
%simulationTime = 1;
%timeStep = 0.1;

%for time = 0:timeStep:simulationTime
%    if time < simulationTime/2

        berEst = zeros(size(EbNoVec));
        for n = 1:length(snr)
            % Обнуление ошибок и бит
            numErrs = 0;
            numBits = 0;
        
            while numErrs < 10 || numBits < 1e3

        %%ПЕРЕДАТЧИК 1
        
                [txSigUp1,tPoly1,rrcFilter1,ts1,dataIn1] = Transmitter(numSymPerFrame,k,M,rolloff,filtlen,sps,fs,fss1);
        
        %%ПЕРЕДАТЧИК 2
        
                [txSigUp2,tPoly2,rrcFilter2,ts2,dataIn2] = Transmitter(numSymPerFrame,k,M,rolloff,filtlen,sps,fs,fss2);
        
        %%%КАНАЛ
        
        %%ПРОХРЖДЕНИЕ ЧЕРЕЗ АБГШ
        Py = mean(txSigUp1.^2);            % Мощность сигнала
        Pn = Py / (10.^(snr/10))
        noise = sqrt(Pn) * randn(1, sps)

                NoiseSig1 = txSigUp1 + noise;
                NoiseSig2 = awgn(txSigUp2,snr(n),'measured');
        
                rxSig = NoiseSig1 + NoiseSig2;

        %%ИНТЕРФЕРЕНЦИОННОЕ ВЗАИМОДЕЙСТВИЕ 
                a1 = 1.0; %Весовые коэффициенты гармонических составляющих
                a2 = 0.3;
                a3 = 0.1;

                interfChan = a1*rxSig + a2*rxSig.^2 + a3*rxSig.^3;

        %%ПРИЕМНИК 1
        
                [dataOut1] = Receiver(rrcFilter1,filtlen,sps,fss1,interfChan,ts1,M,k,tPoly1,traceBack);
        
        %%ПРИЕМНИК 2
        
                [dataOut2] = Receiver(rrcFilter2,filtlen,sps,fss2,interfChan,ts2,M,k,tPoly2,traceBack);
        
        %РАССЧЕТ КОЛЛИЧЕСТВА ОШИБОЧНЫХ БИТ 1
        
                decDelay = 2*traceBack; %Задержка декодера [бит]
                if length(dataIn1) > decDelay
                    nErrors = biterr(dataIn1(1:end - decDelay),dataOut1(decDelay + 1:end));
                else
                    nErrors = 0;
                end
                % Счетчики бит и ошибок
                numErrs = numErrs + nErrors;
                numBits = numBits + numSymPerFrame*k;
            end
        
        %%ОЦЕНКА КОЭФФИЦИЕНТА БИТОВЫХ ОШИБОК 1
        
              berEst1(n) = numErrs/numBits
        
              %РАССЧЕТ КОЛЛИЧЕСТВА ОШИБОЧНЫХ БИТ 2
        
                decDelay = 2*traceBack; %Задержка декодера [бит]
                if length(dataIn2) > decDelay
                    nErrors = biterr(dataIn2(1:end - decDelay),dataOut2(decDelay + 1:end));
                else
                    nErrors = 0;
                end
                % Счетчики бит и ошибок
                numErrs = numErrs + nErrors;
                numBits = numBits + numSymPerFrame*k;
        
        %%ОЦЕНКА КОЭФФИЦИЕНТА БИТОВЫХ ОШИБОК 2
        
              berEst2(n) = numErrs/numBits;
        end
        
        %%ОЦЕНКА СПМ МЕТОДОМ УЭЛЧА
        
        [pxx,wx] = pwelch(rxSig,[],[],512,[]); %Второе значение - размер окна, третье - прекрытие окон, 
                                               % четвертое - количество ДПФ преобразований (разделений на них), пятое - указание на какой частоте СПМ
        plot(wx,10*log10(pxx))
        grid
        xlabel('Spectrum')
        ylabel('Power')
        
        %%ТЕОРЕТИЧЕСКИЕ ЗНАЧЕНИЯ КБО С АБГШ КАНАЛОМ
        
        berTheoryawgn1 = berawgn(EbNoVec,'qam',M);
        semilogy(EbNoVec,berEst1,'*')
        hold on
        berTheoryawgn2 = berawgn(EbNoVec,'qam',M);
        semilogy(EbNoVec,berEst2,'+')
        hold on
        semilogy(EbNoVec,berTheoryawgn1)
        hold on
        spect = distspec(tPoly1,8);
        
        %%ТЕОРЕТИЧЕСКИЕ ЗНАЧЕНИЯ КБО С КОДЕРОМ КАНАЛА:
        
        berTheoryCoded = bercoding(EbNoVec,'conv','hard',codeRate,spect,'qam',M,'nondiff')
        semilogy(EbNoVec,berTheoryCoded)
        grid
        legend('Estimated BER1','Estimated BER2','Theoretical BER awgn','Theoretical BER coding')
        xlabel('Eb/No (dB)')
        ylabel('Bit Error Rate')
%    end
%end
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%ФУНКЦИИ

function [txSigUp,tPoly,rrcFilter,ts,dataIn] = Transmitter(numSymPerFrame,k,M,rolloff,filtlen,sps,fs,fss)
%%ПЕРЕДАТЧИК

%ГЕНЕРАЦИЯ ВХОДНЫХ ДАННЫХ
        
        dataIn = randi([0 1],numSymPerFrame*k,1);

%%ПРИМЕНЕНИЕ СВЕРТОЧНОГО КОДА:

            constrlen = [5 4];           % Длина кодового ограничения
            genpoly = [23 35 0; 0 5 13]; % Создание Полиномов
    
            tPoly = poly2trellis(constrlen,genpoly); %Определение решетки сверточного кодирования                                         
        
%%КОДИРОВАНИЕ ВХОДНЫХ ДАННЫХ:

            dataEnc = convenc(dataIn,tPoly);
            dataSym = bit2int(dataEnc,k);
         
%%КАМ 
            txSig = qammod(dataSym,M);


%%СОЗДАНИЕ ФИЛЬТРА ПРИПОДНЯТОГО КОСИНУСА: 
        
            rrcFilter = rcosdesign(rolloff,filtlen,2*sps,"sqrt"); % функция для создания фильтра Прип.Кос.
            txSignal = upfirdn(txSig,rrcFilter,2*sps,1);
        

%%%ПРОХОЖДЕНИЕ ЧЕРЕЗ СМЕСИТЕЛЬ
   
            ts = (0:length(txSignal)-1)/fs;
            fc = exp(1i * 2 * pi * fss * ts.');           % Частота гетеродина [Гц]
             
            txSigUp = txSignal.*fc; 
        end


function [dataOut] = Receiver(rrcFilter,filtlen,sps,fss,rxSig,ts,M,k,tPoly,traceBack)
%%ПРИЕМНИК

%%СМЕСИТЕЛЬ

        rxSigdown = rxSig .* exp(-1i * 2 * pi * fss * ts.');

%%ФИЛЬТР ПРИПОДНЯТОГО КОСИНУСА
        rxFiltSignal = ...
            upfirdn(rxSigdown,rrcFilter,1,2*sps);       % Уменьшениче частоты дисркетизации и фильтрация
        rxFiltSignal = ...
            rxFiltSignal(filtlen + 1:end - filtlen); 
     
%ДЕМОДУЛЯТОР КАМ
        rxSym = qamdemod(rxFiltSignal,M);
        rxSym = rxSym(:);
%ПЕРЕВОД СИМВОЛОВ В БИТЫ
        codedDataOut = int2bit(rxSym,k);                     
        numCodeWords = ...
            floor(length(codedDataOut)*2/3); % Количество полных кодовых слов
        dataOut = ...
            vitdec(codedDataOut(1:numCodeWords*3/2), ...
            tPoly,traceBack,'cont','hard');  % Декодирование данных
end