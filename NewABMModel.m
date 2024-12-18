% Helper Functions
function location = PlaceCell(areaSize)
    location = [rand(),rand()] .* 2 .* areaSize - areaSize;
end

function distance = ComputeDistance(point1, point2)
    distance = sqrt((point1(1)-point2(1))^2 + (point1(2)-point2(2))^2);
end

function angle = ComputeAngle(point1, point2)
    angle = atan2((point2(2) - point1(2)),(point2(1) - point1(1)));
end

% COVID-19 Classroom Simulation with Ventilation Effects and Statistics
clear 
close all
clc

%% Simulation Time and Size
baseAreaSize = 150;
total_time = 730;
dt = 1;

% Germ movement and spread parameters
germSpeed = 1;
germSpreadRate = 5;
germLifespan = 1;

%% School Type Demographics
schoolDemographics = struct();
schoolDemographics.urban.totalStudents = 588;
schoolDemographics.urban.classSize = 28;
schoolDemographics.urban.roomSizeFactor = 1;
schoolDemographics.urban.maskCompliance = 0.67;

schoolDemographics.rural.totalStudents = 368;
schoolDemographics.rural.classSize = 20;
schoolDemographics.rural.roomSizeFactor = 1;
schoolDemographics.rural.maskCompliance = 0.28;

%% Student Properties
schoolType = ['urban'];

if strcmp(schoolType, 'urban')
    StudentNum = schoolDemographics.urban.classSize;
    areaSize = baseAreaSize * schoolDemographics.urban.roomSizeFactor;
    maskRate = schoolDemographics.urban.maskCompliance;
else
    StudentNum = schoolDemographics.rural.classSize;
    areaSize = baseAreaSize * schoolDemographics.rural.roomSizeFactor;
    maskRate = schoolDemographics.rural.maskCompliance;
end

% Initialize statistics tracking arrays
timeToFirstNewInfection = -1;
infectionHistory = zeros(1, total_time);
maskedInfectionHistory = zeros(1, total_time);
unmaskedInfectionHistory = zeros(1, total_time);
infectionRate = zeros(1, total_time);

StudentLocation = zeros([StudentNum,2]); 
StudentMasked = zeros([StudentNum,1]); 
StudentInfected = zeros([StudentNum,1]); 
StudentTarget = zeros([StudentNum,2]); 
studentSpeed = 0.5;

if strcmp(schoolType, 'urban')
    initialInfected = 3;
else
    initialInfected = 2;
end
maskNeutralizeRate = 0.7; 

%% Ventilation Parameters
if strcmp(schoolType, 'urban')
    hepaPresent = true;
    windowVentilation = 0.539;
    baseVentilationStrength = 0.8;
    ventilationRadius = 30;
    germMaxLifespan = 40;
else
    hepaPresent = false;
    windowVentilation = 0.735;
    baseVentilationStrength = 0.4;
    ventilationRadius = 15;
    germMaxLifespan = 80;
end

ventilationStrength = baseVentilationStrength * (hepaPresent * 0.5 + windowVentilation * 0.5);
ventilationRemovalRate = ventilationStrength * 0.2;

studentDensity = StudentNum / (areaSize * areaSize);
if strcmp(schoolType, 'rural')
    germSpreadRate = round(germSpreadRate * (1 + studentDensity * 1.5));
else
    germSpreadRate = round(germSpreadRate * (1 + studentDensity));
end

% Initialize Students
totalMaskedStudents = round(StudentNum * maskRate);  % Get exact number based on compliance rate
StudentMasked = zeros([StudentNum,1]); 
StudentMasked(1:totalMaskedStudents) = 1;  % First N students are masked
% Shuffle the mask assignments randomly (but total number stays constant)
StudentMasked = StudentMasked(randperm(StudentNum));

for student = 1:StudentNum 
    StudentLocation(student,:) = PlaceCell(areaSize);
    StudentTarget(student,:) = [rand()*2*areaSize-areaSize, rand()*2*areaSize-areaSize];
end

infected_indices = randperm(StudentNum, initialInfected);
StudentInfected(infected_indices) = 1;

%% Germ Properties
germsPerWave = 5;
waveInterval = 50;
lastWaveTime = 0;

