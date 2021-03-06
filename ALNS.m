function [final_path, final_cost] = ALNS(nodeset, depot, capacityL, capacityB, dmax, quantitymax, n)
    % adaptive large neighbor search algorithm
    initialrouteset = [];
    depot.carindex = 1;
    routenode.route = [depot, depot];
    routenode.index = 1;
    routenode.quantityL = 0;
    routenode.quantityB = 0;
    routenode.nodeindex = [];
    initialrouteset = [initialrouteset, routenode];
    [initialrouteset] = regretInsert(nodeset, initialrouteset, capacityL, capacityB, 0, 0);
    
    % 入口参数及出口参数赋值
    currouteset = initialrouteset;
    curcost = routecost(initialrouteset);
    curglobalmincost = curcost; % 当前全局最优解
    globalbestrouteset = currouteset; % 全局最优路线
    
    % 评分机制的相关参数
    removeheuristicnum = 3;  % remove algorithm的数量
    insertheuristicnum = 2;  % insert algorithm的数量
    removeprob = 1/removeheuristicnum * ones(1, removeheuristicnum); % 各个remove algorithm的概率
    insertprob = 1/insertheuristicnum * ones(1, insertheuristicnum); % 各个insert algorihtm的概率
    removeweight = ones(1,removeheuristicnum); % 各个remove algorithm的权重
    insertweight = ones(1,insertheuristicnum); % 各个insert algorithm的权重
    noiseweight = ones(1,2); % 第一个元素是加噪声的权重，第二个元素是不加噪声的权重
    removeusefrequency = zeros(1,removeheuristicnum); % 各个remove算子使用的次数
    insertusefrequency = zeros(1,insertheuristicnum); % 各个insert算子使用的次数
    removescore = zeros(1,removeheuristicnum);  % 各个remove算子在当前segment中的评分
    insertscore = zeros(1,insertheuristicnum);  % 各个insert算子在当前segment中的评分
    noiseaddscore = zeros(1,2);    % 第1个元素是加噪声的得分，第2个元素是不加噪声的得分 
    noiseaddfrequency = 0;         % 噪声使用的次数
    noiseprobability = 0.5;  % 在计算插入代价时添加噪声的概率 
    sigma1 = 33;
    sigma2 = 9;
    sigma3 = 13;
    r = 0.1;
    
    % 其余核心参数
    maxiter = 200;  % 总的迭代次数
    segment = 100;  % 每隔一个segment更新removeprob和insertprob
    w = 0.05;
    T = w * curcost / log(2);  % 初始温度
    p = 6;       % shaw remove中为增加随机性而设立的参数
    pworst = 3;  % worst removal
    ksi = 0.4;   % 每次remove的节点数占总节点数的比例
    eta = 0.025; % 噪声系数，乘以路径中节点间的最大距离
    noiseamount = eta * dmax;   % 噪声量
    c = 0.9998;  % 降温速度
    
    % hash表，用来存储每次被accept的路径的hash code
    initialroutecode = routecode(initialrouteset);  % 把初始解编码，用来生成harsh key
    hashtable = {};
    hashtable{1} = hash(initialroutecode,'MD2');
    
    for iter = 1:maxiter
        % 开始新的segment，应该要将加分相关的变量全部清零
        if mod(iter, segment) == 1  
            if iter ~= 1  % 如果不是刚开始，则应该更新各算子的权重及概率
                for i = 1:removeheuristicnum
                    if removeusefrequency(i) ~= 0
                        removeweight(i) = removeweight(i) * (1-r) + r * removescore(i)/removeusefrequency(i);
                    else  % 如果没有被使用过，权重应该下降
                        removeweight(i) = removeweight(i) * (1-r);
                    end
                end
                for j = 1:insertheuristicnum
                    if insertusefrequency(j) ~= 0
                        insertweight(j) = insertweight(j) * (1-r) + r * insertscore(j)/insertusefrequency(j);
                    else  % 如果没有被使用过，权重应该下降
                        insertweight(j) = insertweight(j) * (1-r);
                    end
                end
                removeprob = removeweight / sum(removeweight); % 归一化
                insertprob = insertweight / sum(insertweight);
                if noiseaddfrequency == 0  % 上一个segment中没有加过噪声
                    noiseweight(1) = noiseweight(1) * (1-r);
                    noiseweight(2) = noiseweight(2) * (1-r) + r * noiseaddscore(2) / segment;
                else
                    if noiseaddfrequency == segment  % 上一个segment中每次都加了噪声
                        noiseweight(1) = noiseweight(1) * (1-r) + r * noiseaddscore(1) / segment;
                        noiseweight(2) = noiseweight(2) * (1-r);
                    else  % 上一个segment中，有的时候加了噪声，有的时候没有加噪声
                        noiseweight(1) = noiseweight(1) * (1-r) + r * noiseaddscore(1) / noiseaddfrequency;
                        noiseweight(2) = noiseweight(2) * (1-r) + r * noiseaddscore(2) / (segment - noiseaddfrequency);
                    end
                end
                noiseprobability = noiseweight(1) / sum(noiseweight);
            end
            fprintf('-----segment: %d, current cost: %f, current best cost: %f, hashtable length: %d\n', floor(iter/segment)+1, curcost, curglobalmincost, length(hashtable));
            fprintf('     shaw removal score: %d, random removal score: %d, worst removal score: %d\n', removescore(1), removescore(2), removescore(3));
            fprintf('     shaw removal weight: %f, random removal weight: %f, worst removal weight: %f\n', removeweight(1), removeweight(2), removeweight(3));
            fprintf('     shaw removal freq: %d, random removal freq: %d, worst removal freq: %d\n', removeusefrequency(1), removeusefrequency(2), removeusefrequency(3));
            fprintf('     greedy insert score: %d, regret insert score: %d\n', insertscore(1), insertscore(2));
            fprintf('     greedy insert weight: %f, regret insert weight: %f\n', insertweight(1), insertweight(2));
            fprintf('     greedy insert freq: %d, regret insert freq: %d\n', insertusefrequency(1), insertusefrequency(2));
            fprintf('     noise score: %d, without noise score: %d\n', noiseaddscore(1), noiseaddscore(2));
            fprintf('     noise weight: %f, without noise weight: %f\n', noiseweight(1), noiseweight(2));
            fprintf('     noise use freq: %d\n', noiseaddfrequency);
            removescore = zeros(1,removeheuristicnum);  % 各个remove算子在当前segment中的评分
            insertscore = zeros(1,insertheuristicnum);  % 各个insert算子在当前segment中的评分
            removeusefrequency = zeros(1,removeheuristicnum); % 各个remove算子使用的次数
            insertusefrequency = zeros(1,insertheuristicnum); % 各个insert算子使用的次数
            noiseaddfrequency = 0;  % 噪声使用的次数
            noiseaddscore = zeros(1,2);  % 第1个元素是加噪声的得分，第2个元素是不加噪声的得分 
        end 
        
        % 产生随机数选取remove算子和insert算子
        % 以概率选择remove算子
        removeselect = rand;
        removeindex = 1;
        while sum(removeprob(1:removeindex)) < removeselect 
            removeindex = removeindex + 1;
        end
        % 以概率选择insert算子
        insertselect = rand;
        insertindex = 1;
        while sum(insertprob(1:insertindex)) < insertselect
            insertindex = insertindex + 1;
        end
        removeusefrequency(removeindex) = removeusefrequency(removeindex) + 1;  % 使用到的remove算子其使用次数加一
        insertusefrequency(insertindex) = insertusefrequency(insertindex) + 1;  % 使用到的insert算子其使用次数加一
        q = randi([4 min(100, floor(ksi * n))]);  % 随机选取4 - min(100,ksi*n)个节点去remove
        switch removeindex
            case 1
                [currouteset] = updateArrivalTime(currouteset);
                tmax = countMaxValue(currouteset);
                [removedrouteset, removednodeset, removednodeindexset] = shawRemoval(currouteset, q, p, n, dmax, tmax, quantitymax);
            case 2
                [removedrouteset, removednodeset, removednodeindexset] = randomRemoval(currouteset, q, n);  % no parameter p
            case 3
                [removedrouteset, removednodeset, removednodeindexset] = worstRemoval(currouteset, q, pworst, n);
        end
        [removedrouteset] = removeNullRoute(removedrouteset, depot);
        switch insertindex
            case 1
                if noiseprobability > rand     % 以概率选择是否添加噪声影响
                    noiseadd = 1;
                    noiseaddfrequency = noiseaddfrequency + 1;
                else
                    noiseadd = 0;
                end
                [finalrouteset] = greedyInsert(removednodeset, removedrouteset, capacityL, capacityB, noiseadd, noiseamount);
            case 2
                if noiseprobability > rand    % 以概率选择是否添加噪声影响
                    noiseadd = 1;
                    noiseaddfrequency = noiseaddfrequency + 1;
                else
                    noiseadd = 0;
                end
                [finalrouteset] = regretInsert(removednodeset, removedrouteset, capacityL, capacityB, noiseadd, noiseamount);
        end
