file = csvread('dataset.csv', 1, 4);
length = 100;
t = 1 : length;
figure(1),
plot(t, file(1 : length, 2));