GermLocation = [];
GermTarget = [];
GermInteractions = [];
GermSource = [];
GermAge = [];

% Create initial wave of germs
for i = 1:StudentNum
    if StudentInfected(i)
        for j = 1:germsPerWave
            newGermPos = StudentLocation(i,:) + [rand()*10-5, rand()*10-5];
            GermLocation = [GermLocation; newGermPos];
            GermTarget = [GermTarget; randi([1, StudentNum])];
            GermInteractions = [GermInteractions; 0];
            GermSource = [GermSource; i];
            GermAge = [GermAge; 0];
        end
    end
end

%% Main Simulation Loop
for t = 0:dt:total_time
    % Update student positions
    for student = 1:StudentNum
        if ComputeDistance(StudentLocation(student,:), StudentTarget(student,:)) < 1 || rand() < 0.05
            StudentTarget(student,:) = [rand()*2*areaSize-areaSize, rand()*2*areaSize-areaSize];
        end
        
        angleToTarget = ComputeAngle(StudentLocation(student,:), StudentTarget(student,:));
        newPos = StudentLocation(student,:) + ...
            [cos(angleToTarget), sin(angleToTarget)] .* studentSpeed;
        
        newPos = max(min(newPos, areaSize), -areaSize);
        StudentLocation(student,:) = newPos;
    end
    
    % Check for new germ wave
    if t - lastWaveTime >= waveInterval
        lastWaveTime = t;
        for i = 1:StudentNum
            if StudentInfected(i)
                for j = 1:germsPerWave
                    newGermPos = StudentLocation(i,:) + [rand()*10-5, rand()*10-5];
                    GermLocation = [GermLocation; newGermPos];
                    GermTarget = [GermTarget; randi([1, StudentNum])];
                    GermInteractions = [GermInteractions; 0];
                    GermSource = [GermSource; i];
                    GermAge = [GermAge; 0];
                end
            end
        end
    end
    
    % Update germs
    germIndicesToRemove = [];
    for germ = 1:length(GermTarget)
        GermAge(germ) = GermAge(germ) + 1;
        
        if GermAge(germ) >= germMaxLifespan
            germIndicesToRemove = [germIndicesToRemove germ];
            continue;
        end
        
        distToWall = min([
            areaSize - abs(GermLocation(germ,1)),
            areaSize - abs(GermLocation(germ,2))
        ]);
        
        if distToWall < ventilationRadius
            if rand() < ventilationRemovalRate
                germIndicesToRemove = [germIndicesToRemove germ];
                continue;
            end
        end
        
        distanceToStudent = ComputeDistance(GermLocation(germ,:), StudentLocation(GermTarget(germ),:));
        angleToStudent = ComputeAngle(GermLocation(germ,:), StudentLocation(GermTarget(germ),:));
        GermLocation(germ,:) = GermLocation(germ,:) + [cos(angleToStudent),sin(angleToStudent)].*germSpeed;
        
        if distanceToStudent <= 1
            GermInteractions(germ) = GermInteractions(germ) + 1;
            targetStudent = GermTarget(germ);
            
            if ~StudentInfected(targetStudent)
                if StudentMasked(targetStudent)
                    if rand() > maskNeutralizeRate
                        StudentInfected(targetStudent) = 1;
                    end
                else
                    StudentInfected(targetStudent) = 1;
                end
            end
            
            germIndicesToRemove = [germIndicesToRemove germ];
        end
    end
    
    % Remove processed germs
    GermLocation(germIndicesToRemove,:) = [];
    GermTarget(germIndicesToRemove) = [];
    GermInteractions(germIndicesToRemove) = [];
    GermSource(germIndicesToRemove) = [];
    GermAge(germIndicesToRemove) = [];
    
    % Update statistics
    currentInfected = sum(StudentInfected);
    currentMaskedInfected = sum(StudentInfected & StudentMasked);
    currentUnmaskedInfected = sum(StudentInfected & ~StudentMasked);
    totalMasked = sum(StudentMasked);
    totalUnmasked = StudentNum - totalMasked;

    infectionHistory(t+1) = currentInfected;
    maskedInfectionHistory(t+1) = currentMaskedInfected;
    unmaskedInfectionHistory(t+1) = currentUnmaskedInfected;

    if t > 0
        infectionRate(t+1) = (infectionHistory(t+1) - infectionHistory(t));
    end

    if timeToFirstNewInfection == -1 && currentInfected > initialInfected
        timeToFirstNewInfection = t;
    end
    
    % Plotting
    clf
    rectangle('Position', [-areaSize -areaSize 2*areaSize 2*areaSize], ...
        'EdgeColor', 'none', 'FaceColor', [0.9 0.9 1 0.2])
    rectangle('Position', [-areaSize+ventilationRadius -areaSize+ventilationRadius ...
        2*(areaSize-ventilationRadius) 2*(areaSize-ventilationRadius)], ...
        'EdgeColor', 'none', 'FaceColor', [1 1 1 1])
    hold on
    
    plot(StudentLocation(StudentInfected==0 & StudentMasked==1, 1), ...
         StudentLocation(StudentInfected==0 & StudentMasked==1, 2), 'ob', 'MarkerFaceColor', 'b')
    plot(StudentLocation(StudentInfected==0 & StudentMasked==0, 1), ...
         StudentLocation(StudentInfected==0 & StudentMasked==0, 2), 'ob')
    plot(StudentLocation(StudentInfected==1 & StudentMasked==1, 1), ...
         StudentLocation(StudentInfected==1 & StudentMasked==1, 2), 'or', 'MarkerFaceColor', 'r')
    plot(StudentLocation(StudentInfected==1 & StudentMasked==0, 1), ...
         StudentLocation(StudentInfected==1 & StudentMasked==0, 2), 'or')
    if ~isempty(GermLocation)
        plot(GermLocation(:, 1), GermLocation(:,2), '.r')
    end
    
    xlim([-areaSize, areaSize])
    ylim([-areaSize, areaSize])
    title(sprintf('Time: %d | Setting: %s\nTotal Infected: %d/%d | Active Germs: %d\nVentilation Strength: %.1f', ...
        t, schoolType, sum(StudentInfected), StudentNum, length(GermTarget), ventilationStrength))
    hold off
    
    pause(0.05)
    
    if sum(StudentInfected) == StudentNum
        break
    end