%         [nodeindex1c, nodeindex2c] = showNodeindexInRouteSet(finalrouteset)
        [finalrouteset] = removeNullRoute(finalrouteset, depot);   % 移除掉路径集中的空路径
%         [nodeindex1d, nodeindex2d] = showNodeindexInRouteSet(finalrouteset)
        
        % 模拟退火算法
        newcost = routecost(finalrouteset);  % 新路径的代价
        acceptprobability = exp(-(newcost - curcost)/T);  % 接受此路径的概率
        accept = 0;
        if acceptprobability > rand
            accept = 1;
        end
        T = T * c;  % 降温
        newroutecode = routecode(finalrouteset);      % 先将路径进行规则编码
        newroutehashkey = hash(newroutecode, 'MD2');  % 再将路径进行hash key编码
        
        % 接下来判断是否需要加分
        % 加分情况如下：
        % 1. 当得到一个全局最优解时
        % 2. 当得到一个尚未被接受过的更好的解
        % 3. 当得到一个尚未被接受过的解，虽然这个解比当前解差，但是这个解被接受了
        if newcost < curglobalmincost   % 情况1
            removescore(removeindex) = removescore(removeindex) + sigma1;
            insertscore(insertindex) = insertscore(insertindex) + sigma1;
            curglobalmincost = newcost;
            globalbestrouteset = finalrouteset;
            if noiseadd == 1
                noiseaddscore(1) = noiseaddscore(1) + sigma1;
            else
                noiseaddscore(2) = noiseaddscore(2) + sigma1;
            end
        else
            if ismember(newroutehashkey, hashtable) == 0  % 该路径还没有被接受过
                if newcost < curcost  % 情况2
                    removescore(removeindex) = removescore(removeindex) + sigma2;
                    insertscore(insertindex) = insertscore(insertindex) + sigma2;
                    if noiseadd == 1
                        noiseaddscore(1) = noiseaddscore(1) + sigma2;
                    else
                        noiseaddscore(2) = noiseaddscore(2) + sigma2;
                    end
                else
                    if accept == 1  % 情况3
                        removescore(removeindex) = removescore(removeindex) + sigma3;
                        insertscore(insertindex) = insertscore(insertindex) + sigma3;
                        if noiseadd == 1
                            noiseaddscore(1) = noiseaddscore(1) + sigma3;
                        else
                            noiseaddscore(2) = noiseaddscore(2) + sigma3;
                        end
                    end
                end
            end
        end
        
        % 更新hash表以及curcost, currouteset
        if accept == 1  % 如果被接受了，先判断当前解是否在hashtable中，若无，则添加到hashtable中
            if ismember(newroutehashkey, hashtable) == 0  % 该路径还没有被接受过
                hashtable{length(hashtable)+1} = newroutehashkey;
            end
            curcost = newcost;  % 更新当前的cost
            currouteset = finalrouteset;  % 更新当前的path
        end  
    end
    final_path = globalbestrouteset;
    final_cost = curglobalmincost;
