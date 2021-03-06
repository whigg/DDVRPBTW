function [initial_path] = initial(LHs, BHs, depot, capacity)
    % 初始化路径函数
    initial_path = []; % 初始路径集
    candidate = [];  
    % 按顺序将顾客节点插入
    % 先将LHs, BHs一个挨一个放入
    % 剩下不对称的部分直接放到后面
    
    min_len = min(length(LHs), length(BHs));
    for i = 1:min_len
        candidate = [candidate, LHs(i)];
        candidate = [candidate, BHs(i)];
    end
    if length(LHs) < length(BHs)
        candidate = [candidate, BHs(min_len+1 : end)];
    else
        candidate = [candidate, LHs(min_len+1 : end)];
    end
    depot.carindex = 1;
    candidate(1).carindex = 1;
    pathnode.route = [depot candidate(1) depot];  % 先将candidate的第一个节点放入到路径中
    pathnode.quantityL = candidate(1).quantity;  % LHs的总重量
    pathnode.quantityB = 0;  % BHs的总重量
    pathnode.index = 1;  % 货车编号
    pathnode.nodeindex = [candidate(1).index];  % 该条路径所拥有的顾客节点的编号，注意按顺序排列
    carindex = 1;
    initial_path = [initial_path, pathnode];
    for k = 2:length(candidate)
        cost = inf;
        curnode = candidate(k);  % 当前要插入到路径中的顾客点
        for pathindex = 1:length(initial_path)  % 逐条路径去找
            curpath = initial_path(pathindex);  % 当前搜索的路径
            curroute = curpath.route;
            for insertpointindex = 1:length(curroute)-1 % 每条路径中逐个插入点进行搜索
                predecessor = curroute(insertpointindex); % 前继节点
                successor = curroute(insertpointindex+1); % 后继节点
                switch curnode.type
                    case 'L'
                        if predecessor.type == 'D' || predecessor.type == 'L' % 是可插入点
                            if curpath.quantityL + curnode.quantity <= capacity % 满足容量约束
                                % 再判断是否满足时间窗约束
                                if timeWindowJudge(insertpointindex, curroute, curnode) == 1 % 满足时间窗约束
                                    tempcost = computeCost(predecessor, curnode, successor, insertpointindex, curroute);
                                    if tempcost < cost
                                        cost = tempcost;
                                        insert.pathindex = pathindex;  % 当前插入的路径
                                        insert.insertpointindex = insertpointindex; % 插入点在其路径中的下标
                                    end
                                end
                            end
                        end
                    case 'B'
                       if predecessor.type == 'L' && successor.type == 'B' || predecessor.type == 'L' && successor.type == 'D' || predecessor.type == 'B'
                            if curpath.quantityB + curnode.quantity <= capacity % 满足容量约束
                                % 再判断是否满足时间窗约束
                                if timeWindowJudge(insertpointindex, curroute, curnode) == 1 % 满足时间窗约束
                                    tempcost = computeCost(predecessor, curnode, successor, insertpointindex, curroute);
                                    if tempcost < cost
                                        cost = tempcost;
                                        insert.pathindex = pathindex;  % 当前插入的路径
                                        insert.insertpointindex = insertpointindex; % 插入点在其路径中的下标
                                    end
                                end
                            end
                        end   
                end
            end
        end
        if cost == inf % 没有可行插入点
            carindex = carindex + 1;
            depot.carindex = carindex;
            curnode.carindex = carindex;
            pathnode.route = [depot, curnode, depot]; % 建立一条新路径
            if curnode.type == 'L'
                pathnode.quantityL = curnode.quantity;
                pathnode.quantityB = 0;
            else
                pathnode.quantityB = curnode.quantity;
                pathnode.quantityL = 0;
            end
            pathnode.index = carindex; % 为每条路径标注其所属车辆
            pathnode.nodeindex = [curnode.index];
            initial_path = [initial_path, pathnode];
        else  % 插入到代价最小处，并更新路径
            selectpath = initial_path(insert.pathindex);
            selectpath_route = selectpath.route;
            temp = [];
            nodeindex = selectpath.nodeindex;
            tempnodeindex = [];
            tempnodeindex = [tempnodeindex, selectpath.nodeindex(1:insert.insertpointindex-1)];
            tempnodeindex = [tempnodeindex, curnode.index];
            tempnodeindex = [tempnodeindex, selectpath.nodeindex(insert.insertpointindex : end)];
            temp = [temp, selectpath_route(1:insert.insertpointindex)];
            curnode.carindex = selectpath.index;  % 为每个顾客标注其所属车辆
            temp = [temp, curnode];
            temp = [temp, selectpath_route(insert.insertpointindex+1 : end)];
            if curnode.type == 'L'
                selectpath.quantityL = selectpath.quantityL + curnode.quantity;
            else
                selectpath.quantityB = selectpath.quantityB + curnode.quantity;
            end
            selectpath.route = temp;
            selectpath.nodeindex = tempnodeindex;
            initial_path(insert.pathindex) = selectpath;
        end
    end
    initial_path = countArrivalTime(initial_path);
