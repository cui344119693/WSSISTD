
close all; clc; clear;
addpath("util\")

% 获取文件夹中所有文件信息 IRSTD-1k  NUDT-SIRST, sirst
datasets_name = 'IRSTD-1k/';
files = dir(fullfile(strcat(datasets_name,'images/', '*.png')));
imageFiles = {files.name};

exist_files = dir(fullfile(strcat(datasets_name,'random_walk_pseudo_coarse+/', '*.png')));
exist_imageFiles = {exist_files.name};

imageFiles = setdiff(imageFiles, exist_imageFiles, 'stable');

image_dir = strcat(datasets_name,'images/');
label_dir = strcat(datasets_name,'masks/');
save_dir = strcat(datasets_name,'random_walk_pseudo_coarse+/');
mkdir(save_dir);

patch_size = 41;
beta = 200;
% for i = 3:4
for i = 1:length(imageFiles)
    image_name = imageFiles{i};
    label = imread([label_dir,char(image_name)]); 
    img = imread([image_dir,char(image_name)]);

    
    if ndims(img) == 3 % 转换灰度图
        img = rgb2gray(img);
    end
    if ndims(label) == 3
        label = rgb2gray(label);
    end
    img = img - 1; %为了应对局部全255的的特殊情况
    img = double(img)/255; % 归一化
    Ilabel = bwlabel(label); 
    Area_I = regionprops(Ilabel,'centroid','BoundingBox','Area');

    img_centroid = zeros(size(label));
    RW_pesudo_label = zeros(size(label));
    for x = 1: numel(Area_I)
        
        gaussian_num_x = normrnd(0,1/2,1,1) ;
        gaussian_num_y = normrnd(0,1/2,1,1) ;
        center_y = floor(Area_I(x).Centroid(1)+Area_I(x).BoundingBox(3)/2*gaussian_num_y);
        center_x = floor(Area_I(x).Centroid(2)+Area_I(x).BoundingBox(4)/2*gaussian_num_x);
        [x_max, y_max] = size(img);
        if center_x <1
            center_x= 1;
        end
        if center_y <1
            center_y= 1;   
        end
        if center_x>x_max
            center_x = x_max;
        end
        if center_y>y_max
            center_y = y_max;
        end


        bbox = find_adaptive_bbox(img,[center_y,center_x],50,1.5);
        
        x1 = max(center_x-(patch_size-1)/2,1); 
        x2 = min(center_x+(patch_size-1)/2,size(img,1));
        y1 = max(center_y-(patch_size-1)/2,1);
        y2 = min(center_y+(patch_size-1)/2,size(img,2));

        local_img = img(x1:x2, y1:y2);
        local_label = label(x1:x2, y1:y2);


        img_2 = local_img;
        img_2(:,1) = 1;
        img_2(:,end) = 1;
        img_2(1,:) = 1;
        img_2(end,:) = 1;  % 将局部图的最外面一圈标记为背景类

        idx = find(img_2==1);
        [X, Y]=size(local_img);   
        s1x=floor((X+1)/2); s1y=floor((Y+1)/2); 
        % 对局部区域超出边界的情况进行中心偏移调节
        if x1 == 1
            s1x = floor(s1x + (center_x-(patch_size-1)/2-1)/2);
        end
        if x2 == size(img,1)
            s1x = floor(s1x + (center_x+(patch_size-1)/2-size(img,1))/2);
        end
        if y1 == 1
            s1y = floor(s1y + (center_y-(patch_size-1)/2-1)/2);
        end
        if y2 == size(img,2)
            s1y = floor(s1y+(center_y+(patch_size-1)/2-size(img,2))/2);
        end

        [~,prob] = random_walker(local_img,[sub2ind([X Y],s1x,s1y),idx'],[1,2*ones(1,length(idx))],beta); 

        mask = prob(:,:,1);
        mask(mask > 0.01) = 255;
        mask(mask <= 0.01) = 0;
        
        img_centroid(floor(Area_I(x).Centroid(2)),floor(Area_I(x).Centroid(1))) = 255;
        RW_pesudo_label(x1:x2, y1:y2) = mask;
    end

end