end

%% ------------------------ removal algorithms ---------------------- %%
%% shaw removal
function [removedrouteset, removednodeset, removednodeindexset] = shawRemoval(initialrouteset, q, p, n, dmax, tmax, quantitymax)
    % initialrouteset: 当前的路径集
    % q: 要移除的request的数量
    % p: 增加removal的随机性
    % n: 总的节点数目
    % dmax: 顾客节点间的最大距离
    % tmax: 货车的最晚到达顾客点的时间
    % quantitymax: 顾客的最大需求量
    % 每次循环移除的request数量为y^p * |L|，L为路径中的剩余节点
    phi = 9;
    kai = 3;
    psi = 2;
    K = length(initialrouteset); % 车辆数
    
    % 下面是随机选取路径中的一个节点
    D = [];  % 被移除的节点编号
    nodeindexinrouteset = 1:n;  % 路径集中的节点编号
    selectednodeindex = nodeindexinrouteset(randi([1 length(nodeindexinrouteset)]));  % 被移除的节点编号
    D = [D, selectednodeindex];
    
    % 计算相似程度R
    R = inf(n,n);  % 衡量节点之间的相近程度
    nodeset = [];     % 先把所有节点的放到一个临时向量temp中
    for i = 1:K  
        curroute = initialrouteset(i).route;
        for j = 2 : length(curroute) - 1
            nodeset = [nodeset, curroute(j)];
        end
    end
    for i = 1:n
        for j = i+1:n
            node1 = nodeset(i);
            node2 = nodeset(j);
            node1index = node1.index;
            node2index = node2.index;
            R(node1index, node2index) = phi * sqrt((node1.cx - node2.cx)^2 + (node1.cy - node2.cy)^2)/dmax + ...
                                        kai * abs(node1.arrival_time - node2.arrival_time)/tmax + ...
                                        psi * abs(node1.quantity - node2.quantity)/quantitymax;
            R(node2index, node1index) = R(node1index, node2index);
        end
    end
    while length(D) < q
        % 一直循环执行到D中的request数量为q为止
        % 将相近程度从低到高进行排序
        % 只考虑尚在路径中的节点
        [sortR, sortRindex] = sort(R(selectednodeindex, nodeindexinrouteset), 'ascend');  
        y = rand;
        removenum = max(floor(y^p * length(nodeindexinrouteset)), 1);  % 移除的request的数量
        removenodeindexset = nodeindexinrouteset(sortRindex(1:removenum)); % 被移除的路径节点的编号
        nodeindexinrouteset = setdiff(nodeindexinrouteset, removenodeindexset, 'stable');
        if isempty(nodeindexinrouteset)
            nodeindexinrouteset = [];
        end
        D = [D, removenodeindexset];
        selectednodeindex = D(randi([1 length(D)]));  % 再次随机选取一个request，已经移除的路径集合中
    end
    % 现在对D中的编号进行映射，移除掉各条路径中的D中的元素
    [removedrouteset, removednodeset] = removeNodeInRouteSet(D, initialrouteset);
    removednodeindexset = D; 
end

%% random removal
function [removedrouteset, removednodeset, removednodeindexset] = randomRemoval(initialrouteset, q, n)
    % 随机移除q个节点
    nodeindexinrouteset = 1:n;  % 所有节点的编号
    D = [];  % 被移除的节点编号
    while length(D) < q   % 随机产生q个request的编号
        selectednodeindex = nodeindexinrouteset(randi([1 length(nodeindexinrouteset)]));  % 当前选中的节点编号
        D = [D, selectednodeindex];
        nodeindexinrouteset = setdiff(nodeindexinrouteset, selectednodeindex, 'stable');
    end
    [removedrouteset, removednodeset] = removeNodeInRouteSet(D, initialrouteset);
    removednodeindexset = D;
