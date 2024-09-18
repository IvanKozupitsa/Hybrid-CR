% ОПРЕДЕЛЕНИЕ ПАРАМЕТРОВ МОДЕЛИРОВАНИЯ:

M = 16;      % Порядок модуляции
k = log2(M); % Количество битов на символ
numBits = k*2.5e5; % Ерл-во Битов для обрабтки
sps = 4;     % Количество выборок на символ (коэффициент избыточной выборки)
rng default  % генератор случайных чисел по умолчанию
dataIn = randi([0 1],numBits,1); % Генерация вектора двоичных данных

% ПРИМЕНЕНИЕ СВЕРТОЧНОГО КОДА:

constrlen = [5 4];          % Длина кодового ограничения
genpoly = [23 35 0; 0 5 13] % Создание Полиномов

tPoly = poly2trellis(constrlen,genpoly); %Определите решетку сверточного кодирования 
codeRate = 2/3;         % для кода со скоростью 2/3 с помощью функции poly2trellis. 
                        % Определенная решетка представляет собой сверточный код, который функция convenc 
                        % использует для кодирования двоичного вектора dataIn.

% КОДИРОВАНИЕ ВХОДНЫХ ДАННЫХ:

dataEnc = convenc(dataIn,tPoly);

% МОДУЛИРОВАНИЕ ДАННЫХ:

dataSymbolsIn = bit2int(dataEnc,k); %Используйте функцию bit2int для преобразования 
                                   % двоичных слов k-кортежа в целочисленные символы.

%figure;  % Создать новое окно
%stem(dataSymbolsIn(1:10)); %отобразить входные данные
%title('Random Symbols');
%xlabel('Symbol Index');
%ylabel('Integer Value');

dataMod = qammod(dataSymbolsIn,M); % 16 QAM модуляция

% СОЗДАНИЕ ФИЛЬТРА ПРИПОДНЯТОГО КОСИНУСА:

filtlen = 10; %Длина фильтра в символах
rolloff = 0.25; %Коэффициент затухания фильтра

rrcFilter = rcosdesign(rolloff,filtlen,sps); %rcosdesign функция для создания фильтра Прип.Кос.

impz(rrcFilter) % отображение импульсной характеристики фильтра


% ПРИМЕНЕНИЕ ФИЛЬТРА ПРИПОДНЯТОГО КОСИНУСА:  

% увеличьте дискретизацию сигнала с помощью коэффициента передискретизации и примените фильтр RRC.

txSignal = upfirdn(dataMod,rrcFilter,sps,1); %Функция upfirdn дополняет сигнал с повышенной
                                             %дискретизацией нулями в конце, чтобы
                                             %очистить фильтр. Затем функция применяет фильтр


% ПРИМЕНЕНИЕ КАНАЛ AWGN:

EbNo = 10;
snr = convertSNR(EbNo,'ebno', ...
    samplespersymbol=sps, ...
    bitspersymbol=k,CodingRate=codeRate); %Перевод Eb/N0 в ОСШ

rxSignal = awgn(txSignal,snr,'measured'); % Пропустить фильтрованый сигнал через AWGN канал:

% ПРИЕМ И ДЕМОДУЛЯЦИЯ СИГНАЛА:

% Удалите первые заполненные символы в децимированном сигнале, чтобы учесть
%суммарную задержку операций фильтрации при передаче и приеме.
%Удалите последние заполненные символы в децимированном сигнале, чтобы
%количество отсчетов на выходе демодулятора соответствовало количеству
%отсчетов на входе модулятора

rxFiltSignal = ...
    upfirdn(rxSignal,rrcFilter,1,sps);  % Понижение дискретизации и фильтрация

rxFiltSignal = ...
    rxFiltSignal(filtlen + 1:end - filtlen); % Учет задержки

% демодуляция принятого отфильтрованного сигнала

dataSymbOut = qamdemod(rxFiltSignal,M);     % Демодуляция 16QAM 

codedDataOut = int2bit(dataSymbOut,k);      % Возвращение данных в вектор столбцов

% ПРИМЕНЕНИЕ ДЕКОДИРОВАНИЯ ВИТЕРБИ:

traceBack = 16;                      % Длинна декодированного сигнала (?не факт)
numCodeWords = ...
    floor(length(codedDataOut)*2/3); % Количество полных кодовых слов
dataOut = ...
    vitdec(codedDataOut(1:numCodeWords*3/2), ...
    tPoly,traceBack,'cont','hard');  % Декодирование данных

% ВЫЧИСЛЕНИЕ КОЭФФИЦИЕНТА БИТОВЫХ ОШИБОК:

decDelay = 2*traceBack; %Задержка декодера [бит]

%Определение количества ошибок и соответствующего BER
[numErrors,ber] = ...
   biterr(dataIn(1:end - decDelay),dataOut(decDelay + 1:end));   
fprintf('\nThe bit error rate is %5.2e, based on %d errors.\n', ...
    ber,numErrors) %Вывод в окно матоаб BER и кол-ва ошибок
%
% Visualize Filter Effects

%To visualize the filter effects in an eye diagram,
% reduce the Eb/No setting and regenerate the received data.
% Visualizing a high SNR signal with no other multipath effects,
% you can use eye diagrams to highlight the intersymbol interference
% (ISI) reduction at the output for the pair of pulse shaping RRC filters. 
% The RRC filter does not have zero-ISI until it is paired with the second 
% RRC filter to form in cascade a raised cosine filter.
%
%EbNo = 20;
%snr = convertSNR(EbNo,'ebno', ...
%    samplespersymbol=sps, ...
%    bitspersymbol=k);
%rxSignal = awgn(txFiltSignal,snr,'measured');
%rxFiltSignal = ...
%    upfirdn(rxSignal,rrcFilter,1,sps);       % Downsample and filter
%rxFiltSignal = ...
%    rxFiltSignal(filtlen + 1:end - filtlen); % Account for delay
%
%%Create an eye diagram
%
%eyediagram(txFiltSignal(1:2000),sps*2);
%eyediagram(rxSignal(1:2000),sps*2);
%eyediagram(rxFiltSignal(1:2000),2);
%
%%Create a constellation diagram of the received signal 
%% before and after filtering.
%
%scatplot = scatterplot(sqrt(sps)*...
%    rxSignal(1:sps*5e3),...
%    sps,0);
%hold on;
%scatterplot(rxFiltSignal(1:5e3),1,0,'bx',scatplot);
%title('Received Signal, Before and After Filtering');
%legend('Before Filtering','After Filtering');
%axis([-5 5 -5 5]); % Set axis ranges
%hold off;
