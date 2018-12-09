clc
close all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%% BLE uses GFSK, but FSK is being used in this example
%------------Sideband caacellation using High pass filter------------%

upsample=10;                                    %Controls binary to digital signal
sample_rate=8;                                  %Sample factor
fd=10;                                          %For change in freq to be perciptible visually, a high fd value is chosen. For BLE fd lies b/w 135kHz to 170 kHz
zcd37=0;
zcd38=0;

fc37=2402;                                      %Center frequency for Ch 37
fs37=sample_rate*fc37;                          %Sampling rate
fc37_0=fc37-fd;                                 %Center frequency for CH 37, data 0
fs37_0=sample_rate*fc37_0;
fc37_1=fc37+fd;                                 %Center frequency for CH 37, data 1
fs37_1=sample_rate*fc37_1;
t37_0=0:1/fs37:1/fc37_0;
t37_1=0:1/fs37:1/fc37_1;

%------Packet construction---------%
preamble=randi([0 1],[1 6*8]);                  %6 bytes for preamble
oui=randi([0 1],[1 6*8]);                       %6 bytes for OUI
dlen=randi([0 1],[1 1*8]);                      %1 byte for data length
dtype=randi([0 1],[1 1*8]);                     %1 bytes for data type
uuid=randi([0 1],[1 2*8]);                      %2 bytes for UUID
steps=zeros([1 8]);                             %1 byte for storing steps
data=[preamble oui dlen dtype uuid steps];      %Construction of 1 BLE packet

%-------Converting binary data into a digital signal--------%
DATA=[];

for i=1:length(data)
    if data(i)==0
        temp=zeros(1,upsample);
    else
        temp=ones(1, upsample);
    end
    DATA=[DATA,temp];
end

%FSK Modulation begins here
A=1;
fsk37=[];

for i=1:length(DATA)
    if DATA(i)==0
        temp=A*cos(2*pi*fc37_0.*t37_0);
        fsk37=[fsk37 temp];
    else
        temp=A*cos(2*pi*fc37_1.*t37_1);
        fsk37=[fsk37 temp];
    end
end

figure
subplot(3,1,1)
plot(DATA,'lineWidth',2.5)
title('Data')
subplot(3,1,2)
plot(fsk37)
title('FSK modulated signal on CH37')

fsk37=fsk37';
%---------FSK modulation ends here--------%

%---------FSK demodulation begins here----------%
zcd = dsp.ZeroCrossingDetector;                 %Using zero-crossing detector to detect 0 or 1
                                                %Change window size of zcd to be either 7 or 11
                                                %Data 1 gives 2 zero-crossings within 7 samples, data 0 gives 2 zero-crossings within 11 samples
window=[length(t37_0)-1,length(t37_1)-1];
Ddata37=[];                                     %Ddata37 contains the digital data on Ch 37

start_idx37=1;
for i=1:length(fsk37)
    if zcd(fsk37(start_idx37:i))==2
        if i-start_idx37==window(1)
            Ddata37=[Ddata37 0];
        else
            Ddata37=[Ddata37 1];
        end
        start_idx37=1+i;
    end
    zcd.release();
    zcd37(i)=zcd(fsk37(1:i));
    zcd.release()
end

%--------FSK demodulation ends here---------%
subplot(3,1,3)
plot(Ddata37,'lineWidth',2.5)
title('Demodulated data on Ch 37')

%-----Modulation by tag begins here-------%
STEPS=de2bi(1000);

m38=24;                                         %Difference in frequency between Ch 37 and Ch38
fc38=fc37+m38;                                  %Center frequency for Ch 38
fs38=8*fc38;
fc38_0=fc38-fd;
t38=0:1/fs38:1/fc38;
cos38=A*cos(2*pi*fc38.*t38);
cos38=repmat(cos38,1,floor(length(fsk37)/length(cos38)));
extra=zeros([1 abs(length(fsk37)-length(cos38))]);
cos38=[cos38 extra];
fsk38=cos38'.*fsk37;
a=2*pi*fc38/fs37;                               %Filter constant a=T/tau
fsk38=filter([1-a a-1],[1 a-1],fsk38);          %Using high pass filter to remove low freq components (i.e. Ch37)

window=[length(t37_0)-1,length(t37_1)-1];
Ddata38=[];
start_idx38=1;
for i=1:length(fsk38)
    if zcd(fsk38(start_idx38:i))==4
        if i-start_idx38==window(1)
            Ddata38=[Ddata38 0];
        else
            Ddata38=[Ddata38 1];
        end
        start_idx38=1+i;
    end
    zcd.release();
    zcd38(i)=zcd(fsk38(1:i));
    zcd.release()
end

figure
subplot(3,1,1)
plot(DATA,'lineWidth',2.5);
title('Original data on Ch37');
subplot(3,1,2)
plot(fsk38);
title('FSK Ch 38')

one_check=find(Ddata38);
for i=2:length(one_check)
   if one_check(i)-one_check(i-1)<3
      Ddata38(one_check(i-1):one_check(i))=ones([1 one_check(i)-one_check(i-1)+1]);
   end
end

subplot(3,1,3)
plot(Ddata38,'lineWidth',2.5)
title('Recovered signal from Ch38')