end

%% worst removal
function [removedpath, removedrequestnode, removedrequestindex] = worstRemoval(solutions, q, p, n)
    % 移除掉q个“最差”的request
    D = [];  % 要移除的节点
    DD = [];  % 要移除的节点编号
    nodeindexset = 1:n;
    while length(D) < q
        [reducedcost] = computeReducedCost(solutions, nodeindexset, n); 
        % reducedcost存放的是所有节点的移除代价
        % 不在nodeindexset中的节点其移除代价赋为∞
        [sortreducedcost, sortindex] = sort(reducedcost, 'ascend'); 
        y = rand;
        removednum = max(floor(y^p*length(nodeindexset)), 1);
        removenodeindex = sortindex(1: removednum);
        DD = [DD, removenodeindex];
        [result, removednode] = removeNodeInRouteSet(removenodeindex, solutions);
        solutions = result;  % 移除节点后更新路径
        nodeindexset = setdiff(nodeindexset, removenodeindex, 'stable');
        if isempty(nodeindexset)
            nodeindexset = [];
        end
        D = [D, removednode];
    end
    removedpath = solutions;
    removedrequestnode = D;
    removedrequestindex = DD;
end

%% 一些附加的函数
function [removedrouteset, removednodeset] = removeNodeInRouteSet(removenodeindexset, initialrouteset)
    % removenodeindex: 要移除的节点编号
    % routeset: 所有的路径集合
    D = removenodeindexset;
    DD = [];
    for i = 1:length(initialrouteset)
        curpath = initialrouteset(i);
        curroute = curpath.route;
        [curremovednodeindexset, curremovenodeposset] = intersect(curpath.nodeindex, D);  % 找出被移除的节点编号
        for j = 1:length(curremovenodeposset)  % 逐个节点进行移除，注意同步更新quantityL和quantityB
            curnode = curroute(curremovenodeposset(j)+1);  % 注意第一个节点是depot，nodeindex中只有顾客节点的编号
            DD = [DD, curnode];
            if (curnode.type == 'L')
                curpath.quantityL = curpath.quantityL - curnode.quantity;
            else
                curpath.quantityB = curpath.quantityB - curnode.quantity;
            end
        end
        curpath.nodeindex = setdiff(curpath.nodeindex, curremovednodeindexset, 'stable');  % 更新路径中的node下标
        if isempty(curpath.nodeindex)
            curpath.nodeindex = [];
        end
        curroute(curremovenodeposset+1) = [];  % 一次性移除掉所有需要移除的节点
        curpath.route = curroute;
        initialrouteset(i) = curpath;
    end
    removedrouteset = initialrouteset;
    removednodeset = DD;
end

function [reducedcostarr] = computeReducedCost(routeset, nodeindexset, n)
    % 计算routeset中所有节点的移除代价（即移除掉它之后带来的路径代价变化量）
    % 不在nodeindexset中的节点其移除代价赋为∞
    reducedcostarr = inf(1,n);  % 没有被计算的node的移除代价记为inf
    for i = 1:length(routeset)
        curroute = routeset(i).route;
        computednodeindexset = intersect(routeset(i).nodeindex, nodeindexset); % 此路径中需要计算reducedcost的节点下标
        for j = 1:length(computednodeindexset)
            nodeindex = computednodeindexset(j);   % 当前选中的节点编号
            pos = find(routeset(i).nodeindex == nodeindex);  % 找到当前要计算的节点在路径的nodeindex数组下的坐标
            predecessor = curroute(pos);
            curnode = curroute(pos+1);
            successor = curroute(pos+2);
            temp = -sqrt((predecessor.cx-curnode.cx)^2 + (predecessor.cy-curnode.cy)^2) -...
                   sqrt((successor.cx-curnode.cx)^2 + (successor.cy-curnode.cy)^2) +...
                   sqrt((predecessor.cx-successor.cx)^2 + (predecessor.cy-successor.cy)^2);
            reducedcostarr(nodeindex) = temp;
        end
    end
end