end

%% Display Final Statistics
fprintf('\n=== Final Simulation Statistics ===\n');
fprintf('School Type: %s\n', schoolType);
fprintf('Total Time Steps: %d\n', t);
fprintf('Initial Infections: %d\n', initialInfected);
fprintf('Final Infections: %d (%.1f%%)\n', currentInfected, (currentInfected/StudentNum)*100);

maskedInfectionRate = (currentMaskedInfected/totalMasked)*100;
unmaskedInfectionRate = (currentUnmaskedInfected/totalUnmasked)*100;
fprintf('\nMasked Students (%d total):\n', totalMasked);
fprintf('- Infected: %d (%.1f%%)\n', currentMaskedInfected, maskedInfectionRate);
fprintf('- Uninfected: %d (%.1f%%)\n', totalMasked-currentMaskedInfected, 100-maskedInfectionRate);

fprintf('\nUnmasked Students (%d total):\n', totalUnmasked);
fprintf('- Infected: %d (%.1f%%)\n', currentUnmaskedInfected, unmaskedInfectionRate);
fprintf('- Uninfected: %d (%.1f%%)\n', totalUnmasked-currentUnmaskedInfected, 100-unmaskedInfectionRate);

timeToFullInfection = find(infectionHistory == StudentNum, 1);
fprintf('\nSpread Analysis:\n');
fprintf('Time to First New Infection: %d steps\n', timeToFirstNewInfection);
if ~isempty(timeToFullInfection)
    fprintf('Time to Full Infection: %d steps\n', timeToFullInfection);
else
    fprintf('Full infection not reached within time limit\n');
end

averageRate = (currentInfected-initialInfected)/t;
fprintf('Average Infection Rate: %.2f new cases per time step\n', averageRate);

[maxRate, maxRateTime] = max(infectionRate);
fprintf('Peak Infection Rate: %.2f new cases (at time step %d)\n', maxRate, maxRateTime);