end

function [mark] = timeWindowJudge(insertpointindex, path, newcustomer)
    % 判断新插入的客户点是否会使得后续节点的时间窗约束被违反
    time = 0;  % 当前时间为0
    temp = [];
    temp = [temp, path(1:insertpointindex)];
    temp = [temp newcustomer];
    temp = [temp path(insertpointindex + 1:end)];
    path = temp;
    mark = 1;  % 为0表示违反约束
    for i = 1:length(path)-1
        predecessor = path(i); % 前继节点
        successor = path(i+1); % 后继节点
        if (i < insertpointindex) % 在插入点之前的顾客的时间窗都没有受到影响，不需要进行判断
            time = time + sqrt((predecessor.cx - successor.cx)^2 + (predecessor.cy - successor.cy)^2); % 车辆运行时间
            if (time < successor.start_time)  % 车辆在时间窗开始前到达
                time = successor.start_time;
            end
            time = time + successor.service_time;   % 服务时间
        else
            % 插入点之后的顾客的时间窗会受到影响，需要进行判断
            if i ~= length(path) - 1  % 后继节点不是仓库
                time = time + sqrt((predecessor.cx - successor.cx)^2 + (predecessor.cy - successor.cy)^2); % 车辆运行时间
                if time > successor.end_time  % 违反了时间窗约束
                    mark = 0;
                    break;
                else
                    if time < successor.start_time   % 车辆在时间窗开始前到达
                        time = successor.start_time;
                    end
                    time = time + successor.service_time;
                end
            end
        end
    end
end

function [c1] = computeCost(predecessor, newcustomer, successor, insertpointindex, path)
    % 计算插入代价
    % 暂时选择最短路插入
    c1 = sqrt((predecessor.cx - newcustomer.cx)^2 + (predecessor.cy - newcustomer.cy)^2) +... 
         sqrt((newcustomer.cx - successor.cx)^2 + (newcustomer.cy - successor.cy)^2) -... 
         sqrt((predecessor.cx - successor.cx)^2 + (predecessor.cy - successor.cy)^2);  % 路长变化
end

function [newrouteset] = countArrivalTime(routeset)
    % 计算route中每个顾客节点的货车到达时间
    routelen = length(routeset);   % 路径数目，即车辆数
    newrouteset = [];
    for i = 1 : routelen
        route = routeset(i).route;  % 当前路径
        currenttime = 0; 
        depot = route(1);
        depot.arrival_time = 0;   % 仓库出发时间记为0
        temp = [depot]; % temp存放增加货车到达时间后的路径
        for j = 2 : length(route) - 1
            predecessor = route(j-1);  % 前继节点
            currentnode = route(j); % 当前
            currenttime = currenttime + sqrt((predecessor.cx - currentnode.cx)^2 + (predecessor.cy - currentnode.cy)^2);
            currentnode.arrival_time = currenttime;  % 这里即为货车到达时间
            if currenttime < currentnode.start_time  % 需要等待
                currenttime = currentnode.start_time;
            end
            currenttime = currenttime + currentnode.service_time;  % 加上服务时间
            temp = [temp, currentnode];
        end
        temp = [temp, depot];
        node.route = temp;
        node.quantityL = routeset(i).quantityL;
        node.quantityB = routeset(i).quantityB;
        node.index = routeset(i).index;
        node.nodeindex = routeset(i).nodeindex;
        newrouteset = [newrouteset, node];
    end
end