%% ------------------------ insertion algorithms ---------------------- %%
%% greedy insert
function [finalrouteset] = greedyInsert(removednodeset, removedrouteset, capacityL, capacityB, noiseadd, noiseamount)
    % 贪婪算法，每次都寻找最好的点插入
    % 把removednodeset插入到removedrouteset中
    % 如果没有找到可行插入点，应该再立一条新的路径
    alreadyinsertposset = [];  % 已经插入的节点在removednodeset中的位置
    m = length(removednodeset);
    mark = ones(1,m);
    [bestinsertcostmap, bestinsertinfomap, secondinsertcostmap] =...
        computeInsertCostMap(removednodeset, removedrouteset, capacityL, capacityB, mark, noiseadd, noiseamount);
    while length(alreadyinsertposset) < length(removednodeset)
        mincost = min(min(bestinsertcostmap));
        
        % 所有剩余的待插入点都没有可行地方插入，则应该开辟一条新的路径
        if mincost == inf   
            restnodeposset = setdiff(1:m, alreadyinsertposset);     % 剩余可选节点在removednodeset中的位置
            selectednodepos = restnodeposset(1);                    % 随便选取一个节点插入到新路径中
            alreadyinsertposset = [alreadyinsertposset, selectednodepos];   % 更新已插入到路径中的节点
            selectednode = removednodeset(selectednodepos);  % selectednodepos对应的节点
            newrouteindex = length(removedrouteset) + 1;     % 新路径对应的车辆编号
            depot = removedrouteset(1).route(1);      % depot节点
            depot.carindex = newrouteindex;
            selectednode.carindex = newrouteindex;
            newroutenode.route = [depot, selectednode, depot];
            newroutenode.nodeindex = [selectednode.index];
            if selectednode.type == 'L'
                newroutenode.quantityL = selectednode.quantity;
                newroutenode.quantityB = 0;
            else
                newroutenode.quantityB = selectednode.quantity;
                newroutenode.quantityL = 0;
            end
            newroutenode.index = newrouteindex;
            removedrouteset = [removedrouteset newroutenode];
            operationroutenode = newroutenode;   % 针对新改变的路径，重新计算剩余带插入节点到此路径的插入代价
            operationrouteindex = newrouteindex; % 改变的路径对应的货车编号
            
        else  % 有可行插入点，直接插入到相应的路径中 
            
            % 找到最小插入代价对应的节点在removednodeset中的位置，以及其所属货车
            index = find(bestinsertcostmap == mincost);
            index = index(1);
            selectedrouteindex = floor(index/m) + 1;
            selectednodepos = index - (selectedrouteindex-1) * m;
            if selectednodepos == 0
                selectednodepos = m;
                selectedrouteindex = selectedrouteindex - 1;
            end
            insertpointpos = bestinsertinfomap(selectednodepos, selectedrouteindex);        % 最佳插入点位置
            alreadyinsertposset = [alreadyinsertposset, selectednodepos];   % 更新已插入到路径中的节点
            selectednode = removednodeset(selectednodepos);   % 此次被选中的节点
            selectednode.carindex = selectedrouteindex;       % 所属货车
            
            % 对于新插入的节点，使得其插入信息无效化，避免下次又被选中
            bestinsertcostmap(selectednodepos,:) = inf;  
            bestinsertinfomap(selectednodepos,:) = -1;  
            secondinsertcostmap(selectednodepos,:) = inf;  
            
            % 对被选中的路径，更新其信息
            nodeindexincurroute = removedrouteset(selectedrouteindex).nodeindex;  % 要插入的路径中其所拥有的节点编号（全局）
            temp = []; 
            temp = [temp, nodeindexincurroute(1:insertpointpos-1)];
            temp = [temp, selectednode.index];
            temp = [temp, nodeindexincurroute(insertpointpos:end)];
            removedrouteset(selectedrouteindex).nodeindex = temp;
            selectedroute = removedrouteset(selectedrouteindex).route;  % 被选中的路径其拥有的节点
            temp = [];
            temp = [temp, selectedroute(1:insertpointpos)];
            temp = [temp, selectednode];
            temp = [temp, selectedroute(insertpointpos+1:end)];
            removedrouteset(selectedrouteindex).route = temp;
            switch selectednode.type   % 修改quantityL和quantityB的值
                case 'L'
                    removedrouteset(selectedrouteindex).quantityL = removedrouteset(selectedrouteindex).quantityL + selectednode.quantity;
                case 'B'
                    removedrouteset(selectedrouteindex).quantityB = removedrouteset(selectedrouteindex).quantityB + selectednode.quantity;
            end
            operationroutenode = removedrouteset(selectedrouteindex);  % 针对新改变的路径，重新计算剩余带插入节点到此路径的插入代价
            operationrouteindex = selectedrouteindex; % 改变的路径对应的货车编号          
        end
        
        % 对当前插入节点的路径，求所有未插入节点到该路径的最小/次小插入代价信息，并按需更新原有的最小/次小插入代价信息
        mark = ones(1,m);  % 1表示节点还没有插入，0表示节点已经插入
        mark(alreadyinsertposset) = 0;  % 已经插入过的节点置为0
        [newbestinsertcostarr, newbestinsertinfoarr, newsecondinsertcostarr] =...
            computeInsertCostMap(removednodeset, operationroutenode, capacityL, capacityB, mark, noiseadd, noiseamount);
        bestinsertcostmap(:,operationrouteindex) = newbestinsertcostarr;
        bestinsertinfomap(:,operationrouteindex) = newbestinsertinfoarr;
        secondinsertcostmap(:,operationrouteindex) = newsecondinsertcostarr;
    end
    finalrouteset = removedrouteset;  
end

%% regret insert
function [completerouteset] = regretInsert(removednodeset, removedrouteset, capacityL, capacityB, noiseadd, noiseamount)
    % 每次选择最好的与次好的只差最大者所对应的节点插入到路径中
    % 其思想是：如果我现在不把这个节点插入，将来要付出更大的代价
    alreadyinsertposset = [];
    m = length(removednodeset);
    mark = ones(1,m);
    [bestinsertcostmap, bestinsertinfomap, secondinsertcostmap] =...
        computeInsertCostMap(removednodeset, removedrouteset, capacityL, capacityB, mark, noiseadd, noiseamount);
    while length(alreadyinsertposset) < length(removednodeset)
        
        % 先求出各个待插入节点的最小和次小代价
        % 次小代价可能是最小代价map中的次小代价，也可能是次小代价map中的最小代价，都要求出来
        if size(bestinsertcostmap,2) == 1  % 只有一条路径，则不会有bestmap的次小
            bestcostarr = bestinsertcostmap;
            secondcostarr1 = bestcostarr;
            secondcostarr2 = secondinsertcostmap;
        else
            tempbestmap = bestinsertcostmap'; % 按行求最小
            [bestcostarr, bestcostindex] = min(tempbestmap);
            tempbestmap(bestcostindex) = inf;       % 继续求次小(bestmap的次小，非最小路径)
            secondcostarr1 = min(tempbestmap);
            tempsecondmap = secondinsertcostmap';   % 求另一次小(secondmap中的最小)
            secondcostarr2 = min(tempsecondmap);
        end
        
        % 先看一下未插入节点中，是否有最佳插入代价为inf的，如果有，应该优先处理
        [infpos] = find(bestcostarr == inf);  % 找出最佳插入代价为inf的节点位置
        infpos = setdiff(infpos, alreadyinsertposset, 'stable');   % 注意已经插入到路径中的节点，其最小插入代价也是无穷大
        if length(infpos) ~= 0       % 也就是说，有一些节点已经没有可行插入位置，则应该优先为这些节点作安排，并新建路径
            selectednodepos = infpos(1);     % 随便选一个节点新建路径
            insertpointpos = -1;
        else
            
            % 所有的未插入节点都有可行插入位置，那么选取regret cost最大者进行插入 
            costdiffarr = max(abs(bestcostarr-secondcostarr1), abs(bestcostarr-secondcostarr2));    % 存放每个节点最好和最差插入代价之差
            costdiffarr(alreadyinsertposset) = -inf;       % 已经插入的节点，其代价差赋为-∞，防止再次被选中
            [maxdiff, maxdiffindex] = max(costdiffarr);
            selectednodepos = maxdiffindex(1);     % 当前regret cost最大的点的下标（在removednode中位置）
            [bestcost, bestcostindex] = min(bestinsertcostmap(selectednodepos, :));        % 选中节点的最小插入代价路径
            selectedrouteindex = bestcostindex(1);     % 选中的路径
            insertpointpos = bestinsertinfomap(selectednodepos, selectedrouteindex);       % 找出当前节点的最佳插入位置
            
            % 对于新插入的节点，使得其插入信息无效化，避免下次又被选中
            bestinsertcostmap(selectednodepos,:) = inf;  
            secondinsertcostmap(selectednodepos,:) = inf;
            bestinsertinfomap(selectednodepos,:) = -1;
        end
        alreadyinsertposset = [alreadyinsertposset, selectednodepos];  % 存放的是相对于removednode的下标
        selectednode = removednodeset(selectednodepos); % 此次被选中的节点
        
        % 然后把选中的节点插入到相应的路径中，并且更新该路径的信息
        if insertpointpos == -1    % 没有找到可行插入点，则新建一条路径
            newrouteindex = length(removedrouteset) + 1;
            depot = removedrouteset(1).route(1);
            depot.carindex = newrouteindex;
            selectednode.carindex = newrouteindex;
            newroutenode.route = [depot, selectednode, depot];
            newroutenode.nodeindex = [selectednode.index];
            if selectednode.type == 'L'
                newroutenode.quantityL = selectednode.quantity;
                newroutenode.quantityB = 0;
            else
                newroutenode.quantityB = selectednode.quantity;
                newroutenode.quantityL = 0;
            end
            newroutenode.index = newrouteindex;
            removedrouteset = [removedrouteset, newroutenode];
            operationroutenode = newroutenode;    % 新路径
            operationrouteindex = newrouteindex;  % 新路径编号
        else   % 有可行插入点
            selectednode.carindex = selectedrouteindex;   % 所属货车
            nodeindexincurroute = removedrouteset(selectedrouteindex).nodeindex;   % 当前路径中的节点编号          
            temp = [];
            temp = [temp, nodeindexincurroute(1:insertpointpos-1)];
            temp = [temp, selectednode.index];
            temp = [temp, nodeindexincurroute(insertpointpos:end)];
            removedrouteset(selectedrouteindex).nodeindex = temp;
            selectedroute = removedrouteset(selectedrouteindex).route;  % 路径中的节点
            temp = [];
            temp = [temp, selectedroute(1:insertpointpos)];
            temp = [temp, selectednode];
            temp = [temp, selectedroute(insertpointpos+1:end)];
            removedrouteset(selectedrouteindex).route = temp;
            switch selectednode.type
                case 'L'
                    removedrouteset(selectedrouteindex).quantityL = removedrouteset(selectedrouteindex).quantityL + selectednode.quantity;
                case 'B'
                    removedrouteset(selectedrouteindex).quantityB = removedrouteset(selectedrouteindex).quantityB + selectednode.quantity;
            end
            operationroutenode = removedrouteset(selectedrouteindex);
            operationrouteindex = selectedrouteindex;  % 插入的路径编号
        end
        
        % 对当前插入节点的路径，求所有未插入节点到该路径的最小/次小插入代价信息，并按需更新原有的最小/次小插入代价信息
        mark = ones(1,m);                 % 1表示节点还没有插入，0表示节点已经插入
        mark(alreadyinsertposset) = 0;    % 已经插入过的节点置为0
        [newbestinsertcostarr, newbestinsertinfoarr, newsecondinsertcostarr] =...
            computeInsertCostMap(removednodeset, operationroutenode, capacityL, capacityB, mark, noiseadd, noiseamount);
        bestinsertcostmap(:,operationrouteindex) = newbestinsertcostarr;
        bestinsertinfomap(:,operationrouteindex) = newbestinsertinfoarr;
        secondinsertcostmap(:,operationrouteindex) = newsecondinsertcostarr;
    end
    completerouteset = removedrouteset;
end

%% 附加函数
function [bestinsertcostmap, bestinsertinfomap, secondinsertcostmap] = computeInsertCostMap(removednodeset, removedrouteset, capacityL, capacityB, mark, noiseadd, noiseamount)
    % 计算removednodeset中节点插入到removedrouteset中的每条路径的最小和次小插入代价
    % bestinsertcostmap: 各个节点在各条路径中的最小插入代价，secondxxx为次小
    % bestinsertinfomap: 各个节点在各条路径的最小插入点信息，secondxxx为次小
    % 对于mark(i) = 0的节点i，表示其已经插入到了路径中，那么其最小插入代价和次小插入代价都为无穷大
    K = length(removedrouteset);  % 车辆数目
    m = length(removednodeset);   % 所有待插入点的数目（里面有一些节点可能已经插入，以mark为标记）
    bestinsertcostmap = inf(m,K);          % 各个待插入节点的最佳插入代价(对于已插入的节点，赋为无穷大)
    bestinsertinfomap = -1*ones(m,K);      % 每一列代表货车编号，而数值表示插入点位置
    secondinsertcostmap = inf(m,K);        % 各个待插入节点的次佳插入代价(对于已插入的节点，赋为无穷大)
    for i = 1:m
        if mark(i) == 1  % 只考虑尚未插入到路径中的节点
            curnode = removednodeset(i);  % 当前需要计算的节点
            for j = 1:K
                curroutenode = removedrouteset(j);
                curroute = curroutenode.route;
                mininsertcost = inf;
                mininsertpointpos = -1;     % 最小代价插入点位置（插入到此点后方）
                secondinsertcost = inf;
                for k = 1:length(curroute) - 1
                    insertnode = curroute(k);  % 插入点，插入到此点后方
                    successor = curroute(k+1);
                    switch curnode.type
                        case 'L'
                            if insertnode.type == 'D' || insertnode.type == 'L' % 是可插入点
                                if curroutenode.quantityL + curnode.quantity < capacityL  % 满足容量约束
                                    if timeWindowJudge(k, curroute, curnode) == 1   % 满足时间窗约束
                                        temp = sqrt((insertnode.cx-curnode.cx)^2 + (insertnode.cy-curnode.cy)^2) +...
                                               sqrt((successor.cx-curnode.cx)^2 + (successor.cy-curnode.cy)^2) -...
                                               sqrt((insertnode.cx-successor.cx)^2 + (insertnode.cy-successor.cy)^2);
                                        if noiseadd == 1
                                            noise = -noiseamount + 2*noiseamount*rand;
                                            temp = max(temp + noise,0);
                                        end
                                        if temp <= mininsertcost
                                            secondinsertcost = mininsertcost;  % 原来“最好的”变成了“次好的”  
                                            mininsertcost = temp;           
                                            mininsertpointpos = k;    % 插入点
                                        end
                                    end
                                end
                            end
                        case 'B'
                            if insertnode.type == 'L' && successor.type == 'B' || insertnode.type == 'L' && successor.type == 'D' ||insertnode.type == 'B'
                                if curroutenode.quantityB + curnode.quantity < capacityB  % 满足容量约束
                                    if timeWindowJudge(k, curroute, curnode) == 1   % 满足时间窗约束
                                        temp = sqrt((insertnode.cx-curnode.cx)^2 + (insertnode.cy-curnode.cy)^2) +...
                                               sqrt((successor.cx-curnode.cx)^2 + (successor.cy-curnode.cy)^2) -...
                                               sqrt((insertnode.cx-successor.cx)^2 + (insertnode.cy-successor.cy)^2);
                                        if noiseadd == 1
                                            noise = -noiseamount + 2*noiseamount*rand;
                                            temp = max(temp + noise,0);
                                        end   
                                        if temp <= mininsertcost
                                            secondinsertcost = mininsertcost;  % 原来“最好的”变成了“次好的”  
                                            mininsertcost = temp;           
                                            mininsertpointpos = k;    % 插入点
                                        end
                                    end
                                end
                            end
                    end                
                end
                bestinsertcostmap(i,j) = mininsertcost;          
                bestinsertinfomap(i,j) = mininsertpointpos;   % 第一行是最佳插入代价对应的路径编号，第二行是插入点编号
                secondinsertcostmap(i,j) = secondinsertcost; 
            end        
        end
    end
end
        
function [mark] = timeWindowJudge(insertpointpos, route, newcustomer)
    % 判断新插入的客户点是否会使得后续节点的时间窗约束被违反
    time = 0;  % 当前时间为0
    temp = [];
    temp = [temp, route(1:insertpointpos)];
    temp = [temp newcustomer];
    temp = [temp route(insertpointpos + 1:end)];
    route = temp;
    mark = 1;  % 为0表示违反约束
    for i = 1:length(route)-2
        predecessor = route(i); % 前继节点
        successor = route(i+1); % 后继节点
        if (i < insertpointpos) % 在插入点之前的顾客的时间窗都没有受到影响，不需要进行判断
            time = time + sqrt((predecessor.cx - successor.cx)^2 + (predecessor.cy - successor.cy)^2); % 车辆运行时间
            if (time < successor.start_time)  % 车辆在时间窗开始前到达
                time = successor.start_time;
            end
            time = time + successor.service_time;   % 服务时间
        else
            % 插入点之后的顾客的时间窗会受到影响，需要进行判断
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

%% --------------------- 其余的附加函数 ------------------------- %%
function [code] = routecode(routeset)
    % 将codepath进行编码
    code = '';
    for i = 1:length(routeset)
        nodeindexarr = routeset(i).nodeindex;
        for j = 1:length(nodeindexarr)
            code = strcat(code, num2str(nodeindexarr(j)));
        end
    end
end

function [cost] = routecost(routeset)
    % 计算path的总路长
    cost = 0;
    for i = 1:length(routeset)
        curroute = routeset(i).route;
        for j = 1:length(curroute)-1
            front = curroute(j);
            back = curroute(j+1);
            cost = cost + sqrt((front.cx-back.cx)^2+(front.cy-back.cy)^2);
        end
    end
end

function [result] = removeNullRoute(routeset, depot)
    % 移除掉routeset中的空路径
    removedindex = [];  % 要移除的route在routeset中的下标
    for i = 1:length(routeset)
        if length(routeset(i).nodeindex) == 0
            removedindex = [removedindex, i];
        end
    end
    routeset(removedindex) = [];  % 去掉空路径
    for i = 1:length(routeset)    % 重新标记routeset中各节点的车辆编号
        routeset(i).index = i;
        curroute = routeset(i).route;
        for j = 1:length(curroute)
            curroute(j).carindex = i;
        end
        routeset(i).route = curroute;
    end
    if isempty(routeset)    % 移除后路径为空
        routeset = [];
        depot.carindex = 1;
        depot.arrival_time = 0;
        routenode.route = [depot depot];
        routenode.index = 1;
        routenode.quantityL = 0;
        routenode.quantityB = 0;
        routenode.nodeindex = [];
        routeset = [routeset routenode];
    end
    result = routeset;
end

function [difftmax] = countMaxValue(routeset)
    % 计算path中的最晚货车到达时间以及最长距离
    tmax = -inf;
    tmin = inf;
    for i = 1:length(routeset)
        curroute = routeset(i).route;
        if curroute(2).arrival_time < tmin
            time = curroute(2).arrival_time;
        end
        time = 0;
        if length(curroute) > 2   % 空路径不计算
            for j = 2:length(curroute) - 1
                predecessor = curroute(j-1);
                successor = curroute(j);
                time = time + sqrt((predecessor.cx-successor.cx)^2 + (predecessor.cy-successor.cy)^2);
                if time < successor.start_time
                    time = successor.start_time;
                end
                time = time + successor.service_time;
            end
            time = time - successor.service_time;  % 最后一个节点的服务时间不算
            if time > tmax
                tmax = time;
            end
        end
    end
    difftmax = tmax - tmin;
end

function [finalrouteset] = updateArrivalTime(initialrouteset)
    % 每次调用shaw removal的时候，都需要更新arrival time
    for i = 1:length(initialrouteset)
        curroute = initialrouteset(i).route;
        currenttime = 0;
        for j = 2:length(curroute)-1  % 首尾都是仓库
            predecessor = curroute(j-1);
            successor = curroute(j);
            currenttime = currenttime + sqrt((predecessor.cx-successor.cx)^2 + (predecessor.cy-successor.cy)^2);
            curroute(j).arrival_time = currenttime;
            if currenttime < successor.start_time
                currenttime = successor.start_time;
            end
            currenttime = currenttime + successor.service_time;
        end
        initialrouteset(i).route = curroute;
    end
    finalrouteset = initialrouteset;
end

%% ------------------ 调试的时候用到的函数 ------------------- %%
function [nodeindex1, nodeindex2] = showNodeindexInRouteSet(routeset)
    % 将routeset中的节点编号取出来
    % nodeindex1取的是routeset(x).nodeindex
    % nodeindex2取的是routeset(x).route.node.index
    nodeindex1 = [];
    nodeindex2 = [];
    for i = 1:length(routeset)
        nodeindex1 = [nodeindex1, routeset(i).nodeindex];
        for j = 2:length(routeset(i).route) - 1
            nodeindex2 = [nodeindex2, routeset(i).route(j).index];
        end
    end
end

function [nodeindex] = showNodeindexInNodeSet(nodeset)
    nodeindex = [];
    for i = 1:length(nodeset)
        nodeindex = [nodeindex, nodeset(i).index];
    end
end


        

            
